/// Validators provides standard form input validation rules matching
/// the MediCrate Backend API Contract v1.0 specifications.
abstract class Validators {
  /// Validates standard user full name (required, min 2 chars, letters only/allowed).
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters.';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(trimmed)) {
      return 'Name must contain letters.';
    }
    if (!RegExp(r"^[a-zA-Z\s\.\'\-]+$").hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, hyphens, and dots.';
    }
    return null;
  }

  /// Validates optional or required phone number (min 7 digits, max 15 digits).
  static String? validatePhone(String? value, {bool isRequired = false}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Phone number is required.' : null;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7 || digits.length > 15) {
      return 'Please enter a valid phone number (7-15 digits).';
    }
    return null;
  }

  /// Validates standard email address format.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final emailRegex = RegExp(r'^[\w\.\+\-]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Validates password against backend contract:
  /// Minimum 8 characters, at least 1 uppercase, 1 lowercase, 1 number, 1 special character.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number.';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\/\\~`]').hasMatch(value)) {
      return 'Password must contain at least one special character.';
    }
    return null;
  }

  /// Validates password confirmation matching.
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  /// Validates 4-digit numeric OTP.
  static String? validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the 4-digit code.';
    }
    final cleanValue = value.trim();
    if (cleanValue.length != 4 || !RegExp(r'^\d{4}$').hasMatch(cleanValue)) {
      return 'The OTP must be exactly 4 digits.';
    }
    return null;
  }

  /// Validates date of birth (must be a date before today).
  static String? validateDob(DateTime? date) {
    if (date == null) {
      return 'Date of birth is required.';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (!date.isBefore(today)) {
      return 'Date of birth must be before today.';
    }
    return null;
  }

  /// Validates gender selection (male, female, other) - optional.
  static String? validateGender(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized != 'male' &&
        normalized != 'female' &&
        normalized != 'other' &&
        normalized != 'others') {
      return 'Selected gender is invalid.';
    }
    return null;
  }
}
