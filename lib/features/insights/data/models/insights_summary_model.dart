import 'package:flutter/widgets.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../consultations/data/models/consultation_model.dart';
import '../../../reports/data/models/report_model.dart';
import '../../../vitals/data/models/measurement_model.dart';
import 'health_insight_recommendation.dart';
import 'health_vault_score_model.dart';

/// Time range options for filtering health insights.
enum InsightsTimeRange {
  sevenDays('7 Days', 7),
  thirtyDays('30 Days', 30),
  threeMonths('3 Months', 90),
  oneYear('1 Year', 365),
  allTime('All Time', 3650),
  custom('Custom', 0);

  final String label;
  final int days;
  const InsightsTimeRange(this.label, this.days);
}

/// Individual vital sign summary item for the Vitals Overview grid.
class VitalOverviewItem {
  final String title;

  final String value;
  final String unit;
  final String status; // NORMAL, ELEVATED, OPTIMAL, STABLE
  final IconData icon;
  final DateTime? recordedAt;

  VitalOverviewItem({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.icon,
    this.recordedAt,
  });

  String get recordedTime {
    if (recordedAt == null || value == '--') return 'No data recorded';
    final now = DateTime.now();
    final difference = now.difference(recordedAt!);
    if (difference.inDays == 0) {
      final hour = recordedAt!.hour.toString().padLeft(2, '0');
      final minute = recordedAt!.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${recordedAt!.day}/${recordedAt!.month}';
    }
  }
}

/// Domain model for Vitals Analysis trend charts.
class VitalTrendSeries {
  final String type;
  final String title;
  final String unit;
  final String latestValue;
  final String latestStatus;
  final DateTime? latestRecordedAt;
  final List<MeasurementModel> readings;

  const VitalTrendSeries({
    required this.type,
    required this.title,
    required this.unit,
    required this.latestValue,
    required this.latestStatus,
    this.latestRecordedAt,
    required this.readings,
  });

  bool get hasTrend => readings.length >= 2;
  bool get hasSingleReading => readings.length == 1;
  bool get isEmpty => readings.isEmpty;
}

/// Aggregated summary for Consultations feature section.
class ConsultationSummaryData {
  final int totalCount;
  final ConsultationModel? latestConsultation;
  final String? topDoctorName;

  const ConsultationSummaryData({
    required this.totalCount,
    this.latestConsultation,
    this.topDoctorName,
  });
}

/// Aggregated summary for Appointments feature section.
class AppointmentSummaryData {
  final int upcomingCount;
  final int completedCount;
  final int cancelledCount;
  final int missedCount;
  final AppointmentModel? nextUpcomingAppointment;

  const AppointmentSummaryData({
    required this.upcomingCount,
    required this.completedCount,
    required this.cancelledCount,
    required this.missedCount,
    this.nextUpcomingAppointment,
  });

  int get totalCount =>
      upcomingCount + completedCount + cancelledCount + missedCount;
}

/// Aggregated summary for Medicines feature section.
class MedicineSummaryData {
  final int activeCount;
  final int completedCount;
  final Map<String, dynamic>? latestMedicine;

  const MedicineSummaryData({
    required this.activeCount,
    required this.completedCount,
    this.latestMedicine,
  });

  int get totalCount => activeCount + completedCount;
}

/// Aggregated summary for Reports feature section.
class ReportSummaryData {
  final int totalCount;
  final Map<String, int> categoryCounts;
  final ReportModel? latestReport;

  const ReportSummaryData({
    required this.totalCount,
    required this.categoryCounts,
    this.latestReport,
  });
}

/// Aggregated summary for Care Directory feature section.
class CareDirectorySummaryData {
  final int doctorsCount;
  final int hospitalsCount;
  final String? mostRecentlyConsultedDoctor;

  const CareDirectorySummaryData({
    required this.doctorsCount,
    required this.hospitalsCount,
    this.mostRecentlyConsultedDoctor,
  });
}

/// Expense category/hospital/doctor breakdown item for progress bars.
class ExpenseBreakdownItem {
  final String label;
  final double amount;
  final double percentage; // 0.0 to 1.0

  ExpenseBreakdownItem({
    required this.label,
    required this.amount,
    required this.percentage,
  });
}

/// Monthly expense item for vertical bar chart presentation.
class MonthlyExpenseBarItem {
  final String monthLabel; // e.g. "Aug", "Jul", "Jun"
  final double amount;

  MonthlyExpenseBarItem({required this.monthLabel, required this.amount});
}

/// Complete aggregated domain model for the Insights Screen.
class InsightsSummaryModel {
  final String profileId;
  final String profileName;
  final InsightsTimeRange timeRange;
  final int healthScore; // 0 - 100
  final HealthVaultScoreModel vaultScore;
  final String healthSummary;

  // Overview stats in Health Score Hero Card
  final int overviewConsultationsCount;
  final int overviewUpcomingAppointmentsCount;
  final int overviewDoctorsSeenCount;

  // Vitals Overview Items
  final List<VitalOverviewItem> vitalsOverview;

  // Vitals Analysis Trend Series
  final List<VitalTrendSeries> vitalTrends;

  // Healthcare Activity Counts & Detailed Data
  final int totalConsultations;
  final int totalAppointments;
  final int totalReports;
  final int totalVitalsLogged;

  final ConsultationSummaryData consultationSummary;
  final AppointmentSummaryData appointmentSummary;
  final MedicineSummaryData medicineSummary;
  final ReportSummaryData reportSummary;
  final CareDirectorySummaryData careDirectorySummary;

  // Expense Analytics
  final double totalExpenses;
  final int recordsWithCostCount;
  final List<MonthlyExpenseBarItem> monthlyExpenses;
  final List<ExpenseBreakdownItem> expensesByCategory;
  final List<ExpenseBreakdownItem> expensesByHospital;
  final List<ExpenseBreakdownItem> expensesByDoctor;

  // Actionable Recommendations
  final List<HealthInsightRecommendation> recommendations;

  InsightsSummaryModel({
    required this.profileId,
    required this.profileName,
    required this.timeRange,
    required this.healthScore,
    required this.vaultScore,
    required this.healthSummary,
    required this.overviewConsultationsCount,
    required this.overviewUpcomingAppointmentsCount,
    required this.overviewDoctorsSeenCount,
    required this.vitalsOverview,
    this.vitalTrends = const [],
    required this.totalConsultations,
    required this.totalAppointments,
    required this.totalReports,
    required this.totalVitalsLogged,
    this.consultationSummary = const ConsultationSummaryData(totalCount: 0),
    this.appointmentSummary = const AppointmentSummaryData(
      upcomingCount: 0,
      completedCount: 0,
      cancelledCount: 0,
      missedCount: 0,
    ),
    this.medicineSummary = const MedicineSummaryData(
      activeCount: 0,
      completedCount: 0,
    ),
    this.reportSummary = const ReportSummaryData(
      totalCount: 0,
      categoryCounts: {},
    ),
    this.careDirectorySummary = const CareDirectorySummaryData(
      doctorsCount: 0,
      hospitalsCount: 0,
    ),
    required this.totalExpenses,
    required this.recordsWithCostCount,
    required this.monthlyExpenses,
    required this.expensesByCategory,
    required this.expensesByHospital,
    required this.expensesByDoctor,
    this.recommendations = const [],
  });
}
