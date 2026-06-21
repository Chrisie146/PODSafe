import 'package:intl/intl.dart';

class Helpers {
  // Date and Time Formatting
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }
  
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
  }
  
  static String formatDateTimeDetailed(DateTime dateTime) {
    return DateFormat('EEEE, MMMM dd, yyyy at HH:mm:ss').format(dateTime);
  }
  
  static String getTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 7) {
      return formatDate(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
  
  // String Utilities
  static String capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
  
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  static String formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }
    
    return phoneNumber; // Return original if format not recognized
  }
  
  // Validation Helpers
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }
  
  static bool isValidPhoneNumber(String phoneNumber) {
    return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phoneNumber);
  }
  
  static bool isValidInvoiceNumber(String invoiceNumber) {
    return RegExp(r'^[A-Z0-9\-_]+$').hasMatch(invoiceNumber);
  }
  
  // File Size Formatting
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  // Distance Formatting
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }
  
  // Currency Formatting
  static String formatCurrency(double amount, {String symbol = '\$'}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }
  
  // Generate Unique IDs
  static String generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
  
  // Address Formatting
  static String formatAddress(String address) {
    // Clean up address formatting
    return address
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split('\n')
        .where((line) => line.isNotEmpty)
        .join(', ');
  }
  
  // Color Utilities
  static String colorToHex(int colorValue) {
    return '#${colorValue.toRadixString(16).padLeft(8, '0').substring(2)}';
  }
  
  // Status Formatting
  static String formatStatus(String status) {
    return status
        .split('_')
        .map((word) => capitalizeFirst(word))
        .join(' ');
  }
  
  // Error Handling
  static String getErrorMessage(dynamic error) {
    if (error == null) return 'Unknown error occurred';
    
    String message = error.toString();
    
    // Firebase-specific errors
    if (message.contains('network-request-failed')) {
      return 'Network connection failed. Please check your internet connection.';
    } else if (message.contains('permission-denied')) {
      return 'Access denied. Please check your permissions.';
    } else if (message.contains('not-found')) {
      return 'The requested resource was not found.';
    } else if (message.contains('already-exists')) {
      return 'This resource already exists.';
    }
    
    return 'An error occurred: $message';
  }
  
  // Debug Helpers
  static void debugPrint(String message, [String? tag]) {
    if (tag != null) {
      print('[$tag] $message');
    } else {
      print(message);
    }
  }
  
  // App Version Comparison
  static int compareVersions(String version1, String version2) {
    List<int> v1Parts = version1.split('.').map(int.parse).toList();
    List<int> v2Parts = version2.split('.').map(int.parse).toList();
    
    int maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    
    for (int i = 0; i < maxLength; i++) {
      int v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      int v2Part = i < v2Parts.length ? v2Parts[i] : 0;
      
      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }
    
    return 0;
  }
  
  // Network Utilities
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return url.startsWith('http://') || url.startsWith('https://');
    } catch (e) {
      return false;
    }
  }
  
  // List Utilities
  static List<T> removeDuplicates<T>(List<T> list) {
    return list.toSet().toList();
  }
  
  static List<List<T>> chunkList<T>(List<T> list, int chunkSize) {
    List<List<T>> chunks = [];
    for (int i = 0; i < list.length; i += chunkSize) {
      chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
    }
    return chunks;
  }
}