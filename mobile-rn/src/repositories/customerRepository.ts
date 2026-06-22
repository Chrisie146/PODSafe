import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { Customer, customerSearchString } from '../models/customer';
import { customerFromFirestore, customerToFirestore } from '../models/customer.converters';
import { ParsedCustomer } from './customerImportService';

/**
 * Ported from lib/providers/customer_provider.dart (verified against source on
 * 2026-06-22), following the constructor-injected repository pattern from
 * deliveryRepository.ts/claimRepository.ts rather than the hardcoded-singleton pattern
 * the Flutter provider used.
 *
 * This is a genuine improvement over the Dart source per the migration plan: today
 * `CustomerProvider` talks directly to Firestore with no service/repository layer at
 * all — this gives the customer domain a real one for the first time.
 *
 * Deviations from the Flutter source:
 * - The in-memory cache (`_customers`/`_favoriteCustomers` lists kept on the provider,
 *   used by `searchCustomers`/`getCustomer`/`getCustomerByNumber` to avoid a Firestore
 *   round-trip) is NOT ported into this repository — caching is a UI-state concern that
 *   belongs in `useCustomerStore.ts`, not in a stateless repository. `searchCustomers`/
 *   `getCustomer`/`getCustomerByNumber` here always query Firestore directly; the store
 *   layers a cache-first check on top, matching the same end-to-end behavior.
 */
export class CustomerRepository {
  constructor(private firestoreInstance: FirebaseFirestoreTypes.Module = firestore()) {}

  private customersRef() {
    return this.firestoreInstance.collection('customers');
  }

  /** Mirrors loadCustomers(). */
  async getCustomers(companyId: string): Promise<Customer[]> {
    const snapshot = await this.customersRef().where('companyId', '==', companyId).orderBy('name').get();
    return snapshot.docs.map(customerFromFirestore);
  }

  /** Mirrors searchCustomers()'s Firestore-query fallback path. */
  async searchCustomers(companyId: string, query: string): Promise<Customer[]> {
    const q = query.toLowerCase().trim();
    if (q.length === 0) {
      const all = await this.getCustomers(companyId);
      return all.filter((c) => c.isActive);
    }

    const snapshot = await this.customersRef().where('companyId', '==', companyId).where('isActive', '==', true).get();
    const results = snapshot.docs.map(customerFromFirestore).filter((customer) => customerSearchString(customer).includes(q));

    results.sort((a, b) => {
      const aNumberMatch = a.customerNumber.toLowerCase().startsWith(q);
      const bNumberMatch = b.customerNumber.toLowerCase().startsWith(q);
      if (aNumberMatch && !bNumberMatch) return -1;
      if (!aNumberMatch && bNumberMatch) return 1;
      return a.name.localeCompare(b.name);
    });

    return results;
  }

  /** Mirrors getCustomer(). */
  async getCustomer(customerId: string): Promise<Customer | null> {
    try {
      const doc = await this.customersRef().doc(customerId).get();
      return doc.exists() ? customerFromFirestore(doc) : null;
    } catch {
      return null;
    }
  }

  /** Mirrors getCustomerByNumber(). */
  async getCustomerByNumber(companyId: string, customerNumber: string): Promise<Customer | null> {
    try {
      const snapshot = await this.customersRef()
        .where('companyId', '==', companyId)
        .where('customerNumber', '==', customerNumber)
        .limit(1)
        .get();
      return snapshot.docs.length > 0 ? customerFromFirestore(snapshot.docs[0]) : null;
    } catch {
      return null;
    }
  }

  /** Mirrors createCustomer(): rejects if the customer number already exists for the company. */
  async createCustomer(companyId: string, customer: Customer): Promise<string> {
    const existing = await this.getCustomerByNumber(companyId, customer.customerNumber);
    if (existing) {
      throw new Error(`Customer number ${customer.customerNumber} already exists`);
    }

    const now = new Date();
    const docRef = await this.customersRef().add(customerToFirestore({ ...customer, companyId, createdAt: now, updatedAt: now }));
    return docRef.id;
  }

  /** Mirrors updateCustomer(). */
  async updateCustomer(customer: Customer): Promise<void> {
    await this.customersRef()
      .doc(customer.id)
      .update(customerToFirestore({ ...customer, updatedAt: new Date() }));
  }

  /** Mirrors deleteCustomer(). */
  async deleteCustomer(customerId: string): Promise<void> {
    await this.customersRef().doc(customerId).delete();
  }

  /** Mirrors toggleFavorite() — read-modify-write, same as the Dart source. */
  async toggleFavorite(customer: Customer): Promise<void> {
    await this.updateCustomer({ ...customer, isFavorite: !customer.isFavorite });
  }

  /** Mirrors updateCustomerStats(). */
  async updateCustomerStats(customer: Customer, deliveryDate: Date): Promise<void> {
    await this.updateCustomer({
      ...customer,
      stats: {
        totalDeliveries: customer.stats.totalDeliveries + 1,
        lastDelivery: deliveryDate,
        firstDelivery: customer.stats.firstDelivery ?? deliveryDate,
      },
    });
  }

  /** Mirrors createCustomers(): batched writes, 500/batch (Firestore's limit). */
  async createCustomers(companyId: string, customers: Customer[]): Promise<void> {
    const batchSize = 500;
    for (let i = 0; i < customers.length; i += batchSize) {
      const chunk = customers.slice(i, i + batchSize);
      const batch = this.firestoreInstance.batch();
      for (const customer of chunk) {
        const docRef = this.customersRef().doc();
        batch.set(docRef, customerToFirestore({ ...customer, companyId }));
      }
      await batch.commit();
    }
  }

  /**
   * Mirrors importCustomers(): batched writes with duplicate-number detection against
   * the existing customer list (passed in, since caching is the store's job here).
   */
  async importCustomers(
    companyId: string,
    parsedCustomers: ParsedCustomer[],
    existingCustomers: Customer[],
    onProgress?: (current: number, total: number) => void,
  ): Promise<{ total: number; successful: number; failed: number; errors: string[] }> {
    const existingNumbers = new Set(existingCustomers.map((c) => c.customerNumber.toLowerCase()));
    let successCount = 0;
    let errorCount = 0;
    const errors: string[] = [];

    const batchSize = 500;
    for (let i = 0; i < parsedCustomers.length; i += batchSize) {
      const end = Math.min(i + batchSize, parsedCustomers.length);
      const batch = this.firestoreInstance.batch();

      for (let j = i; j < end; j++) {
        const parsed = parsedCustomers[j];
        if (existingNumbers.has(parsed.customerNumber.toLowerCase())) {
          errorCount++;
          errors.push(`Row ${parsed.rowNumber}: Customer number ${parsed.customerNumber} already exists`);
          continue;
        }

        const docRef = this.customersRef().doc();
        batch.set(docRef, customerToFirestore(parsed.toCustomer(companyId)));
        successCount++;
        onProgress?.(j + 1, parsedCustomers.length);
      }

      await batch.commit();
    }

    return { total: parsedCustomers.length, successful: successCount, failed: errorCount, errors };
  }
}
