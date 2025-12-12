import 'package:intl/intl.dart';

/// Utility class for formatting various data types
class FormatterUtils {
  /// Format a date to a readable string (e.g., "Apr 22, 2025")
  static String formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }

  /// Format a date with time (e.g., "Apr 22, 2025 17:30")
  static String formatDateTime(DateTime date) {
    return DateFormat.yMMMd().add_Hm().format(date);
  }

  /// Format a date to a relative time string (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Format a number with thousand separators
  static String formatNumber(num number) {
    return NumberFormat.decimalPattern().format(number);
  }

  /// Format a currency amount
  static String formatCurrency(num amount, {String symbol = '\$'}) {
    return NumberFormat.currency(symbol: symbol).format(amount);
  }

  /// Format a percentage
  static String formatPercentage(num percentage) {
    return NumberFormat.percentPattern().format(percentage / 100);
  }

  /// Format a file size (e.g., "2.5 MB")
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

  /// Format a phone number (e.g., "(123) 456-7890")
  static String formatPhoneNumber(String phoneNumber) {
    // Remove any non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    // Format based on length
    if (digitsOnly.length == 10) {
      return '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    } else {
      return phoneNumber; // Return as is if not a standard 10-digit number
    }
  }

  /// Format GPS coordinates (e.g., "40.7128° N, 74.0060° W")
  static String formatCoordinates(double latitude, double longitude) {
    final latDirection = latitude >= 0 ? 'N' : 'S';
    final longDirection = longitude >= 0 ? 'E' : 'W';
    
    return '${latitude.abs().toStringAsFixed(4)}° $latDirection, ${longitude.abs().toStringAsFixed(4)}° $longDirection';
  }
}
