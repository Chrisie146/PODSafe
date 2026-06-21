import 'dart:typed_data';
import 'dart:html' as html;

/// Web platform implementation for PDF download
Future<void> downloadPDF(String filename, Uint8List bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$filename.pdf')
    ..click();
  html.Url.revokeObjectUrl(url);
}
