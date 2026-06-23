import React, { useState } from 'react';
import { Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useCustomerStore } from '../stores/useCustomerStore';
import { Customer, customerDisplayString } from '../models/customer';
import { colors, spacing, radii, shadows } from '../theme/tokens';
import { textStyles } from '../theme/textStyles';

/**
 * Ported from lib/widgets/customer_autocomplete.dart (verified against source on
 * 2026-06-23) — its only call site is create_delivery_screen.dart, so it lives
 * alongside the other shared components rather than being inlined there, in case future
 * screens need the same search-and-select UX.
 *
 * Deviation: no FocusNode-driven "show favorites/recent on focus" — RN's onFocus works
 * the same way, but the dropdown is driven by component state directly (`showDropdown`)
 * rather than a focus-listener side effect, slightly simpler for the same behavior.
 */
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
  if (diffDays < 30) return `${Math.floor(diffDays / 7)} week${Math.floor(diffDays / 7) > 1 ? 's' : ''} ago`;
  if (diffDays < 365) return `${Math.floor(diffDays / 30)} month${Math.floor(diffDays / 30) > 1 ? 's' : ''} ago`;
  return `${Math.floor(diffDays / 365)} year${Math.floor(diffDays / 365) > 1 ? 's' : ''} ago`;
}

export default function CustomerAutocomplete({ initialCustomer, onCustomerSelected, labelText = 'Customer', hintText }: CustomerAutocompleteProps) {
  const customers = useCustomerStore((s) => s.customers);
  const favoriteCustomers = useCustomerStore((s) => s.favoriteCustomers);
  const searchCustomers = useCustomerStore((s) => s.searchCustomers);

  const [text, setText] = useState(initialCustomer ? customerDisplayString(initialCustomer) : '');
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(initialCustomer ?? null);
  const [searchResults, setSearchResults] = useState<Customer[]>([]);
  const [showDropdown, setShowDropdown] = useState(false);

  const loadFavoritesAndRecent = () => {
    setSearchResults([...favoriteCustomers, ...customers.slice(0, 10)]);
    setShowDropdown(true);
  };

  const handleFocus = () => {
    setShowDropdown(true);
    if (text.length === 0) loadFavoritesAndRecent();
  };

  const handleChangeText = async (value: string) => {
    setText(value);
    if (selectedCustomer && value !== customerDisplayString(selectedCustomer)) {
      setSelectedCustomer(null);
      onCustomerSelected(null);
    }

    if (value.length === 0) {
      loadFavoritesAndRecent();
      return;
    }

    try {
      const results = await searchCustomers(value);
      setSearchResults(results);
      setShowDropdown(true);
    } catch {
      // Search failed, keep existing results.
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
    <View>
      <View style={styles.inputRow}>
        <Text style={styles.inputIcon}>👤</Text>
        <TextInput
          style={styles.input}
          value={text}
          placeholder={hintText ?? 'Search by customer number or name...'}
          onFocus={handleFocus}
          onChangeText={handleChangeText}
        />
        {selectedCustomer?.isFavorite ? <Text style={styles.favoriteIcon}>⭐</Text> : null}
        {text.length > 0 ? (
          <Pressable onPress={clearSelection}>
            <Text style={styles.clearIcon}>✕</Text>
          </Pressable>
        ) : null}
      </View>
      <Text style={styles.label}>{labelText}</Text>

      {showDropdown && searchResults.length > 0 ? (
        <View style={[styles.dropdown, shadows.card]}>
          {text.length === 0 ? (
            <View style={styles.dropdownHeader}>
              <Text style={styles.dropdownHeaderText}>⭐ Favorites & Recent</Text>
            </View>
          ) : null}
          {searchResults.map((customer) => (
            <Pressable key={customer.id} style={styles.resultRow} onPress={() => selectCustomer(customer)}>
              <View style={[styles.typeIcon, { backgroundColor: customer.customerType === 'business' ? `${colors.primary}1A` : `${colors.success}1A` }]}>
                <Text>{customer.customerType === 'business' ? '🏢' : '🏠'}</Text>
              </View>
              <View style={styles.resultTextBox}>
                <View style={styles.resultNameRow}>
                  <Text style={styles.resultName} numberOfLines={1}>
                    {customerDisplayString(customer)}
                  </Text>
                  {customer.isFavorite ? <Text style={styles.favoriteIcon}>⭐</Text> : null}
                </View>
                <Text style={styles.resultAddress} numberOfLines={1}>
                  {customer.address}
                </Text>
                {customer.phone ? <Text style={styles.resultPhone}>{customer.phone}</Text> : null}
              </View>
              {customer.stats.totalDeliveries > 0 ? (
                <View style={styles.resultStats}>
                  <View style={styles.deliveryCountPill}>
                    <Text style={styles.deliveryCountText}>{customer.stats.totalDeliveries} deliveries</Text>
                  </View>
                  {customer.stats.lastDelivery ? <Text style={styles.lastDeliveryText}>{formatLastDelivery(customer.stats.lastDelivery)}</Text> : null}
                </View>
              ) : null}
            </Pressable>
          ))}
          <Pressable style={styles.closeRow} onPress={() => setShowDropdown(false)}>
            <Text style={styles.closeText}>Close</Text>
          </Pressable>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  inputRow: { flexDirection: 'row', alignItems: 'center', borderWidth: 1, borderColor: colors.divider, borderRadius: radii.borderRadius, paddingHorizontal: spacing.medium, backgroundColor: colors.card },
  inputIcon: { marginRight: spacing.small },
  input: { flex: 1, paddingVertical: spacing.small + 4 },
  favoriteIcon: { fontSize: 14, marginLeft: 4 },
  clearIcon: { fontSize: 16, color: colors.textSecondary, marginLeft: spacing.small },
  label: { fontSize: 11, color: colors.textSecondary, marginTop: 4 },
  dropdown: { backgroundColor: colors.card, borderRadius: radii.borderRadius, marginTop: spacing.small, maxHeight: 300, overflow: 'hidden' },
  dropdownHeader: { backgroundColor: colors.background, paddingHorizontal: spacing.medium, paddingVertical: spacing.small },
  dropdownHeaderText: { fontSize: 12, fontWeight: '600', color: colors.textSecondary },
  resultRow: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: spacing.medium, paddingVertical: spacing.small + 4, borderBottomWidth: 1, borderBottomColor: colors.divider },
  typeIcon: { width: 36, height: 36, borderRadius: 8, alignItems: 'center', justifyContent: 'center', marginRight: spacing.small + 4 },
  resultTextBox: { flex: 1 },
  resultNameRow: { flexDirection: 'row', alignItems: 'center', gap: 4 },
  resultName: { fontWeight: '600', fontSize: 14, flexShrink: 1 },
  resultAddress: { fontSize: 12, color: colors.textSecondary, marginTop: 2 },
  resultPhone: { fontSize: 11, color: colors.textSecondary, marginTop: 2 },
  resultStats: { alignItems: 'flex-end', marginLeft: spacing.small },
  deliveryCountPill: { backgroundColor: `${colors.success}1A`, borderRadius: 12, paddingHorizontal: spacing.small, paddingVertical: 2 },
  deliveryCountText: { fontSize: 10, fontWeight: '600', color: colors.success },
  lastDeliveryText: { fontSize: 10, color: colors.textSecondary, marginTop: 2 },
  closeRow: { paddingVertical: spacing.small, alignItems: 'center' },
  closeText: { fontSize: 12, color: colors.textSecondary, ...textStyles.bodySmall },
});
