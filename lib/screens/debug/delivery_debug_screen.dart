import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart';
import 'fix_deliveries_screen.dart';

/// Debug screen to diagnose delivery assignment issues
class DeliveryDebugScreen extends StatefulWidget {
  const DeliveryDebugScreen({super.key});

  @override
  State<DeliveryDebugScreen> createState() => _DeliveryDebugScreenState();
}

class _DeliveryDebugScreenState extends State<DeliveryDebugScreen> {
  bool _isLoading = true;
  String _currentUserId = '';
  String _currentUserEmail = '';
  List<Map<String, dynamic>> _allDeliveries = [];
  final List<Map<String, dynamic>> _myDeliveries = [];
  String _diagnostics = '';

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _diagnostics = 'Running diagnostics...\n\n';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _diagnostics += '❌ No user logged in\n';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = user.uid;
      _currentUserEmail = user.email ?? '';

      String diag = '';
      diag += '✅ Logged in as: $_currentUserEmail\n';
      diag += '📱 User ID: $_currentUserId\n\n';

      // Get user data
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      if (userData.exists) {
        final role = userData.data()?['role'];
        final fullName = userData.data()?['fullName'];
        diag += '👤 Role: $role\n';
        diag += '👤 Name: $fullName\n\n';
      }

      // Get ALL deliveries
      diag += '🔍 Checking all deliveries in database...\n';
      final allDeliveriesSnapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .get();

      _allDeliveries = allDeliveriesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'data': data,
        };
      }).toList();

      diag += '📦 Total deliveries in database: ${_allDeliveries.length}\n\n';

      if (_allDeliveries.isEmpty) {
        diag += '⚠️  No deliveries found in database!\n';
        diag += '💡 Create a delivery from the admin panel.\n\n';
      } else {
        diag += '📋 Analyzing deliveries:\n';
        for (var delivery in _allDeliveries) {
          final data = delivery['data'] as Map<String, dynamic>;
          final driverId = data['driverId'];
          final assignedDriverId = data['assignedDriverId'];
          final customerName = data['customerName'] ?? 'Unknown';
          final status = data['status'] ?? 'Unknown';
          final scheduledDate = data['scheduledDate'] as Timestamp?;
          
          diag += '\n  Delivery: $customerName\n';
          diag += '  └─ ID: ${delivery['id']}\n';
          diag += '  └─ Status: $status\n';
          diag += '  └─ driverId: $driverId\n';
          
          if (assignedDriverId != null) {
            diag += '  └─ ⚠️  assignedDriverId (legacy): $assignedDriverId\n';
          }
          
          if (scheduledDate != null) {
            final date = scheduledDate.toDate();
            final today = DateTime.now();
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            diag += '  └─ Scheduled: ${date.toString().split('.')[0]} ${isToday ? '(TODAY)' : '(NOT TODAY)'}\n';
          }

          if (driverId == _currentUserId) {
            diag += '  └─ ✅ ASSIGNED TO YOU\n';
            _myDeliveries.add(delivery);
          } else if (driverId == null) {
            diag += '  └─ ❌ NO DRIVER ASSIGNED\n';
          } else {
            diag += '  └─ ℹ️  Assigned to different driver\n';
          }
        }
      }

      diag += '\n\n📊 Summary:\n';
      diag += '  Total deliveries: ${_allDeliveries.length}\n';
      diag += '  Your deliveries: ${_myDeliveries.length}\n';

      if (_myDeliveries.isEmpty && _allDeliveries.isNotEmpty) {
        diag += '\n❗ ISSUE FOUND:\n';
        diag += '  You have no deliveries assigned to you.\n';
        diag += '  Check that:\n';
        diag += '  1. Deliveries use "driverId" field (not "assignedDriverId")\n';
        diag += '  2. driverId matches your UID: $_currentUserId\n';
        diag += '  3. Deliveries are scheduled for today\n';
      } else if (_myDeliveries.isEmpty) {
        diag += '\n💡 No deliveries in system. Create one from admin panel.\n';
      } else {
        diag += '\n✅ Everything looks good!\n';
      }

      setState(() {
        _diagnostics = diag;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _diagnostics += '\n❌ Error: $e\n';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Diagnostics'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: SelectableText(
                      _diagnostics,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_myDeliveries.isEmpty && _allDeliveries.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FixDeliveriesScreen(),
                          ),
                        ).then((_) => _runDiagnostics());
                      },
                      icon: const Icon(Icons.auto_fix_high),
                      label: const Text('FIX DELIVERIES NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
