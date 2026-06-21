import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/vehicle_utils.dart';

enum VehicleStatus { active, inactive, maintenance }

class Vehicle {
  final String id;
  final String companyId;
  final String registration;
  final List<String>? documents;
  final String? make;
  final String? model;
  final String? color;
  final String? licensePlate;
  final VehicleStatus status;
  final int totalDeliveries; // Counter for analytics
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final String? notes;

  Vehicle({
    required this.id,
    required this.companyId,
    required this.registration,
    this.documents,
    this.make,
    this.model,
    this.color,
    this.licensePlate,
    this.status = VehicleStatus.active,
    this.totalDeliveries = 0,
    required this.createdAt,
    this.lastUsedAt,
    this.notes,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Vehicle(
      id: doc.id,
      companyId: data['companyId'] ?? '',
      registration: normalizeRegistration(data['registration'] ?? ''),
      make: data['make'],
      model: data['model'],
      color: data['color'],
      licensePlate: data['licensePlate'],
      status: VehicleStatus.values.firstWhere(
        (e) => e.toString().split('.').last == data['status'],
        orElse: () => VehicleStatus.active,
      ),
      totalDeliveries: data['totalDeliveries'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastUsedAt: data['lastUsedAt'] != null
          ? (data['lastUsedAt'] as Timestamp).toDate()
          : null,
      notes: data['notes'],
      documents: (data['documents'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'registration': registration,
      'make': make,
      'model': model,
      'color': color,
      'licensePlate': licensePlate,
      'status': status.toString().split('.').last,
      'totalDeliveries': totalDeliveries,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastUsedAt': lastUsedAt != null ? Timestamp.fromDate(lastUsedAt!) : null,
      'notes': notes,
      'documents': documents,
    };
  }

  Vehicle copyWith({
    String? id,
    String? companyId,
    String? registration,
    List<String>? documents,
    String? make,
    String? model,
    String? color,
    String? licensePlate,
    VehicleStatus? status,
    int? totalDeliveries,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    String? notes,
  }) {
    return Vehicle(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      registration: registration ?? this.registration,
      documents: documents ?? this.documents,
      make: make ?? this.make,
      model: model ?? this.model,
      color: color ?? this.color,
      licensePlate: licensePlate ?? this.licensePlate,
      status: status ?? this.status,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      notes: notes ?? this.notes,
    );
  }
}
