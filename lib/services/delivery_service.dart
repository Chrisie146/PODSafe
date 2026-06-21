import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/vehicle_utils.dart';
import '../models/delivery_model.dart';
import 'notification_service.dart';

class DeliveryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get deliveries for a specific driver
  Stream<List<Delivery>> getDeliveriesForDriver(String driverId) {
    print('🚚 Loading deliveries for driver: $driverId');
    
    return _firestore
        .collection('deliveries')
        .where('driverId', isEqualTo: driverId)
        .orderBy('scheduledDate', descending: true)
        .snapshots()
        .map((snapshot) {
          print('📦 Received ${snapshot.docs.length} deliveries for driver');
          final deliveries = snapshot.docs
              .map((doc) => Delivery.fromFirestore(doc))
              .toList();
          
          if (deliveries.isEmpty) {
            print('⚠️ No deliveries found for driver $driverId');
          } else {
            print('✅ Loaded ${deliveries.length} deliveries');
            for (var d in deliveries) {
              print('   - ${d.customerName} (${d.status})');
            }
          }
          
          return deliveries;
        });
  }
  
  // Get deliveries for a specific date and driver
  Stream<List<Delivery>> getDeliveriesForDate(String driverId, DateTime date) {
    print('📅 Loading deliveries for driver: $driverId on date: $date');
    
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));
    
    print('📅 Date range: $startOfDay to $endOfDay');
    
    return _firestore
        .collection('deliveries')
        .where('driverId', isEqualTo: driverId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledDate')
        .snapshots()
        .map((snapshot) {
          print('📦 Received ${snapshot.docs.length} deliveries for today');
          final deliveries = snapshot.docs
              .map((doc) => Delivery.fromFirestore(doc))
              .toList();
          
          if (deliveries.isEmpty) {
            print('⚠️ No deliveries found for today for driver $driverId');
          } else {
            print('✅ Loaded ${deliveries.length} today\'s deliveries');
            for (var d in deliveries) {
              print('   - ${d.customerName} scheduled: ${d.scheduledDate}');
            }
          }
          
          return deliveries;
        }).handleError((error) {
          print('❌ Error loading deliveries for date: $error');
          // If there's an index error, try simpler query
          if (error.toString().contains('index')) {
            print('⚠️ Index required for date range query. Using simple query instead.');
            return getDeliveriesForDriver(driverId).map((allDeliveries) {
              // Filter client-side for today
              return allDeliveries.where((d) {
                return d.scheduledDate.year == date.year &&
                       d.scheduledDate.month == date.month &&
                       d.scheduledDate.day == date.day;
              }).toList();
            });
          }
          throw error;
        });
  }
  
  // Get all deliveries for a company (admin view)
  Stream<List<Delivery>> getCompanyDeliveries(String companyId) {
    return _firestore
        .collection('deliveries')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Delivery.fromFirestore(doc))
            .toList());
  }
  
  // Get delivery by ID
  Future<Delivery?> getDeliveryById(String deliveryId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (doc.exists) {
        return Delivery.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Get delivery error: $e');
      return null;
    }
  }
  
  // Create new delivery
  Future<String> createDelivery(Delivery delivery) async {
    try {
      DocumentReference ref = await _firestore
          .collection('deliveries')
          .add(delivery.toFirestore());
      return ref.id;
    } catch (e) {
      print('Create delivery error: $e');
      throw Exception('Failed to create delivery');
    }
  }
  
  // Update delivery
  Future<void> updateDelivery(Delivery delivery) async {
    try {
      await _firestore
          .collection('deliveries')
          .doc(delivery.id)
          .update(delivery.toFirestore());
    } catch (e) {
      print('Update delivery error: $e');
      throw Exception('Failed to update delivery');
    }
  }
  
  // Update delivery status
  Future<void> updateDeliveryStatus(String deliveryId, DeliveryStatus status) async {
    try {
      // Get delivery details before updating for notification
      final deliveryDoc = await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .get();
      
      if (!deliveryDoc.exists) {
        throw Exception('Delivery not found');
      }
      
      final delivery = Delivery.fromFirestore(deliveryDoc);
      
      Map<String, dynamic> updateData = {
        'status': status.toString().split('.').last,
      };
      
      if (status == DeliveryStatus.delivered) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      }
      
      await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .update(updateData);
      
      // Update vehicle totalDeliveries if delivery is now completed
      if (delivery.status != DeliveryStatus.delivered && status == DeliveryStatus.delivered && delivery.vehicleUsed != null) {
        print('🔄 Incrementing vehicle delivery count for vehicle: ${delivery.vehicleUsed}');
        final vehicleQuery = await _firestore
            .collection('companies')
            .doc(delivery.companyId)
            .collection('vehicles')
            .where('registration', isEqualTo: normalizeRegistration(delivery.vehicleUsed ?? ''))
            .get();
        
        if (vehicleQuery.docs.isNotEmpty) {
          final vehicleDoc = vehicleQuery.docs.first;
          print('✅ Found vehicle document, incrementing totalDeliveries');
          await vehicleDoc.reference.update({
            'totalDeliveries': FieldValue.increment(1),
          });
        } else {
          print('❌ No vehicle found with registration: ${delivery.vehicleUsed}');
        }
      } else {
        print('⏭️ Skipping vehicle increment - status: ${delivery.status} -> $status, vehicleUsed: ${delivery.vehicleUsed}');
      }
      
      // 🔔 Send notification to company admins about status change
      await _notifyAdminsOfStatusChange(delivery, status);
      
    } catch (e) {
      print('Update delivery status error: $e');
      throw Exception('Failed to update delivery status');
    }
  }
  
  // Send status update notifications to admins
  Future<void> _notifyAdminsOfStatusChange(Delivery delivery, DeliveryStatus newStatus) async {
    try {
      // Get all admins for the company
      final adminsSnapshot = await _firestore
          .collection('users')
          .where('companyId', isEqualTo: delivery.companyId)
          .where('role', isEqualTo: 'admin')
          .get();
      
      // Determine notification details based on status
      String title;
      String emoji;
      String priority;
      
      switch (newStatus) {
        case DeliveryStatus.inTransit:
          title = 'Delivery In Transit';
          emoji = '🚚';
          priority = 'normal';
          break;
        case DeliveryStatus.delivered:
          title = 'Delivery Completed';
          emoji = '✅';
          priority = 'high';
          break;
        case DeliveryStatus.failed:
          title = 'Delivery Failed';
          emoji = '❌';
          priority = 'urgent';
          break;
        default:
          return; // Don't notify for pending status
      }
      
      // Send notification to each admin
      for (final adminDoc in adminsSnapshot.docs) {
        await NotificationService().sendToUser(
          userId: adminDoc.id,
          title: '$emoji $title',
          body: '${delivery.customerName} - ${delivery.customerAddress}',
          data: {
            'type': 'delivery_status_change',
            'deliveryId': delivery.id,
            'customerId': delivery.customerId ?? '',
            'customerName': delivery.customerName,
            'newStatus': newStatus.toString().split('.').last,
            'priority': priority,
          },
        );
      }
    } catch (e) {
      print('Error sending status change notifications: $e');
      // Don't throw - notification failure shouldn't block status update
    }
  }
  
  // Link POD to delivery
  Future<void> linkPODToDelivery(String deliveryId, String podId) async {
    try {
      // Read delivery first so we can decide whether to increment vehicle counters
      final deliveryDoc = await _firestore.collection('deliveries').doc(deliveryId).get();
      if (!deliveryDoc.exists) {
        throw Exception('Delivery not found');
      }

      final delivery = Delivery.fromFirestore(deliveryDoc);

      await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .update({
        'podId': podId,
        'status': DeliveryStatus.delivered.toString().split('.').last,
        'deliveredAt': FieldValue.serverTimestamp(),
      });

      // If this delivery transitioned to delivered and a vehicle was used,
      // increment that vehicle's totalDeliveries counter (if vehicle doc exists)
      if (delivery.status != DeliveryStatus.delivered && delivery.vehicleUsed != null) {
        try {
          print('🔄 Incrementing vehicle delivery count for vehicle (via POD link): ${delivery.vehicleUsed}');
          final vehicleQuery = await _firestore
              .collection('companies')
              .doc(delivery.companyId)
              .collection('vehicles')
              .where('registration', isEqualTo: normalizeRegistration(delivery.vehicleUsed ?? ''))
              .get();

          if (vehicleQuery.docs.isNotEmpty) {
            final vehicleDoc = vehicleQuery.docs.first;
            await vehicleDoc.reference.update({
              'totalDeliveries': FieldValue.increment(1),
            });
            print('✅ Vehicle totalDeliveries incremented for ${delivery.vehicleUsed}');
          } else {
            print('❌ No vehicle found with registration: ${delivery.vehicleUsed}');
          }
        } catch (e) {
          print('❌ Error incrementing vehicle counter after POD link: $e');
        }
      } else {
        print('⏭️ Skipping vehicle increment after POD link - status: ${delivery.status} -> delivered, vehicleUsed: ${delivery.vehicleUsed}');
      }

      // Notify admins about this delivery now marked delivered
      await _notifyAdminsOfStatusChange(delivery, DeliveryStatus.delivered);
    } catch (e) {
      print('Link POD error: $e');
      throw Exception('Failed to link POD to delivery');
    }
  }
  
  // Delete delivery
  Future<void> deleteDelivery(String deliveryId) async {
    try {
      await _firestore
          .collection('deliveries')
          .doc(deliveryId)
          .delete();
    } catch (e) {
      print('Delete delivery error: $e');
      throw Exception('Failed to delete delivery');
    }
  }
  
  // Get delivery statistics for a company
  Future<Map<String, int>> getDeliveryStats(String companyId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _firestore
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId);
      
      if (startDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      
      if (endDate != null) {
        query = query.where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      
      QuerySnapshot snapshot = await query.get();
      
      Map<String, int> stats = {
        'total': 0,
        'pending': 0,
        'inTransit': 0,
        'delivered': 0,
        'failed': 0,
      };
      
      for (var doc in snapshot.docs) {
        Delivery delivery = Delivery.fromFirestore(doc);
        stats['total'] = stats['total']! + 1;
        stats[delivery.status.toString().split('.').last] = 
            (stats[delivery.status.toString().split('.').last] ?? 0) + 1;
      }
      
      return stats;
    } catch (e) {
      print('Get delivery stats error: $e');
      return {};
    }
  }
  
  // Search deliveries
  Future<List<Delivery>> searchDeliveries(String companyId, String searchTerm) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('deliveries')
          .where('companyId', isEqualTo: companyId)
          .get();
      
      List<Delivery> deliveries = snapshot.docs
          .map((doc) => Delivery.fromFirestore(doc))
          .where((delivery) =>
              delivery.customerName.toLowerCase().contains(searchTerm.toLowerCase()) ||
              delivery.invoiceNumber.toLowerCase().contains(searchTerm.toLowerCase()) ||
              delivery.customerAddress.toLowerCase().contains(searchTerm.toLowerCase()))
          .toList();
      
      return deliveries;
    } catch (e) {
      print('Search deliveries error: $e');
      return [];
    }
  }
}