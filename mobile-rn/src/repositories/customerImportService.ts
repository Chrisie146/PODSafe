import Papa from 'papaparse';
import { Customer, CustomerType } from '../models/customer';

/**
 * Ported from lib/services/customer_import_service.dart (verified against source on
 * 2026-06-22). Pure CSV-parsing logic — no Firebase dependency. Uses papaparse instead
 * of Dart's `csv` package per the migration plan's package table.
 */
export interface ImportError {
  rowNumber: number;
  field: string;
  message: string;
}

export interface ImportWarning {
  rowNumber: number;
  field: string;
  message: string;
}

export interface CustomerImportResult {
  validCustomers: ParsedCustomer[];
  errors: ImportError[];
  warnings: ImportWarning[];
}

export class ParsedCustomer {
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
  }

  /** Mirrors ParsedCustomer.toCustomer(). */
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
}

const REQUIRED_HEADERS: Record<string, string[]> = {
  'customer number': ['customernumber', 'customer number', 'number', 'customer_number'],
  'customer name': ['customername', 'customer name', 'name', 'customer_name'],
  address: ['address', 'deliveryaddress', 'delivery address', 'delivery_address'],
};

function findColumnIndex(headers: string[], possibleNames: string[]): number {
  for (let i = 0; i < headers.length; i++) {
    const header = headers[i].replace(/ /g, '').replace(/_/g, '').toLowerCase();
    for (const name of possibleNames) {
      if (header.includes(name.replace(/ /g, ''))) {
        return i;
      }
    }
  }
  return -1;
}

function getCell(row: string[], index: number): string | undefined {
  if (index < 0 || index >= row.length) return undefined;
  const value = row[index]?.toString();
  return value === '' ? undefined : value;
}

function isValidEmail(email: string): boolean {
  return /^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$/.test(email);
}

/** Mirrors CustomerImportService.parseCsv(). */
export function parseCustomerCsv(csvContent: string): CustomerImportResult {
  const validCustomers: ParsedCustomer[] = [];
  const errors: ImportError[] = [];
  const warnings: ImportWarning[] = [];

  const parsed = Papa.parse<string[]>(csvContent, { skipEmptyLines: false });
  const rows = parsed.data;

  if (rows.length === 0) {
    errors.push({ rowNumber: 0, field: 'File', message: 'CSV file is empty' });
    return { validCustomers, errors, warnings };
  }

  const headers = rows[0].map((h) => h.toString().trim().toLowerCase());

  for (const [displayName, possibleNames] of Object.entries(REQUIRED_HEADERS)) {
    const found = headers.some((header) => {
      const normalizedHeader = header.replace(/ /g, '').replace(/_/g, '');
      return possibleNames.some((possible) => normalizedHeader === possible.replace(/ /g, '').replace(/_/g, ''));
    });
    if (!found) {
      errors.push({ rowNumber: 1, field: 'Headers', message: `Missing required column: ${displayName}` });
    }
  }

  if (errors.length > 0) {
    return { validCustomers, errors, warnings };
  }

  const customerNumberIndex = findColumnIndex(headers, ['customernumber', 'customer number', 'number', 'code']);
  const nameIndex = findColumnIndex(headers, ['customername', 'customer name', 'name']);
  const addressIndex = findColumnIndex(headers, ['address', 'deliveryaddress', 'delivery address']);
  const contactPersonIndex = findColumnIndex(headers, ['contactperson', 'contact person', 'contact']);
  const phoneIndex = findColumnIndex(headers, ['phone', 'phonenumber', 'phone number', 'telephone']);
  const emailIndex = findColumnIndex(headers, ['email', 'e-mail']);
  const instructionsIndex = findColumnIndex(headers, ['deliveryinstructions', 'delivery instructions', 'instructions', 'notes']);
  const accountNumberIndex = findColumnIndex(headers, ['accountnumber', 'account number', 'account', 'acc']);
  const customerTypeIndex = findColumnIndex(headers, ['customertype', 'customer type', 'type']);
  const tagsIndex = findColumnIndex(headers, ['tags', 'categories']);
  const activeIndex = findColumnIndex(headers, ['active', 'isactive', 'status']);

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    const rowNumber = i + 1;

    if (row.every((cell) => cell.toString().trim().length === 0)) {
      continue;
    }

    try {
      const customerNumber = getCell(row, customerNumberIndex)?.trim() ?? '';
      const name = getCell(row, nameIndex)?.trim() ?? '';
      const address = getCell(row, addressIndex)?.trim() ?? '';

      const rowErrors: ImportError[] = [];
      if (customerNumber.length === 0) rowErrors.push({ rowNumber, field: 'Customer Number', message: 'Customer number is required' });
      if (name.length === 0) rowErrors.push({ rowNumber, field: 'Customer Name', message: 'Customer name is required' });
      if (address.length === 0) rowErrors.push({ rowNumber, field: 'Address', message: 'Address is required' });

      if (rowErrors.length > 0) {
        errors.push(...rowErrors);
        continue;
      }

      const contactPerson = getCell(row, contactPersonIndex)?.trim();
      const phone = getCell(row, phoneIndex)?.trim();
      const email = getCell(row, emailIndex)?.trim();
      const instructions = getCell(row, instructionsIndex)?.trim();
      const accountNumber = getCell(row, accountNumberIndex)?.trim();

      const typeStr = getCell(row, customerTypeIndex)?.trim().toLowerCase();
      const customerType: CustomerType = typeStr === 'residential' || typeStr === 'resident' || typeStr === 'res' ? 'residential' : 'business';

      const tagsStr = getCell(row, tagsIndex)?.trim() ?? '';
      const tags = tagsStr.length > 0 ? tagsStr.split(',').map((t) => t.trim()).filter((t) => t.length > 0) : [];

      const activeStr = getCell(row, activeIndex)?.trim().toLowerCase();
      const isActive = activeStr !== 'false' && activeStr !== 'no' && activeStr !== '0';

      if (email && email.length > 0 && !isValidEmail(email)) {
        warnings.push({ rowNumber, field: 'Email', message: `Email format may be invalid: ${email}` });
      }

      validCustomers.push(
        new ParsedCustomer({
          rowNumber,
          customerNumber,
          name,
          address,
          contactPerson,
          phone,
          email,
          deliveryInstructions: instructions,
          accountNumber,
          customerType,
          tags,
          isActive,
        }),
      );
    } catch (e) {
      errors.push({ rowNumber, field: 'Row', message: `Error parsing row: ${(e as Error).message}` });
    }
  }

  return { validCustomers, errors, warnings };
}

/** Mirrors CustomerImportService.checkDuplicates(). */
export function checkDuplicateCustomerNumbers(customers: ParsedCustomer[]): ImportError[] {
  const errors: ImportError[] = [];
  const seen = new Map<string, number>();

  for (const customer of customers) {
    const number = customer.customerNumber.toLowerCase();
    const seenRow = seen.get(number);
    if (seenRow != null) {
      errors.push({
        rowNumber: customer.rowNumber,
        field: 'Customer Number',
        message: `Duplicate customer number: ${customer.customerNumber} (also in row ${seenRow})`,
      });
    } else {
      seen.set(number, customer.rowNumber);
    }
  }

  return errors;
}

/** Mirrors CustomerImportService.checkExistingCustomers(). */
export function checkExistingCustomerNumbers(customers: ParsedCustomer[], existingCustomers: Customer[]): ImportError[] {
  const errors: ImportError[] = [];
  const existingNumbers = new Set(existingCustomers.map((c) => c.customerNumber.toLowerCase()));

  for (const customer of customers) {
    if (existingNumbers.has(customer.customerNumber.toLowerCase())) {
      errors.push({ rowNumber: customer.rowNumber, field: 'Customer Number', message: `Customer number already exists: ${customer.customerNumber}` });
    }
  }

  return errors;
}

/** Mirrors CustomerImportService.generateTemplate(). */
export function generateCustomerCsvTemplate(): string {
  const headers = [
    'Customer Number*',
    'Customer Name*',
    'Address*',
    'Contact Person',
    'Phone',
    'Email',
    'Delivery Instructions',
    'Account Number',
    'Customer Type',
    'Tags',
    'Active',
  ];

  const exampleRows = [
    [
      'BOX001',
      'Boxer Superstore',
      '123 Main St, Miami, FL 33101',
      'John Manager',
      '305-555-0100',
      'john@boxersuper.com',
      'Ring bell at loading dock. Gate code: 1234',
      'ACC-1001',
      'business',
      'VIP,Weekly',
      'TRUE',
    ],
    [
      'ACME999',
      'ACME Corporation',
      '789 Business Blvd, Miami, FL 33103',
      'Sarah Smith',
      '305-555-0200',
      'sarah@acme.com',
      'Call 30 min before arrival',
      'ACC-2002',
      'business',
      'Wholesale',
      'TRUE',
    ],
    [
      'RES001',
      'John Doe Residence',
      '321 Oak Ave, Miami, FL 33104',
      'John Doe',
      '305-555-0300',
      'johndoe@email.com',
      'Leave at front door if no answer',
      '',
      'residential',
      'Residential',
      'TRUE',
    ],
  ];

  return Papa.unparse([headers, ...exampleRows]);
}
