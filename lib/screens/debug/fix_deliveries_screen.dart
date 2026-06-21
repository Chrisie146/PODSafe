import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/theme.dart';

/// Screen to fix delivery assignments - reassign to current user
class FixDeliveriesScreen extends StatefulWidget {
  const FixDeliveriesScreen({super.key});

  @override
  State<FixDeliveriesScreen> createState() => _FixDeliveriesScreenState();
}

class _FixDeliveriesScreenState extends State<FixDeliveriesScreen> {
  bool _isLoading = false;
  String _log = '';

  void _addLog(String message) {
    setState(() {
      _log += '$message\n';
    });
  }

  Future<void> _fixAllDeliveries() async {
    setState(() {
      _isLoading = true;
      _log = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      final myUserId = user.uid;
      _addLog('✅ Current user ID: $myUserId');
      _addLog('📧 Current email: ${user.email}\n');

      // Get all deliveries
      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .get();

      _addLog('📦 Found ${snapshot.docs.length} deliveries\n');

      if (snapshot.docs.isEmpty) {
        _addLog('⚠️  No deliveries to fix');
        setState(() => _isLoading = false);
        return;
      }

      int fixed = 0;
      int skipped = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final currentDriverId = data['driverId'];
        final customerName = data['customerName'] ?? 'Unknown';

        _addLog('Delivery: $customerName (${doc.id})');

        if (currentDriverId == myUserId) {
          _addLog('  ✅ Already assigned to you - skipped\n');
          skipped++;
        } else {
          _addLog('  🔧 Reassigning from "$currentDriverId" to "$myUserId"');
          
          // Update the delivery
          await doc.reference.update({
            'driverId': myUserId,
          });
          
          _addLog('  ✅ Fixed!\n');
          fixed++;
        }
      }

      _addLog('\n✅ DONE!');
      _addLog('Fixed: $fixed deliveries');
      _addLog('Skipped: $skipped deliveries');
      _addLog('\n💡 Go back to dashboard and refresh to see your deliveries!');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _reassignToday() async {
    setState(() {
      _isLoading = true;
      _log = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      final myUserId = user.uid;
      _addLog('✅ Current user ID: $myUserId\n');

      // Get today's date range
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));

      // Get deliveries scheduled for today
      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(tomorrow))
          .get();

      _addLog('📦 Found ${snapshot.docs.length} deliveries scheduled for TODAY\n');

      if (snapshot.docs.isEmpty) {
        _addLog('⚠️  No deliveries scheduled for today');
        
        // Update all deliveries to today
        final allDeliveries = await FirebaseFirestore.instance
            .collection('deliveries')
            .get();
        
        if (allDeliveries.docs.isNotEmpty) {
          _addLog('\n💡 Found ${allDeliveries.docs.length} deliveries on other dates');
          _addLog('Would you like to reassign ALL deliveries to today and to you?');
        }
        
        setState(() => _isLoading = false);
        return;
      }

      int fixed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final customerName = data['customerName'] ?? 'Unknown';

        _addLog('Delivery: $customerName');
        _addLog('  🔧 Reassigning to you');
        
        await doc.reference.update({
          'driverId': myUserId,
        });
        
        _addLog('  ✅ Fixed!\n');
        fixed++;
      }

      _addLog('\n✅ DONE! Fixed $fixed deliveries');
      _addLog('\n💡 Go back to dashboard to see your deliveries!');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _rescheduleAllToToday() async {
    setState(() {
      _isLoading = true;
      _log = '';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _addLog('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      final myUserId = user.uid;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10, 0); // 10 AM today

      _addLog('✅ Current user ID: $myUserId');
      _addLog('📅 Target date: ${today.toString().split('.')[0]}\n');

      // Get all deliveries
      final snapshot = await FirebaseFirestore.instance
          .collection('deliveries')
          .get();

      _addLog('📦 Found ${snapshot.docs.length} deliveries\n');

      int fixed = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final customerName = data['customerName'] ?? 'Unknown';

        _addLog('Delivery: $customerName');
        _addLog('  🔧 Reassigning to you + rescheduling to TODAY');
        
        await doc.reference.update({
          'driverId': myUserId,
          'scheduledDate': Timestamp.fromDate(today),
        });
        
        _addLog('  ✅ Fixed!\n');
        fixed++;
      }

      _addLog('\n✅ DONE! Fixed $fixed deliveries');
      _addLog('All deliveries are now:');
      _addLog('  - Assigned to you');
      _addLog('  - Scheduled for TODAY');
      _addLog('\n💡 Go back to dashboard to see your deliveries!');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fix Deliveries'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Delivery Assignment Fixer',
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This tool will reassign deliveries to your account so you can see them.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _rescheduleAllToToday,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('FIX ALL (Recommended)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reassigns ALL deliveries to you and schedules for TODAY',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _reassignToday,
                  icon: const Icon(Icons.today),
                  label: const Text('Fix Today\'s Deliveries Only'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _fixAllDeliveries,
                  icon: const Icon(Icons.build),
                  label: const Text('Reassign All (Keep Dates)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(),
          
          Expanded(
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: _isLoading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Processing...'),
                          ],
                        ),
                      )
                    : SelectableText(
                        _log.isEmpty ? 'Press a button to start...' : _log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
