import 'package:cloud_firestore/cloud_firestore.dart';

String normalizeRegistration(String registration) {
  if (registration.trim().isEmpty) return '';
  // Remove non-alphanumeric characters and uppercase
  return registration.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
}

Future<DocumentSnapshot<Map<String, dynamic>>?> findVehicleDocForCompany(String companyId, String vehicleUsed) async {
  if (companyId.isEmpty || vehicleUsed.trim().isEmpty) return null;
  final docRef = FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('vehicles')
      .doc(vehicleUsed);
  final docSnap = await docRef.get();
  if (docSnap.exists) return docSnap;
  final regQuery = await FirebaseFirestore.instance
      .collection('companies')
      .doc(companyId)
      .collection('vehicles')
      .where('registration', isEqualTo: normalizeRegistration(vehicleUsed))
      .limit(1)
      .get();
  if (regQuery.docs.isNotEmpty) return regQuery.docs.first as DocumentSnapshot<Map<String, dynamic>>;
  return null;
}
