import 'dart:html' as html;

/// Web-specific implementation for downloading CSV files
/// Returns null as web downloads don't have a file path
Future<String?> downloadCSV(String filename, List<int> bytes) async {
  // Create blob and download
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);

  // Create download link and trigger download
  html.AnchorElement(href: url)
    ..setAttribute('download', '$filename.csv')
    ..click();

  // Cleanup
  html.Url.revokeObjectUrl(url);
  
  // Web downloads don't have a file path
  return null;
}
