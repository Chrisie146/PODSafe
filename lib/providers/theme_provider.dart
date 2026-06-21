import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider for managing dynamic theme and branding settings
class ThemeProvider extends ChangeNotifier {
  Color _primaryColor = const Color(0xFF1976D2);
  Color _accentColor = Colors.blue;
  Color _warningColor = Colors.orange;
  Color _successColor = Colors.green;
  String _appName = 'PODSafe';
  String? _appLogoUrl;
  bool _useDarkMode = false;
  
  bool _isLoading = false;

  // Getters
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  Color get warningColor => _warningColor;
  Color get successColor => _successColor;
  String get appName => _appName;
  String? get appLogoUrl => _appLogoUrl;
  bool get useDarkMode => _useDarkMode;
  bool get isLoading => _isLoading;

  /// Load branding settings from Firestore for a company (without notifying during build)
  Future<void> loadBrandingSettings(String companyId, {bool notifyOnComplete = true}) async {
    try {
      if (notifyOnComplete) {
        _isLoading = true;
        notifyListeners();
      }

      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('branding')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        
        _appName = data['appName'] ?? 'PODSafe';
        _appLogoUrl = data['appLogoUrl'];
        _useDarkMode = data['useDarkMode'] ?? false;
        
        debugPrint('Loaded branding from Firestore:');
        debugPrint('  appName: $_appName');
        debugPrint('  appLogoUrl: $_appLogoUrl');
        debugPrint('  useDarkMode: $_useDarkMode');
        
        // Parse colors from stored hex strings
        if (data['primaryColor'] != null) {
          try {
            _primaryColor = Color(int.parse(data['primaryColor'] as String));
          } catch (e) {
            debugPrint('Error parsing primary color: $e');
          }
        }
        
        if (data['accentColor'] != null) {
          try {
            _accentColor = Color(int.parse(data['accentColor'] as String));
          } catch (e) {
            debugPrint('Error parsing accent color: $e');
          }
        }
        
        if (data['warningColor'] != null) {
          try {
            _warningColor = Color(int.parse(data['warningColor'] as String));
          } catch (e) {
            debugPrint('Error parsing warning color: $e');
          }
        }
        
        if (data['successColor'] != null) {
          try {
            _successColor = Color(int.parse(data['successColor'] as String));
          } catch (e) {
            debugPrint('Error parsing success color: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading branding settings: $e');
    } finally {
      if (notifyOnComplete) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Notify listeners after loading without notification
  void notifyLoadingComplete() {
    notifyListeners();
  }

  /// Update a single color and notify listeners
  void setPrimaryColor(Color color) {
    _primaryColor = color;
    notifyListeners();
  }

  void setAccentColor(Color color) {
    _accentColor = color;
    notifyListeners();
  }

  void setWarningColor(Color color) {
    _warningColor = color;
    notifyListeners();
  }

  void setSuccessColor(Color color) {
    _successColor = color;
    notifyListeners();
  }

  void setAppName(String name) {
    _appName = name;
    notifyListeners();
  }

  void setAppLogoUrl(String? url) {
    _appLogoUrl = url;
    notifyListeners();
  }

  void setDarkMode(bool enabled) {
    _useDarkMode = enabled;
    notifyListeners();
  }

  /// Reset to default values
  void reset() {
    _primaryColor = const Color(0xFF1976D2);
    _accentColor = Colors.blue;
    _warningColor = Colors.orange;
    _successColor = Colors.green;
    _appName = 'PODSafe';
    _appLogoUrl = null;
    _useDarkMode = false;
    notifyListeners();
  }
}
