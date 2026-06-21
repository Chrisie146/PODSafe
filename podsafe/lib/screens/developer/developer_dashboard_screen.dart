import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import '../../utils/theme.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';

class DeveloperDashboardScreen extends StatefulWidget {
  const DeveloperDashboardScreen({super.key});

  @override
  State<DeveloperDashboardScreen> createState() => _DeveloperDashboardScreenState();
}

class _DeveloperDashboardScreenState extends State<DeveloperDashboardScreen> {
  final _companyNameController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isAuthenticated = false;
  bool _isLoading = false;

  // Developer PIN - change this to your desired PIN
  static const String _developerPin = '1234';

  @override
  void dispose() {
    _companyNameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    if (_pinController.text == _developerPin) {
      setState(() {
        _isAuthenticated = true;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid PIN'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _generateCompanyCode() async {
    if (_companyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a company name'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Call Cloud Function instead of direct Firestore write
      final callable = FirebaseFunctions.instance.httpsCallable('generateCompanyCode');
      final result = await callable.call({
        'companyName': _companyNameController.text.trim(),
      });

      final data = result.data as Map<String, dynamic>;
      final code = data['code'] as String;

      // Copy code to clipboard
      try {
        await Clipboard.setData(ClipboardData(text: code));
      } catch (clipboardError) {
        // Clipboard might not work on all platforms, continue anyway
        print('Clipboard error: $clipboardError');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Company code generated: $code'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      _companyNameController.clear();
      // Refresh the list
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating code: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadCompanyCodes() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('listCompanyCodes');
      final result = await callable.call();
      final data = result.data as Map<String, dynamic>;
      return (data['codes'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw 'Failed to load company codes: $e';
    }
  }

  Future<void> _toggleCodeStatus(String docId, bool currentStatus) async {
    try {
      // Call Cloud Function to update status
      final callable = FirebaseFunctions.instance.httpsCallable('updateCompanyCodeStatus');
      await callable.call({
        'codeId': docId,
        'status': currentStatus ? 'inactive' : 'active',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code ${currentStatus ? 'deactivated' : 'activated'} successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
      // Refresh the list
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating code status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteCode(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company Code'),
        content: const Text('Are you sure you want to delete this company code? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Call Cloud Function to delete
        final callable = FirebaseFunctions.instance.httpsCallable('deleteCompanyCode');
        await callable.call({
          'codeId': docId,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code deleted successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        // Refresh the list
        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting code: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Developer Access'),
          backgroundColor: AppTheme.primaryColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 64,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Developer Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter developer PIN to continue',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),
              CustomTextField(
                controller: _pinController,
                label: 'Developer PIN',
                hintText: 'Enter PIN',
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Authenticate',
                onPressed: _authenticate,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Dashboard'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              setState(() {
                _isAuthenticated = false;
                _pinController.clear();
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Generate Code Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Generate Company Code',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _companyNameController,
                      label: 'Company Name',
                      hintText: 'Enter company name',
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Generate Code',
                      onPressed: _isLoading ? null : _generateCompanyCode,
                      isLoading: _isLoading,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Company Codes List
            const Text(
              'Company Codes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            FutureBuilder(
              future: _loadCompanyCodes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.error, color: Colors.red),
                          const SizedBox(height: 8),
                          Text('Error loading codes: ${snapshot.error}'),
                          TextButton(
                            onPressed: () {
                              // Force refresh by rebuilding
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final codes = (snapshot.data as List?) ?? [];

                if (codes.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppTheme.paddingLarge),
                      child: Text('No company codes generated yet'),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: codes.length,
                  itemBuilder: (context, index) {
                    final code = codes[index];
                    final isActive = code['status'] == 'active';

                    // Parse timestamp from Cloud Function response
                    String createdDate = 'Unknown';
                    if (code['createdAt'] != null) {
                      try {
                        final timestamp = code['createdAt'];
                        if (timestamp is Map && timestamp.containsKey('_seconds')) {
                          final date = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
                          createdDate = date.toString().split(' ')[0];
                        } else if (timestamp is Timestamp) {
                          createdDate = timestamp.toDate().toString().split(' ')[0];
                        }
                      } catch (e) {
                        // Keep 'Unknown' if parsing fails
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${code['companyName']} - ${code['code']}'),
                        subtitle: Text(
                          'Created: $createdDate\n'
                          'Status: ${code['status'] ?? 'unknown'} | Used: ${code['used'] ? 'Yes' : 'No'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(isActive ? Icons.block : Icons.check_circle),
                              onPressed: () => _toggleCodeStatus(code['id'], isActive),
                              tooltip: isActive ? 'Deactivate' : 'Activate',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteCode(code['id']),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}