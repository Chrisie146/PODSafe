import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:podsafe/utils/vehicle_utils.dart';

/// This script normalizes vehicle registrations and normalizes vehicleUsed on deliveries.
/// Run via: `dart run tools/migration/normalize_vehicle_registrations.dart` after authenticating with Firestore admin credentials.

Future<void> main() async {
  final firestore = FirebaseFirestore.instance;

  final companiesSnap = await firestore.collection('companies').get();
  for (final comp in companiesSnap.docs) {
    final companyId = comp.id;
    print('Processing company: $companyId');
    final vehiclesSnap = await firestore.collection('companies').doc(companyId).collection('vehicles').get();

    for (final vdoc in vehiclesSnap.docs) {
      final registration = vdoc.data()['registration'] as String? ?? '';
      final normalized = normalizeRegistration(registration);
      if (normalized != registration) {
        print('Updating vehicle ${vdoc.id} registration: "$registration" -> "$normalized"');
        await vdoc.reference.update({'registration': normalized});
      }
    }

    // Update deliveries for the company
    final deliveriesSnap = await firestore.collection('deliveries').where('companyId', isEqualTo: companyId).get();
    for (final ddoc in deliveriesSnap.docs) {
      final data = ddoc.data();
      final vehicleUsed = data['vehicleUsed'] as String?;
      if (vehicleUsed != null && vehicleUsed.isNotEmpty) {
        final normalizedUsed = normalizeRegistration(vehicleUsed);
        if (normalizedUsed != vehicleUsed) {
          await ddoc.reference.update({'vehicleUsed': normalizedUsed});
          print('Updated delivery ${ddoc.id} vehicleUsed: "$vehicleUsed" -> "$normalizedUsed"');
        }
      }
    }
  }

  print('Done');
}
