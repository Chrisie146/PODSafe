import 'dart:typed_data';
import 'dart:html' as html;

/// Web implementation for file downloads
void downloadFile(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
