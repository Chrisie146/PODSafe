/// Stub implementation for non-web platforms
void downloadFile(String filename, String content) {
  // This should never be called on non-web platforms
  throw UnimplementedError('File download is only supported on web platform');
}
