import Papa from 'papaparse';
import { Delivery, DeliveryItem } from '../models/delivery';

/**
 * Ported from lib/services/bulk_import_service.dart (verified against source on
 * 2026-06-22). Pure CSV-parsing logic — no Firebase dependency. Uses papaparse instead
 * of Dart's `csv` package, same as customerImportService.ts. Unlike that file, header
 * matching here is an exact (case-sensitive) match, mirroring this Dart source's own
 * `headers.contains(column)` check rather than customer import's fuzzy synonym matching.
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

export interface DeliveryImportResult {
  validDeliveries: ParsedDelivery[];
  errors: ImportError[];
  warnings: ImportWarning[];
}

export class ParsedDelivery {
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
  }

  /** Mirrors ParsedDelivery.toDelivery(). */
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
}

const REQUIRED_COLUMNS = ['customerName', 'customerAddress', 'invoiceNumber', 'scheduledDate'];

function tryMakeDate(year: number, month: number, day: number): Date | null {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const date = new Date(year, month - 1, day);
  if (date.getFullYear() !== year || date.getMonth() !== month - 1 || date.getDate() !== day) return null;
  return date;
}

/** Mirrors BulkImportService._parseDate(), trying the same format order. */
function parseDate(dateStr: string): Date | null {
  const s = dateStr.trim();

  let m = s.match(/^(\d{4})-(\d{2})-(\d{2})$/); // yyyy-MM-dd
  if (m) {
    const d = tryMakeDate(+m[1], +m[2], +m[3]);
    if (d) return d;
  }

  m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/); // dd/MM/yyyy
  if (m) {
    const d = tryMakeDate(+m[3], +m[2], +m[1]);
    if (d) return d;
  }

  m = s.match(/^(\d{2})\/(\d{2})\/(\d{4})$/); // MM/dd/yyyy
  if (m) {
    const d = tryMakeDate(+m[3], +m[1], +m[2]);
    if (d) return d;
  }

  m = s.match(/^(\d{2})-(\d{2})-(\d{4})$/); // dd-MM-yyyy
  if (m) {
    const d = tryMakeDate(+m[3], +m[2], +m[1]);
    if (d) return d;
  }

  m = s.match(/^(\d{4})\/(\d{2})\/(\d{2})$/); // yyyy/MM/dd
  if (m) {
    const d = tryMakeDate(+m[1], +m[2], +m[3]);
    if (d) return d;
  }

  m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/); // d/M/yyyy
  if (m) {
    const d = tryMakeDate(+m[3], +m[2], +m[1]);
    if (d) return d;
  }

  m = s.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})$/); // M/d/yyyy
  if (m) {
    const d = tryMakeDate(+m[3], +m[1], +m[2]);
    if (d) return d;
  }

  return null;
}

function parseNumber(value: string, rowNumber: number, field: string, label: string, warnings: ImportWarning[]): number | undefined {
  const n = Number(value);
  if (Number.isNaN(n)) {
    warnings.push({ rowNumber, field, message: `Invalid ${label} format (expected number)` });
    return undefined;
  }
  if (n < 0) {
    warnings.push({ rowNumber, field, message: `${label[0].toUpperCase()}${label.slice(1)} should not be negative` });
  }
  return n;
}

/** Mirrors BulkImportService._parseRow(). */
function parseRow(rowNumber: number, rowData: Record<string, string>, errors: ImportError[], warnings: ImportWarning[]): ParsedDelivery | null {
  const customerName = (rowData.customerName ?? '').trim();
  const customerAddress = (rowData.customerAddress ?? '').trim();
  const customerPhone = rowData.customerPhone?.trim();
  const customerNumber = rowData.customerNumber?.trim();
  const orderNumber = rowData.orderNumber?.trim();
  const invoiceNumber = (rowData.invoiceNumber ?? '').trim();
  const invoiceDateStr = rowData.invoiceDate?.trim();
  const invoiceTotalStr = rowData.invoiceTotal?.trim();
  const taxAmountStr = rowData.taxAmount?.trim();
  const discountAmountStr = rowData.discountAmount?.trim();
  const scheduledDateStr = (rowData.scheduledDate ?? '').trim();
  const driverEmail = rowData.driverEmail?.trim();
  const notes = rowData.notes?.trim();

  let hasError = false;

  if (customerName.length === 0) {
    errors.push({ rowNumber, field: 'customerName', message: 'Customer name is required' });
    hasError = true;
  }
  if (customerAddress.length === 0) {
    errors.push({ rowNumber, field: 'customerAddress', message: 'Customer address is required' });
    hasError = true;
  }
  if (invoiceNumber.length === 0) {
    errors.push({ rowNumber, field: 'invoiceNumber', message: 'Invoice number is required' });
    hasError = true;
  }

  let invoiceDate: Date | undefined;
  if (invoiceDateStr) {
    invoiceDate = parseDate(invoiceDateStr) ?? undefined;
    if (!invoiceDate) {
      errors.push({
        rowNumber,
        field: 'invoiceDate',
        message: 'Invalid invoice date format. Use YYYY-MM-DD (e.g., 2025-10-20), DD/MM/YYYY, or MM/DD/YYYY',
      });
      hasError = true;
    }
  }

  let scheduledDate: Date | null = null;
  if (scheduledDateStr.length === 0) {
    errors.push({ rowNumber, field: 'scheduledDate', message: 'Scheduled date is required' });
    hasError = true;
  } else {
    scheduledDate = parseDate(scheduledDateStr);
    if (!scheduledDate) {
      errors.push({
        rowNumber,
        field: 'scheduledDate',
        message: 'Invalid date format. Use YYYY-MM-DD (e.g., 2025-10-20), DD/MM/YYYY, or MM/DD/YYYY',
      });
      hasError = true;
    } else if (scheduledDate.getTime() < Date.now() - 86400000) {
      warnings.push({ rowNumber, field: 'scheduledDate', message: 'Scheduled date is in the past' });
    }
  }

  const invoiceTotal = invoiceTotalStr ? parseNumber(invoiceTotalStr, rowNumber, 'invoiceTotal', 'invoice total', warnings) : undefined;
  const taxAmount = taxAmountStr ? parseNumber(taxAmountStr, rowNumber, 'taxAmount', 'tax amount', warnings) : undefined;
  const discountAmount = discountAmountStr ? parseNumber(discountAmountStr, rowNumber, 'discountAmount', 'discount amount', warnings) : undefined;

  const items: DeliveryItem[] = [];
  for (let i = 1; i <= 10; i++) {
    const description = (rowData[`item${i}_description`] ?? '').trim();
    if (description.length === 0) continue;

    const quantityStr = (rowData[`item${i}_quantity`] ?? '').trim();
    const unit = rowData[`item${i}_unit`]?.trim();
    const unitPriceStr = rowData[`item${i}_unitPrice`]?.trim();
    const totalPriceStr = rowData[`item${i}_totalPrice`]?.trim();

    let quantity: number | undefined = 1;
    if (quantityStr) {
      quantity = Number(quantityStr);
      if (Number.isNaN(quantity)) {
        errors.push({ rowNumber, field: `item${i}_quantity`, message: `Item ${i} quantity must be a number` });
        hasError = true;
      } else if (quantity <= 0) {
        errors.push({ rowNumber, field: `item${i}_quantity`, message: `Item ${i} quantity must be greater than 0` });
        hasError = true;
      }
    }

    const unitPrice = unitPriceStr ? parseNumber(unitPriceStr, rowNumber, `item${i}_unitPrice`, `item ${i} unit price`, warnings) : undefined;
    const totalPrice = totalPriceStr ? parseNumber(totalPriceStr, rowNumber, `item${i}_totalPrice`, `item ${i} total price`, warnings) : undefined;

    if (quantity != null && quantity > 0) {
      items.push({ description, quantity, unit, unitPrice, totalPrice });
    }
  }

  if (items.length === 0) {
    warnings.push({ rowNumber, field: 'items', message: 'No items specified for this delivery' });
  }

  if (hasError || !scheduledDate) {
    return null;
  }

  return new ParsedDelivery({
    rowNumber,
    customerName,
    customerAddress,
    customerPhone: customerPhone || undefined,
    customerNumber: customerNumber || undefined,
    orderNumber: orderNumber || undefined,
    invoiceNumber,
    invoiceDate,
    invoiceTotal,
    taxAmount,
    discountAmount,
    scheduledDate,
    driverEmail: driverEmail || undefined,
    notes: notes || undefined,
    items,
  });
}

/** Mirrors BulkImportService.parseCsv(). */
export function parseDeliveryCsv(csvContent: string): DeliveryImportResult {
  const validDeliveries: ParsedDelivery[] = [];
  const errors: ImportError[] = [];
  const warnings: ImportWarning[] = [];

  const parsed = Papa.parse<string[]>(csvContent, { skipEmptyLines: false });
  const rows = parsed.data;

  if (rows.length === 0) {
    errors.push({ rowNumber: 0, field: 'file', message: 'CSV file is empty' });
    return { validDeliveries, errors, warnings };
  }

  const headers = rows[0].map((h) => h.toString().trim());

  for (const column of REQUIRED_COLUMNS) {
    if (!headers.includes(column)) {
      errors.push({ rowNumber: 0, field: 'headers', message: `Missing required column: ${column}` });
    }
  }

  if (errors.length > 0) {
    return { validDeliveries, errors, warnings };
  }

  for (let i = 1; i < rows.length; i++) {
    const row = rows[i];
    const rowNumber = i + 1;

    if (row.every((cell) => cell == null || cell.toString().trim().length === 0)) {
      continue;
    }

    try {
      const rowData: Record<string, string> = {};
      for (let j = 0; j < headers.length && j < row.length; j++) {
        rowData[headers[j]] = row[j];
      }

      const parsedRow = parseRow(rowNumber, rowData, errors, warnings);
      if (parsedRow) {
        validDeliveries.push(parsedRow);
      }
    } catch (e) {
      errors.push({ rowNumber, field: 'row', message: `Error parsing row: ${(e as Error).message}` });
    }
  }

  return { validDeliveries, errors, warnings };
}

const TEMPLATE_HEADERS = [
  'customerName',
  'customerAddress',
  'customerPhone',
  'customerNumber',
  'orderNumber',
  'invoiceNumber',
  'invoiceDate',
  'invoiceTotal',
  'taxAmount',
  'discountAmount',
  'scheduledDate',
  'driverEmail',
  'notes',
  'item1_description',
  'item1_quantity',
  'item1_unit',
  'item1_unitPrice',
  'item1_totalPrice',
  'item2_description',
  'item2_quantity',
  'item2_unit',
  'item2_unitPrice',
  'item2_totalPrice',
  'item3_description',
  'item3_quantity',
  'item3_unit',
  'item3_unitPrice',
  'item3_totalPrice',
];

/** Mirrors DeliveryExportService.generateTemplate(), returned as headers+rows for exportToCSV(). */
export function getDeliveryCsvTemplate(): { headers: string[]; rows: string[][] } {
  const today = new Date().toISOString().slice(0, 10);
  const exampleRows = [
    [
      'John Smith',
      '123 Main Street, City, State 12345',
      '+1234567890',
      'CUST001',
      'ORD001',
      'INV001',
      today,
      '1250.00',
      '187.50',
      '0.00',
      today,
      'john@driver.com',
      'Handle with care',
      'Box of Parts',
      '5',
      'boxes',
      '250.00',
      '1250.00',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ],
    [
      'Jane Doe',
      '456 Oak Avenue, Town, State 67890',
      '+9876543210',
      'CUST002',
      'ORD002',
      'INV002',
      today,
      '8960.00',
      '1344.00',
      '200.00',
      today,
      'john@driver.com',
      '',
      'Laptop',
      '1',
      'unit',
      '6000.00',
      '6000.00',
      'Mouse',
      '2',
      'units',
      '296.00',
      '592.00',
      'Keyboard',
      '1',
      'unit',
      '368.00',
      '368.00',
    ],
  ];

  return { headers: TEMPLATE_HEADERS, rows: exampleRows };
}

const ABSERVE_TEMPLATE_HEADERS = [
  'customerName',
  'customerAddress',
  'customerPhone',
  'customerNumber',
  'orderNumber',
  'invoiceNumber',
  'invoiceDate',
  'scheduledDate',
  'driverEmail',
  'vehicleReg',
  'notes',
  'item1_description',
  'item1_quantity',
  'item1_unit',
  'item1_unitPrice',
  'item2_description',
  'item2_quantity',
  'item2_unit',
  'item2_unitPrice',
  'item3_description',
  'item3_quantity',
  'item3_unit',
  'item3_unitPrice',
];

/**
 * Mirrors abaserve_import_screen.dart's bundled `assets/abaserve_import_template.csv`
 * (hardcoded here rather than bundled as a native asset — no other text-asset bundling
 * exists in this project yet, and this is a small, static, one-off template).
 */
export function getAbaserveCsvTemplate(): { headers: string[]; rows: string[][] } {
  const rows = [
    [
      'Acme Butchery',
      '12 Main Rd, Block B, Cape Town, 8001',
      '+27-21-555-0100',
      'C-019',
      'SO-20498',
      'INV-003248',
      '2025-10-25',
      '2025-10-26',
      'christest@test.com',
      'TST123EC',
      'Urgent delivery client closes at 3pm',
      'Beef Rump A Grade',
      '40.5',
      'KG',
      '95',
      'Beef Sirloin Premium',
      '25',
      'KG',
      '145',
      'Lamb Chops Fresh',
      '18',
      'KG',
      '165',
    ],
    [
      'Fresh Meats Ltd',
      '45 Industrial Ave, Durban, 4001',
      '+27-31-555-0200',
      'C-042',
      'SO-20499',
      'INV-003249',
      '2025-10-25',
      '2025-10-27',
      'christest@test.com',
      'TST123EC',
      'Temperature sensitive keep below 2 degrees',
      'Pork Loin Boneless',
      '55.75',
      'KG',
      '85',
      'Chicken Breast Fillet',
      '120',
      'KG',
      '65',
      'Lamb Shanks',
      '12.5',
      'KG',
      '120',
    ],
    [
      'Premium Foods',
      '78 Commerce St, Unit 12, Johannesburg, 2001',
      '+27-11-555-0300',
      'C-085',
      'SO-20500',
      'INV-003250',
      '2025-10-24',
      '2025-10-25',
      'christest@test.com',
      'TST123EC',
      'Standard delivery',
      'Beef Mince 80/20',
      '200.25',
      'KG',
      '75',
      'Pork Ribs',
      '45',
      'KG',
      '95',
      'Chicken Wings',
      '80.5',
      'KG',
      '45',
    ],
  ];

  return { headers: ABSERVE_TEMPLATE_HEADERS, rows };
}

/** Mirrors BulkImportService.checkDuplicateInvoices(). */
export function checkDuplicateInvoices(deliveries: ParsedDelivery[]): ImportError[] {
  const errors: ImportError[] = [];
  const seen = new Map<string, number>();

  for (const delivery of deliveries) {
    const invoice = delivery.invoiceNumber.toLowerCase();
    const seenRow = seen.get(invoice);
    if (seenRow != null) {
      errors.push({
        rowNumber: delivery.rowNumber,
        field: 'invoiceNumber',
        message: `Duplicate invoice number: ${delivery.invoiceNumber} (also in row ${seenRow})`,
      });
    } else {
      seen.set(invoice, delivery.rowNumber);
    }
  }

  return errors;
}
