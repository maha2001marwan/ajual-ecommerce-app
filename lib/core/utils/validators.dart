/// Lightweight, dependency-free form validators reused across the app.
class Validators {
  Validators._();

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    final regex = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!regex.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? confirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password';
    if (value != original) return 'Passwords do not match';
    return null;
  }

  static String? name(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Name is required';
    return null;
  }

  static String? required(String? value, [String field = 'This field']) {
    if ((value ?? '').trim().isEmpty) return '$field is required';
    return null;
  }

  static String? phone(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(text)) {
      return 'Use international format, e.g. +15551234567';
    }
    return null;
  }

  /// Local part of a phone number entered next to a country prefix.
  static String? localPhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^\d{6,13}$').hasMatch(digits)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  static String? postalCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Postal code is required';
    if (!RegExp(r'^[A-Za-z0-9 \-]{3,10}$').hasMatch(text)) {
      return 'Enter a valid postal code';
    }
    return null;
  }

  /// Card number with a Luhn checksum.
  static String? cardNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Card number is required';
    if (digits.length < 13 || digits.length > 19) {
      return 'Enter a valid card number';
    }
    var sum = 0;
    var alternate = false;
    for (var i = digits.length - 1; i >= 0; i--) {
      var n = int.parse(digits[i]);
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    if (sum % 10 != 0) return 'This card number is not valid';
    return null;
  }

  static String? expiry(String? value) {
    final text = value ?? '';
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
    if (match == null) return 'Use MM/YY';
    final month = int.parse(match.group(1)!);
    final year = 2000 + int.parse(match.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    final lastDay = DateTime(year, month + 1, 0, 23, 59);
    if (lastDay.isBefore(now)) return 'Card has expired';
    return null;
  }

  static String? cvv(String? value) {
    if (!RegExp(r'^\d{3,4}$').hasMatch(value ?? '')) return 'Invalid CVV';
    return null;
  }
}
