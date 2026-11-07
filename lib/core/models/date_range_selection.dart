import 'package:flutter/foundation.dart';
import '../utils/date_formatter.dart';

/// Available presets for date range filtering.
enum DateRangePreset {
  last30Days('Last 30 days', 30),
  last90Days('Last 90 days', 90),
  lastYear('Last year', 365),
  allTime('All time', null),
  custom('Custom range…', null);

  final String label;
  final int? days;
  const DateRangePreset(this.label, this.days);
}

/// DateRangeSelection encapsulates a preset or custom start/end date range.
@immutable
class DateRangeSelection {
  final DateRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DateRangeSelection({
    required this.preset,
    this.customStart,
    this.customEnd,
  });

  const DateRangeSelection.preset(this.preset)
    : customStart = null,
      customEnd = null;

  const DateRangeSelection.custom(DateTime start, DateTime end)
    : preset = DateRangePreset.custom,
      customStart = start,
      customEnd = end;

  const DateRangeSelection.allTime()
    : preset = DateRangePreset.allTime,
      customStart = null,
      customEnd = null;

  const DateRangeSelection.last30Days()
    : preset = DateRangePreset.last30Days,
      customStart = null,
      customEnd = null;

  const DateRangeSelection.last90Days()
    : preset = DateRangePreset.last90Days,
      customStart = null,
      customEnd = null;

  const DateRangeSelection.lastYear()
    : preset = DateRangePreset.lastYear,
      customStart = null,
      customEnd = null;

  /// Returns the human-readable display label for the active range.
  String get label {
    if (preset == DateRangePreset.custom &&
        customStart != null &&
        customEnd != null) {
      return DateFormatter.formatDateRange(customStart!, customEnd!);
    }
    return preset.label;
  }

  /// Evaluates whether a given [date] falls within this selection inclusively.
  bool isDateInRange(DateTime date) {
    DateTime? start;
    DateTime? end;

    if (preset == DateRangePreset.custom &&
        customStart != null &&
        customEnd != null) {
      start = DateTime(customStart!.year, customStart!.month, customStart!.day);
      end = DateTime(
        customEnd!.year,
        customEnd!.month,
        customEnd!.day,
        23,
        59,
        59,
        999,
      );
    } else if (preset != DateRangePreset.allTime && preset.days != null) {
      final now = DateTime.now();
      start = DateTime(now.year, now.month, now.day - preset.days!);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    if (start != null && date.isBefore(start)) return false;
    if (end != null && date.isAfter(end)) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeSelection &&
          runtimeType == other.runtimeType &&
          preset == other.preset &&
          customStart == other.customStart &&
          customEnd == other.customEnd;

  @override
  int get hashCode => Object.hash(preset, customStart, customEnd);
}
