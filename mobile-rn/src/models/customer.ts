/**
 * Ported from lib/models/customer_model.dart (verified against source on 2026-06-22).
 */
export type CustomerType = 'business' | 'residential';

export interface CustomerStats {
  totalDeliveries: number;
  lastDelivery?: Date;
  firstDelivery?: Date;
}

export interface Customer {
  id: string;
  companyId: string;
  customerNumber: string;
  name: string;
  address: string;
  contactPerson?: string;
  phone?: string;
  email?: string;
  deliveryInstructions?: string;
  accountNumber?: string;
  customerType: CustomerType;
  stats: CustomerStats;
  isActive: boolean;
  isFavorite: boolean;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
}

/** Mirrors Customer.displayString. */
export function customerDisplayString(customer: Customer): string {
  return `${customer.customerNumber} - ${customer.name}`;
}

/** Mirrors Customer.searchString. */
export function customerSearchString(customer: Customer): string {
  return `${customer.customerNumber.toLowerCase()} ${customer.name.toLowerCase()} ${customer.contactPerson?.toLowerCase() ?? ''}`;
}

export function defaultCustomerStats(): CustomerStats {
  return { totalDeliveries: 0 };
}
