import 'package:intl/intl.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../data/models/measurement_model.dart';

class VitalsListFilterHelper {
  /// Apply search and filter chips
  static List<MeasurementModel> applyFilters({
    required List<MeasurementModel> list,
    required String query,
    required String selectedFilterType,
    required DateRangeSelection dateRange,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    return list.where((m) {
      // Type Filter
      if (selectedFilterType != 'All') {
        if (m.type.toLowerCase() != selectedFilterType.toLowerCase()) {
          return false;
        }
      }

      // Date Range Filter
      if (!dateRange.isDateInRange(m.recordedAt)) {
        return false;
      }

      // Search Query
      if (cleanQuery.isNotEmpty) {
        final titleMatch = m.title.toLowerCase().contains(cleanQuery);
        final typeMatch = m.type.toLowerCase().contains(cleanQuery);
        final notesMatch = (m.notes ?? '').toLowerCase().contains(cleanQuery);
        final valueMatch = m.value.toLowerCase().contains(cleanQuery);
        final unitMatch = m.unit.toLowerCase().contains(cleanQuery);
        return titleMatch || typeMatch || notesMatch || valueMatch || unitMatch;
      }

      return true;
    }).toList();
  }

  /// Apply sort order
  static void applySorting({
    required List<MeasurementModel> list,
    required String sortOrder,
  }) {
    if (sortOrder == 'Oldest first') {
      list.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    } else if (sortOrder == 'Highest value') {
      list.sort((a, b) {
        final valA = a.systolic ?? a.numericValue ?? 0;
        final valB = b.systolic ?? b.numericValue ?? 0;
        return valB.compareTo(valA);
      });
    } else {
      // Default: Newest first
      list.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    }
  }

  /// Group items by formatted date header
  static Map<String, List<MeasurementModel>> groupByDate(
    List<MeasurementModel> list,
  ) {
    final map = <String, List<MeasurementModel>>{};
    for (final item in list) {
      final key = DateFormat('EEEE d MMMM').format(item.recordedAt);
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(item);
    }
    return map;
  }
}
