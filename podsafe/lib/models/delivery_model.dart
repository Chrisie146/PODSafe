import 'package:cloud_firestore/cloud_firestore.dart';

enum DeliveryStatus { pending, inTransit, delivered, failed }

class DeliveryItem {
  final String description;
  final double quantity;
  final String? unit;
  final double? unitPrice;  // Price per unit
  final double? totalPrice; // Total for this line item

  DeliveryItem({
    required this.description,
    required this.quantity,
    this.unit,
    this.unitPrice,
    this.totalPrice,
  });

  factory DeliveryItem.fromMap(Map<String, dynamic> map) {
    return DeliveryItem(
      description: map['description'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      unit: map['unit'],
      unitPrice: map['unitPrice']?.toDouble(),
      totalPrice: map['totalPrice']?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}

class Delivery {
  final String id;
  final String companyId;
  final String driverId;
  final String customerName;
  final String customerAddress;
  final String? customerPhone;
  
  // Customer linking (optional for backwards compatibility)
  final String? customerId;        // Links to customers collection
  final String? customerNumber;    // For quick lookup and reporting
  
  final String? orderNumber;       // Optional order number
  final String invoiceNumber;
  final DateTime? invoiceDate;     // Date invoice was issued
  final List<DeliveryItem> items;
  
  // Financial information
  final double? invoiceTotal;      // Total invoice amount
  final double? taxAmount;         // Tax amount
  final double? discountAmount;    // Discount amount
  final String? currency;          // Currency code (default: ZAR)
  
  // Vehicle information
  final String? vehicleUsed;       // Vehicle registration/info used for this delivery
  
  // Third-party transport information
  final bool isThirdPartyTransport;       // Whether this delivery uses third-party transport
  final String? thirdPartyProviderName;   // Name of transport company (e.g., "HFR")
  final String? thirdPartyDriverName;     // External driver's name
  final String? thirdPartyDriverPhone;    // External driver's phone
  final String? thirdPartyVehicleInfo;    // External vehicle details
  final String? uploadToken;              // Secure token for document upload
  final List<String>? thirdPartyDocs;     // URLs of uploaded documents from third party
  
  final DeliveryStatus status;
  final DateTime scheduledDate;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String? notes;
  final String? podId; // Reference to POD document

  Delivery({
    required this.id,
    required this.companyId,
    required this.driverId,
    required this.customerName,
    required this.customerAddress,
    this.customerPhone,
    this.customerId,
    this.customerNumber,
    this.orderNumber,
    required this.invoiceNumber,
    this.invoiceDate,
    required this.items,
    this.invoiceTotal,
    this.taxAmount,
    this.discountAmount,
    this.currency = 'ZAR',
    this.vehicleUsed,
    this.isThirdPartyTransport = false,
    this.thirdPartyProviderName,
    this.thirdPartyDriverName,
    this.thirdPartyDriverPhone,
    this.thirdPartyVehicleInfo,
    this.uploadToken,
    this.thirdPartyDocs,
    this.status = DeliveryStatus.pending,
    required this.scheduledDate,
    required this.createdAt,
    this.deliveredAt,
    this.notes,
    this.podId,
  });

  factory Delivery.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Delivery(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      driverId: data['driverId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      customerPhone: data['customerPhone'],
      customerId: data['customerId'],
      customerNumber: data['customerNumber'],
      orderNumber: data['orderNumber'],
      invoiceNumber: data['invoiceNumber'] ?? '',
      invoiceDate: data['invoiceDate'] != null 
        ? (data['invoiceDate'] as Timestamp).toDate() 
        : null,
      items: (data['items'] as List<dynamic>?)
          ?.map((item) => DeliveryItem.fromMap(item))
          .toList() ?? [],
      invoiceTotal: data['invoiceTotal']?.toDouble(),
      taxAmount: data['taxAmount']?.toDouble(),
      discountAmount: data['discountAmount']?.toDouble(),
      currency: data['currency'] ?? 'ZAR',
      vehicleUsed: data['vehicleUsed'],
      isThirdPartyTransport: data['isThirdPartyTransport'] ?? false,
      thirdPartyProviderName: data['thirdPartyProviderName'],
      thirdPartyDriverName: data['thirdPartyDriverName'],
      thirdPartyDriverPhone: data['thirdPartyDriverPhone'],
      thirdPartyVehicleInfo: data['thirdPartyVehicleInfo'],
      uploadToken: data['uploadToken'],
      thirdPartyDocs: (data['thirdPartyDocs'] as List<dynamic>?)?.cast<String>(),
      status: DeliveryStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => DeliveryStatus.pending,
      ),
      scheduledDate: data['scheduledDate'] != null
          ? (data['scheduledDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      deliveredAt: data['deliveredAt'] != null 
        ? (data['deliveredAt'] as Timestamp).toDate() 
        : null,
      notes: data['notes'],
      podId: data['podId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'driverId': driverId,
      'customerName': customerName,
      'customerAddress': customerAddress,
      'customerPhone': customerPhone,
      'customerId': customerId,
      'customerNumber': customerNumber,
      'orderNumber': orderNumber,
      'invoiceNumber': invoiceNumber,
      'invoiceDate': invoiceDate != null 
        ? Timestamp.fromDate(invoiceDate!) 
        : null,
      'items': items.map((item) => item.toMap()).toList(),
      'invoiceTotal': invoiceTotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'currency': currency,
      'vehicleUsed': vehicleUsed,
      'isThirdPartyTransport': isThirdPartyTransport,
      'thirdPartyProviderName': thirdPartyProviderName,
      'thirdPartyDriverName': thirdPartyDriverName,
      'thirdPartyDriverPhone': thirdPartyDriverPhone,
      'thirdPartyVehicleInfo': thirdPartyVehicleInfo,
      'uploadToken': uploadToken,
      'thirdPartyDocs': thirdPartyDocs,
      'status': status.toString().split('.').last,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'deliveredAt': deliveredAt != null 
        ? Timestamp.fromDate(deliveredAt!) 
        : null,
      'notes': notes,
      'podId': podId,
    };
  }

  Delivery copyWith({
    String? id,
    String? companyId,
    String? driverId,
    String? customerName,
    String? customerAddress,
    String? customerPhone,
    String? customerId,
    String? customerNumber,
    String? orderNumber,
    String? invoiceNumber,
    DateTime? invoiceDate,
    List<DeliveryItem>? items,
    double? invoiceTotal,
    double? taxAmount,
    double? discountAmount,
    String? currency,
    String? vehicleUsed,
    bool? isThirdPartyTransport,
    String? thirdPartyProviderName,
    String? thirdPartyDriverName,
    String? thirdPartyDriverPhone,
    String? thirdPartyVehicleInfo,
    String? uploadToken,
    List<String>? thirdPartyDocs,
    DeliveryStatus? status,
    DateTime? scheduledDate,
    DateTime? createdAt,
    DateTime? deliveredAt,
    String? notes,
    String? podId,
  }) {
    return Delivery(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      driverId: driverId ?? this.driverId,
      customerName: customerName ?? this.customerName,
      customerAddress: customerAddress ?? this.customerAddress,
      customerPhone: customerPhone ?? this.customerPhone,
      customerId: customerId ?? this.customerId,
      customerNumber: customerNumber ?? this.customerNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      items: items ?? this.items,
      invoiceTotal: invoiceTotal ?? this.invoiceTotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      currency: currency ?? this.currency,
      vehicleUsed: vehicleUsed ?? this.vehicleUsed,
      isThirdPartyTransport: isThirdPartyTransport ?? this.isThirdPartyTransport,
      thirdPartyProviderName: thirdPartyProviderName ?? this.thirdPartyProviderName,
      thirdPartyDriverName: thirdPartyDriverName ?? this.thirdPartyDriverName,
      thirdPartyDriverPhone: thirdPartyDriverPhone ?? this.thirdPartyDriverPhone,
      thirdPartyVehicleInfo: thirdPartyVehicleInfo ?? this.thirdPartyVehicleInfo,
      uploadToken: uploadToken ?? this.uploadToken,
      thirdPartyDocs: thirdPartyDocs ?? this.thirdPartyDocs,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      podId: podId ?? this.podId,
    );
  }
}