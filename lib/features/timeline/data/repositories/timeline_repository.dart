import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../appointments/data/repositories/appointment_repository.dart';
import '../../../consultations/data/repositories/consultation_repository.dart';
import '../../../doctors/data/repositories/doctor_repository.dart';
import '../../../expenses/data/repositories/expense_repository.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../../../medicines/data/repositories/medicine_repository.dart';
import '../../../reports/data/repositories/report_repository.dart';
import '../../../vitals/data/repositories/measurement_repository.dart';
import '../mappers/timeline_event_mapper.dart';
import '../models/timeline_event_model.dart';
import '../services/timeline_filter_service.dart';

/// TimelineRepository acts strictly as an aggregation layer over domain feature repositories,
/// converting profile-scoped health records into unified [TimelineEventModel] instances.
class TimelineRepository {
  final HiveService hiveService;
  final SyncService? syncService;

  late final ConsultationRepository _consultationRepository;
  late final AppointmentRepository _appointmentRepository;
  late final MeasurementRepository _measurementRepository;
  late final MedicineRepository _medicineRepository;
  late final ReportRepository _reportRepository;
  late final ExpenseRepository _expenseRepository;
  late final DoctorRepository _doctorRepository;
  late final HospitalRepository _hospitalRepository;

  TimelineRepository({required this.hiveService, this.syncService}) {
    final activeSync =
        syncService ??
        SyncService(
          hiveService: hiveService,
          connectivityService: ConnectivityService(),
        );

    _consultationRepository = ConsultationRepository(
      hiveService: hiveService,
      syncService: activeSync,
    );
    _appointmentRepository = AppointmentRepository(hiveService: hiveService);
    _measurementRepository = MeasurementRepository(hiveService: hiveService);
    _medicineRepository = MedicineRepository(
      hiveService: hiveService,
      syncService: activeSync,
    );
    _reportRepository = ReportRepository(
      hiveService: hiveService,
      syncService: syncService,
    );
    _expenseRepository = ExpenseRepository(hiveService: hiveService);
    _doctorRepository = DoctorRepository(hiveService: hiveService);
    _hospitalRepository = HospitalRepository(hiveService: hiveService);
  }

  /// Aggregates all timeline events for active [profileId].
  Future<List<TimelineEventModel>> getTimelineEvents(String profileId) async {
    final events = <TimelineEventModel>[];

    final rawConsultations = await _consultationRepository.getConsultations(
      profileId,
    );
    for (final c in rawConsultations) {
      events.add(TimelineEventMapper.mapConsultationToEvent(profileId, c));
    }

    final rawAppointments = await _appointmentRepository.getAppointments(
      profileId,
    );
    for (final a in rawAppointments) {
      events.add(TimelineEventMapper.mapAppointmentToEvent(profileId, a));
    }

    final rawMeasurements = await _measurementRepository.getMeasurements(
      profileId,
    );
    for (final m in rawMeasurements) {
      events.add(TimelineEventMapper.mapMeasurementToEvent(profileId, m));
    }

    final rawReports = await _reportRepository.getReportsForProfile(profileId);
    for (final r in rawReports) {
      events.add(TimelineEventMapper.mapReportToEvent(profileId, r));
    }

    final rawMedicines = await _medicineRepository.getMedicines(profileId);
    for (final med in rawMedicines) {
      events.add(TimelineEventMapper.mapMedicineToEvent(profileId, med));
    }

    final rawExpenses = await _expenseRepository.getExpenses(profileId);
    for (final exp in rawExpenses) {
      events.add(TimelineEventMapper.mapExpenseToEvent(profileId, exp));
    }

    final rawDoctors = await _doctorRepository.getDoctors(profileId);
    for (final doc in rawDoctors) {
      events.add(TimelineEventMapper.mapDoctorToEvent(profileId, doc));
    }

    final rawHospitals = await _hospitalRepository.getHospitals(profileId);
    for (final hosp in rawHospitals) {
      events.add(TimelineEventMapper.mapHospitalToEvent(profileId, hosp));
    }

    final seenEventKeys = <String>{};
    final deduplicatedEvents = <TimelineEventModel>[];

    for (final e in events) {
      final target = e.targetId.isNotEmpty ? e.targetId : e.id;
      final key = '${e.type}_$target';
      if (!seenEventKeys.contains(key)) {
        seenEventKeys.add(key);
        deduplicatedEvents.add(e);
      }
    }

    deduplicatedEvents.sort((a, b) {
      if (a.eventDate == null && b.eventDate == null) return 0;
      if (a.eventDate == null) return 1;
      if (b.eventDate == null) return -1;
      return b.eventDate!.compareTo(a.eventDate!);
    });
    return deduplicatedEvents;
  }

  /// Checks whether a given [date] falls within [startDate] and [endDate] inclusively.
  static bool isDateInRange(
    DateTime date,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return TimelineFilterService.isDateInRange(date, startDate, endDate);
  }

  /// Filters and sorts timeline events in memory.
  List<TimelineEventModel> filterAndSortEvents({
    required List<TimelineEventModel> events,
    required String query,
    required String categoryFilter,
    required String dateRange,
    DateTime? customStartDate,
    DateTime? customEndDate,
    required String sortOption,
  }) {
    return TimelineFilterService.filterAndSortEvents(
      events: events,
      query: query,
      categoryFilter: categoryFilter,
      dateRange: dateRange,
      customStartDate: customStartDate,
      customEndDate: customEndDate,
      sortOption: sortOption,
    );
  }

  /// Groups events by Day Header (e.g. "WEDNESDAY 19 AUGUST").
  Map<String, List<TimelineEventModel>> groupEventsByDay(
    List<TimelineEventModel> events,
  ) {
    return TimelineFilterService.groupEventsByDay(events);
  }
}
