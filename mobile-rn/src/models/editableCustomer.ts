import { Customer, CustomerType } from './customer';
import { ImportError, ImportWarning, ParsedCustomer } from '../repositories/customerImportService';

/**
 * Ported from lib/models/editable_customer.dart (verified against source on
 * 2026-06-22) — editable wrapper around ParsedCustomer for the bulk customer-creation
 * table UI.
 */
export class EditableCustomer {
  rowNumber: number;
  customerNumber: string;
  name: string;
  address: string;
  contactPerson?: string;
  phone?: string;
  email?: string;
  deliveryInstructions?: string;
  accountNumber?: string;
  customerType: CustomerType;
  tags: string[];
  isActive: boolean;

  isSelected: boolean;
  isRemoved: boolean;
  isEdited: boolean;
  errors: ImportError[];
  warnings: ImportWarning[];

  constructor(params: {
    rowNumber: number;
    customerNumber: string;
    name: string;
    address: string;
    contactPerson?: string;
    phone?: string;
    email?: string;
    deliveryInstructions?: string;
    accountNumber?: string;
    customerType?: CustomerType;
    tags?: string[];
    isActive?: boolean;
    isSelected?: boolean;
    isRemoved?: boolean;
    isEdited?: boolean;
    errors?: ImportError[];
    warnings?: ImportWarning[];
  }) {
    this.rowNumber = params.rowNumber;
    this.customerNumber = params.customerNumber;
    this.name = params.name;
    this.address = params.address;
    this.contactPerson = params.contactPerson;
    this.phone = params.phone;
    this.email = params.email;
    this.deliveryInstructions = params.deliveryInstructions;
    this.accountNumber = params.accountNumber;
    this.customerType = params.customerType ?? 'business';
    this.tags = params.tags ?? [];
    this.isActive = params.isActive ?? true;
    this.isSelected = params.isSelected ?? true;
    this.isRemoved = params.isRemoved ?? false;
    this.isEdited = params.isEdited ?? false;
    this.errors = params.errors ?? [];
    this.warnings = params.warnings ?? [];
  }

  /** Mirrors EditableCustomer.fromParsed(). */
  static fromParsed(parsed: ParsedCustomer): EditableCustomer {
    return new EditableCustomer({
      rowNumber: parsed.rowNumber,
      customerNumber: parsed.customerNumber,
      name: parsed.name,
      address: parsed.address,
      contactPerson: parsed.contactPerson,
      phone: parsed.phone,
      email: parsed.email,
      deliveryInstructions: parsed.deliveryInstructions,
      accountNumber: parsed.accountNumber,
      customerType: parsed.customerType,
      tags: [...parsed.tags],
      isActive: parsed.isActive,
    });
  }

  /** Mirrors EditableCustomer.toCustomer(). */
  toCustomer(companyId: string): Customer {
    const now = new Date();
    return {
      id: '',
      companyId,
      customerNumber: this.customerNumber,
      name: this.name,
      address: this.address,
      contactPerson: this.contactPerson,
      phone: this.phone,
      email: this.email,
      deliveryInstructions: this.deliveryInstructions,
      accountNumber: this.accountNumber,
      customerType: this.customerType,
      stats: { totalDeliveries: 0 },
      isActive: this.isActive,
      isFavorite: false,
      tags: this.tags,
      createdAt: now,
      updatedAt: now,
    };
  }

  /** Mirrors EditableCustomer.validate(). */
  validate(existingNumbers?: string[], allCustomers?: EditableCustomer[]): void {
    this.errors = [];
    this.warnings = [];

    if (this.customerNumber.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'customerNumber', message: 'Customer number is required' });
    } else {
      if (existingNumbers?.includes(this.customerNumber)) {
        this.errors.push({ rowNumber: this.rowNumber, field: 'customerNumber', message: 'Customer number already exists' });
      }

      if (allCustomers) {
        const duplicates = allCustomers.filter((d) => d !== this && !d.isRemoved && d.customerNumber === this.customerNumber);
        if (duplicates.length > 0) {
          this.errors.push({
            rowNumber: this.rowNumber,
            field: 'customerNumber',
            message: `Duplicate customer number in rows: ${duplicates.map((d) => d.rowNumber).join(', ')}`,
          });
        }
      }
    }

    if (this.name.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'name', message: 'Customer name is required' });
    }

    if (this.address.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'address', message: 'Address is required' });
    }

    if (!this.phone || this.phone.trim().length === 0) {
      this.warnings.push({ rowNumber: this.rowNumber, field: 'phone', message: 'No phone number provided' });
    }

    if (!this.email || this.email.trim().length === 0) {
      this.warnings.push({ rowNumber: this.rowNumber, field: 'email', message: 'No email provided' });
    }
  }

  get hasErrors(): boolean {
    return this.errors.length > 0;
  }

  get hasWarnings(): boolean {
    return this.warnings.length > 0;
  }

  get isValid(): boolean {
    return !this.hasErrors && !this.isRemoved;
  }
}
