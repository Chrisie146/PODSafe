import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/company_model.dart';

class CompanyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Register a new company with admin user
  Future<String> registerCompany({
    required String companyName,
    required String companyEmail,
    required String companyPhone,
    required String companyAddress,
    required String adminName,
    required String adminEmail,
    required String adminPassword,
  }) async {
    try {
      // 1. Create admin Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      final adminUid = userCredential.user!.uid;

      // 2. Create company document
      final companyRef = await _firestore.collection('companies').add({
        'name': companyName,
        'email': companyEmail,
        'phone': companyPhone,
        'address': companyAddress,
        'createdAt': FieldValue.serverTimestamp(),
        'plan': 'free',
        'isActive': true,
        'settings': {
          'autoApproveDrivers': false,
          'requireDriverApproval': true,
        },
      });

      final companyId = companyRef.id;

      // 3. Create admin user document
      await _firestore.collection('users').doc(adminUid).set({
        'id': adminUid,
        'email': adminEmail,
        'displayName': adminName,
        'role': 'admin',
        'companyId': companyId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      // 4. Update display name
      await userCredential.user!.updateDisplayName(adminName);

      return companyId;
    } catch (e) {
      throw Exception('Failed to register company: $e');
    }
  }

  /// Get company by ID
  Future<Company?> getCompany(String companyId) async {
    try {
      final doc = await _firestore.collection('companies').doc(companyId).get();
      if (doc.exists) {
        return Company.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get company: $e');
    }
  }

  /// Get company stream for real-time updates
  Stream<Company?> getCompanyStream(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .snapshots()
        .map((doc) => doc.exists ? Company.fromFirestore(doc) : null);
  }

  /// Update company information
  Future<void> updateCompany(String companyId, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('companies').doc(companyId).update(data);
    } catch (e) {
      throw Exception('Failed to update company: $e');
    }
  }

  /// Verify company code is valid
  Future<bool> verifyCompanyCode(String companyCode) async {
    try {
      final cleanCode = companyCode.trim();
      print('🔍 Verifying company code: "$cleanCode"');
      
      // Call Cloud Function to verify code
      final callable = FirebaseFunctions.instance.httpsCallable('verifyCompanyCode');
      final result = await callable.call({'code': cleanCode});
      
      final data = result.data as Map<String, dynamic>;
      final isValid = data['valid'] == true;
      
      print('✅ Code valid: $isValid');
      if (isValid && data.containsKey('companyName')) {
        print('📋 Company name: ${data['companyName']}');
      }
      
      return isValid;
    } catch (e) {
      print('❌ Error verifying company code: $e');
      return false;
    }
  }

  /// Get company details for registration (name only)
  Future<String?> getCompanyName(String companyCode) async {
    try {
      final cleanCode = companyCode.trim();
      print('📛 Getting company name for: "$cleanCode"');
      
      // Call Cloud Function to verify code and get company name
      final callable = FirebaseFunctions.instance.httpsCallable('verifyCompanyCode');
      final result = await callable.call({'code': cleanCode});
      
      final data = result.data as Map<String, dynamic>;
      if (data['valid'] == true && data.containsKey('companyName')) {
        final name = data['companyName'];
        print('✅ Found company: $name');
        return name;
      }
      
      print('❌ Company code not valid or not found');
      return null;
    } catch (e) {
      print('❌ Error getting company name: $e');
      return null;
    }
  }
}
