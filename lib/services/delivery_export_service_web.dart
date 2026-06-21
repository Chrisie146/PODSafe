import 'dart:html' as html;
import 'dart:convert';

/// Web-specific implementation for file download
void downloadFile(String filename, String content) {
  // Create blob and download for web
  // Use UTF-8 encoding to properly convert string to bytes
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
