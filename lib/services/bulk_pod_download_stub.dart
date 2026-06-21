import 'dart:typed_data';

/// Stub implementation for non-web platforms
void downloadFile(Uint8List bytes, String filename) {
  print('📥 Download ready: $filename (${bytes.length} bytes)');
}
