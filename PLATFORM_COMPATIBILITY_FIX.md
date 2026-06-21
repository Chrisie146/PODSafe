# Platform Compatibility Fix - CSV Export

## Issue
The app failed to compile on Android/iOS because `dart:html` (web-only library) was imported unconditionally in `delivery_export_service.dart`.

## Error
```
lib/services/delivery_export_service.dart:3:8: Error: Dart library 'dart:html' is not available on this platform.
import 'dart:html' as html;
```

## Solution
Implemented **conditional imports** to use platform-specific implementations.

### Files Created

#### 1. `delivery_export_service_stub.dart`
Stub implementation for non-web platforms:
```dart
void downloadFile(String filename, String content) {
  throw UnimplementedError('File download is only supported on web platform');
}
```

#### 2. `delivery_export_service_web.dart`
Web-specific implementation using `dart:html`:
```dart
import 'dart:html' as html;
import 'dart:convert';

void downloadFile(String filename, String content) {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
```

### File Modified

#### `delivery_export_service.dart`
Changed from:
```dart
import 'dart:html' as html;

static void downloadCSV(String filename, String csvContent) {
  if (kIsWeb) {
    final bytes = utf8.encode(csvContent);
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    // ... web-specific code
  }
}
```

To:
```dart
import 'delivery_export_service_stub.dart'
    if (dart.library.html) 'delivery_export_service_web.dart' as platform;

static void downloadCSV(String filename, String csvContent) {
  if (kIsWeb) {
    platform.downloadFile(filename, csvContent);
  } else {
    print('Mobile file download not implemented yet');
  }
}
```

## How It Works

### Conditional Imports
```dart
import 'delivery_export_service_stub.dart'
    if (dart.library.html) 'delivery_export_service_web.dart' as platform;
```

- **On Web**: Imports `delivery_export_service_web.dart` (has dart:html)
- **On Android/iOS**: Imports `delivery_export_service_stub.dart` (no dart:html)
- Both files expose the same `downloadFile()` function
- Platform is detected at compile time, not runtime

### Runtime Check
```dart
if (kIsWeb) {
  platform.downloadFile(filename, csvContent);
} else {
  print('Mobile file download not implemented yet');
}
```

- `kIsWeb` is a Flutter constant (`true` on web, `false` on mobile)
- Provides additional safety at runtime
- Mobile download can be implemented later using `path_provider`

## Benefits

✅ **Cross-Platform**: App now compiles on Android, iOS, and Web
✅ **Type Safe**: Compile-time platform detection
✅ **Clean Code**: Platform-specific code separated into dedicated files
✅ **Future-Proof**: Easy to add mobile file download later
✅ **No Breaking Changes**: Existing functionality unchanged

## Testing Status

- ✅ Compiles without errors on all platforms
- ✅ Web functionality preserved (CSV download works)
- ✅ Android/iOS compile successfully (file download gracefully disabled)

## Future Enhancement

To add mobile file download support:

1. Add `path_provider` package
2. Implement file write in stub:
```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile(String filename, String content) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsString(content);
  // Show notification or share dialog
}
```

3. Change stub to async and update callers

## Files Summary

| File | Purpose | Platform |
|------|---------|----------|
| `delivery_export_service.dart` | Main service with conditional import | All |
| `delivery_export_service_web.dart` | Web implementation (dart:html) | Web only |
| `delivery_export_service_stub.dart` | Mobile stub (throws error) | Android/iOS |

---

**Status**: ✅ Fixed and tested
**Impact**: App now builds on all platforms
**Breaking Changes**: None
