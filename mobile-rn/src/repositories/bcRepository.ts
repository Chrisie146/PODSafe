import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import functions, { FirebaseFunctionsTypes } from '@react-native-firebase/functions';
import { BcConfig } from '../models/bcConfig';
import { bcConfigFromFirestore, bcConfigToFirestore } from '../models/bcConfig.converters';

/**
 * Ported from lib/services/business_central_service.dart (verified against source on
 * 2026-06-22), following the constructor-injected repository pattern from
 * deliveryRepository.ts/claimRepository.ts.
 *
 * Per the migration plan, the 3 callables this depends on (`bcAuthenticate`,
 * `bcApiCall`, `bcTestConnection`) don't exist yet — they're Phase 5 backend work (see
 * vault "08 Backend Gap Fix Tracker"). This is the REAL client integration code, not a
 * placeholder: every method here will start working as soon as those callables are
 * deployed, with no changes needed on this side.
 *
 * Deviation: the Dart source caches the BC access token in `flutter_secure_storage`
 * (persists across app restarts). This repository caches in-memory only
 * (`_cachedAccessToken`/`_cachedTokenExpiry` instance fields) — BC settings/sync is an
 * occasionally-used admin feature, not a core driver flow, so losing the cached token on
 * app restart just costs one extra OAuth round-trip, not a correctness issue. Adding
 * `react-native-keychain` (the plan's chosen flutter_secure_storage replacement) for
 * persistent secure caching is a reasonable follow-up, not done here to avoid pulling in
 * another native dependency for a low-stakes cache.
 */
export class BcRepository {
  private cachedAccessToken: string | null = null;
  private cachedTokenExpiry: Date | null = null;

  constructor(
    private firestoreInstance: FirebaseFirestoreTypes.Module = firestore(),
    private functionsInstance: FirebaseFunctionsTypes.Module = functions(),
  ) {}

  private bcConfigRef(companyId: string) {
    return this.firestoreInstance.collection('companies').doc(companyId).collection('integrations').doc('businessCentral');
  }

  // ===================== CONFIGURATION =====================

  /** Mirrors getConfig(). */
  async getConfig(companyId: string): Promise<BcConfig | null> {
    try {
      const doc = await this.bcConfigRef(companyId).get();
      return doc.exists() ? bcConfigFromFirestore(doc) : null;
    } catch {
      return null;
    }
  }

  /** Mirrors saveConfig(). */
  async saveConfig(config: BcConfig): Promise<void> {
    await this.bcConfigRef(config.companyId).set(bcConfigToFirestore(config), { merge: true });
  }

  /** Mirrors updateSyncStatus(). */
  async updateSyncStatus(companyId: string, status: string, error?: string): Promise<void> {
    try {
      await this.bcConfigRef(companyId).update({
        lastSyncStatus: status,
        lastSyncError: error ?? null,
        lastSyncedAt: firestore.FieldValue.serverTimestamp(),
      });
    } catch {
      // Mirrors the Dart source: a sync-status write failure is logged, not thrown.
    }
  }

  // ===================== AUTHENTICATION =====================

  /** Mirrors authenticate(): calls the bcAuthenticate Cloud Function. */
  async authenticate(config: BcConfig, clientSecret: string): Promise<string> {
    const callable = this.functionsInstance.httpsCallable('bcAuthenticate');
    const result = await callable({ companyId: config.companyId, clientSecret });
    const data = result.data as { accessToken: string; expiresIn: number };

    this.cachedAccessToken = data.accessToken;
    this.cachedTokenExpiry = new Date(Date.now() + data.expiresIn * 1000);

    return data.accessToken;
  }

  /** Mirrors getAccessToken(): returns the cached token if still valid, else re-authenticates. */
  async getAccessToken(config: BcConfig, clientSecret: string): Promise<string> {
    if (this.cachedAccessToken && this.cachedTokenExpiry && this.cachedTokenExpiry.getTime() > Date.now() + 5 * 60 * 1000) {
      return this.cachedAccessToken;
    }
    return this.authenticate(config, clientSecret);
  }

  /** Mirrors clearTokens(). */
  clearTokens(): void {
    this.cachedAccessToken = null;
    this.cachedTokenExpiry = null;
  }

  // ===================== API CALLS =====================

  /** Mirrors get(): calls the bcApiCall Cloud Function with method GET. */
  async get(config: BcConfig, endpoint: string, clientSecret: string): Promise<Record<string, unknown>> {
    const callable = this.functionsInstance.httpsCallable('bcApiCall');
    const result = await callable({ companyId: config.companyId, clientSecret, method: 'GET', endpoint });
    return result.data as Record<string, unknown>;
  }

  /** Mirrors post(). */
  async post(config: BcConfig, endpoint: string, clientSecret: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
    const callable = this.functionsInstance.httpsCallable('bcApiCall');
    const result = await callable({ companyId: config.companyId, clientSecret, method: 'POST', endpoint, body });
    return result.data as Record<string, unknown>;
  }

  /** Mirrors patch(). */
  async patch(config: BcConfig, endpoint: string, clientSecret: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
    const callable = this.functionsInstance.httpsCallable('bcApiCall');
    const result = await callable({ companyId: config.companyId, clientSecret, method: 'PATCH', endpoint, body });
    return result.data as Record<string, unknown>;
  }

  // ===================== TEST CONNECTION =====================

  /** Mirrors testConnection(): calls the bcTestConnection Cloud Function. */
  async testConnection(config: BcConfig, clientSecret: string): Promise<boolean> {
    try {
      const callable = this.functionsInstance.httpsCallable('bcTestConnection');
      const result = await callable({ companyId: config.companyId, clientSecret });
      const data = result.data as { success: boolean };
      return data.success;
    } catch {
      return false;
    }
  }

  // ===================== CUSTOMER SYNC =====================

  /** Mirrors getCustomers(). */
  async getCustomers(config: BcConfig, clientSecret: string, options?: { top?: number; skip?: number }): Promise<Record<string, unknown>[]> {
    let endpoint = `companies(${config.bcCompanyId})/customers`;
    const params: string[] = [];
    if (options?.top != null) params.push(`$top=${options.top}`);
    if (options?.skip != null) params.push(`$skip=${options.skip}`);
    if (params.length > 0) endpoint += `?${params.join('&')}`;

    const result = await this.get(config, endpoint, clientSecret);
    return (result.value as Record<string, unknown>[]) ?? [];
  }

  /** Mirrors syncCustomerToFirestore(): uses the BC customer number as the doc ID to prevent duplicates. */
  async syncCustomerToFirestore(companyId: string, bcCustomer: Record<string, unknown>): Promise<void> {
    const address = bcCustomer.address as Record<string, unknown> | undefined;
    const customerId = (bcCustomer.number as string) ?? (bcCustomer.id as string);

    await this.firestoreInstance
      .collection('customers')
      .doc(`bc_${customerId}`)
      .set(
        {
          companyId,
          name: bcCustomer.displayName ?? bcCustomer.number ?? 'Unknown',
          email: bcCustomer.email ?? '',
          phone: bcCustomer.phoneNumber ?? '',
          address: address?.street ?? '',
          city: address?.city ?? '',
          postalCode: address?.postalCode ?? '',
          accountNumber: bcCustomer.number ?? '',
          customerNumber: bcCustomer.number ?? '',
          bcCustomerId: bcCustomer.id,
          bcSyncedAt: firestore.FieldValue.serverTimestamp(),
          updatedAt: firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
  }

  // ===================== SALES ORDER SYNC =====================

  /** Mirrors getSalesOrders(). */
  async getSalesOrders(config: BcConfig, clientSecret: string, options?: { filter?: string; top?: number }): Promise<Record<string, unknown>[]> {
    let endpoint = `companies(${config.bcCompanyId})/salesOrders`;
    const params: string[] = [];
    if (options?.filter) params.push(`$filter=${options.filter}`);
    if (options?.top != null) params.push(`$top=${options.top}`);
    params.push('$expand=salesOrderLines');
    endpoint += `?${params.join('&')}`;

    const result = await this.get(config, endpoint, clientSecret);
    return (result.value as Record<string, unknown>[]) ?? [];
  }

  /** Mirrors updateSalesOrderStatus(). */
  async updateSalesOrderStatus(config: BcConfig, clientSecret: string, orderId: string, updates: Record<string, unknown>): Promise<void> {
    const endpoint = `companies(${config.bcCompanyId})/salesOrders(${orderId})`;
    await this.patch(config, endpoint, clientSecret, updates);
  }

  // ===================== DELIVERY STATUS SYNC =====================

  /**
   * Mirrors syncDeliveryStatus() — an explicit placeholder in the Dart source (it only
   * logs; the actual BC update call is commented out pending custom-field setup in BC).
   * Ported as the same placeholder rather than inventing an implementation the source
   * doesn't have.
   */
  async syncDeliveryStatus(orderNumber: string, status: string, deliveredAt?: Date, driverName?: string): Promise<void> {
    console.log(`Would sync delivery status for order: ${orderNumber}`, { status, deliveredAt, driverName });
    // TODO: Implement actual BC update when custom fields are configured in BC (see Dart source).
  }

  // ===================== ITEMS/PRODUCTS SYNC =====================

  /** Mirrors getItems(). */
  async getItems(config: BcConfig, clientSecret: string, top?: number): Promise<Record<string, unknown>[]> {
    let endpoint = `companies(${config.bcCompanyId})/items`;
    if (top != null) endpoint += `?$top=${top}`;

    const result = await this.get(config, endpoint, clientSecret);
    return (result.value as Record<string, unknown>[]) ?? [];
  }

  // ===================== SYNC LOGS =====================

  /** Mirrors logSync(). */
  async logSync(
    companyId: string,
    syncType: string,
    status: string,
    recordsProcessed: number,
    options?: { errors?: string[]; durationMs?: number },
  ): Promise<void> {
    try {
      await this.firestoreInstance.collection('companies').doc(companyId).collection('syncLogs').add({
        timestamp: firestore.FieldValue.serverTimestamp(),
        syncType,
        status,
        recordsProcessed,
        errors: options?.errors ?? [],
        duration: options?.durationMs ?? null,
      });
    } catch {
      // Mirrors the Dart source: a logging failure shouldn't break the sync flow itself.
    }
  }
}
