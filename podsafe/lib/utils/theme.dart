import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors - Professional & Calm
  static const Color primaryColor = Color(0xFF5B6B7A);
  static const Color secondaryColor = Color(0xFF7A8A99);
  static const Color accentColor = Color(0xFF8FA5B8);
  
  // Status Colors - Muted and Professional
  static const Color successColor = Color(0xFF6B9B7A);
  static const Color errorColor = Color(0xFFB77B7B);
  static const Color warningColor = Color(0xFFB89A6B);
  static const Color infoColor = Color(0xFF7A92B8);
  
  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF5F6F8);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C9A);
  static const Color dividerColor = Color(0xFFE5E8EB);
  
  // Color Scheme
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primaryColor,
    onPrimary: Colors.white,
    secondary: secondaryColor,
    onSecondary: Colors.white,
    tertiary: accentColor,
    onTertiary: Colors.white,
    surface: cardColor,
    onSurface: textPrimary,
    error: errorColor,
    onError: Colors.white,
  );
  
  // Gradient Definitions
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, accentColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [successColor, Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Border Radius
  static const double borderRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  
  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Box Shadows
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  
  static const BoxShadow buttonShadow = BoxShadow(
    color: Color(0x26000000),
    blurRadius: 4,
    offset: Offset(0, 2),
  );
  
  // Status Colors for POD States
  static const Color podPendingColor = Color(0xFFFFA726); // Orange
  static const Color podSignedColor = Color(0xFF4CAF50);  // Green
  static const Color podMissingColor = Color(0xFFE57373); // Red
  static const Color podInTransitColor = Color(0xFF42A5F5); // Blue
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle heading3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppTheme.textPrimary,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondary,
  );
  
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  static const TextStyle captionText = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppTheme.textSecondary,
  );
}