import 'package:cloud_firestore/cloud_firestore.dart';

/// Migration script to update existing POD documents with delivery information
/// Run this once to fix PODs that were created before the fix
Future<void> migratePODData() async {
  final firestore = FirebaseFirestore.instance;
  
  print('🔄 Starting POD data migration...');
  
  try {
    // Get all PODs
    final podsSnapshot = await firestore.collection('pods').get();
    
    print('📊 Found ${podsSnapshot.docs.length} PODs to check');
    
    int updated = 0;
    int skipped = 0;
    int errors = 0;
    
    for (var podDoc in podsSnapshot.docs) {
      try {
        final podData = podDoc.data();
        final deliveryId = podData['deliveryId'] as String?;
        
        if (deliveryId == null) {
          print('⚠️  POD ${podDoc.id} has no deliveryId, skipping');
          skipped++;
          continue;
        }
        
        // Check if POD already has customer information
        if (podData['customerName'] != null && 
            podData['invoiceNumber'] != null) {
          print('✅ POD ${podDoc.id} already has delivery info, skipping');
          skipped++;
          continue;
        }
        
        // Get delivery information
        final deliveryDoc = await firestore
            .collection('deliveries')
            .doc(deliveryId)
            .get();
        
        if (!deliveryDoc.exists) {
          print('⚠️  Delivery $deliveryId not found for POD ${podDoc.id}');
          skipped++;
          continue;
        }
        
        final deliveryData = deliveryDoc.data()!;
        
        // Update POD with delivery information
        await firestore.collection('pods').doc(podDoc.id).update({
          'customerName': deliveryData['customerName'],
          'customerNumber': deliveryData['customerNumber'],
          'orderNumber': deliveryData['orderNumber'],
          'invoiceNumber': deliveryData['invoiceNumber'],
          'customerAddress': deliveryData['customerAddress'],
        });
        
        print('✅ Updated POD ${podDoc.id} with delivery info');
        updated++;
        
      } catch (e) {
        print('❌ Error processing POD ${podDoc.id}: $e');
        errors++;
      }
    }
    
    print('\n📊 Migration Summary:');
    print('   ✅ Updated: $updated');
    print('   ⏭️  Skipped: $skipped');
    print('   ❌ Errors: $errors');
    print('   📦 Total: ${podsSnapshot.docs.length}');
    print('\n✨ Migration complete!');
    
  } catch (e) {
    print('❌ Migration failed: $e');
    rethrow;
  }
}

/// Run this from main.dart or a debug screen to execute the migration
/// Example:
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     await migratePODData();
///     ScaffoldMessenger.of(context).showSnackBar(
///       const SnackBar(content: Text('Migration complete!')),
///     );
///   },
///   child: const Text('Migrate POD Data'),
/// ),
/// ```
