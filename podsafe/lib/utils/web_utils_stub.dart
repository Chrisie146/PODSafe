/// Stub for non-web platforms
/// This file is used when dart:html is not available
library;

class Blob {
  Blob(List<dynamic> parts, String type);
}

class Url {
  static String createObjectUrlFromBlob(Blob blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  AnchorElement({String? href});
  void setAttribute(String name, String value) {}
  void click() {}
}
