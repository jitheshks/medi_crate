import '../models/home_summary_model.dart';

/// HomeMapper transforms raw API responses into HomeSummaryModel data structures.
abstract class HomeMapper {
  static HomeSummaryModel fromMap(Map<String, dynamic> map) {
    return HomeSummaryModel.initial();
  }
}
