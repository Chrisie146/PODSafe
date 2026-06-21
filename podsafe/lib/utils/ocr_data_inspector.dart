// OCR Data Query Helper
// Add this to your Flutter app to inspect OCR data programmatically

import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to query and display OCR data
class OCRDataInspector {
  static final _firestore = FirebaseFirestore.instance;

  /// Get the most recently submitted POD with OCR data
  static Future<void> printLatestPODWithOCR() async {
    try {
      print('\n📊 ═══════════════════════════════════════════════════════');
      print('📊 FETCHING LATEST POD WITH OCR DATA...');
      print('📊 ═══════════════════════════════════════════════════════\n');

      final snapshot = await _firestore
          .collection('pods')
          .where('ocrFields', isNotEqualTo: null)
          .orderBy('ocrFields')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        print('❌ No PODs with OCR data found!');
        return;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      print('✅ POD ID: ${doc.id}');
      print('📅 Timestamp: ${data['timestamp']}');
      print('👤 Driver ID: ${data['driverId']}');
      print('📦 Delivery ID: ${data['deliveryId']}');
      print('');
      
      // Print OCR Raw Text
      if (data['ocrRawText'] != null) {
        print('📄 RAW OCR TEXT (${(data['ocrRawText'] as String).length} chars):');
        print('┌─────────────────────────────────────────────────┐');
        print((data['ocrRawText'] as String).split('\n').take(10).join('\n'));
        print('└─────────────────────────────────────────────────┘');
        print('');
      }

      // Print OCR Fields
      if (data['ocrFields'] != null) {
        final fields = data['ocrFields'] as Map<String, dynamic>;
        print('✓ OCR FIELDS EXTRACTED:');
        print('┌─────────────────────────────────────────────────┐');
        fields.forEach((key, value) {
          print('  $key: $value');
        });
        print('└─────────────────────────────────────────────────┘');
        print('');
      }

      // Print OCR Confidence
      if (data['ocrConfidence'] != null) {
        final confidence = data['ocrConfidence'] as double;
        final percentage = (confidence * 100).toStringAsFixed(1);
        final bar = _buildConfidenceBar(confidence);
        print('📈 CONFIDENCE SCORE: $percentage%');
        print('   $bar');
        print('');
      }

      print('📊 ═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error fetching OCR data: $e');
    }
  }

  /// Get all PODs with OCR data and statistics
  static Future<void> printOCRStatistics() async {
    try {
      print('\n📊 ═══════════════════════════════════════════════════════');
      print('📊 OCR DATA STATISTICS');
      print('📊 ═══════════════════════════════════════════════════════\n');

      final snapshot = await _firestore.collection('pods').get();

      final allDocs = snapshot.docs;
      final docsWithOCR = allDocs.where((doc) {
        final ocrFields = doc['ocrFields'];
        return ocrFields != null && (ocrFields as Map).isNotEmpty;
      }).toList();

      print('Total PODs: ${allDocs.length}');
      print('PODs with OCR: ${docsWithOCR.length}');
      print('OCR Coverage: ${((docsWithOCR.length / allDocs.length) * 100).toStringAsFixed(1)}%');
      print('');

      if (docsWithOCR.isNotEmpty) {
        final confidences = docsWithOCR
            .map((doc) => doc['ocrConfidence'] as double? ?? 0.0)
            .toList();
        
        final avgConfidence = confidences.reduce((a, b) => a + b) / confidences.length;
        final maxConfidence = confidences.reduce((a, b) => a > b ? a : b);
        final minConfidence = confidences.reduce((a, b) => a < b ? a : b);

        print('Average Confidence: ${(avgConfidence * 100).toStringAsFixed(1)}%');
        print('Highest Confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%');
        print('Lowest Confidence: ${(minConfidence * 100).toStringAsFixed(1)}%');
        print('');

        // Group by confidence ranges
        final excellent = docsWithOCR.where((doc) => (doc['ocrConfidence'] as double) >= 0.85).length;
        final good = docsWithOCR.where((doc) {
          final conf = doc['ocrConfidence'] as double;
          return conf >= 0.70 && conf < 0.85;
        }).length;
        final fair = docsWithOCR.where((doc) {
          final conf = doc['ocrConfidence'] as double;
          return conf >= 0.60 && conf < 0.70;
        }).length;

        print('Confidence Distribution:');
        print('  ✓ Excellent (≥85%):  $excellent PODs');
        print('  ○ Good (70-84%):     $good PODs');
        print('  ◐ Fair (60-69%):     $fair PODs');
      }

      print('\n📊 ═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error fetching statistics: $e');
    }
  }

  /// Get all PODs with low confidence OCR for review
  static Future<void> printLowConfidencePODs({double threshold = 0.65}) async {
    try {
      print('\n⚠️  ═══════════════════════════════════════════════════════');
      print('⚠️  LOW CONFIDENCE OCR DATA (< ${(threshold * 100).toStringAsFixed(0)}%)');
      print('⚠️  ═══════════════════════════════════════════════════════\n');

      final snapshot = await _firestore
          .collection('pods')
          .where('ocrConfidence', isLessThan: threshold)
          .orderBy('ocrConfidence')
          .get();

      if (snapshot.docs.isEmpty) {
        print('✅ No low confidence PODs found!');
        print('⚠️  ═══════════════════════════════════════════════════════\n');
        return;
      }

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final confidence = data['ocrConfidence'] as double;
        final fields = data['ocrFields'] as Map<String, dynamic>?;

        print('📋 POD: ${doc.id}');
        print('   Confidence: ${(confidence * 100).toStringAsFixed(1)}% ${_buildConfidenceBar(confidence)}');
        
        if (fields != null) {
          print('   Fields extracted: ${fields.keys.where((k) => fields[k] != null).length}/${fields.length}');
          fields.forEach((key, value) {
            if (value != null) {
              print('   - $key: $value');
            }
          });
        }
        print('');
      }

      print('⚠️  ═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error fetching low confidence PODs: $e');
    }
  }

  /// Print a single POD's OCR data by delivery ID
  static Future<void> printPODByDeliveryId(String deliveryId) async {
    try {
      print('\n🔍 ═══════════════════════════════════════════════════════');
      print('🔍 OCR DATA FOR DELIVERY: $deliveryId');
      print('🔍 ═══════════════════════════════════════════════════════\n');

      final doc = await _firestore.collection('pods').doc(deliveryId).get();

      if (!doc.exists) {
        print('❌ POD not found for delivery: $deliveryId');
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // Basic info
      print('✓ POD ID: ${doc.id}');
      print('✓ Driver: ${data['driverId']}');
      print('✓ Customer: ${data['customerName']}');
      print('✓ Timestamp: ${data['timestamp']}');
      print('');

      // OCR Raw Text
      if (data['ocrRawText'] != null && (data['ocrRawText'] as String).isNotEmpty) {
        print('📄 RAW OCR TEXT:');
        print((data['ocrRawText'] as String));
        print('');
      } else {
        print('❌ No OCR raw text');
        print('');
      }

      // OCR Fields
      if (data['ocrFields'] != null && (data['ocrFields'] as Map).isNotEmpty) {
        final fields = data['ocrFields'] as Map<String, dynamic>;
        print('✓ EXTRACTED FIELDS:');
        fields.forEach((key, value) {
          print('  $key: ${value ?? "N/A"}');
        });
        print('');
      } else {
        print('❌ No OCR fields');
        print('');
      }

      // Confidence
      if (data['ocrConfidence'] != null) {
        final confidence = data['ocrConfidence'] as double;
        print('📈 Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
        print('   ${_buildConfidenceBar(confidence)}');
      } else {
        print('❌ No confidence score');
      }

      print('\n🔍 ═══════════════════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  /// Helper to build a visual confidence bar
  static String _buildConfidenceBar(double confidence) {
    final filled = (confidence * 20).round();
    final empty = 20 - filled;
    
    if (confidence >= 0.80) {
      return '${'█' * filled}${'░' * empty} ✓ Excellent';
    } else if (confidence >= 0.70) {
      return '${'█' * filled}${'░' * empty} ○ Good';
    } else if (confidence >= 0.60) {
      return '${'█' * filled}${'░' * empty} ◐ Fair';
    } else {
      return '${'█' * filled}${'░' * empty} ⚠ Low';
    }
  }
}

// USAGE EXAMPLES:
/*

// 1. Print the latest POD with OCR data
await OCRDataInspector.printLatestPODWithOCR();

// 2. Print OCR statistics across all PODs
await OCRDataInspector.printOCRStatistics();

// 3. Print all PODs with low confidence (< 65%)
await OCRDataInspector.printLowConfidencePODs(threshold: 0.65);

// 4. Print OCR data for a specific delivery
await OCRDataInspector.printPODByDeliveryId('delivery-id-123');

// Add to a debug button or method:
void showOCRDebugInfo() {
  OCRDataInspector.printLatestPODWithOCR();
  OCRDataInspector.printOCRStatistics();
}

*/
