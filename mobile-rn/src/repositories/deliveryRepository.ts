import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Delivery, DeliveryStatus } from '../models/delivery';
import { deliveryFromFirestore, deliveryToFirestore } from '../models/delivery.converters';
import { normalizeRegistration } from '../utils/vehicleUtils';

/**
 * Ported from lib/services/delivery_service.dart (verified against source on 2026-06-21),
 * following the constructor-injected repository pattern from authRepository.ts rather
 * than the hardcoded-singleton pattern the Flutter service used.
 *
 * Deviations from the Flutter source:
 * - `_notifyAdminsOfStatusChange` (push notifications to company admins on status change)
 *   is NOT ported. No NotificationService exists yet on the RN side (it's a separate,
 *   not-yet-ported domain) — wiring this back in is tracked as follow-up once that
 *   service lands, rather than silently dropping it forever.
 * - The vehicle `totalDeliveries` counter increment (pure Firestore read/update logic,
 *   no notification dependency) IS ported, in `updateDeliveryStatus` and
 *   `linkPODToDelivery`, to preserve that side effect's correctness.
 * - Firestore listeners are exposed as `subscribe*` methods returning an unsubscribe
 *   function (the RN/JS idiom) instead of Dart `Stream<List<Delivery>>` getters.
 */
export class DeliveryRepository {
  constructor(private firestoreInstance: FirebaseFirestoreTypes.Module = firestore()) {}

  /** Mirrors getDeliveriesForDriver(). Returns an unsubscribe function. */
  subscribeToDeliveriesForDriver(
    driverId: string,
    onChange: (deliveries: Delivery[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    return this.firestoreInstance
      .collection('deliveries')
      .where('driverId', '==', driverId)
      .orderBy('scheduledDate', 'desc')
      .onSnapshot(
        (snapshot) => onChange(snapshot.docs.map(deliveryFromFirestore)),
        (error) => onError?.(error as unknown as Error),
      );
  }

  /**
   * Mirrors getDeliveriesForDate(). The Flutter version falls back to a client-side
   * filter of getDeliveriesForDriver() if the composite-index query errors; we replicate
   * that same fallback here since the underlying index requirement is identical.
   */
  subscribeToDeliveriesForDate(
    driverId: string,
    date: Date,
    onChange: (deliveries: Delivery[]) => void,
    onError?: (error: Error) => void,
  ): () => void {
    const startOfDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const endOfDay = new Date(startOfDay);
    endOfDay.setDate(endOfDay.getDate() + 1);

    let fallbackUnsubscribe: (() => void) | null = null;

    const unsubscribe = this.firestoreInstance
      .collection('deliveries')
      .where('driverId', '==', driverId)
      .where('scheduledDate', '>=', firestore.Timestamp.fromDate(startOfDay))
      .where('scheduledDate', '<', firestore.Timestamp.fromDate(endOfDay))
      .orderBy('scheduledDate')
      .onSnapshot(
        (snapshot) => onChange(snapshot.docs.map(deliveryFromFirestore)),
        (error) => {
          const message = String(error);
          if (message.includes('index')) {
            fallbackUnsubscribe = this.subscribeToDeliveriesForDriver(
              driverId,
              (allDeliveries) =>
                onChange(
                  allDeliveries.filter(
                    (d) =>
                      d.scheduledDate.getFullYear() === date.getFullYear() &&
                      d.scheduledDate.getMonth() === date.getMonth() &&
                      d.scheduledDate.getDate() === date.getDate(),
                  ),
                ),
              onError,
            );
            return;
          }
          onError?.(error as unknown as Error);
        },
      );

    return () => {
      unsubscribe();
      fallbackUnsubscribe?.();
    };
  }

  /** Mirrors getCompanyDeliveries() (admin view). */
  /**
   * Mirrors getCompanyDeliveries() by default. delivery_management_screen.dart's own
   * `_getDeliveriesStream` runs a *different* query against the same collection (ordered
   * by `scheduledDate` desc, with a server-side `status` filter per tab) — `filters` below
   * is opt-in so existing callers (e.g. CreateClaimForm.tsx) keep the original
   * createdAt-ordered, unfiltered behavior.
   */
  subscribeToCompanyDeliveries(
    companyId: string,
    onChange: (deliveries: Delivery[]) => void,
    onError?: (error: Error) => void,
    filters?: { status?: DeliveryStatus; orderByScheduledDate?: boolean; limit?: number },
  ): () => void {
    let query: FirebaseFirestoreTypes.Query = this.firestoreInstance.collection('deliveries').where('companyId', '==', companyId);
    if (filters?.status) {
      query = query.where('status', '==', filters.status);
    }
    query = query.orderBy(filters?.orderByScheduledDate ? 'scheduledDate' : 'createdAt', 'desc');
    if (filters?.limit) {
      query = query.limit(filters.limit);
    }

    return query.onSnapshot(
      (snapshot) => onChange(snapshot.docs.map(deliveryFromFirestore)),
      (error) => onError?.(error as unknown as Error),
    );
  }

  async getDeliveryById(deliveryId: string): Promise<Delivery | null> {
    try {
      const doc = await this.firestoreInstance.collection('deliveries').doc(deliveryId).get();
      return doc.exists() ? deliveryFromFirestore(doc) : null;
    } catch {
      return null;
    }
  }

  async createDelivery(delivery: Delivery): Promise<string> {
    try {
      const ref = await this.firestoreInstance.collection('deliveries').add(deliveryToFirestore(delivery));
      return ref.id;
    } catch {
      throw new Error('Failed to create delivery');
    }
  }

  /** Mirrors bulk_upload_screen.dart/abaserve_import_screen.dart's batched bulk-import write (500/batch, Firestore's limit). */
  async createDeliveries(deliveries: Delivery[]): Promise<void> {
    const batchSize = 500;
    for (let i = 0; i < deliveries.length; i += batchSize) {
      const chunk = deliveries.slice(i, i + batchSize);
      const batch = this.firestoreInstance.batch();
      for (const delivery of chunk) {
        const docRef = this.firestoreInstance.collection('deliveries').doc();
        batch.set(docRef, deliveryToFirestore(delivery));
      }
      await batch.commit();
    }
  }

  /** Mirrors bulk_upload_screen.dart's `_loadExistingInvoices` duplicate-detection lookup. */
  async getExistingInvoiceNumbers(companyId: string): Promise<string[]> {
    const snapshot = await this.firestoreInstance.collection('deliveries').where('companyId', '==', companyId).get();
    return snapshot.docs.map((doc) => doc.data().invoiceNumber as string | undefined).filter((value): value is string => Boolean(value));
  }

  async updateDelivery(delivery: Delivery): Promise<void> {
    try {
      await this.firestoreInstance.collection('deliveries').doc(delivery.id).update(deliveryToFirestore(delivery));
    } catch {
      throw new Error('Failed to update delivery');
    }
  }

  async updateDeliveryStatus(deliveryId: string, status: DeliveryStatus): Promise<void> {
    try {
      const deliveryDoc = await this.firestoreInstance.collection('deliveries').doc(deliveryId).get();
      if (!deliveryDoc.exists()) {
        throw new Error('Delivery not found');
      }
      const delivery = deliveryFromFirestore(deliveryDoc);

      const updateData: Record<string, unknown> = { status };
      if (status === 'delivered') {
        updateData.deliveredAt = firestore.FieldValue.serverTimestamp();
      }

      await this.firestoreInstance.collection('deliveries').doc(deliveryId).update(updateData);

      if (delivery.status !== 'delivered' && status === 'delivered' && delivery.vehicleUsed) {
        await this.incrementVehicleDeliveryCount(delivery.companyId, delivery.vehicleUsed);
      }

      // NOTE: Flutter's _notifyAdminsOfStatusChange() is intentionally not ported here.
      // See class-level deviation note.
    } catch {
      throw new Error('Failed to update delivery status');
    }
  }

  async linkPODToDelivery(deliveryId: string, podId: string): Promise<void> {
    try {
      const deliveryDoc = await this.firestoreInstance.collection('deliveries').doc(deliveryId).get();
      if (!deliveryDoc.exists()) {
        throw new Error('Delivery not found');
      }
      const delivery = deliveryFromFirestore(deliveryDoc);

      await this.firestoreInstance.collection('deliveries').doc(deliveryId).update({
        podId,
        status: 'delivered',
        deliveredAt: firestore.FieldValue.serverTimestamp(),
      });

      if (delivery.status !== 'delivered' && delivery.vehicleUsed) {
        await this.incrementVehicleDeliveryCount(delivery.companyId, delivery.vehicleUsed);
      }

      // NOTE: Flutter's _notifyAdminsOfStatusChange() is intentionally not ported here.
      // See class-level deviation note.
    } catch {
      throw new Error('Failed to link POD to delivery');
    }
  }

  async deleteDelivery(deliveryId: string): Promise<void> {
    try {
      await this.firestoreInstance.collection('deliveries').doc(deliveryId).delete();
    } catch {
      throw new Error('Failed to delete delivery');
    }
  }

  async getDeliveryStats(
    companyId: string,
    options?: { startDate?: Date; endDate?: Date },
  ): Promise<Record<string, number>> {
    try {
      let query: FirebaseFirestoreTypes.Query = this.firestoreInstance
        .collection('deliveries')
        .where('companyId', '==', companyId);

      if (options?.startDate) {
        query = query.where('createdAt', '>=', firestore.Timestamp.fromDate(options.startDate));
      }
      if (options?.endDate) {
        query = query.where('createdAt', '<=', firestore.Timestamp.fromDate(options.endDate));
      }

      const snapshot = await query.get();

      const stats: Record<string, number> = {
        total: 0,
        pending: 0,
        inTransit: 0,
        delivered: 0,
        failed: 0,
      };

      snapshot.docs.forEach((doc) => {
        const delivery = deliveryFromFirestore(doc);
        stats.total += 1;
        stats[delivery.status] = (stats[delivery.status] ?? 0) + 1;
      });

      return stats;
    } catch {
      return {};
    }
  }

  async searchDeliveries(companyId: string, searchTerm: string): Promise<Delivery[]> {
    try {
      const snapshot = await this.firestoreInstance
        .collection('deliveries')
        .where('companyId', '==', companyId)
        .get();

      const term = searchTerm.toLowerCase();
      return snapshot.docs.map(deliveryFromFirestore).filter(
        (delivery) =>
          delivery.customerName.toLowerCase().includes(term) ||
          delivery.invoiceNumber.toLowerCase().includes(term) ||
          delivery.customerAddress.toLowerCase().includes(term),
      );
    } catch {
      return [];
    }
  }

  /** Mirrors the vehicle totalDeliveries increment side effect in delivery_service.dart. */
  private async incrementVehicleDeliveryCount(companyId: string, vehicleUsed: string): Promise<void> {
    try {
      const vehicleQuery = await this.firestoreInstance
        .collection('companies')
        .doc(companyId)
        .collection('vehicles')
        .where('registration', '==', normalizeRegistration(vehicleUsed))
        .get();

      if (vehicleQuery.docs.length > 0) {
        const vehicleDoc = vehicleQuery.docs[0];
        await vehicleDoc.ref.update({
          totalDeliveries: firestore.FieldValue.increment(1),
        });
      }
    } catch {
      // Mirrors Flutter: failure to increment the vehicle counter should not block
      // the delivery status update itself.
    }
  }
}
