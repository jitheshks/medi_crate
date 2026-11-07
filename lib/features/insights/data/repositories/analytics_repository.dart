import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../appointments/data/repositories/appointment_repository.dart';
import '../../../consultations/data/repositories/consultation_repository.dart';
import '../../../doctors/data/repositories/doctor_repository.dart';
import '../../../expenses/data/repositories/expense_repository.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../../../medicines/data/repositories/medicine_repository.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../reports/data/repositories/report_repository.dart';
import '../../../vitals/data/repositories/measurement_repository.dart';
import '../models/insights_summary_model.dart';
import 'activity_summary_builder.dart';
import 'expense_analytics_calculator.dart';
import 'health_vault_score_calculator.dart';
import 'vault_confirmation_manager.dart';

/// AnalyticsRepository aggregates profile-scoped Health Vault Completeness Score,
/// vitals overview, healthcare activity, and expense analytics.
class AnalyticsRepository {
  static const int vitalRecencyDays = 90;

  final HiveService hiveService;
  final SyncService? syncService;
  final VaultConfirmationManager _confirmationManager;

  late final MeasurementRepository _measurementRepository;
  late final ConsultationRepository _consultationRepository;
  late final AppointmentRepository _appointmentRepository;
  late final ReportRepository _reportRepository;
  late final DoctorRepository _doctorRepository;
  late final HospitalRepository _hospitalRepository;
  late final ExpenseRepository _expenseRepository;
  late final MedicineRepository _medicineRepository;

  AnalyticsRepository({required this.hiveService, this.syncService})
    : _confirmationManager = VaultConfirmationManager(
        hiveService: hiveService,
      ) {
    _measurementRepository = MeasurementRepository(hiveService: hiveService);
    _consultationRepository = ConsultationRepository(
      hiveService: hiveService,
      syncService:
          syncService ??
          SyncService(
            hiveService: hiveService,
            connectivityService: ConnectivityService(),
          ),
    );
    _appointmentRepository = AppointmentRepository(hiveService: hiveService);
    _reportRepository = ReportRepository(hiveService: hiveService);
    _doctorRepository = DoctorRepository(hiveService: hiveService);
    _hospitalRepository = HospitalRepository(hiveService: hiveService);
    _expenseRepository = ExpenseRepository(hiveService: hiveService);
    _medicineRepository = MedicineRepository(
      hiveService: hiveService,
      syncService: syncService,
    );
  }

  // --- Profile-scoped Vault Confirmation State Delegation ---

  bool isNoMedicinesConfirmed(String profileId) =>
      _confirmationManager.isNoMedicinesConfirmed(profileId);

  Future<void> setNoMedicinesConfirmed(String profileId, bool confirmed) =>
      _confirmationManager.setNoMedicinesConfirmed(profileId, confirmed);

  bool isNoConsultationsConfirmed(String profileId) =>
      _confirmationManager.isNoConsultationsConfirmed(profileId);

  Future<void> setNoConsultationsConfirmed(String profileId, bool confirmed) =>
      _confirmationManager.setNoConsultationsConfirmed(profileId, confirmed);

  bool isNoReportsConfirmed(String profileId) =>
      _confirmationManager.isNoReportsConfirmed(profileId);

  Future<void> setNoReportsConfirmed(String profileId, bool confirmed) =>
      _confirmationManager.setNoReportsConfirmed(profileId, confirmed);

  bool isNoAllergiesConfirmed(String profileId) =>
      _confirmationManager.isNoAllergiesConfirmed(profileId);

  Future<void> setNoAllergiesConfirmed(String profileId, bool confirmed) =>
      _confirmationManager.setNoAllergiesConfirmed(profileId, confirmed);

  bool isNoChronicConditionsConfirmed(String profileId) =>
      _confirmationManager.isNoChronicConditionsConfirmed(profileId);

  Future<void> setNoChronicConditionsConfirmed(
    String profileId,
    bool confirmed,
  ) => _confirmationManager.setNoChronicConditionsConfirmed(
    profileId,
    confirmed,
  );

  /// Checks whether a given [date] falls within [startDate] and [endDate] inclusively.
  static bool isDateInRange(
    DateTime date,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate != null && date.isBefore(startDate)) return false;
    if (endDate != null && date.isAfter(endDate)) return false;
    return true;
  }

  // --- Aggregate Summary & Health Vault Calculation ---

  Future<InsightsSummaryModel> getInsightsSummary({
    required ProfileModel profile,
    required InsightsTimeRange timeRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
  }) async {
    final profileId = profile.profileId;
    final profileName = profile.fullName;

    DateTime? filterStart;
    DateTime? filterEnd;

    if (timeRange == InsightsTimeRange.custom &&
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
    } else if (timeRange != InsightsTimeRange.allTime &&
        timeRange != InsightsTimeRange.custom) {
      final now = DateTime.now();
      filterStart = DateTime(now.year, now.month, now.day - timeRange.days);
      filterEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    }

    // Fetch profile-scoped raw records & typed models
    final measurementModels = await _measurementRepository.getMeasurementModels(
      profileId,
    );
    final rawMeasurements = measurementModels.map((m) => m.toMap()).toList();

    final consultationModels = await _consultationRepository
        .getConsultationModels(profileId);
    final rawConsultations = consultationModels.map((c) => c.toJson()).toList();

    final appointmentModels = await _appointmentRepository.getAppointmentModels(
      profileId,
    );

    final reportModels = await _reportRepository.getReportsForProfile(
      profileId,
    );
    final rawReports = reportModels.map((r) => r.toJson()).toList();

    final doctorModels = await _doctorRepository.getDoctorModels(profileId);
    final rawDoctors = doctorModels.map((d) => d.toJson()).toList();

    final hospitalModels = await _hospitalRepository.getHospitalModels(
      profileId,
    );
    final rawHospitals = hospitalModels.map((h) => h.toJson()).toList();

    final rawExpenses = await _expenseRepository.getExpenses(profileId);
    final rawMedicines = await _medicineRepository.getMedicines(profileId);

    // 1. Process Vitals Overview & Detailed Vitals Trends
    final vitalsOverview = ActivitySummaryBuilder.buildVitalsOverview(
      rawMeasurements,
    );
    final filteredMeasurements = (filterStart != null || filterEnd != null)
        ? measurementModels
              .where((m) => isDateInRange(m.recordedAt, filterStart, filterEnd))
              .toList()
        : measurementModels;
    final vitalTrends = ActivitySummaryBuilder.buildVitalTrends(
      filteredMeasurements.isNotEmpty
          ? filteredMeasurements
          : measurementModels,
    );

    // 2. Compute Health Vault Completeness Score
    final vaultScore = HealthVaultScoreCalculator.computeHealthVaultScore(
      profile: profile,
      measurements: rawMeasurements,
      medicines: rawMedicines,
      consultations: rawConsultations,
      reports: rawReports,
    );

    final healthScore = vaultScore.totalScore;
    final summary =
        'Your health record is $healthScore% complete. Keep your health information up to date.';

    // 3. Generate Recommendations for "See What's Missing"
    final recommendations = HealthVaultScoreCalculator.generateRecommendations(
      profileId: profileId,
      profileName: profileName,
      vaultScore: vaultScore,
      measurements: rawMeasurements,
      consultations: rawConsultations,
    );

    // 4. Detailed Feature Summaries
    final consultationSummary = ActivitySummaryBuilder.buildConsultationSummary(
      consultationModels,
    );
    final appointmentSummary = ActivitySummaryBuilder.buildAppointmentSummary(
      appointmentModels,
    );
    final medicineSummary = ActivitySummaryBuilder.buildMedicineSummary(
      rawMedicines,
    );
    final reportSummary = ActivitySummaryBuilder.buildReportSummary(
      reportModels,
    );
    final careDirectorySummary =
        ActivitySummaryBuilder.buildCareDirectorySummary(
          doctorModels,
          hospitalModels,
        );

    // 5. Compute Healthcare Expenses from real records
    final expenseAnalytics = ExpenseAnalyticsCalculator.computeExpenseAnalytics(
      rawExpenses: (filterStart != null || filterEnd != null)
          ? rawExpenses.where((e) {
              final d = DateTime.tryParse(e['date']?.toString() ?? '');
              return d == null || isDateInRange(d, filterStart, filterEnd);
            }).toList()
          : rawExpenses,
      consultations: (filterStart != null || filterEnd != null)
          ? consultationModels
                .where(
                  (c) => isDateInRange(c.visitDate, filterStart, filterEnd),
                )
                .toList()
          : consultationModels,
      appointments: (filterStart != null || filterEnd != null)
          ? appointmentModels
                .where((a) => isDateInRange(a.date, filterStart, filterEnd))
                .toList()
          : appointmentModels,
      reports: (filterStart != null || filterEnd != null)
          ? reportModels
                .where((r) => isDateInRange(r.date, filterStart, filterEnd))
                .toList()
          : reportModels,
      rawHospitals: rawHospitals,
    );

    return InsightsSummaryModel(
      profileId: profileId,
      profileName: profileName,
      timeRange: timeRange,
      healthScore: healthScore,
      vaultScore: vaultScore,
      healthSummary: summary,
      overviewConsultationsCount: rawConsultations.length,
      overviewUpcomingAppointmentsCount: appointmentSummary.upcomingCount,
      overviewDoctorsSeenCount: rawDoctors.length,
      vitalsOverview: vitalsOverview,
      vitalTrends: vitalTrends,
      totalConsultations: rawConsultations.length,
      totalAppointments: appointmentModels.length,
      totalReports: rawReports.length,
      totalVitalsLogged: rawMeasurements.length,
      consultationSummary: consultationSummary,
      appointmentSummary: appointmentSummary,
      medicineSummary: medicineSummary,
      reportSummary: reportSummary,
      careDirectorySummary: careDirectorySummary,
      totalExpenses: expenseAnalytics.totalExpenses,
      recordsWithCostCount: expenseAnalytics.recordsWithCostCount,
      monthlyExpenses: expenseAnalytics.monthlyExpenses,
      expensesByCategory: expenseAnalytics.expensesByCategory,
      expensesByHospital: expenseAnalytics.expensesByHospital,
      expensesByDoctor: expenseAnalytics.expensesByDoctor,
      recommendations: recommendations,
    );
  }
}
