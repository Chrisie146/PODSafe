import React, { useEffect, useMemo, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useAuthStore } from '../../stores/useAuthStore';
import { useDeliveryStore } from '../../stores/useDeliveryStore';
import { useCustomerStore } from '../../stores/useCustomerStore';
import { AuthRepository } from '../../repositories/authRepository';
import { VehicleRepository } from '../../repositories/vehicleRepository';
import {
  createUploadToken,
  generateUploadLink,
} from '../../repositories/externalUploadService';
import { sendNotificationToUser } from '../../repositories/notificationService';
import { normalizeRegistration } from '../../utils/vehicleUtils';
import CustomerAutocomplete from '../../components/CustomerAutocomplete';
import { AppUser } from '../../models/user';
import { Vehicle } from '../../models/vehicle';
import { Customer } from '../../models/customer';
import { Delivery, DeliveryItem } from '../../models/delivery';
import {
  AppIcon,
  FormField,
  IconButton,
  LoadingState,
  PrimaryButton,
  SecondaryButton,
} from '../../components/ui';
import { colors, spacing, radii, shadows } from '../../theme/tokens';
import { textStyles } from '../../theme/textStyles';

/**
 * Ported from lib/screens/admin/create_delivery_screen.dart (verified against source on
 * 2026-06-23) — the Wizard (single-entry, 3-step) mode only, the Dart source's default.
 * Per explicit user direction, Table mode (spreadsheet-style multi-row entry) and Rapid
 * Entry (fast sequential queue) are NOT ported — both are fully-implemented alternate
 * UX paths in the Dart source, together roughly as large as everything else ported this
 * session. BulkUpload.tsx/AbaserveImport.tsx already cover CSV-based bulk creation as a
 * different path to a similar end. The popup menu's "Bulk Table Entry"/"Rapid Entry
 * Mode" items are dropped along with it; "Bulk Import CSV"/"Download CSV Template"
 * remain (they navigate to/reuse already-ported screens).
 *
 * Other deviations from the Flutter source:
 * - Edit mode takes only `deliveryId` via route params and loads the full delivery
 *   through useDeliveryStore.loadDeliveryById(), instead of requiring the caller to pass
 *   the full Delivery object — same deep-link/refresh-safety precedent as
 *   DriverDetails.tsx/CreateDriver.tsx.
 * - CatalogProvider initialization is not ported: grep-confirmed the catalog/item-lookup
 *   feature has no consumer in this screen's actual Wizard-mode item dialog (manual
 *   description/quantity/unit/price entry only) — it's only used by Table mode's add-item
 *   dialog, which isn't ported here either.
 * - Scheduled/invoice dates use a plain `YYYY-MM-DD` text field instead of a native date
 *   picker, same convention as BulkUpload.tsx (no date-picker package installed anywhere
 *   in this project; this migration's first date-editing UI).
 * - Driver loading reuses AuthRepository.getUsersByCompany() (role: 'driver') instead of
 *   a raw query, then applies the same approval-status filter (exclude only 'rejected')
 *   as the Dart source. Vehicle loading reuses VehicleRepository.subscribeToVehicles()
 *   (already company-wide, matching the Dart source's own un-driver-scoped query despite
 *   its `_subscribeToVehiclesForDriver` name) with a client-side `status === 'active'`
 *   filter, since that repository doesn't take a status filter param yet.
 */
interface CreateDeliveryProps {
  route: { params?: { deliveryId?: string } };
  navigation: { goBack: () => void; navigate: (screen: string) => void };
}

const authRepository = new AuthRepository();
const vehicleRepository = new VehicleRepository();

function formatLongDate(date: Date): string {
  return date.toLocaleDateString(undefined, {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
}

export default function CreateDelivery({
  route,
  navigation,
}: CreateDeliveryProps) {
  const deliveryId = route.params?.deliveryId;
  const isEditing = !!deliveryId;

  const currentUser = useAuthStore(s => s.currentUser);
  const selectedDelivery = useDeliveryStore(s => s.selectedDelivery);
  const loadDeliveryById = useDeliveryStore(s => s.loadDeliveryById);
  const createDelivery = useDeliveryStore(s => s.createDelivery);
  const updateDelivery = useDeliveryStore(s => s.updateDelivery);
  const customers = useCustomerStore(s => s.customers);
  const initializeCustomers = useCustomerStore(s => s.initialize);

  const [currentStep, setCurrentStep] = useState(0);
  const [isLoadingDelivery, setIsLoadingDelivery] = useState(isEditing);
  const [isSaving, setIsSaving] = useState(false);

  const [customerName, setCustomerName] = useState('');
  const [customerAddress, setCustomerAddress] = useState('');
  const [customerPhone, setCustomerPhone] = useState('');
  const [orderNumber, setOrderNumber] = useState('');
  const [invoiceNumber, setInvoiceNumber] = useState('');
  const [notes, setNotes] = useState('');
  const [scheduledDateText, setScheduledDateText] = useState(
    new Date().toISOString().slice(0, 10),
  );
  const [invoiceDateText, setInvoiceDateText] = useState('');
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(
    null,
  );
  const [selectedCustomerId, setSelectedCustomerId] = useState<
    string | undefined
  >(undefined);
  const [selectedCustomerNumber, setSelectedCustomerNumber] = useState<
    string | undefined
  >(undefined);

  const [items, setItems] = useState<DeliveryItem[]>([]);
  const [itemDialog, setItemDialog] = useState<{ index: number | null } | null>(
    null,
  );

  const [isThirdPartyTransport, setIsThirdPartyTransport] = useState(false);
  const [thirdPartyProvider, setThirdPartyProvider] = useState('');
  const [thirdPartyDriver, setThirdPartyDriver] = useState('');
  const [thirdPartyPhone, setThirdPartyPhone] = useState('');
  const [thirdPartyVehicle, setThirdPartyVehicle] = useState('');

  const [drivers, setDrivers] = useState<AppUser[] | null>(null);
  const [selectedDriverId, setSelectedDriverId] = useState<string | undefined>(
    undefined,
  );
  const [vehicles, setVehicles] = useState<Vehicle[]>([]);
  const [isLoadingVehicles, setIsLoadingVehicles] = useState(false);
  const [selectedVehicle, setSelectedVehicle] = useState<string | undefined>(
    undefined,
  );

  const [instructionsModal, setInstructionsModal] = useState<string | null>(
    null,
  );
  const [uploadLinkModal, setUploadLinkModal] = useState<string | null>(null);

  useEffect(() => {
    if (!currentUser) return;
    authRepository
      .getUsersByCompany(currentUser.companyId, { role: 'driver' })
      .then(users =>
        setDrivers(users.filter(u => u.approvalStatus !== 'rejected')),
      )
      .catch(() => setDrivers([]));

    if (customers.length === 0) {
      initializeCustomers(currentUser.companyId);
    }
  }, [currentUser, customers.length, initializeCustomers]);

  useEffect(() => {
    if (!selectedDriverId || !currentUser) {
      setVehicles([]);
      return;
    }
    setIsLoadingVehicles(true);
    const unsubscribe = vehicleRepository.subscribeToVehicles(
      currentUser.companyId,
      allVehicles => {
        const active = allVehicles.filter(v => v.status === 'active');
        setVehicles(active);
        setIsLoadingVehicles(false);
        setSelectedVehicle(prev =>
          prev && active.some(v => v.registration === prev)
            ? prev
            : active[0]?.registration,
        );
      },
      () => setIsLoadingVehicles(false),
    );
    return unsubscribe;
  }, [selectedDriverId, currentUser]);

  useEffect(() => {
    if (deliveryId) {
      loadDeliveryById(deliveryId);
    }
  }, [deliveryId, loadDeliveryById]);

  useEffect(() => {
    if (!isEditing || !selectedDelivery) return;
    setCustomerName(selectedDelivery.customerName);
    setCustomerAddress(selectedDelivery.customerAddress);
    setCustomerPhone(selectedDelivery.customerPhone ?? '');
    setOrderNumber(selectedDelivery.orderNumber ?? '');
    setInvoiceNumber(selectedDelivery.invoiceNumber);
    setNotes(selectedDelivery.notes ?? '');
    setScheduledDateText(
      selectedDelivery.scheduledDate.toISOString().slice(0, 10),
    );
    setInvoiceDateText(
      selectedDelivery.invoiceDate
        ? selectedDelivery.invoiceDate.toISOString().slice(0, 10)
        : '',
    );
    setSelectedCustomerNumber(selectedDelivery.customerNumber);
    setItems(selectedDelivery.items);
    setSelectedDriverId(
      selectedDelivery.driverId === 'third-party'
        ? undefined
        : selectedDelivery.driverId,
    );
    setSelectedVehicle(selectedDelivery.vehicleUsed);
    setIsThirdPartyTransport(selectedDelivery.isThirdPartyTransport);
    setIsLoadingDelivery(false);
  }, [isEditing, selectedDelivery]);

  const scheduledDate = useMemo(() => {
    const parsed = new Date(scheduledDateText);
    return Number.isNaN(parsed.getTime()) ? new Date() : parsed;
  }, [scheduledDateText]);

  const invoiceDate = useMemo(() => {
    if (!invoiceDateText) return undefined;
    const parsed = new Date(invoiceDateText);
    return Number.isNaN(parsed.getTime()) ? undefined : parsed;
  }, [invoiceDateText]);

  const handleSelectCustomer = (customer: Customer | null) => {
    setSelectedCustomer(customer);
    if (customer) {
      setCustomerName(customer.name);
      setCustomerAddress(customer.address);
      setCustomerPhone(customer.phone ?? '');
      setSelectedCustomerId(customer.id);
      setSelectedCustomerNumber(customer.customerNumber);
      if (customer.deliveryInstructions) {
        setInstructionsModal(customer.deliveryInstructions);
      }
    } else {
      setSelectedCustomerId(undefined);
    }
  };

  const handleNextStep = () => {
    if (currentStep === 0) {
      if (customerName.trim().length === 0) {
        Alert.alert('Notice', 'Please enter a customer name');
        return;
      }
      if (customerAddress.trim().length === 0) {
        Alert.alert('Notice', 'Please enter a delivery address');
        return;
      }
    } else if (currentStep === 1) {
      if (items.length === 0) {
        Alert.alert('Notice', 'Please add at least one item');
        return;
      }
    }
    if (currentStep < 2) setCurrentStep(s => s + 1);
  };

  const handlePrevStep = () => setCurrentStep(s => Math.max(0, s - 1));

  const handleSelectDriver = (driverId: string | undefined) => {
    setSelectedDriverId(driverId);
    setSelectedVehicle(undefined);
  };

  const handleSaveItem = (item: DeliveryItem, index: number | null) => {
    setItems(prev => {
      if (index != null) {
        const next = [...prev];
        next[index] = item;
        return next;
      }
      return [...prev, item];
    });
    setItemDialog(null);
  };

  const handleSave = async () => {
    if (!currentUser) return;

    if (!isThirdPartyTransport && !selectedDriverId) {
      Alert.alert('Notice', 'Please select a driver');
      return;
    }
    if (items.length === 0) {
      Alert.alert('Notice', 'Please add at least one item');
      return;
    }
    if (invoiceNumber.trim().length === 0) {
      Alert.alert('Notice', 'Invoice number is required');
      return;
    }
    if (isThirdPartyTransport && thirdPartyProvider.trim().length === 0) {
      Alert.alert('Notice', 'Provider name is required');
      return;
    }

    setIsSaving(true);
    try {
      const delivery: Delivery = {
        id: isEditing && selectedDelivery ? selectedDelivery.id : '',
        companyId: currentUser.companyId,
        driverId: isThirdPartyTransport ? 'third-party' : selectedDriverId!,
        customerName: customerName.trim(),
        customerAddress: customerAddress.trim(),
        customerPhone: customerPhone.trim() || undefined,
        customerId: selectedCustomerId,
        customerNumber: selectedCustomerNumber,
        orderNumber: orderNumber.trim() || undefined,
        invoiceNumber: invoiceNumber.trim(),
        invoiceDate,
        items,
        vehicleUsed: isThirdPartyTransport
          ? undefined
          : selectedVehicle
          ? normalizeRegistration(selectedVehicle)
          : undefined,
        isThirdPartyTransport,
        thirdPartyProviderName: isThirdPartyTransport
          ? thirdPartyProvider.trim()
          : undefined,
        thirdPartyDriverName: isThirdPartyTransport
          ? thirdPartyDriver.trim() || undefined
          : undefined,
        thirdPartyDriverPhone: isThirdPartyTransport
          ? thirdPartyPhone.trim() || undefined
          : undefined,
        thirdPartyVehicleInfo: isThirdPartyTransport
          ? thirdPartyVehicle.trim() || undefined
          : undefined,
        status: 'pending',
        scheduledDate,
        createdAt:
          isEditing && selectedDelivery
            ? selectedDelivery.createdAt
            : new Date(),
        notes: notes.trim() || undefined,
      };

      if (isEditing) {
        const ok = await updateDelivery(delivery);
        if (!ok)
          throw new Error(
            useDeliveryStore.getState().errorMessage ??
              'Failed to update delivery',
          );
        Alert.alert('Success', 'Delivery updated successfully!');
        navigation.goBack();
        return;
      }

      const ok = await createDelivery(delivery);
      if (!ok)
        throw new Error(
          useDeliveryStore.getState().errorMessage ??
            'Failed to create delivery',
        );
      const newDeliveryId = useDeliveryStore.getState().selectedDelivery?.id;
      if (!newDeliveryId)
        throw new Error('Delivery created but no ID was returned');

      if (isThirdPartyTransport) {
        const token = await createUploadToken({
          deliveryId: newDeliveryId,
          companyId: currentUser.companyId,
          providerName: thirdPartyProvider.trim(),
          providerContact: thirdPartyPhone.trim() || undefined,
          expiryDays: 14,
        });
        setUploadLinkModal(generateUploadLink(token.id));
      } else if (selectedDriverId) {
        await sendNotificationToUser({
          userId: selectedDriverId,
          title: '🚚 New Delivery Assignment',
          body: `Delivery to ${customerName.trim()} scheduled for ${scheduledDate.toLocaleDateString()}`,
          data: {
            type: 'delivery_assigned',
            deliveryId: newDeliveryId,
            customerName: customerName.trim(),
            customerAddress: customerAddress.trim(),
            itemCount: String(items.length),
            scheduledDate: scheduledDate.toISOString(),
            priority: 'high',
          },
        });
        Alert.alert('Success', 'Delivery created successfully!');
        navigation.goBack();
      } else {
        Alert.alert('Success', 'Delivery created successfully!');
        navigation.goBack();
      }
    } catch (e) {
      Alert.alert('Error', (e as Error).message);
    } finally {
      setIsSaving(false);
    }
  };

  if (isLoadingDelivery) {
    return (
      <View style={styles.centered}>
        <LoadingState
          title="Loading delivery"
          message="Preparing the delivery workflow."
        />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <StepIndicator
        currentStep={currentStep}
        onStepTap={step => step < currentStep && setCurrentStep(step)}
      />

      {currentStep === 0 ? (
        <ScrollView contentContainerStyle={styles.stepContent}>
          <Text style={textStyles.heading3}>Who are we delivering to?</Text>
          <View style={styles.gap} />
          <CustomerAutocomplete
            initialCustomer={selectedCustomer}
            onCustomerSelected={handleSelectCustomer}
            labelText="Search Customer"
            hintText="Search by name or customer number..."
          />
          <View style={styles.gap} />
          <LabeledInput
            label="Customer Name *"
            value={customerName}
            onChangeText={setCustomerName}
          />
          {selectedCustomer ? (
            <Text style={styles.helperTextOk}>
              From: {selectedCustomer.customerNumber}
            </Text>
          ) : (
            <Text style={styles.helperText}>Or type a name manually</Text>
          )}
          <View style={styles.gap} />
          <LabeledInput
            label="Delivery Address *"
            value={customerAddress}
            onChangeText={setCustomerAddress}
            multiline
          />
          <View style={styles.gap} />
          <LabeledInput
            label="Phone Number (Optional)"
            value={customerPhone}
            onChangeText={setCustomerPhone}
            keyboardType="phone-pad"
          />
          <View style={styles.gapLarge} />
          <View style={styles.stepButtonRow}>
            <PrimaryButton
              label="Next: items"
              icon="arrowRight"
              onPress={handleNextStep}
            />
          </View>
        </ScrollView>
      ) : null}

      {currentStep === 1 ? (
        <View style={styles.stepFlexColumn}>
          {customerName ? (
            <View style={styles.bannerBar}>
              <Text style={styles.bannerText}>
                Delivering to: {customerName}
              </Text>
            </View>
          ) : null}
          <ScrollView contentContainerStyle={styles.stepContent}>
            <View style={styles.rowBetween}>
              <Text style={textStyles.heading3}>What are we delivering?</Text>
              <PrimaryButton
                label="Add item"
                icon="plus"
                onPress={() => setItemDialog({ index: null })}
              />
            </View>
            <View style={styles.gap} />
            {items.length === 0 ? (
              <View style={[styles.card, shadows.card, styles.emptyItemsCard]}>
                <AppIcon
                  name="package"
                  size={36}
                  color={colors.contentSecondary}
                />
                <Text style={styles.emptyItemsText}>No items added yet</Text>
                <Text style={styles.emptyItemsHint}>
                  Tap &quot;Add Item&quot; to add products to this delivery
                </Text>
              </View>
            ) : (
              items.map((item, index) => (
                <View
                  key={index}
                  style={[styles.card, shadows.card, styles.itemRow]}
                >
                  <View style={styles.itemQtyBadge}>
                    <Text style={styles.itemQtyText}>
                      {item.quantity % 1 === 0
                        ? item.quantity.toString()
                        : item.quantity.toFixed(2)}
                    </Text>
                  </View>
                  <View style={styles.itemTextBox}>
                    <Text style={styles.itemDescription}>
                      {item.description}
                    </Text>
                    {item.unit || item.unitPrice != null ? (
                      <Text style={styles.itemSubtitle}>
                        {[
                          item.unit,
                          item.unitPrice != null
                            ? `R${item.unitPrice.toFixed(2)} each`
                            : undefined,
                        ]
                          .filter(Boolean)
                          .join(' · ')}
                      </Text>
                    ) : null}
                  </View>
                  <IconButton
                    icon="edit"
                    accessibilityLabel={`Edit ${item.description}`}
                    onPress={() => setItemDialog({ index })}
                  />
                  <IconButton
                    icon="trash"
                    accessibilityLabel={`Remove ${item.description}`}
                    color={colors.critical}
                    onPress={() =>
                      setItems(prev => prev.filter((_, i) => i !== index))
                    }
                  />
                </View>
              ))
            )}
          </ScrollView>
          <View style={styles.stepButtonRow}>
            <SecondaryButton
              label="Back"
              icon="arrowLeft"
              onPress={handlePrevStep}
            />
            <View style={styles.spacer} />
            {items.length > 0 ? (
              <Text style={styles.itemCountText}>
                {items.length} item{items.length === 1 ? '' : 's'}
              </Text>
            ) : null}
            <PrimaryButton
              label="Next: schedule"
              icon="arrowRight"
              onPress={handleNextStep}
            />
          </View>
        </View>
      ) : null}

      {currentStep === 2 ? (
        <View style={styles.stepFlexColumn}>
          {customerName ? (
            <View style={styles.bannerBar}>
              <Text style={styles.bannerText}>
                {customerName} · {items.length} item
                {items.length === 1 ? '' : 's'}
              </Text>
            </View>
          ) : null}
          <ScrollView contentContainerStyle={styles.stepContent}>
            <Text style={textStyles.heading3}>When & How?</Text>
            <View style={styles.gap} />
            <LabeledInput
              label="Invoice Number *"
              value={invoiceNumber}
              onChangeText={setInvoiceNumber}
            />
            <View style={styles.gap} />
            <LabeledInput
              label="Scheduled Date * (YYYY-MM-DD)"
              value={scheduledDateText}
              onChangeText={setScheduledDateText}
            />
            <Text style={styles.helperText}>
              {formatLongDate(scheduledDate)}
            </Text>
            <View style={styles.gapLarge} />

            <Text style={styles.fieldLabel}>Transport Method</Text>
            <View style={styles.gap} />
            <View style={[styles.card, shadows.card]}>
              <RadioRow
                label="Own Fleet"
                subtitle="Assign to your driver and vehicle"
                selected={!isThirdPartyTransport}
                onPress={() => setIsThirdPartyTransport(false)}
              />
              <Divider />
              <RadioRow
                label="Third-Party Transport"
                subtitle="External transport company"
                selected={isThirdPartyTransport}
                onPress={() => setIsThirdPartyTransport(true)}
              />
            </View>
            <View style={styles.gapLarge} />

            {!isThirdPartyTransport ? (
              <>
                <Text style={styles.fieldLabel}>Assign Driver *</Text>
                {drivers === null ? (
                  <ActivityIndicator color={colors.primary} />
                ) : (
                  <View style={styles.chipRow}>
                    {drivers.map(driver => (
                      <Pressable
                        key={driver.id}
                        style={[
                          styles.chip,
                          selectedDriverId === driver.id && styles.chipSelected,
                        ]}
                        onPress={() => handleSelectDriver(driver.id)}
                      >
                        <Text
                          style={[
                            styles.chipText,
                            selectedDriverId === driver.id &&
                              styles.chipTextSelected,
                          ]}
                        >
                          {driver.fullName}
                        </Text>
                      </Pressable>
                    ))}
                  </View>
                )}
                {selectedDriverId ? (
                  <>
                    <View style={styles.gap} />
                    {isLoadingVehicles ? (
                      <Text style={styles.helperText}>Loading vehicles...</Text>
                    ) : vehicles.length === 0 ? (
                      <Text style={styles.helperText}>
                        No active vehicles available
                      </Text>
                    ) : (
                      <>
                        <Text style={styles.fieldLabel}>Select Vehicle</Text>
                        <View style={styles.chipRow}>
                          {vehicles.map(vehicle => {
                            const details = [vehicle.make, vehicle.model]
                              .filter(Boolean)
                              .join(' ');
                            return (
                              <Pressable
                                key={vehicle.id}
                                style={[
                                  styles.chip,
                                  selectedVehicle === vehicle.registration &&
                                    styles.chipSelected,
                                ]}
                                onPress={() =>
                                  setSelectedVehicle(vehicle.registration)
                                }
                              >
                                <Text
                                  style={[
                                    styles.chipText,
                                    selectedVehicle === vehicle.registration &&
                                      styles.chipTextSelected,
                                  ]}
                                >
                                  {vehicle.registration}
                                  {details ? ` · ${details}` : ''}
                                </Text>
                              </Pressable>
                            );
                          })}
                        </View>
                      </>
                    )}
                  </>
                ) : null}
              </>
            ) : (
              <View style={[styles.card, shadows.card, styles.thirdPartyCard]}>
                <View style={styles.thirdPartyHeading}>
                  <AppIcon
                    name="truck"
                    size={20}
                    color={colors.contentPrimary}
                  />
                  <Text style={styles.thirdPartyTitle}>
                    Third-party transport details
                  </Text>
                </View>
                <View style={styles.gap} />
                <LabeledInput
                  label="Provider Name *"
                  value={thirdPartyProvider}
                  onChangeText={setThirdPartyProvider}
                  placeholder="e.g., HFR Transport"
                />
                <View style={styles.gap} />
                <LabeledInput
                  label="Driver Name (Optional)"
                  value={thirdPartyDriver}
                  onChangeText={setThirdPartyDriver}
                />
                <View style={styles.gap} />
                <LabeledInput
                  label="Driver Phone (Optional)"
                  value={thirdPartyPhone}
                  onChangeText={setThirdPartyPhone}
                  keyboardType="phone-pad"
                />
                <View style={styles.gap} />
                <LabeledInput
                  label="Vehicle Info (Optional)"
                  value={thirdPartyVehicle}
                  onChangeText={setThirdPartyVehicle}
                  placeholder="Registration or description"
                />
                <View style={styles.gap} />
                <View style={styles.infoNote}>
                  <AppIcon name="info" size={18} color={colors.shell} />
                  <Text style={styles.infoNoteText}>
                    An upload link will be generated for this provider to submit
                    POD documents.
                  </Text>
                </View>
              </View>
            )}
            <View style={styles.gapLarge} />

            <LabeledInput
              label="Order Number (Optional)"
              value={orderNumber}
              onChangeText={setOrderNumber}
            />
            <View style={styles.gap} />
            <LabeledInput
              label="Invoice Date (YYYY-MM-DD, Optional)"
              value={invoiceDateText}
              onChangeText={setInvoiceDateText}
            />
            <View style={styles.gap} />
            <LabeledInput
              label="Notes"
              value={notes}
              onChangeText={setNotes}
              multiline
            />
            <View style={styles.gapLarge} />

            <PrimaryButton
              label={isEditing ? 'Update delivery' : 'Create delivery'}
              icon={isEditing ? 'edit' : 'plus'}
              loading={isSaving}
              onPress={handleSave}
              style={styles.saveButton}
            />
          </ScrollView>
          <View style={styles.stepButtonRow}>
            <SecondaryButton
              label="Back"
              icon="arrowLeft"
              onPress={handlePrevStep}
            />
          </View>
        </View>
      ) : null}

      {itemDialog ? (
        <ItemDialog
          existingItem={
            itemDialog.index != null ? items[itemDialog.index] : null
          }
          onCancel={() => setItemDialog(null)}
          onSave={item => handleSaveItem(item, itemDialog.index)}
        />
      ) : null}

      {instructionsModal ? (
        <Modal
          visible
          transparent
          animationType="fade"
          onRequestClose={() => setInstructionsModal(null)}
        >
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Delivery instructions</Text>
              <Text style={styles.helperText}>
                Special instructions for this customer:
              </Text>
              <View style={styles.infoNote}>
                <Text style={styles.instructionsText}>{instructionsModal}</Text>
              </View>
              <Pressable
                style={styles.modalCloseButton}
                onPress={() => setInstructionsModal(null)}
              >
                <Text style={textStyles.buttonText}>Got it!</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}

      {uploadLinkModal ? (
        <Modal visible transparent animationType="fade">
          <View style={styles.modalBackdrop}>
            <View style={[styles.modalCard, shadows.card]}>
              <Text style={textStyles.heading3}>Upload link generated</Text>
              <Text style={styles.helperText}>
                Delivery created successfully! Share this link with the
                transport provider to upload POD documents:
              </Text>
              <View style={styles.infoNote}>
                <Text selectable style={styles.instructionsText}>
                  {uploadLinkModal}
                </Text>
              </View>
              <Pressable
                style={styles.modalCloseButton}
                onPress={() => {
                  setUploadLinkModal(null);
                  navigation.goBack();
                }}
              >
                <Text style={textStyles.buttonText}>Done</Text>
              </Pressable>
            </View>
          </View>
        </Modal>
      ) : null}
    </View>
  );
}

function StepIndicator({
  currentStep,
  onStepTap,
}: {
  currentStep: number;
  onStepTap: (step: number) => void;
}) {
  return (
    <View style={styles.stepIndicatorRow}>
      <StepChip
        step={0}
        label="Customer"
        currentStep={currentStep}
        onPress={onStepTap}
      />
      <View
        style={[
          styles.stepDivider,
          currentStep > 0 && styles.stepDividerActive,
        ]}
      />
      <StepChip
        step={1}
        label="Items"
        currentStep={currentStep}
        onPress={onStepTap}
      />
      <View
        style={[
          styles.stepDivider,
          currentStep > 1 && styles.stepDividerActive,
        ]}
      />
      <StepChip
        step={2}
        label="Schedule"
        currentStep={currentStep}
        onPress={onStepTap}
      />
    </View>
  );
}

function StepChip({
  step,
  label,
  currentStep,
  onPress,
}: {
  step: number;
  label: string;
  currentStep: number;
  onPress: (step: number) => void;
}) {
  const isActive = currentStep === step;
  const isCompleted = currentStep > step;
  const color = isCompleted
    ? colors.success
    : isActive
    ? colors.primary
    : colors.divider;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`${label}${
        isCompleted ? ', complete' : isActive ? ', current step' : ''
      }`}
      accessibilityState={{ selected: isActive }}
      style={styles.stepChipContainer}
      onPress={() => onPress(step)}
    >
      <View style={[styles.stepCircle, { backgroundColor: color }]}>
        {isCompleted ? (
          <AppIcon name="check" size={18} color={colors.onPrimary} />
        ) : (
          <Text style={styles.stepCircleText}>{step + 1}</Text>
        )}
      </View>
      <Text
        style={[
          styles.stepLabel,
          { color },
          isActive && styles.stepLabelActive,
        ]}
      >
        {label}
      </Text>
    </Pressable>
  );
}

function RadioRow({
  label,
  subtitle,
  selected,
  onPress,
}: {
  label: string;
  subtitle: string;
  selected: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityLabel={label}
      accessibilityState={{ selected }}
      style={styles.radioRow}
      onPress={onPress}
    >
      <View
        style={[
          styles.radioIndicator,
          selected && styles.radioIndicatorSelected,
        ]}
      >
        {selected ? (
          <AppIcon name="check" size={14} color={colors.onPrimary} />
        ) : null}
      </View>
      <View style={styles.radioTextBox}>
        <Text style={styles.radioLabel}>{label}</Text>
        <Text style={styles.radioSubtitle}>{subtitle}</Text>
      </View>
    </Pressable>
  );
}

function Divider() {
  return <View style={styles.dividerLine} />;
}

function LabeledInput({
  label,
  value,
  onChangeText,
  ...rest
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
} & React.ComponentProps<typeof TextInput>) {
  return (
    <FormField
      label={label}
      value={value}
      onChangeText={onChangeText}
      inputStyle={rest.multiline ? styles.inputMultiline : undefined}
      {...rest}
    />
  );
}

function ItemDialog({
  existingItem,
  onCancel,
  onSave,
}: {
  existingItem: DeliveryItem | null | undefined;
  onCancel: () => void;
  onSave: (item: DeliveryItem) => void;
}) {
  const [description, setDescription] = useState(
    existingItem?.description ?? '',
  );
  const [quantity, setQuantity] = useState(
    existingItem ? String(existingItem.quantity) : '1',
  );
  const [unit, setUnit] = useState(existingItem?.unit ?? '');
  const [unitPrice, setUnitPrice] = useState(
    existingItem?.unitPrice != null ? existingItem.unitPrice.toFixed(2) : '',
  );

  const handleSave = () => {
    const trimmedDescription = description.trim();
    if (trimmedDescription.length === 0) {
      Alert.alert('Notice', 'Please enter item description');
      return;
    }
    const parsedQuantity = Number(quantity.trim()) || 1;
    const parsedUnitPrice =
      unitPrice.trim().length === 0 ? undefined : Number(unitPrice.trim());
    onSave({
      description: trimmedDescription,
      quantity: parsedQuantity,
      unit: unit.trim() || undefined,
      unitPrice: parsedUnitPrice,
      totalPrice:
        parsedUnitPrice != null ? parsedQuantity * parsedUnitPrice : undefined,
    });
  };

  return (
    <Modal visible transparent animationType="fade" onRequestClose={onCancel}>
      <View style={styles.modalBackdrop}>
        <View style={[styles.modalCard, shadows.card]}>
          <Text style={textStyles.heading3}>
            {existingItem ? 'Edit Item' : 'Add Item'}
          </Text>
          <View style={styles.gap} />
          <LabeledInput
            label="Description *"
            value={description}
            onChangeText={setDescription}
            placeholder="Product or item description"
            autoFocus
          />
          <View style={styles.gap} />
          <View style={styles.rowGap}>
            <View style={styles.flex1}>
              <LabeledInput
                label="Quantity *"
                value={quantity}
                onChangeText={setQuantity}
                keyboardType="numeric"
              />
            </View>
            <View style={styles.flex1}>
              <LabeledInput
                label="Unit"
                value={unit}
                onChangeText={setUnit}
                placeholder="e.g., box, kg"
              />
            </View>
          </View>
          <View style={styles.gap} />
          <LabeledInput
            label="Unit Price (Optional)"
            value={unitPrice}
            onChangeText={setUnitPrice}
            keyboardType="decimal-pad"
            placeholder="0.00"
          />
          <View style={styles.modalActionsRow}>
            <Pressable style={styles.secondaryButton} onPress={onCancel}>
              <Text style={styles.secondaryButtonText}>Cancel</Text>
            </Pressable>
            <Pressable style={styles.modalCloseButton} onPress={handleSave}>
              <Text style={textStyles.buttonText}>
                {existingItem ? 'Save' : 'Add'}
              </Text>
            </Pressable>
          </View>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: colors.background },
  centered: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.background,
  },
  stepIndicatorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.card,
    paddingVertical: spacing.medium,
    paddingHorizontal: spacing.large,
  },
  stepChipContainer: { alignItems: 'center' },
  stepCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  stepCircleText: { color: colors.white, fontWeight: 'bold', fontSize: 13 },
  stepLabel: { fontSize: 11, marginTop: 4 },
  stepLabelActive: { fontWeight: 'bold' },
  stepDivider: {
    flex: 1,
    height: 2,
    backgroundColor: colors.divider,
    marginHorizontal: spacing.small,
  },
  stepDividerActive: { backgroundColor: colors.primary },
  stepContent: { padding: spacing.medium, paddingBottom: spacing.xLarge },
  stepFlexColumn: { flex: 1 },
  gap: { height: spacing.medium },
  gapLarge: { height: spacing.large },
  bannerBar: {
    backgroundColor: `${colors.primary}1A`,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  bannerText: { color: colors.primary, fontWeight: '600', fontSize: 13 },
  helperText: { fontSize: 11, color: colors.textSecondary, marginTop: 4 },
  helperTextOk: { fontSize: 11, color: colors.success, marginTop: 4 },
  fieldLabel: { fontSize: 14, fontWeight: '600' },
  inputLabel: { fontSize: 12, color: colors.textSecondary, marginBottom: 4 },
  input: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small + 4,
    backgroundColor: colors.card,
  },
  inputMultiline: { minHeight: 70, textAlignVertical: 'top' },
  stepButtonRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: spacing.medium,
    backgroundColor: colors.card,
    borderTopWidth: 1,
    borderTopColor: colors.divider,
  },
  spacer: { flex: 1 },
  primaryButton: {
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
    alignItems: 'center',
  },
  secondaryButton: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
  },
  secondaryButtonText: { color: colors.textSecondary, fontWeight: '600' },
  smallPrimaryButton: {
    backgroundColor: colors.primary,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  smallPrimaryButtonText: {
    color: colors.white,
    fontWeight: '600',
    fontSize: 13,
  },
  rowBetween: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  card: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.medium,
  },
  emptyItemsCard: { alignItems: 'center', paddingVertical: spacing.xLarge },
  emptyItemsIcon: { fontSize: 40, opacity: 0.4 },
  emptyItemsText: {
    fontWeight: '600',
    color: colors.textSecondary,
    marginTop: spacing.small,
  },
  emptyItemsHint: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: 4,
    textAlign: 'center',
  },
  itemRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: spacing.small,
  },
  itemQtyBadge: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: `${colors.primary}1A`,
    alignItems: 'center',
    justifyContent: 'center',
    marginRight: spacing.medium,
  },
  itemQtyText: { color: colors.primary, fontWeight: 'bold', fontSize: 12 },
  itemTextBox: { flex: 1 },
  itemDescription: { fontWeight: '600' },
  itemSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  itemActionIcon: { fontSize: 18, marginLeft: spacing.medium },
  itemActionDelete: { color: colors.error },
  itemCountText: {
    fontSize: 13,
    color: colors.textSecondary,
    marginRight: spacing.medium,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.small,
    marginTop: spacing.small,
  },
  chip: {
    borderWidth: 1,
    borderColor: colors.divider,
    borderRadius: radii.borderRadius,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  chipSelected: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  chipText: { fontSize: 13, color: colors.textSecondary },
  chipTextSelected: { color: colors.white, fontWeight: '600' },
  radioRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: spacing.small + 4,
  },
  radioIndicator: {
    alignItems: 'center',
    borderColor: colors.border,
    borderRadius: 12,
    borderWidth: 1,
    height: 24,
    justifyContent: 'center',
    marginRight: spacing.medium,
    width: 24,
  },
  radioIndicatorSelected: {
    backgroundColor: colors.shell,
    borderColor: colors.shell,
  },
  radioTextBox: { flex: 1 },
  radioLabel: { fontWeight: '600' },
  radioSubtitle: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  dividerLine: { height: 1, backgroundColor: colors.divider },
  thirdPartyCard: { backgroundColor: `${colors.warning}14` },
  thirdPartyHeading: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: spacing.small,
  },
  thirdPartyTitle: { ...textStyles.label, color: colors.contentPrimary },
  infoNote: {
    alignItems: 'flex-start',
    backgroundColor: colors.activeMuted,
    borderRadius: radii.inputRadius,
    flexDirection: 'row',
    gap: spacing.small,
    padding: spacing.medium,
  },
  infoNoteText: { ...textStyles.bodySmall, color: colors.shell, flex: 1 },
  saveButton: { alignSelf: 'stretch' },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: spacing.large,
  },
  modalCard: {
    backgroundColor: colors.card,
    borderRadius: radii.cardRadius,
    padding: spacing.large,
    width: '100%',
    maxWidth: 440,
  },
  modalActionsRow: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: spacing.medium,
    marginTop: spacing.large,
  },
  modalCloseButton: {
    backgroundColor: colors.primary,
    borderRadius: radii.buttonRadius,
    paddingHorizontal: spacing.large,
    paddingVertical: spacing.small + 4,
    alignItems: 'center',
    minWidth: 80,
  },
  instructionsText: { fontSize: 14, fontWeight: '500' },
  rowGap: { flexDirection: 'row', gap: spacing.medium },
  flex1: { flex: 1 },
});
