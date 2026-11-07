import 'package:intl/intl.dart';

/// DateFormatter provides centralized date formatting utilities across the app.
abstract class DateFormatter {
  static String formatFullDate(DateTime date) {
    return DateFormat('EEEE, d MMMM yyyy').format(date);
  }

  static String formatShortDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatDateRange(DateTime start, DateTime end) {
    if (start.year != end.year) {
      return "${DateFormat('d MMM yyyy').format(start)} - ${DateFormat('d MMM yyyy').format(end)}";
    }
    return "${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM').format(end)}";
  }

  /// Formats a DateTime, String, or timestamp into Indian format: dd-MM-yy (e.g. 15-09-26).
  /// Extracts the date parts directly to prevent timezone shift issues.
  static String formatIndianDate(dynamic rawDate, {String fallback = 'N/A'}) {
    if (rawDate == null) return fallback;
    if (rawDate is DateTime) {
      final dd = rawDate.day.toString().padLeft(2, '0');
      final mm = rawDate.month.toString().padLeft(2, '0');
      final yy = (rawDate.year % 100).toString().padLeft(2, '0');
      return '$dd-$mm-$yy';
    }
    final str = rawDate.toString().trim();
    if (str.isEmpty) return fallback;

    final isoMatch = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(str);
    if (isoMatch != null) {
      final y = (int.parse(isoMatch.group(1)!) % 100).toString().padLeft(
        2,
        '0',
      );
      final m = int.parse(isoMatch.group(2)!).toString().padLeft(2, '0');
      final d = int.parse(isoMatch.group(3)!).toString().padLeft(2, '0');
      return '$d-$m-$y';
    }

    final matchDdMmYy = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})$')
        .firstMatch(str);
    if (matchDdMmYy != null) {
      final d = int.tryParse(matchDdMmYy.group(1)!)?.toString().padLeft(2, '0');
      final m = int.tryParse(matchDdMmYy.group(2)!)?.toString().padLeft(2, '0');
      final rawY = int.tryParse(matchDdMmYy.group(3)!);
      if (d != null && m != null && rawY != null) {
        final y = (rawY % 100).toString().padLeft(2, '0');
        return '$d-$m-$y';
      }
    }

    final dt = DateTime.tryParse(str);
    if (dt != null) {
      final dd = dt.day.toString().padLeft(2, '0');
      final mm = dt.month.toString().padLeft(2, '0');
      final yy = (dt.year % 100).toString().padLeft(2, '0');
      return '$dd-$mm-$yy';
    }

    return str.contains('T') ? str.split('T')[0] : str;
  }

  /// Formats a DateTime, String, or timestamp into Indian date + time format: dd-MM-yy · hh:mm a (e.g. 15-09-26 · 10:30 AM).
  static String formatIndianDateTime(
    dynamic rawDate, {
    String fallback = 'N/A',
  }) {
    if (rawDate == null) return fallback;
    final str = rawDate.toString().trim();
    if (str.isEmpty) return fallback;

    DateTime? dt;
    if (rawDate is DateTime) {
      dt = rawDate;
    } else {
      dt = DateTime.tryParse(str);
    }

    if (dt != null) {
      final dateStr = formatIndianDate(dt, fallback: fallback);
      final timeStr = DateFormat('hh:mm a').format(dt);
      return '$dateStr · $timeStr';
    }

    return formatIndianDate(rawDate, fallback: fallback);
  }
}
