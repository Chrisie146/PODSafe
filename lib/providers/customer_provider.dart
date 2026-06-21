import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/customer_model.dart';
import '../services/customer_import_service.dart';

/// Provider for managing customer data
class CustomerProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _companyId;
  List<Customer> _customers = [];
  List<Customer> _favoriteCustomers = [];
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Customer> get customers => _customers;
  List<Customer> get favoriteCustomers => _favoriteCustomers;
  List<Customer> get activeCustomers => _customers.where((c) => c.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCustomers => _customers.isNotEmpty;

  /// Initialize provider with company ID
  Future<void> initialize(String companyId) async {
    _companyId = companyId;
    await loadCustomers();
  }

  /// Load all customers for the company
  Future<void> loadCustomers() async {
    if (_companyId == null) return;

    try {
      _isLoading = true;
      _error = null;
      // Only notify if we have listeners (not during initial setup)
      if (hasListeners) notifyListeners();

      final snapshot = await _firestore
          .collection('customers')
          .where('companyId', isEqualTo: _companyId)
          .orderBy('name')
          .get();

      _customers = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .toList();

      _favoriteCustomers = _customers.where((c) => c.isFavorite).toList();

      _isLoading = false;
      if (hasListeners) notifyListeners();
    } catch (e) {
      _error = 'Failed to load customers: $e';
      _isLoading = false;
      if (hasListeners) notifyListeners();
      rethrow;
    }
  }

  /// Search customers by query (customer number or name)
  Future<List<Customer>> searchCustomers(String query) async {
    if (_companyId == null) return [];
    if (query.trim().isEmpty) return activeCustomers;

    final q = query.toLowerCase().trim();

    // First check cached customers
    final cachedResults = _customers.where((customer) {
      return customer.isActive && customer.searchString.contains(q);
    }).toList();

    if (cachedResults.isNotEmpty) {
      // Sort by relevance (customer number match first)
      cachedResults.sort((a, b) {
        final aNumberMatch = a.customerNumber.toLowerCase().startsWith(q);
        final bNumberMatch = b.customerNumber.toLowerCase().startsWith(q);
        if (aNumberMatch && !bNumberMatch) return -1;
        if (!aNumberMatch && bNumberMatch) return 1;
        return a.name.compareTo(b.name);
      });
      return cachedResults;
    }

    // If no cached results, query Firestore
    try {
      final snapshot = await _firestore
          .collection('customers')
          .where('companyId', isEqualTo: _companyId)
          .where('isActive', isEqualTo: true)
          .get();

      final results = snapshot.docs
          .map((doc) => Customer.fromFirestore(doc))
          .where((customer) => customer.searchString.contains(q))
          .toList();

      results.sort((a, b) {
        final aNumberMatch = a.customerNumber.toLowerCase().startsWith(q);
        final bNumberMatch = b.customerNumber.toLowerCase().startsWith(q);
        if (aNumberMatch && !bNumberMatch) return -1;
        if (!aNumberMatch && bNumberMatch) return 1;
        return a.name.compareTo(b.name);
      });

      return results;
    } catch (e) {
      debugPrint('Error searching customers: $e');
      return [];
    }
  }

  /// Get customer by ID
  Future<Customer?> getCustomer(String customerId) async {
    try {
      // Check cache first
      final cached = _customers.firstWhere(
        (c) => c.id == customerId,
        orElse: () => Customer(
          id: '',
          companyId: '',
          customerNumber: '',
          name: '',
          address: '',
        ),
      );

      if (cached.id.isNotEmpty) return cached;

      // Fetch from Firestore
      final doc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();

      if (doc.exists) {
        return Customer.fromFirestore(doc);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting customer: $e');
      return null;
    }
  }

  /// Get customer by customer number
  Future<Customer?> getCustomerByNumber(String customerNumber) async {
    if (_companyId == null) return null;

    try {
      // Check cache first
      final cached = _customers.firstWhere(
        (c) => c.customerNumber.toLowerCase() == customerNumber.toLowerCase(),
        orElse: () => Customer(
          id: '',
          companyId: '',
          customerNumber: '',
          name: '',
          address: '',
        ),
      );

      if (cached.id.isNotEmpty) return cached;

      // Fetch from Firestore
      final snapshot = await _firestore
          .collection('customers')
          .where('companyId', isEqualTo: _companyId)
          .where('customerNumber', isEqualTo: customerNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Customer.fromFirestore(snapshot.docs.first);
      }

      return null;
    } catch (e) {
      debugPrint('Error getting customer by number: $e');
      return null;
    }
  }

  /// Create a new customer
  Future<String?> createCustomer(Customer customer) async {
    if (_companyId == null) return null;

    try {
      // Check if customer number already exists
      final existing = await getCustomerByNumber(customer.customerNumber);
      if (existing != null) {
        throw Exception('Customer number ${customer.customerNumber} already exists');
      }

      // Create customer
      final docRef = await _firestore.collection('customers').add(
        customer.copyWith(
          companyId: _companyId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ).toFirestore(),
      );

      // Reload customers
      await loadCustomers();

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating customer: $e');
      rethrow;
    }
  }

  /// Update an existing customer
  Future<void> updateCustomer(Customer customer) async {
    try {
      await _firestore.collection('customers').doc(customer.id).update(
        customer.copyWith(updatedAt: DateTime.now()).toFirestore(),
      );

      // Update local cache
      final index = _customers.indexWhere((c) => c.id == customer.id);
      if (index != -1) {
        _customers[index] = customer.copyWith(updatedAt: DateTime.now());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  /// Delete a customer
  Future<void> deleteCustomer(String customerId) async {
    try {
      await _firestore.collection('customers').doc(customerId).delete();

      // Remove from local cache
      _customers.removeWhere((c) => c.id == customerId);
      _favoriteCustomers.removeWhere((c) => c.id == customerId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting customer: $e');
      rethrow;
    }
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String customerId) async {
    try {
      final customer = _customers.firstWhere((c) => c.id == customerId);
      final updated = customer.copyWith(
        isFavorite: !customer.isFavorite,
        updatedAt: DateTime.now(),
      );

      await updateCustomer(updated);

      // Update favorites list
      if (updated.isFavorite) {
        _favoriteCustomers.add(updated);
      } else {
        _favoriteCustomers.removeWhere((c) => c.id == customerId);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Update customer statistics after delivery
  Future<void> updateCustomerStats(String customerId, DateTime deliveryDate) async {
    try {
      final customer = await getCustomer(customerId);
      if (customer == null) return;

      final updatedStats = customer.stats.copyWith(
        totalDeliveries: customer.stats.totalDeliveries + 1,
        lastDelivery: deliveryDate,
        firstDelivery: customer.stats.firstDelivery ?? deliveryDate,
      );

      await updateCustomer(customer.copyWith(stats: updatedStats));
    } catch (e) {
      debugPrint('Error updating customer stats: $e');
    }
  }

  /// Bulk import customers from CSV
  Future<ImportProgress> importCustomers(
    List<ParsedCustomer> customers,
    void Function(int current, int total) onProgress,
  ) async {
    if (_companyId == null) {
      throw Exception('Company ID not initialized');
    }

    int successCount = 0;
    int errorCount = 0;
    final errors = <String>[];

    try {
      // Check for existing customer numbers
      final existingNumbers = _customers
          .map((c) => c.customerNumber.toLowerCase())
          .toSet();

      // Import in batches
      final batchSize = 500; // Firestore batch limit
      for (int i = 0; i < customers.length; i += batchSize) {
        final end = (i + batchSize < customers.length) 
            ? i + batchSize 
            : customers.length;
        final batch = _firestore.batch();

        for (int j = i; j < end; j++) {
          try {
            final parsed = customers[j];

            // Check for duplicates
            if (existingNumbers.contains(parsed.customerNumber.toLowerCase())) {
              errorCount++;
              errors.add('Row ${parsed.rowNumber}: Customer number ${parsed.customerNumber} already exists');
              continue;
            }

            // Create customer
            final customer = parsed.toCustomer(companyId: _companyId!);
            final docRef = _firestore.collection('customers').doc();
            batch.set(docRef, customer.toFirestore());

            successCount++;
            onProgress(j + 1, customers.length);
          } catch (e) {
            errorCount++;
            errors.add('Row ${customers[j].rowNumber}: $e');
          }
        }

        // Commit batch
        await batch.commit();
      }

      // Reload customers
      await loadCustomers();

      return ImportProgress(
        total: customers.length,
        successful: successCount,
        failed: errorCount,
        errors: errors,
      );
    } catch (e) {
      debugPrint('Error importing customers: $e');
      rethrow;
    }
  }

  /// Create new customers from the creation form
  Future<void> createCustomers(List<Customer> customers) async {
    if (_companyId == null) {
      throw Exception('Company ID not initialized');
    }

    try {
      // Import in batches (Firestore limit: 500 operations per batch)
      final batchSize = 500;
      for (int i = 0; i < customers.length; i += batchSize) {
        final end = (i + batchSize < customers.length) 
            ? i + batchSize 
            : customers.length;
        final batch = _firestore.batch();

        for (int j = i; j < end; j++) {
          final customer = customers[j];
          final docRef = _firestore.collection('customers').doc();
          batch.set(docRef, customer.toFirestore());
        }

        // Commit batch
        await batch.commit();
      }

      // Reload customers
      await loadCustomers();
    } catch (e) {
      debugPrint('Error creating customers: $e');
      rethrow;
    }
  }

  /// Clear all data (for logout)
  void clear() {
    _companyId = null;
    _customers = [];
    _favoriteCustomers = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

/// Import progress result
class ImportProgress {
  final int total;
  final int successful;
  final int failed;
  final List<String> errors;

  ImportProgress({
    required this.total,
    required this.successful,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => failed > 0;
  double get successRate => total > 0 ? successful / total : 0.0;
}
