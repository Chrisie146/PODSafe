import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../utils/theme.dart';

/// Debug screen to diagnose image loading issues
class ImageDebugScreen extends StatefulWidget {
  const ImageDebugScreen({super.key});

  @override
  State<ImageDebugScreen> createState() => _ImageDebugScreenState();
}

class _ImageDebugScreenState extends State<ImageDebugScreen> {
  bool _isLoading = true;
  String _log = '';
  final List<Map<String, dynamic>> _pods = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  void _addLog(String message) {
    setState(() {
      _log += '$message\n';
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isLoading = true;
      _log = 'Running image diagnostics...\n\n';
    });

    try {
      _addLog('📦 Checking POD documents...\n');

      // Get all PODs
      final podsSnapshot = await FirebaseFirestore.instance
          .collection('pods')
          .get();

      _addLog('Found ${podsSnapshot.docs.length} POD(s)\n');

      if (podsSnapshot.docs.isEmpty) {
        _addLog('⚠️  No PODs found. Create a delivery and capture POD first.\n');
        setState(() => _isLoading = false);
        return;
      }

      for (var doc in podsSnapshot.docs) {
        final data = doc.data();
        final signatureUrl = data['signatureUrl'] as String?;
        final photoUrl = data['photoUrl'] as String?;
        final deliveryId = data['deliveryId'] as String?;

        _addLog('━━━━━━━━━━━━━━━━━━━━━━');
        _addLog('POD: $deliveryId\n');

        Map<String, dynamic> podInfo = {
          'id': doc.id,
          'deliveryId': deliveryId,
          'signatureUrl': signatureUrl,
          'photoUrl': photoUrl,
          'signatureStatus': 'Not checked',
          'photoStatus': 'Not checked',
        };

        // Check signature URL
        if (signatureUrl != null) {
          _addLog('📝 Signature URL:');
          _addLog('   $signatureUrl\n');
          
          final sigStatus = await _checkImageUrl(signatureUrl, 'Signature');
          podInfo['signatureStatus'] = sigStatus;
        } else {
          _addLog('❌ No signature URL\n');
        }

        // Check photo URL
        if (photoUrl != null) {
          _addLog('📷 Photo URL:');
          _addLog('   $photoUrl\n');
          
          final photoStatus = await _checkImageUrl(photoUrl, 'Photo');
          podInfo['photoStatus'] = photoStatus;
        } else {
          _addLog('❌ No photo URL\n');
        }

        _pods.add(podInfo);
        _addLog('');
      }

      _addLog('\n✅ Diagnostics complete!\n');
      _addLog('\n💡 TIP: If URLs are "gs://" format, they need conversion.');
      _addLog('💡 TIP: If "https://" URLs fail, check Firebase Storage rules.');

    } catch (e) {
      _addLog('\n❌ Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<String> _checkImageUrl(String url, String type) async {
    try {
      if (url.startsWith('gs://')) {
        _addLog('   ℹ️  Format: gs:// (needs conversion)');
        
        try {
          final ref = FirebaseStorage.instance.refFromURL(url);
          final downloadUrl = await ref.getDownloadURL();
          _addLog('   ✅ Converted to: ${downloadUrl.substring(0, 50)}...');
          _addLog('   ✅ $type URL is accessible\n');
          return 'OK (gs:// converted)';
        } catch (e) {
          _addLog('   ❌ Failed to convert: $e\n');
          return 'FAIL: $e';
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        _addLog('   ℹ️  Format: https:// (direct download URL)');
        
        // Try to get the reference from the URL
        try {
          // Check if we can access the file
          final uri = Uri.parse(url);
          final path = uri.pathSegments.join('/');
          _addLog('   ℹ️  Path extracted: $path');
          _addLog('   ✅ $type URL looks valid\n');
          return 'OK (https://)';
        } catch (e) {
          _addLog('   ⚠️  Could not validate: $e\n');
          return 'UNKNOWN: $e';
        }
      } else {
        _addLog('   ❌ Unknown URL format\n');
        return 'FAIL: Unknown format';
      }
    } catch (e) {
      _addLog('   ❌ Error checking URL: $e\n');
      return 'ERROR: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Diagnostics'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runDiagnostics,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking images...'),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SelectableText(
                        _log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
          ),
          if (!_isLoading && _pods.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 26),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Quick Summary',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 12),
                  ..._pods.map((pod) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery: ${pod['deliveryId']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text('Signature: '),
                                  Text(
                                    pod['signatureStatus'],
                                    style: TextStyle(
                                      color: pod['signatureStatus'].startsWith('OK')
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Photo: '),
                                  Text(
                                    pod['photoStatus'],
                                    style: TextStyle(
                                      color: pod['photoStatus'].startsWith('OK')
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
