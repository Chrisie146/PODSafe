import { create } from 'zustand';
import { Customer, customerSearchString } from '../models/customer';
import { CustomerRepository } from '../repositories/customerRepository';
import { ParsedCustomer } from '../repositories/customerImportService';

/**
 * Replaces lib/providers/customer_provider.dart's CustomerProvider (ChangeNotifier).
 * The in-memory cache-first behavior (search/get checking `_customers` before hitting
 * Firestore) is preserved here, same as the Dart source — see customerRepository.ts's
 * class-level comment for why that cache lives in the store rather than the repository.
 */
const customerRepository = new CustomerRepository();

interface CustomerState {
  companyId: string | null;
  customers: Customer[];
  favoriteCustomers: Customer[];
  activeCustomers: Customer[];
  isLoading: boolean;
  errorMessage: string | null;
  hasCustomers: boolean;

  initialize: (companyId: string) => Promise<void>;
  loadCustomers: () => Promise<void>;
  searchCustomers: (query: string) => Promise<Customer[]>;
  getCustomer: (customerId: string) => Promise<Customer | null>;
  getCustomerByNumber: (customerNumber: string) => Promise<Customer | null>;
  createCustomer: (customer: Customer) => Promise<string | null>;
  updateCustomer: (customer: Customer) => Promise<void>;
  deleteCustomer: (customerId: string) => Promise<void>;
  toggleFavorite: (customerId: string) => Promise<void>;
  updateCustomerStats: (customerId: string, deliveryDate: Date) => Promise<void>;
  importCustomers: (
    parsedCustomers: ParsedCustomer[],
    onProgress?: (current: number, total: number) => void,
  ) => Promise<{ total: number; successful: number; failed: number; errors: string[] }>;
  createCustomers: (customers: Customer[]) => Promise<void>;
  clear: () => void;
}

function deriveActiveAndFavorites(customers: Customer[]) {
  return {
    activeCustomers: customers.filter((c) => c.isActive),
    favoriteCustomers: customers.filter((c) => c.isFavorite),
  };
}

export const useCustomerStore = create<CustomerState>((set, get) => ({
  companyId: null,
  customers: [],
  favoriteCustomers: [],
  activeCustomers: [],
  isLoading: false,
  errorMessage: null,
  hasCustomers: false,

  initialize: async (companyId) => {
    set({ companyId });
    await get().loadCustomers();
  },

  loadCustomers: async () => {
    const { companyId } = get();
    if (!companyId) return;

    set({ isLoading: true, errorMessage: null });
    try {
      const customers = await customerRepository.getCustomers(companyId);
      set({ customers, hasCustomers: customers.length > 0, isLoading: false, ...deriveActiveAndFavorites(customers) });
    } catch (e) {
      set({ errorMessage: `Failed to load customers: ${(e as Error).message}`, isLoading: false });
    }
  },

  searchCustomers: async (query) => {
    const { companyId, customers } = get();
    if (!companyId) return [];

    const q = query.toLowerCase().trim();
    if (q.length === 0) return customers.filter((c) => c.isActive);

    const cached = customers.filter((c) => c.isActive && customerSearchString(c).includes(q));
    if (cached.length > 0) {
      cached.sort((a, b) => {
        const aMatch = a.customerNumber.toLowerCase().startsWith(q);
        const bMatch = b.customerNumber.toLowerCase().startsWith(q);
        if (aMatch && !bMatch) return -1;
        if (!aMatch && bMatch) return 1;
        return a.name.localeCompare(b.name);
      });
      return cached;
    }

    try {
      return await customerRepository.searchCustomers(companyId, query);
    } catch {
      return [];
    }
  },

  getCustomer: async (customerId) => {
    const cached = get().customers.find((c) => c.id === customerId);
    if (cached) return cached;
    return customerRepository.getCustomer(customerId);
  },

  getCustomerByNumber: async (customerNumber) => {
    const { companyId, customers } = get();
    if (!companyId) return null;

    const cached = customers.find((c) => c.customerNumber.toLowerCase() === customerNumber.toLowerCase());
    if (cached) return cached;

    return customerRepository.getCustomerByNumber(companyId, customerNumber);
  },

  createCustomer: async (customer) => {
    const { companyId } = get();
    if (!companyId) {
      set({ errorMessage: 'No company selected' });
      return null;
    }

    try {
      const id = await customerRepository.createCustomer(companyId, customer);
      await get().loadCustomers();
      return id;
    } catch (e) {
      set({ errorMessage: (e as Error).message });
      throw e;
    }
  },

  updateCustomer: async (customer) => {
    try {
      await customerRepository.updateCustomer(customer);
      set((state) => {
        const customers = state.customers.map((c) => (c.id === customer.id ? { ...customer, updatedAt: new Date() } : c));
        return { customers, ...deriveActiveAndFavorites(customers) };
      });
    } catch (e) {
      set({ errorMessage: `Failed to update customer: ${(e as Error).message}` });
      throw e;
    }
  },

  deleteCustomer: async (customerId) => {
    try {
      await customerRepository.deleteCustomer(customerId);
      set((state) => {
        const customers = state.customers.filter((c) => c.id !== customerId);
        return { customers, ...deriveActiveAndFavorites(customers) };
      });
    } catch (e) {
      set({ errorMessage: `Failed to delete customer: ${(e as Error).message}` });
      throw e;
    }
  },

  toggleFavorite: async (customerId) => {
    const customer = get().customers.find((c) => c.id === customerId);
    if (!customer) return;
    await get().updateCustomer({ ...customer, isFavorite: !customer.isFavorite });
  },

  updateCustomerStats: async (customerId, deliveryDate) => {
    const customer = await get().getCustomer(customerId);
    if (!customer) return;

    await get().updateCustomer({
      ...customer,
      stats: {
        totalDeliveries: customer.stats.totalDeliveries + 1,
        lastDelivery: deliveryDate,
        firstDelivery: customer.stats.firstDelivery ?? deliveryDate,
      },
    });
  },

  importCustomers: async (parsedCustomers, onProgress) => {
    const { companyId, customers } = get();
    if (!companyId) {
      throw new Error('Company ID not initialized');
    }

    const result = await customerRepository.importCustomers(companyId, parsedCustomers, customers, onProgress);
    await get().loadCustomers();
    return result;
  },

  createCustomers: async (customers) => {
    const { companyId } = get();
    if (!companyId) {
      throw new Error('Company ID not initialized');
    }

    await customerRepository.createCustomers(companyId, customers);
    await get().loadCustomers();
  },

  clear: () =>
    set({
      companyId: null,
      customers: [],
      favoriteCustomers: [],
      activeCustomers: [],
      isLoading: false,
      errorMessage: null,
      hasCustomers: false,
    }),
}));
