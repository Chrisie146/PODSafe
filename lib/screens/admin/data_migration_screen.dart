import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  bool _isRunning = false;
  final List<String> _logs = [];
  String? _defaultCompanyId;

  void _addLog(String message) {
    setState(() {
      _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
    });
    debugPrint(message);
  }

  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      _addLog('🚀 Starting data migration...');

      // Step 1: Create default company
      _addLog('📝 Step 1: Creating default company...');
      final companyRef = await FirebaseFirestore.instance.collection('companies').add({
        'name': 'Default Company',
        'email': 'admin@podsafe.com',
        'phone': '+1234567890',
        'address': '123 Main Street, City, Country',
        'plan': 'free',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'settings': {
          'autoApproveDrivers': false,
          'requireDriverApproval': true,
        },
      });

      _defaultCompanyId = companyRef.id;
      _addLog('✅ Default company created with ID: $_defaultCompanyId');

      // Step 2: Update existing users
      _addLog('📝 Step 2: Updating existing users...');
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      
      int usersUpdated = 0;
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        
        // Check if user already has companyId
        if (data['companyId'] == null || data['companyId'] == '') {
          final role = data['role'] ?? 'driver';
          
          await doc.reference.update({
            'companyId': _defaultCompanyId,
            'approvalStatus': 'approved', // Approve existing drivers
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          usersUpdated++;
          _addLog('  ✓ Updated user: ${data['email']} ($role)');
        }
      }
      _addLog('✅ Updated $usersUpdated users');

      // Step 3: Update existing deliveries
      _addLog('📝 Step 3: Updating existing deliveries...');
      final deliveriesSnapshot = await FirebaseFirestore.instance.collection('deliveries').get();
      
      int deliveriesUpdated = 0;
      for (var doc in deliveriesSnapshot.docs) {
        final data = doc.data();
        
        // Check if delivery already has companyId
        if (data['companyId'] == null || data['companyId'] == '') {
          await doc.reference.update({
            'companyId': _defaultCompanyId,
          });
          
          deliveriesUpdated++;
          _addLog('  ✓ Updated delivery: ${doc.id}');
        }
      }
      _addLog('✅ Updated $deliveriesUpdated deliveries');

      // Step 4: Summary
      _addLog('');
      _addLog('🎉 Migration completed successfully!');
      _addLog('');
      _addLog('Summary:');
      _addLog('  • Company ID: $_defaultCompanyId');
      _addLog('  • Users updated: $usersUpdated');
      _addLog('  • Deliveries updated: $deliveriesUpdated');
      _addLog('');
      _addLog('ℹ️  All existing users are now part of "Default Company"');
      _addLog('ℹ️  All existing drivers are approved and active');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 32),
                SizedBox(width: 12),
                Text('Migration Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your data has been successfully migrated to the multi-company system.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Code',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _defaultCompanyId!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '• $usersUpdated users updated\n'
                  '• $deliveriesUpdated deliveries updated\n'
                  '• All drivers approved',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Close migration screen
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _addLog('');
      _addLog('❌ ERROR: ${e.toString()}');
      _addLog('');
      _addLog('Migration failed. Please try again or contact support.');

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 32),
                SizedBox(width: 12),
                Text('Migration Failed'),
              ],
            ),
            content: Text('Error: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Migration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Multi-Company Migration',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This migration will:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Create a "Default Company" for existing data\n'
                    '• Add companyId to all existing users\n'
                    '• Add companyId to all existing deliveries\n'
                    '• Approve all existing drivers automatically',
                    style: TextStyle(
                      color: Colors.blue[900],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'This is a one-time migration. Run it only once.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Run Migration Button
            FilledButton.icon(
              onPressed: _isRunning ? null : _runMigration,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                _isRunning ? 'Running Migration...' : 'Run Migration',
                style: const TextStyle(fontSize: 16),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.blue,
              ),
            ),

            const SizedBox(height: 24),

            // Logs Section
            if (_logs.isNotEmpty) ...[
              const Text(
                'Migration Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          _logs[index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Ready to migrate',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Click the button above to start',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
