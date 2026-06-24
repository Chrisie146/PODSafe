import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Customer, customerDisplayString } from '../models/customer';
import { useCustomerStore } from '../stores/useCustomerStore';
import { colors, spacing } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';
import {
  AppIcon,
  Card,
  FormField,
  IconButton,
  SecondaryButton,
  StatusChip,
} from './ui';

interface CustomerAutocompleteProps {
  initialCustomer?: Customer | null;
  onCustomerSelected: (customer: Customer | null) => void;
  labelText?: string;
  hintText?: string;
}

function formatLastDelivery(date: Date): string {
  const diffDays = Math.floor((Date.now() - date.getTime()) / 86400000);
  if (diffDays === 0) return 'Today';
  if (diffDays === 1) return 'Yesterday';
  if (diffDays < 7) return `${diffDays} days ago`;
  if (diffDays < 30)
    return `${Math.floor(diffDays / 7)} week${
      Math.floor(diffDays / 7) > 1 ? 's' : ''
    } ago`;
  if (diffDays < 365)
    return `${Math.floor(diffDays / 30)} month${
      Math.floor(diffDays / 30) > 1 ? 's' : ''
    } ago`;
  return `${Math.floor(diffDays / 365)} year${
    Math.floor(diffDays / 365) > 1 ? 's' : ''
  } ago`;
}

/** Search and select a customer without relying on text icons. */
export default function CustomerAutocomplete({
  initialCustomer,
  onCustomerSelected,
  labelText = 'Customer',
  hintText,
}: CustomerAutocompleteProps) {
  const customers = useCustomerStore(state => state.customers);
  const favoriteCustomers = useCustomerStore(state => state.favoriteCustomers);
  const searchCustomers = useCustomerStore(state => state.searchCustomers);
  const [text, setText] = useState(
    initialCustomer ? customerDisplayString(initialCustomer) : '',
  );
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(
    initialCustomer ?? null,
  );
  const [searchResults, setSearchResults] = useState<Customer[]>([]);
  const [showDropdown, setShowDropdown] = useState(false);

  const loadFavoritesAndRecent = () => {
    const distinct = [...favoriteCustomers, ...customers.slice(0, 10)].filter(
      (customer, index, list) =>
        list.findIndex(candidate => candidate.id === customer.id) === index,
    );
    setSearchResults(distinct);
    setShowDropdown(true);
  };

  const handleFocus = () => {
    setShowDropdown(true);
    if (!text.length) loadFavoritesAndRecent();
  };

  const handleChangeText = async (value: string) => {
    setText(value);
    if (selectedCustomer && value !== customerDisplayString(selectedCustomer)) {
      setSelectedCustomer(null);
      onCustomerSelected(null);
    }
    if (!value.length) {
      loadFavoritesAndRecent();
      return;
    }
    try {
      setSearchResults(await searchCustomers(value));
      setShowDropdown(true);
    } catch {
      setShowDropdown(true);
    }
  };

  const selectCustomer = (customer: Customer) => {
    setSelectedCustomer(customer);
    setText(customerDisplayString(customer));
    setShowDropdown(false);
    onCustomerSelected(customer);
  };

  const clearSelection = () => {
    setSelectedCustomer(null);
    setText('');
    setSearchResults([]);
    setShowDropdown(false);
    onCustomerSelected(null);
  };

  return (
    <View style={styles.container}>
      <FormField
        label={labelText}
        value={text}
        placeholder={hintText ?? 'Search by customer number or name'}
        onFocus={handleFocus}
        onChangeText={handleChangeText}
        rightAccessory={
          text.length ? (
            <IconButton
              icon="close"
              accessibilityLabel="Clear selected customer"
              onPress={clearSelection}
            />
          ) : undefined
        }
        helperText={
          selectedCustomer
            ? `Selected customer ${selectedCustomer.customerNumber}`
            : 'Search by customer name or number, or enter details manually.'
        }
      />

      {showDropdown && searchResults.length ? (
        <Card padding="none" style={styles.dropdown}>
          {!text.length ? (
            <View style={styles.dropdownHeader}>
              <AppIcon name="users" size={18} color={colors.contentSecondary} />
              <Text style={textStyles.labelSmall}>
                Favorites and recent customers
              </Text>
            </View>
          ) : null}
          {searchResults.map(customer => (
            <CustomerResult
              key={customer.id}
              customer={customer}
              onPress={() => selectCustomer(customer)}
            />
          ))}
          <SecondaryButton
            label="Close results"
            icon="close"
            onPress={() => setShowDropdown(false)}
            style={styles.closeButton}
          />
        </Card>
      ) : null}
    </View>
  );
}

function CustomerResult({
  customer,
  onPress,
}: {
  customer: Customer;
  onPress: () => void;
}) {
  const businessCustomer = customer.customerType === 'business';
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Select ${customerDisplayString(customer)}`}
      onPress={onPress}
      style={({ pressed }) => [styles.result, pressed && styles.pressed]}
    >
      <View
        style={[
          styles.typeMark,
          {
            backgroundColor: businessCustomer
              ? colors.activeMuted
              : colors.verifiedMuted,
          },
        ]}
      >
        <AppIcon
          name={businessCustomer ? 'users' : 'user'}
          size={20}
          color={businessCustomer ? colors.active : colors.verified}
        />
      </View>
      <View style={styles.resultCopy}>
        <View style={styles.resultTitleRow}>
          <Text numberOfLines={1} style={textStyles.label}>
            {customerDisplayString(customer)}
          </Text>
          {customer.isFavorite ? (
            <StatusChip label="Preferred" tone="info" icon="check" />
          ) : null}
        </View>
        <Text numberOfLines={1} style={textStyles.bodySmall}>
          {customer.address}
        </Text>
        {customer.phone ? (
          <Text style={textStyles.bodySmall}>{customer.phone}</Text>
        ) : null}
      </View>
      {customer.stats.totalDeliveries ? (
        <View style={styles.stats}>
          <StatusChip
            label={`${customer.stats.totalDeliveries} deliveries`}
            tone="success"
            icon="truck"
          />
          {customer.stats.lastDelivery ? (
            <Text style={textStyles.bodySmall}>
              {formatLastDelivery(customer.stats.lastDelivery)}
            </Text>
          ) : null}
        </View>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: { gap: spacing.small },
  dropdown: { maxHeight: 320, overflow: 'hidden' },
  dropdownHeader: {
    alignItems: 'center',
    backgroundColor: colors.surfaceMuted,
    flexDirection: 'row',
    gap: spacing.small,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  result: {
    alignItems: 'center',
    borderBottomColor: colors.border,
    borderBottomWidth: StyleSheet.hairlineWidth,
    flexDirection: 'row',
    gap: spacing.small,
    minHeight: 72,
    paddingHorizontal: spacing.medium,
    paddingVertical: spacing.small,
  },
  typeMark: {
    alignItems: 'center',
    borderRadius: 12,
    height: 40,
    justifyContent: 'center',
    width: 40,
  },
  resultCopy: { flex: 1, gap: spacing.xs, minWidth: 0 },
  resultTitleRow: {
    alignItems: 'center',
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
  },
  stats: { alignItems: 'flex-end', gap: spacing.xs },
  closeButton: { margin: spacing.small },
  pressed: { backgroundColor: colors.surfaceMuted },
});
