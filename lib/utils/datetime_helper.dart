/// DateTime utilities for handling timezone conversions
/// Ensures all dates are in South African timezone (SAST - UTC+2)
library;

/// Get current DateTime in South African timezone (SAST - UTC+2)
/// 
/// South Africa uses SAST (South African Standard Time) which is UTC+2 year-round
/// (no daylight saving time)
DateTime getSouthAfricanTime() {
  final utcNow = DateTime.now().toUtc();
  // Add 2 hours for SAST (UTC+2)
  return utcNow.add(const Duration(hours: 2));
}

/// Convert any DateTime to South African timezone
DateTime toSouthAfricanTime(DateTime dateTime) {
  final utc = dateTime.toUtc();
  return utc.add(const Duration(hours: 2));
}

/// Get current date in South African timezone (without time)
DateTime getSouthAfricanDate() {
  final saTime = getSouthAfricanTime();
  return DateTime(saTime.year, saTime.month, saTime.day);
}

/// Check if a date is today in South African timezone
bool isTodaySA(DateTime date) {
  final today = getSouthAfricanDate();
  final checkDate = DateTime(date.year, date.month, date.day);
  return checkDate.isAtSameMomentAs(today);
}

/// Get start of today in South African timezone
DateTime getStartOfTodaySA() {
  final saDate = getSouthAfricanDate();
  return saDate;
}

/// Get end of today in South African timezone
DateTime getEndOfTodaySA() {
  final saDate = getSouthAfricanDate();
  return saDate.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
}
