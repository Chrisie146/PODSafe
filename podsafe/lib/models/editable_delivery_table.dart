import '../models/delivery_model.dart';

class EditableDeliveryTable {
  int rowNumber;
  String? customerId;
  String? customerNumber;
  String customerName;
  String deliveryAddress;
  String? phoneNumber;
  String? orderNumber;
  String invoiceNumber;
  DateTime scheduledDate;
  DateTime? invoiceDate;
  String? notes;
  List<DeliveryItem> items;
  String? selectedDriverId;
  String? selectedVehicle;

  // UI state
  bool isSelected;
  bool isRemoved;
  bool isValid;
  bool hasErrors;
  List<String> errors;
  List<String> warnings;

  // Validation state
  bool customerValidated;
  bool itemsValidated;

  EditableDeliveryTable({
    required this.rowNumber,
    this.customerId,
    this.customerNumber,
    required this.customerName,
    required this.deliveryAddress,
    this.phoneNumber,
    this.orderNumber,
    required this.invoiceNumber,
    required this.scheduledDate,
    this.invoiceDate,
    this.notes,
    required this.items,
    this.selectedDriverId,
    this.selectedVehicle,
    this.isSelected = false,
    this.isRemoved = false,
    this.isValid = false,
    this.hasErrors = false,
    this.errors = const [],
    this.warnings = const [],
    this.customerValidated = false,
    this.itemsValidated = false,
  });

  // Factory for creating blank delivery
  factory EditableDeliveryTable.blank(int rowNumber) {
    return EditableDeliveryTable(
      rowNumber: rowNumber,
      customerName: '',
      deliveryAddress: '',
      invoiceNumber: '',
      scheduledDate: DateTime.now(),
      items: [],
    );
  }

  // Copy with method for updates
  EditableDeliveryTable copyWith({
    int? rowNumber,
    String? customerId,
    String? customerNumber,
    String? customerName,
    String? deliveryAddress,
    String? phoneNumber,
    String? orderNumber,
    String? invoiceNumber,
    DateTime? scheduledDate,
    DateTime? invoiceDate,
    String? notes,
    List<DeliveryItem>? items,
    String? selectedDriverId,
    String? selectedVehicle,
    bool? isSelected,
    bool? isRemoved,
    bool? isValid,
    bool? hasErrors,
    List<String>? errors,
    List<String>? warnings,
    bool? customerValidated,
    bool? itemsValidated,
  }) {
    return EditableDeliveryTable(
      rowNumber: rowNumber ?? this.rowNumber,
      customerId: customerId ?? this.customerId,
      customerNumber: customerNumber ?? this.customerNumber,
      customerName: customerName ?? this.customerName,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      notes: notes ?? this.notes,
      items: items ?? this.items,
      selectedDriverId: selectedDriverId ?? this.selectedDriverId,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      isSelected: isSelected ?? this.isSelected,
      isRemoved: isRemoved ?? this.isRemoved,
      isValid: isValid ?? this.isValid,
      hasErrors: hasErrors ?? this.hasErrors,
      errors: errors ?? this.errors,
      warnings: warnings ?? this.warnings,
      customerValidated: customerValidated ?? this.customerValidated,
      itemsValidated: itemsValidated ?? this.itemsValidated,
    );
  }

  // Validation methods
  void validate(Set<String> existingOrderNumbers, Set<String> existingCustomerNumbers) {
    errors = [];
    warnings = [];

    // Required fields
    if (customerName.trim().isEmpty) {
      errors.add('Customer name is required');
    }

    if (deliveryAddress.trim().isEmpty) {
      errors.add('Delivery address is required');
    }

    if (items.isEmpty) {
      errors.add('At least one item is required');
    }

    // Order number uniqueness
    if (orderNumber != null && orderNumber!.trim().isNotEmpty) {
      if (existingOrderNumbers.contains(orderNumber!.trim())) {
        warnings.add('Order number already exists');
      }
    }

    // Customer number validation
    if (customerNumber != null && customerNumber!.trim().isNotEmpty) {
      if (!existingCustomerNumbers.contains(customerNumber!.trim())) {
        warnings.add('Customer number not found in existing customers');
      }
    }

    // Item validation
    for (var item in items) {
      if (item.description.trim().isEmpty) {
        errors.add('Item description cannot be empty');
        break;
      }
      if (item.quantity <= 0) {
        errors.add('Item quantity must be greater than 0');
        break;
      }
    }

    // Update validation state
    hasErrors = errors.isNotEmpty;
    isValid = errors.isEmpty && customerName.trim().isNotEmpty &&
              deliveryAddress.trim().isNotEmpty && items.isNotEmpty;
  }

  // Convert to Delivery model
  Delivery toDelivery(String companyId, String driverId) {
    return Delivery(
      id: '', // Will be set by Firestore
      companyId: companyId,
      driverId: driverId,
      customerName: customerName,
      customerAddress: deliveryAddress,
      customerPhone: phoneNumber,
      customerId: customerId,
      customerNumber: customerNumber,
      orderNumber: orderNumber,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      items: items,
      status: DeliveryStatus.pending,
      scheduledDate: scheduledDate,
      createdAt: DateTime.now(),
      notes: notes,
      vehicleUsed: selectedVehicle,
    );
  }

  // Get display text for items
  String get itemsDisplayText {
    if (items.isEmpty) return 'No items';
    if (items.length == 1) {
      final item = items.first;
      return '${item.quantity}x ${item.description}';
    }
    return '${items.length} items';
  }

  // Get total quantity
  double get totalQuantity {
    return items.fold(0.0, (sum, item) => sum + item.quantity);
  }
}