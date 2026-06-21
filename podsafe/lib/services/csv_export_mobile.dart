import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Mobile-specific implementation for downloading CSV files
/// Returns the file path where the CSV was saved
Future<String> downloadCSV(String filename, List<int> bytes) async {
  try {
    // Get the downloads directory
    Directory? directory;
    
    if (Platform.isAndroid) {
      // For Android, try to get Downloads directory
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      // For iOS, use app documents directory
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Fallback
      directory = await getApplicationDocumentsDirectory();
    }

    if (directory == null) {
      debugPrint('Could not get directory for CSV export');
      throw Exception('Could not access storage directory');
    }

    // Create file and write bytes
    final file = File('${directory.path}/$filename.csv');
    await file.writeAsBytes(bytes);

    debugPrint('✅ CSV exported to: ${file.path}');
    
    return file.path;
  } catch (e) {
    debugPrint('❌ Error saving CSV on mobile: $e');
    rethrow;
  }
}
