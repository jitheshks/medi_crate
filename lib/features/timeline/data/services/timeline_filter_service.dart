import 'package:intl/intl.dart';
import '../models/timeline_event_model.dart';

class TimelineFilterService {
  /// Checks whether a given [date] falls within [startDate] and [endDate] inclusively.
  static bool isDateInRange(
    DateTime date,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate != null && date.isBefore(startDate)) {
      return false;
    }
    if (endDate != null && date.isAfter(endDate)) {
      return false;
    }
    return true;
  }

  /// Filters and sorts timeline events in memory.
  static List<TimelineEventModel> filterAndSortEvents({
    required List<TimelineEventModel> events,
    required String query,
    required String categoryFilter,
    required String dateRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    required String sortOption,
  }) {
    final now = DateTime.now();

    DateTime? filterStart;
    DateTime? filterEnd;

    if (dateRange == 'custom' &&
        customStartDate != null &&
        customEndDate != null) {
      filterStart = DateTime(
        customStartDate.year,
        customStartDate.month,
        customStartDate.day,
      );
      filterEnd = DateTime(
        customEndDate.year,
        customEndDate.month,
        customEndDate.day,
        23,
        59,
        59,
        999,
      );
    } else if (dateRange != 'allTime') {
      int days = 90;
      if (dateRange == 'last30Days') days = 30;
      if (dateRange == 'last90Days') days = 90;
      if (dateRange == 'last6Months') days = 180;
      if (dateRange == 'lastYear') days = 365;

      filterStart = DateTime(now.year, now.month, now.day - days);
      filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    var filtered = events.where((event) {
      if (categoryFilter.toUpperCase() != 'ALL') {
        final cat = categoryFilter.toUpperCase();
        if (cat == 'CONSULTATIONS' && event.type != 'consultation') {
          return false;
        }
        if (cat == 'REPORTS' && event.type != 'report') {
          return false;
        }
        if (cat == 'MEDICINES' && event.type != 'medicine') {
          return false;
        }
        if (cat == 'MEASUREMENTS' && event.type != 'measurement') {
          return false;
        }
        if (cat == 'APPOINTMENTS' && event.type != 'appointment') {
          return false;
        }
        if (cat == 'EXPENSES' && event.type != 'expense') {
          return false;
        }
        if (cat == 'DOCTORS' && event.type != 'doctor') {
          return false;
        }
        if (cat == 'HOSPITALS' && event.type != 'hospital') {
          return false;
        }
      }

      if (filterStart != null || filterEnd != null) {
        if (event.eventDate == null) return false;
        if (!isDateInRange(event.eventDate!, filterStart, filterEnd)) {
          return false;
        }
      }

      if (query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchTitle = event.title.toLowerCase().contains(q);
        final matchSummary = event.summary.toLowerCase().contains(q);
        final matchBadge = event.badgeText.toLowerCase().contains(q);
        final matchType = event.type.toLowerCase().contains(q);

        if (!matchTitle && !matchSummary && !matchBadge && !matchType) {
          return false;
        }
      }

      return true;
    }).toList();

    if (sortOption == 'oldest') {
      filtered.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return a.eventDate!.compareTo(b.eventDate!);
      });
    } else {
      filtered.sort((a, b) {
        if (a.eventDate == null && b.eventDate == null) return 0;
        if (a.eventDate == null) return 1;
        if (b.eventDate == null) return -1;
        return b.eventDate!.compareTo(a.eventDate!);
      });
    }

    return filtered;
  }

  /// Groups events by Day Header (e.g. "WEDNESDAY 19 AUGUST").
  static Map<String, List<TimelineEventModel>> groupEventsByDay(
    List<TimelineEventModel> events,
  ) {
    final Map<String, List<TimelineEventModel>> grouped = {};
    final DateFormat formatter = DateFormat('EEEE d MMMM');

    for (final event in events) {
      final key = event.eventDate != null
          ? formatter.format(event.eventDate!).toUpperCase()
          : 'UNDATED';
      grouped.putIfAbsent(key, () => []).add(event);
    }

    return grouped;
  }
}
