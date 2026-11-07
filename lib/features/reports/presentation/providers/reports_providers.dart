import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/mutable_state_notifier.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/id_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/models/date_range_selection.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../timeline/presentation/providers/timeline_providers.dart';
import '../../data/datasources/remote/report_remote_data_source.dart';
import '../../data/models/report_model.dart';
import '../../data/repositories/report_repository.dart';

final reportRemoteDataSourceProvider = Provider<ReportRemoteDataSource>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ReportRemoteDataSource(apiClient: apiClient);
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  final remote = ref.watch(reportRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  return ReportRepository(
    hiveService: hive,
    syncService: sync,
    remoteDataSource: remote,
    connectivityService: connectivity,
    onPullMerged: () {
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}
    },
  );
});

/// Search query provider for live filtering of medical reports.
final reportSearchQueryProvider = mutableStateProvider<String>('');

/// Category filter chip provider (e.g. 'ALL', 'LAB TEST', 'IMAGING', etc.).
final reportFilterCategoryProvider = mutableStateProvider<String>('ALL');

/// Date range filter provider for reports.
final reportDateRangeProvider =
    mutableStateProvider<DateRangeSelection?>(null);

/// Sort option provider (e.g., 'NEWEST_FIRST', 'OLDEST_FIRST', 'A_TO_Z', 'Z_TO_A').
final reportSortOptionProvider =
    mutableStateProvider<String>('NEWEST_FIRST');

/// AsyncNotifier managing the medical reports list for active profile with offline-first synchronization.
class ReportsListNotifier extends AsyncNotifier<List<ReportModel>> {
  @override
  Future<List<ReportModel>> build() async {
    ref.watch(clinicalCacheRevisionProvider);
    final activeProfile = ref.watch(activeProfileProvider);
    if (activeProfile == null) return [];

    try {
      final repo = ref.watch(reportRepositoryProvider);
      return await repo.getReportsForProfile(activeProfile.profileId);
    } catch (_) {
      return [];
    }
  }

  Future<void> refreshReports() async {
    state = const AsyncLoading<List<ReportModel>>();
    state = await AsyncValue.guard(() async {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) return [];
      final repo = ref.read(reportRepositoryProvider);
      return await repo.getReportsForProfile(activeProfile.profileId);
    });
  }

  Future<void> refresh() async {
    await refreshReports();
    ref.invalidate(insightsSummaryProvider);
  }

  /// Saves or updates a report and triggers appropriate timeline / storage invalidation.
  Future<ReportModel> saveReport(ReportModel report) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) {
      throw Exception('No active profile selected.');
    }

    final repo = ref.read(reportRepositoryProvider);
    final saved = await repo.saveReport(activeProfile.profileId, report);
    await _invalidateDownstream();
    return saved;
  }

  /// Deletes a report permanently from Hive and disk.
  Future<void> deleteReport(String reportId) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repo = ref.read(reportRepositoryProvider);
    await repo.deleteReport(activeProfile.profileId, reportId);
    await _invalidateDownstream();
  }

  Future<void> _invalidateDownstream() async {
    ref.invalidate(homeSummaryProvider);
    ref.invalidate(insightsSummaryProvider);
    ref.invalidate(timelineEventsNotifierProvider);
    try {
      ref.read(clinicalCacheRevisionProvider.notifier).bump();
    } catch (_) {}
    ref.invalidateSelf();
  }
}

final reportsListNotifierProvider =
    AsyncNotifierProvider<ReportsListNotifier, List<ReportModel>>(
      ReportsListNotifier.new,
    );

/// Provider computing filtered and sorted reports list.
final filteredReportsProvider = Provider<AsyncValue<List<ReportModel>>>((ref) {
  final reportsAsync = ref.watch(reportsListNotifierProvider);
  final query = ref.watch(reportSearchQueryProvider);
  final category = ref.watch(reportFilterCategoryProvider);
  final dateRange = ref.watch(reportDateRangeProvider);
  final sortOption = ref.watch(reportSortOptionProvider);
  final repo = ref.watch(reportRepositoryProvider);

  return reportsAsync.whenData((reports) {
    return repo.filterAndSortReports(
      reports: reports,
      query: query,
      categoryFilter: category,
      dateRange: dateRange,
      sortOption: sortOption,
    );
  });
});

/// Provider computing grouped reports by Month Year for presentation list.
final groupedReportsProvider =
    Provider<AsyncValue<Map<String, List<ReportModel>>>>((ref) {
      final filteredAsync = ref.watch(filteredReportsProvider);
      final repo = ref.watch(reportRepositoryProvider);

      return filteredAsync.whenData((filteredReports) {
        return repo.groupReportsByMonthYear(filteredReports);
      });
    });

/// Provider returning total count of reports for current profile.
final totalReportsCountProvider = Provider<int>((ref) {
  final reportsAsync = ref.watch(reportsListNotifierProvider);
  return reportsAsync.value?.length ?? 0;
});

/// Provider returning count of filtered reports.
final filteredReportsCountProvider = Provider<int>((ref) {
  final filteredAsync = ref.watch(filteredReportsProvider);
  return filteredAsync.value?.length ?? 0;
});

/// State container for detail view of a single report.
class ViewReportState {
  final ReportModel report;
  final String? linkedConsultationTitle;
  final String? linkedConsultationDate;
  final String? linkedConsultationDoctor;

  const ViewReportState({
    required this.report,
    this.linkedConsultationTitle,
    this.linkedConsultationDate,
    this.linkedConsultationDoctor,
  });
}

/// Family provider for loading details of a specific report.
final viewReportProvider = FutureProvider.family<ViewReportState?, String>((
  ref,
  reportId,
) async {
  ref.watch(clinicalCacheRevisionProvider);
  final activeProfile = ref.watch(activeProfileProvider);
  final repo = ref.watch(reportRepositoryProvider);
  final consultRepo = ref.watch(consultationRepositoryProvider);
  if (activeProfile == null) return null;

  final reports = await ref.watch(reportsListNotifierProvider.future);
  final matched = reports
      .where(
        (r) =>
            IdUtils.matches(r.id, reportId) ||
            r.id == reportId ||
            (r.clientUuid != null &&
                r.clientUuid!.isNotEmpty &&
                (r.clientUuid == reportId ||
                    IdUtils.matches(r.clientUuid, reportId))),
      )
      .firstOrNull;

  final ReportModel? report;
  if (matched != null) {
    report = matched;
  } else {
    report = await repo.getReportById(activeProfile.profileId, reportId);
  }

  if (report == null) return null;

  String? consultTitle = report.consultationTitle;
  String? consultDate;
  String? consultDoctor = report.doctorName;

  if (report.consultationId != null &&
      report.consultationId.toString().isNotEmpty) {
    try {
      final consult = await consultRepo.getConsultationById(
        activeProfile.profileId,
        report.consultationId.toString(),
      );
      if (consult != null) {
        consultTitle = consult.diagnosis.isNotEmpty
            ? consult.diagnosis
            : (consult.chiefComplaint.isNotEmpty
                  ? consult.chiefComplaint
                  : consultTitle);
        consultDate = DateFormat('dd MMM yyyy').format(consult.visitDate);
        if (consult.doctorName.isNotEmpty) {
          consultDoctor = consult.doctorName;
        }
      }
    } catch (_) {}
  }

  return ViewReportState(
    report: report,
    linkedConsultationTitle: consultTitle,
    linkedConsultationDate: consultDate,
    linkedConsultationDoctor: consultDoctor,
  );
});
