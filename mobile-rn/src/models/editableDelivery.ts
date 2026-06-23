import { Delivery, DeliveryItem } from './delivery';
import { ImportError, ImportWarning, ParsedDelivery } from '../repositories/bulkImportService';

/**
 * Ported from lib/models/editable_delivery.dart (verified against source on
 * 2026-06-22) — editable wrapper around ParsedDelivery for the bulk-upload /
 * ABServe-import table UIs. Mirrors models/editableCustomer.ts's structure.
 */
export class EditableDelivery {
  rowNumber: number;
  customerName: string;
  customerAddress: string;
  customerPhone?: string;
  customerNumber?: string;
  orderNumber?: string;
  invoiceNumber: string;
  invoiceDate?: Date;
  invoiceTotal?: number;
  taxAmount?: number;
  discountAmount?: number;
  scheduledDate: Date;
  driverEmail?: string;
  notes?: string;
  items: DeliveryItem[];

  isSelected: boolean;
  isRemoved: boolean;
  isEdited: boolean;
  errors: ImportError[];
  warnings: ImportWarning[];

  constructor(params: {
    rowNumber: number;
    customerName: string;
    customerAddress: string;
    customerPhone?: string;
    customerNumber?: string;
    orderNumber?: string;
    invoiceNumber: string;
    invoiceDate?: Date;
    invoiceTotal?: number;
    taxAmount?: number;
    discountAmount?: number;
    scheduledDate: Date;
    driverEmail?: string;
    notes?: string;
    items: DeliveryItem[];
    isSelected?: boolean;
    isRemoved?: boolean;
    isEdited?: boolean;
    errors?: ImportError[];
    warnings?: ImportWarning[];
  }) {
    this.rowNumber = params.rowNumber;
    this.customerName = params.customerName;
    this.customerAddress = params.customerAddress;
    this.customerPhone = params.customerPhone;
    this.customerNumber = params.customerNumber;
    this.orderNumber = params.orderNumber;
    this.invoiceNumber = params.invoiceNumber;
    this.invoiceDate = params.invoiceDate;
    this.invoiceTotal = params.invoiceTotal;
    this.taxAmount = params.taxAmount;
    this.discountAmount = params.discountAmount;
    this.scheduledDate = params.scheduledDate;
    this.driverEmail = params.driverEmail;
    this.notes = params.notes;
    this.items = params.items;
    this.isSelected = params.isSelected ?? true;
    this.isRemoved = params.isRemoved ?? false;
    this.isEdited = params.isEdited ?? false;
    this.errors = params.errors ?? [];
    this.warnings = params.warnings ?? [];
  }

  /** Mirrors EditableDelivery.fromParsed(). */
  static fromParsed(parsed: ParsedDelivery): EditableDelivery {
    return new EditableDelivery({
      rowNumber: parsed.rowNumber,
      customerName: parsed.customerName,
      customerAddress: parsed.customerAddress,
      customerPhone: parsed.customerPhone,
      customerNumber: parsed.customerNumber,
      orderNumber: parsed.orderNumber,
      invoiceNumber: parsed.invoiceNumber,
      invoiceDate: parsed.invoiceDate,
      invoiceTotal: parsed.invoiceTotal,
      taxAmount: parsed.taxAmount,
      discountAmount: parsed.discountAmount,
      scheduledDate: parsed.scheduledDate,
      driverEmail: parsed.driverEmail,
      notes: parsed.notes,
      items: [...parsed.items],
    });
  }

  /** Mirrors EditableDelivery.toDelivery(). */
  toDelivery(params: { companyId: string; driverId: string }): Delivery {
    return {
      id: '',
      companyId: params.companyId,
      driverId: params.driverId,
      customerName: this.customerName,
      customerAddress: this.customerAddress,
      customerPhone: this.customerPhone,
      customerNumber: this.customerNumber,
      orderNumber: this.orderNumber,
      invoiceNumber: this.invoiceNumber,
      invoiceDate: this.invoiceDate,
      items: this.items,
      invoiceTotal: this.invoiceTotal,
      taxAmount: this.taxAmount,
      discountAmount: this.discountAmount,
      isThirdPartyTransport: false,
      status: 'pending',
      scheduledDate: this.scheduledDate,
      createdAt: new Date(),
      notes: this.notes,
    };
  }

  /** Mirrors EditableDelivery.validate(). */
  validate(existingInvoices?: string[], allDeliveries?: EditableDelivery[]): void {
    this.errors = [];
    this.warnings = [];

    if (this.customerName.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'customerName', message: 'Customer name is required' });
    }

    if (this.customerAddress.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'customerAddress', message: 'Customer address is required' });
    }

    if (this.invoiceNumber.trim().length === 0) {
      this.errors.push({ rowNumber: this.rowNumber, field: 'invoiceNumber', message: 'Invoice number is required' });
    } else {
      if (existingInvoices?.includes(this.invoiceNumber)) {
        this.errors.push({ rowNumber: this.rowNumber, field: 'invoiceNumber', message: 'Invoice number already exists in database' });
      }

      if (allDeliveries) {
        const duplicates = allDeliveries.filter((d) => d !== this && !d.isRemoved && d.invoiceNumber === this.invoiceNumber);
        if (duplicates.length > 0) {
          this.errors.push({
            rowNumber: this.rowNumber,
            field: 'invoiceNumber',
            message: `Duplicate invoice number in rows: ${duplicates.map((d) => d.rowNumber).join(', ')}`,
          });
        }
      }
    }

    if (!this.customerPhone || this.customerPhone.trim().length === 0) {
      this.warnings.push({ rowNumber: this.rowNumber, field: 'customerPhone', message: 'No customer phone number' });
    }

    if (!this.driverEmail || this.driverEmail.trim().length === 0) {
      this.warnings.push({ rowNumber: this.rowNumber, field: 'driverEmail', message: 'No driver assigned - will be marked as unassigned' });
    }

    if (this.items.length === 0) {
      this.warnings.push({ rowNumber: this.rowNumber, field: 'items', message: 'No line items' });
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
