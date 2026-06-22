/**
 * Ported from lib/models/vehicle_model.dart (verified against source on 2026-06-22).
 */
export type VehicleStatus = 'active' | 'inactive' | 'maintenance';

export interface Vehicle {
  id: string;
  companyId: string;
  registration: string;
  documents?: string[];
  make?: string;
  model?: string;
  color?: string;
  licensePlate?: string;
  status: VehicleStatus;
  totalDeliveries: number;
  createdAt: Date;
  lastUsedAt?: Date;
  notes?: string;
}
