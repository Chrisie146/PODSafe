import { create } from 'zustand';
import { Vehicle, VehicleStatus } from '../models/vehicle';
import { VehicleRepository } from '../repositories/vehicleRepository';

/**
 * NEW store — there is no Dart provider to port from (both vehicle screens manage their
 * own local widget state directly against Firestore). See vehicleRepository.ts's
 * class-level comment for the same point on the repository side.
 */
const vehicleRepository = new VehicleRepository();

let vehiclesUnsubscribe: (() => void) | null = null;

interface VehicleState {
  companyId: string | null;
  vehicles: Vehicle[];
  isLoading: boolean;
  errorMessage: string | null;

  subscribeForCompany: (companyId: string) => void;
  createVehicle: (params: {
    registration: string;
    make?: string;
    model?: string;
    color?: string;
    licensePlate?: string;
    status: VehicleStatus;
    notes?: string;
  }) => Promise<string>;
  updateVehicle: (
    vehicle: Vehicle,
    params: { registration: string; make?: string; model?: string; color?: string; licensePlate?: string; status: VehicleStatus; notes?: string },
  ) => Promise<void>;
  deleteVehicle: (vehicleId: string) => Promise<void>;
  uploadDocument: (vehicleId: string, fileUri: string, fileName: string, onProgress?: (progress: number) => void) => Promise<string>;
  setDocuments: (vehicleId: string, documentUrls: string[]) => Promise<void>;
  appendDocuments: (vehicleId: string, newUrls: string[]) => Promise<void>;
  removeDocument: (vehicleId: string, docUrl: string) => Promise<void>;
  deleteDocumentByUrl: (url: string) => Promise<void>;
  clear: () => void;
}

export const useVehicleStore = create<VehicleState>((set, get) => ({
  companyId: null,
  vehicles: [],
  isLoading: false,
  errorMessage: null,

  subscribeForCompany: (companyId) => {
    set({ companyId, isLoading: true, errorMessage: null });
    vehiclesUnsubscribe?.();
    vehiclesUnsubscribe = vehicleRepository.subscribeToVehicles(
      companyId,
      (vehicles) => set({ vehicles, isLoading: false }),
      (error) => set({ errorMessage: `Failed to load vehicles: ${error.message}`, isLoading: false }),
    );
  },

  createVehicle: async (params) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    return vehicleRepository.createVehicle(companyId, params);
  },

  updateVehicle: async (vehicle, params) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    await vehicleRepository.updateVehicle(companyId, vehicle, params);
  },

  deleteVehicle: async (vehicleId) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    await vehicleRepository.deleteVehicle(companyId, vehicleId);
  },

  uploadDocument: async (vehicleId, fileUri, fileName, onProgress) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    return vehicleRepository.uploadDocument({ companyId, vehicleId, fileUri, fileName, onProgress });
  },

  setDocuments: async (vehicleId, documentUrls) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    await vehicleRepository.setDocuments(companyId, vehicleId, documentUrls);
  },

  appendDocuments: async (vehicleId, newUrls) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    await vehicleRepository.appendDocuments(companyId, vehicleId, newUrls);
  },

  removeDocument: async (vehicleId, docUrl) => {
    const { companyId } = get();
    if (!companyId) throw new Error('No company selected');
    await vehicleRepository.removeDocument(companyId, vehicleId, docUrl);
  },

  deleteDocumentByUrl: (url) => vehicleRepository.deleteDocumentByUrl(url),

  clear: () => {
    vehiclesUnsubscribe?.();
    vehiclesUnsubscribe = null;
    set({ companyId: null, vehicles: [], isLoading: false, errorMessage: null });
  },
}));
