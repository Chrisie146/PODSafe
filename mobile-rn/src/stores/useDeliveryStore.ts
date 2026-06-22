import { create } from 'zustand';
import { Delivery, DeliveryStatus } from '../models/delivery';
import { DeliveryRepository } from '../repositories/deliveryRepository';

/**
 * Replaces lib/providers/delivery_provider.dart's DeliveryProvider (ChangeNotifier).
 *
 * Deviations from the Flutter source:
 * - Offline queueing (OfflineService: isOnline()/saveDeliveriesOffline()/addToSyncQueue()/
 *   getSyncQueue()/syncOfflineData()) is NOT ported. No OfflineService exists yet on the
 *   RN side — this store always goes straight to the repository (online-only for now).
 *   Re-introducing offline support is tracked as follow-up once that service is ported.
 * - `todaysDeliveries` exists as a getter-only empty list in the Flutter provider (it's
 *   declared `final` and never populated — `loadTodaysDeliveries`/`refreshTodaysDeliveries`
 *   write into `_deliveries`, not `_todaysDeliveries`, which looks like a latent bug
 *   upstream). We replicate the same observable behavior here for parity: dedicated
 *   `todaysDeliveries` state populated by `loadTodaysDeliveries`/`refreshTodaysDeliveries`,
 *   kept separate from `deliveries`, since storing it as dead state would be pointless to
 *   port and a plain bug-for-bug clone would be worse for a production app than fixing the
 *   obvious mismatch while keeping the same public method names.
 * - Firestore listeners are unsubscribed automatically when a new subscription replaces
 *   them (e.g. calling loadDriverDeliveries twice), since this store retains the
 *   unsubscribe handle internally — the Flutter provider leaked its stream subscriptions.
 */

const deliveryRepository = new DeliveryRepository();

interface DeliveryState {
  deliveries: Delivery[];
  todaysDeliveries: Delivery[];
  selectedDelivery: Delivery | null;
  isLoading: boolean;
  errorMessage: string | null;
  deliveryStats: Record<string, number>;

  loadDriverDeliveries: (driverId: string) => void;
  loadTodaysDeliveries: (driverId: string) => Promise<void>;
  refreshTodaysDeliveries: (driverId: string) => Promise<void>;
  loadCompanyDeliveries: (companyId: string) => void;
  loadDeliveryById: (deliveryId: string) => Promise<void>;
  deleteDelivery: (deliveryId: string) => Promise<boolean>;
  createDelivery: (delivery: Delivery) => Promise<boolean>;
  updateDelivery: (delivery: Delivery) => Promise<boolean>;
  updateDeliveryStatus: (deliveryId: string, status: DeliveryStatus) => Promise<boolean>;
  linkPODToDelivery: (deliveryId: string, podId: string) => Promise<boolean>;
  loadDeliveryStats: (companyId: string, options?: { startDate?: Date; endDate?: Date }) => Promise<void>;
  searchDeliveries: (companyId: string, searchTerm: string) => Promise<void>;
  setSelectedDelivery: (delivery: Delivery) => void;
  clearSelectedDelivery: () => void;
  clearData: () => void;
}

let driverDeliveriesUnsubscribe: (() => void) | null = null;
let todaysDeliveriesUnsubscribe: (() => void) | null = null;
let companyDeliveriesUnsubscribe: (() => void) | null = null;

function isSameDay(a: Date, b: Date): boolean {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
}

export const useDeliveryStore = create<DeliveryState>((set, get) => ({
  deliveries: [],
  todaysDeliveries: [],
  selectedDelivery: null,
  isLoading: false,
  errorMessage: null,
  deliveryStats: {},

  loadDriverDeliveries: (driverId) => {
    set({ isLoading: true, errorMessage: null });
    driverDeliveriesUnsubscribe?.();
    driverDeliveriesUnsubscribe = deliveryRepository.subscribeToDeliveriesForDriver(
      driverId,
      (deliveries) => set({ deliveries, isLoading: false }),
      (error) => set({ errorMessage: `Failed to load deliveries: ${error.message}`, isLoading: false }),
    );
  },

  loadTodaysDeliveries: async (driverId) => {
    set({ isLoading: true, errorMessage: null });
    const today = new Date();

    try {
      todaysDeliveriesUnsubscribe?.();
      todaysDeliveriesUnsubscribe = deliveryRepository.subscribeToDeliveriesForDriver(
        driverId,
        (allDeliveries) => {
          set({
            todaysDeliveries: allDeliveries.filter((d) => isSameDay(d.scheduledDate, today)),
            isLoading: false,
          });
        },
        (error) => set({ errorMessage: `Failed to load today's deliveries: ${error.message}`, isLoading: false }),
      );
    } catch (e) {
      set({ errorMessage: `Failed to load today's deliveries: ${(e as Error).message}`, isLoading: false });
    }
  },

  refreshTodaysDeliveries: async (driverId) => {
    await get().loadTodaysDeliveries(driverId);
  },

  loadCompanyDeliveries: (companyId) => {
    set({ isLoading: true, errorMessage: null });
    companyDeliveriesUnsubscribe?.();
    companyDeliveriesUnsubscribe = deliveryRepository.subscribeToCompanyDeliveries(
      companyId,
      (deliveries) => set({ deliveries, isLoading: false }),
      (error) => set({ errorMessage: `Failed to load company deliveries: ${error.message}`, isLoading: false }),
    );
  },

  loadDeliveryById: async (deliveryId) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const delivery = await deliveryRepository.getDeliveryById(deliveryId);
      if (delivery) {
        set({ selectedDelivery: delivery, isLoading: false });
      } else {
        set({ errorMessage: 'Delivery not found', isLoading: false });
      }
    } catch (e) {
      set({ errorMessage: `Failed to load delivery: ${(e as Error).message}`, isLoading: false });
    }
  },

  deleteDelivery: async (deliveryId) => {
    try {
      await deliveryRepository.deleteDelivery(deliveryId);
      set((state) => ({
        deliveries: state.deliveries.filter((d) => d.id !== deliveryId),
        selectedDelivery: state.selectedDelivery?.id === deliveryId ? null : state.selectedDelivery,
      }));
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to delete delivery: ${(e as Error).message}` });
      return false;
    }
  },

  createDelivery: async (delivery) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const deliveryId = await deliveryRepository.createDelivery(delivery);
      set({ selectedDelivery: { ...delivery, id: deliveryId }, isLoading: false });
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to create delivery: ${(e as Error).message}`, isLoading: false });
      return false;
    }
  },

  updateDelivery: async (delivery) => {
    set({ isLoading: true, errorMessage: null });
    try {
      await deliveryRepository.updateDelivery(delivery);

      set((state) => ({
        selectedDelivery: delivery,
        deliveries: state.deliveries.map((d) => (d.id === delivery.id ? delivery : d)),
        todaysDeliveries: state.todaysDeliveries.map((d) => (d.id === delivery.id ? delivery : d)),
        isLoading: false,
      }));
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to update delivery: ${(e as Error).message}`, isLoading: false });
      return false;
    }
  },

  updateDeliveryStatus: async (deliveryId, status) => {
    set({ isLoading: true, errorMessage: null });
    try {
      await deliveryRepository.updateDeliveryStatus(deliveryId, status);

      set((state) => ({
        selectedDelivery:
          state.selectedDelivery?.id === deliveryId
            ? {
                ...state.selectedDelivery,
                status,
                deliveredAt: status === 'delivered' ? new Date() : state.selectedDelivery.deliveredAt,
              }
            : state.selectedDelivery,
        isLoading: false,
      }));
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to update delivery status: ${(e as Error).message}`, isLoading: false });
      return false;
    }
  },

  linkPODToDelivery: async (deliveryId, podId) => {
    try {
      await deliveryRepository.linkPODToDelivery(deliveryId, podId);

      set((state) =>
        state.selectedDelivery?.id === deliveryId
          ? {
              selectedDelivery: {
                ...state.selectedDelivery,
                podId,
                status: 'delivered',
                deliveredAt: new Date(),
              },
            }
          : {},
      );
      return true;
    } catch (e) {
      set({ errorMessage: `Failed to link POD to delivery: ${(e as Error).message}` });
      return false;
    }
  },

  loadDeliveryStats: async (companyId, options) => {
    try {
      const stats = await deliveryRepository.getDeliveryStats(companyId, options);
      set({ deliveryStats: stats });
    } catch {
      // Mirrors Flutter: stats load failure is logged only, not surfaced as an error state.
    }
  },

  searchDeliveries: async (companyId, searchTerm) => {
    set({ isLoading: true, errorMessage: null });
    try {
      const searchResults = await deliveryRepository.searchDeliveries(companyId, searchTerm);
      set({ deliveries: searchResults, isLoading: false });
    } catch (e) {
      set({ errorMessage: `Failed to search deliveries: ${(e as Error).message}`, isLoading: false });
    }
  },

  setSelectedDelivery: (delivery) => set({ selectedDelivery: delivery }),

  clearSelectedDelivery: () => set({ selectedDelivery: null }),

  clearData: () => {
    driverDeliveriesUnsubscribe?.();
    todaysDeliveriesUnsubscribe?.();
    companyDeliveriesUnsubscribe?.();
    driverDeliveriesUnsubscribe = null;
    todaysDeliveriesUnsubscribe = null;
    companyDeliveriesUnsubscribe = null;
    set({
      deliveries: [],
      todaysDeliveries: [],
      selectedDelivery: null,
      deliveryStats: {},
      isLoading: false,
      errorMessage: null,
    });
  },
}));
