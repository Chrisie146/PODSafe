import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Mobile/desktop platform implementation for PDF download
/// This will attempt to save into the system Downloads folder on desktop
/// and the appropriate external downloads directory on Android.
Future<void> downloadPDF(String filename, Uint8List bytes) async {
  try {
    Directory? directory;

    // Android: prefer external downloads directory
    if (Platform.isAndroid) {
      try {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (dirs != null && dirs.isNotEmpty) {
          directory = dirs.first;
        }
      } catch (_) {
        // Fallback to external storage directory
        directory = await getExternalStorageDirectory();
      }
    } else {
      // Desktop (Windows/macOS/Linux) use getDownloadsDirectory()
      directory = await getDownloadsDirectory();
    }

    if (directory == null) {
      throw Exception('Could not access downloads directory');
    }

    final file = File('${directory.path}${Platform.pathSeparator}$filename.pdf');
    await file.writeAsBytes(bytes);

    print('PDF saved to: ${file.path}');
  } catch (e) {
    print('Error saving PDF: $e');
    rethrow;
  }
}
