/**
 * Ported from lib/models/delivery_model.dart (verified against source on 2026-06-21).
 */
export type DeliveryStatus = 'pending' | 'inTransit' | 'delivered' | 'failed';

export interface DeliveryItem {
  description: string;
  quantity: number;
  unit?: string;
  unitPrice?: number;
  totalPrice?: number;
}

export interface Delivery {
  id: string;
  companyId: string;
  driverId: string;
  customerName: string;
  customerAddress: string;
  customerPhone?: string;

  // Customer linking (optional for backwards compatibility)
  customerId?: string; // Links to customers collection
  customerNumber?: string; // For quick lookup and reporting

  orderNumber?: string; // Optional order number
  invoiceNumber: string;
  invoiceDate?: Date; // Date invoice was issued
  items: DeliveryItem[];

  // Financial information
  invoiceTotal?: number; // Total invoice amount
  taxAmount?: number; // Tax amount
  discountAmount?: number; // Discount amount
  currency?: string; // Currency code (default: ZAR)

  // Vehicle information
  vehicleUsed?: string; // Vehicle registration/info used for this delivery

  // Third-party transport information
  isThirdPartyTransport: boolean; // Whether this delivery uses third-party transport
  thirdPartyProviderName?: string; // Name of transport company (e.g., "HFR")
  thirdPartyDriverName?: string; // External driver's name
  thirdPartyDriverPhone?: string; // External driver's phone
  thirdPartyVehicleInfo?: string; // External vehicle details
  uploadToken?: string; // Secure token for document upload
  thirdPartyDocs?: string[]; // URLs of uploaded documents from third party

  status: DeliveryStatus;
  scheduledDate: Date;
  createdAt: Date;
  deliveredAt?: Date;
  notes?: string;
  podId?: string; // Reference to POD document
}
