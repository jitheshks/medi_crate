import 'package:flutter/material.dart';
import '../../../../core/storage/hive_service.dart';
import '../../../appointments/data/repositories/appointment_repository.dart';
import '../../../consultations/data/repositories/consultation_repository.dart';
import '../../../doctors/data/repositories/doctor_repository.dart';
import '../../../hospitals/data/repositories/hospital_repository.dart';
import '../../../medicines/data/repositories/medicine_repository.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../reports/data/repositories/report_repository.dart';
import '../../../vitals/data/repositories/measurement_repository.dart';
import '../models/doctor_summary_model.dart';

/// DoctorSummaryRepository aggregates profile-scoped clinical records while
/// strictly stripping out financial and fee information.
class DoctorSummaryRepository {
  final HiveService hiveService;
  late final ConsultationRepository _consultationRepository;
  late final MedicineRepository _medicineRepository;
  late final MeasurementRepository _measurementRepository;
  late final ReportRepository _reportRepository;
  late final AppointmentRepository _appointmentRepository;
  late final DoctorRepository _doctorRepository;
  late final HospitalRepository _hospitalRepository;

  DoctorSummaryRepository({required this.hiveService}) {
    _consultationRepository = ConsultationRepository(hiveService: hiveService);
    _medicineRepository = MedicineRepository(hiveService: hiveService);
    _measurementRepository = MeasurementRepository(hiveService: hiveService);
    _reportRepository = ReportRepository(hiveService: hiveService);
    _appointmentRepository = AppointmentRepository(hiveService: hiveService);
    _doctorRepository = DoctorRepository(hiveService: hiveService);
    _hospitalRepository = HospitalRepository(hiveService: hiveService);
  }

  Future<DoctorSummaryModel> getDoctorSummary(
    ProfileModel profile, {
    DateTimeRange? dateRange,
    String? dateRangeLabel,
  }) async {
    final profileId = profile.profileId;

    final rawConsultations = await _consultationRepository.getConsultations(
      profileId,
    );
    final rawMedicines = await _medicineRepository.getMedicines(profileId);
    final rawVitals = await _measurementRepository.getMeasurements(profileId);
    final rawReports = await _reportRepository.getReportsForProfile(profileId);
    final rawAppointments = await _appointmentRepository.getAppointments(
      profileId,
    );
    final rawDoctors = await _doctorRepository.getDoctors(profileId);
    final rawHospitals = await _hospitalRepository.getHospitals(profileId);

    // Explicitly exclude financial fields (consultation_fee, expense, payment status, monetary amounts)
    final sanitizedConsultations = rawConsultations.map((c) {
      final map = Map<String, dynamic>.from(c);
      map.remove('consultation_fee');
      map.remove('fee');
      map.remove('expense');
      map.remove('amount');
      map.remove('currency');
      map.remove('cost');
      return map;
    }).toList();

    final sanitizedMedicines = rawMedicines.map((m) {
      final map = Map<String, dynamic>.from(m);
      map.remove('cost');
      map.remove('price');
      map.remove('amount');
      map.remove('currency');
      map.remove('expense');
      return map;
    }).toList();

    final sanitizedVitals = rawVitals.map((v) {
      final map = Map<String, dynamic>.from(v);
      map.remove('cost');
      map.remove('expense');
      map.remove('amount');
      map.remove('fee');
      return map;
    }).toList();

    final sanitizedReports = rawReports.map((r) {
      final map = r.toJson();
      map.remove('expense');
      map.remove('amount');
      map.remove('cost');
      map.remove('fee');
      map.remove('currency');
      return map;
    }).toList();

    final sanitizedAppointments = rawAppointments.map((a) {
      final map = Map<String, dynamic>.from(a);
      map.remove('cost');
      map.remove('currency');
      map.remove('expense');
      map.remove('amount');
      map.remove('fee');
      return map;
    }).toList();

    final relevantDoctors = _extractAssociatedDoctors(
      directoryDoctors: rawDoctors,
      consultations: sanitizedConsultations,
      appointments: sanitizedAppointments,
    );

    final relevantHospitals = _extractAssociatedHospitals(
      directoryHospitals: rawHospitals,
      consultations: sanitizedConsultations,
      appointments: sanitizedAppointments,
    );

    final baseModel = DoctorSummaryModel(
      profile: profile,
      consultations: sanitizedConsultations,
      medicines: sanitizedMedicines,
      vitals: sanitizedVitals,
      reports: sanitizedReports,
      appointments: sanitizedAppointments,
      doctors: relevantDoctors,
      hospitals: relevantHospitals,
    );

    if (dateRange == null) {
      return baseModel.copyWith(dateRangeLabel: dateRangeLabel);
    }

    return filterSummaryByDate(
      baseModel,
      dateRange: dateRange,
      dateRangeLabel: dateRangeLabel,
      directoryDoctors: rawDoctors,
      directoryHospitals: rawHospitals,
    );
  }

  /// Filters an in-memory DoctorSummaryModel by date range without touching storage
  DoctorSummaryModel filterSummaryByDate(
    DoctorSummaryModel summary, {
    DateTimeRange? dateRange,
    String? dateRangeLabel,
    List<Map<String, dynamic>>? directoryDoctors,
    List<Map<String, dynamic>>? directoryHospitals,
  }) {
    if (dateRange == null) {
      return summary.copyWith(dateRange: null, dateRangeLabel: dateRangeLabel);
    }

    final filteredConsultations = _filterByDate(
      summary.consultations,
      dateKeys: const ['visit_date', 'date', 'created_at'],
      dateRange: dateRange,
    );

    final filteredMedicines = _filterMedicinesByDate(
      summary.medicines,
      dateRange: dateRange,
    );

    final filteredVitals = _filterByDate(
      summary.vitals,
      dateKeys: const ['recorded_at', 'date', 'created_at'],
      dateRange: dateRange,
    );

    final filteredReports = _filterByDate(
      summary.reports,
      dateKeys: const ['date', 'report_date', 'created_at'],
      dateRange: dateRange,
    );

    final filteredAppointments = _filterByDate(
      summary.appointments,
      dateKeys: const ['date', 'appointment_date', 'created_at'],
      dateRange: dateRange,
    );

    final filteredDoctors = directoryDoctors != null
        ? _extractAssociatedDoctors(
            directoryDoctors: directoryDoctors,
            consultations: filteredConsultations,
            appointments: filteredAppointments,
          )
        : summary.doctors;

    final filteredHospitals = directoryHospitals != null
        ? _extractAssociatedHospitals(
            directoryHospitals: directoryHospitals,
            consultations: filteredConsultations,
            appointments: filteredAppointments,
          )
        : summary.hospitals;

    return summary.copyWith(
      consultations: filteredConsultations,
      medicines: filteredMedicines,
      vitals: filteredVitals,
      reports: filteredReports,
      appointments: filteredAppointments,
      doctors: filteredDoctors,
      hospitals: filteredHospitals,
      dateRange: dateRange,
      dateRangeLabel: dateRangeLabel,
    );
  }

  List<Map<String, dynamic>> _extractAssociatedDoctors({
    required List<Map<String, dynamic>> directoryDoctors,
    required List<Map<String, dynamic>> consultations,
    required List<Map<String, dynamic>> appointments,
  }) {
    final Set<String> associatedDoctorIds = {};
    final Set<String> associatedDoctorNames = {};

    for (final c in consultations) {
      final docId = (c['doctor_id'] ?? c['doctorId'])?.toString();
      if (docId != null && docId.isNotEmpty) associatedDoctorIds.add(docId);
      final docName = (c['doctor_name'] ?? c['doctorName'] ?? c['doctor'])
          ?.toString()
          .trim();
      if (docName != null && docName.isNotEmpty) {
        associatedDoctorNames.add(docName.toLowerCase());
      }
    }

    for (final a in appointments) {
      final docId = (a['doctor_id'] ?? a['doctorId'])?.toString();
      if (docId != null && docId.isNotEmpty) associatedDoctorIds.add(docId);
      final docName = (a['doctor_name'] ?? a['doctorName'] ?? a['doctor'])
          ?.toString()
          .trim();
      if (docName != null && docName.isNotEmpty) {
        associatedDoctorNames.add(docName.toLowerCase());
      }
    }

    final List<Map<String, dynamic>> matched = [];
    final Set<String> addedKeys = {};

    for (final doc in directoryDoctors) {
      final id = (doc['id'] ?? doc['doctor_id'] ?? doc['uuid'])?.toString();
      final name = (doc['name'] ?? doc['doctor_name'])
          ?.toString()
          .trim()
          .toLowerCase();
      if ((id != null && associatedDoctorIds.contains(id)) ||
          (name != null && associatedDoctorNames.contains(name))) {
        final key = id ?? name ?? '';
        if (key.isNotEmpty && !addedKeys.contains(key)) {
          addedKeys.add(key);
          matched.add(doc);
        }
      }
    }

    for (final name in associatedDoctorNames) {
      if (!matched.any(
        (d) =>
            (d['name'] ?? d['doctor_name'])?.toString().trim().toLowerCase() ==
            name,
      )) {
        final matchDoc = consultations.firstWhere(
          (c) =>
              (c['doctor_name'] ?? c['doctorName'] ?? c['doctor'])
                  ?.toString()
                  .trim()
                  .toLowerCase() ==
              name,
          orElse: () => appointments.firstWhere(
            (a) =>
                (a['doctor_name'] ?? a['doctorName'] ?? a['doctor'])
                    ?.toString()
                    .trim()
                    .toLowerCase() ==
                name,
            orElse: () => {'doctor_name': name},
          ),
        );
        matched.add({
          'id': 'doc_assoc_${name.hashCode}',
          'name': matchDoc['doctor_name'] ?? matchDoc['doctor'] ?? name,
          'specialty':
              matchDoc['doctor_specialty'] ??
              matchDoc['specialty'] ??
              'Attending Physician',
        });
      }
    }

    return matched;
  }

  List<Map<String, dynamic>> _extractAssociatedHospitals({
    required List<Map<String, dynamic>> directoryHospitals,
    required List<Map<String, dynamic>> consultations,
    required List<Map<String, dynamic>> appointments,
  }) {
    final Set<String> associatedHospitalIds = {};
    final Set<String> associatedHospitalNames = {};

    for (final c in consultations) {
      final hospId = (c['hospital_id'] ?? c['hospitalId'])?.toString();
      if (hospId != null && hospId.isNotEmpty) {
        associatedHospitalIds.add(hospId);
      }
      final hospName =
          (c['hospital_name'] ?? c['hospitalName'] ?? c['hospital'])
              ?.toString()
              .trim();
      if (hospName != null && hospName.isNotEmpty) {
        associatedHospitalNames.add(hospName.toLowerCase());
      }
    }

    for (final a in appointments) {
      final hospId = (a['hospital_id'] ?? a['hospitalId'])?.toString();
      if (hospId != null && hospId.isNotEmpty) {
        associatedHospitalIds.add(hospId);
      }
      final hospName =
          (a['hospital_name'] ?? a['hospitalName'] ?? a['hospital'])
              ?.toString()
              .trim();
      if (hospName != null && hospName.isNotEmpty) {
        associatedHospitalNames.add(hospName.toLowerCase());
      }
    }

    final List<Map<String, dynamic>> matched = [];
    final Set<String> addedKeys = {};

    for (final hosp in directoryHospitals) {
      final id = (hosp['id'] ?? hosp['hospital_id'] ?? hosp['uuid'])
          ?.toString();
      final name = (hosp['name'] ?? hosp['hospital_name'])
          ?.toString()
          .trim()
          .toLowerCase();
      if ((id != null && associatedHospitalIds.contains(id)) ||
          (name != null && associatedHospitalNames.contains(name))) {
        final key = id ?? name ?? '';
        if (key.isNotEmpty && !addedKeys.contains(key)) {
          addedKeys.add(key);
          matched.add(hosp);
        }
      }
    }

    for (final name in associatedHospitalNames) {
      if (!matched.any(
        (h) =>
            (h['name'] ?? h['hospital_name'])
                ?.toString()
                .trim()
                .toLowerCase() ==
            name,
      )) {
        final matchHosp = consultations.firstWhere(
          (c) =>
              (c['hospital_name'] ?? c['hospitalName'] ?? c['hospital'])
                  ?.toString()
                  .trim()
                  .toLowerCase() ==
              name,
          orElse: () => appointments.firstWhere(
            (a) =>
                (a['hospital_name'] ?? a['hospitalName'] ?? a['hospital'])
                    ?.toString()
                    .trim()
                    .toLowerCase() ==
                name,
            orElse: () => {'hospital_name': name},
          ),
        );
        matched.add({
          'id': 'hosp_assoc_${name.hashCode}',
          'name': matchHosp['hospital_name'] ?? matchHosp['hospital'] ?? name,
          'location':
              matchHosp['location'] ??
              matchHosp['address'] ??
              'Associated Facility',
        });
      }
    }

    return matched;
  }

  List<Map<String, dynamic>> _filterByDate(
    List<Map<String, dynamic>> items, {
    required List<String> dateKeys,
    DateTimeRange? dateRange,
  }) {
    if (dateRange == null) return items;

    final start = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
    );
    final end = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      23,
      59,
      59,
      999,
    );

    return items.where((item) {
      DateTime? itemDate;
      for (final key in dateKeys) {
        final val = item[key];
        if (val != null) {
          if (val is DateTime) {
            itemDate = val;
            break;
          } else if (val is String) {
            itemDate = DateTime.tryParse(val);
            if (itemDate != null) break;
          }
        }
      }

      // In a bounded date range, records lacking a valid date must be excluded
      if (itemDate == null) return false;

      return !itemDate.isBefore(start) && !itemDate.isAfter(end);
    }).toList();
  }

  List<Map<String, dynamic>> _filterMedicinesByDate(
    List<Map<String, dynamic>> medicines, {
    DateTimeRange? dateRange,
  }) {
    if (dateRange == null) return medicines;

    final start = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
    );
    final end = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
      23,
      59,
      59,
      999,
    );

    return medicines.where((med) {
      DateTime? startDate;
      DateTime? endDate;

      final startVal = med['start_date'] ?? med['startDate'];
      if (startVal is DateTime) {
        startDate = startVal;
      } else if (startVal is String) {
        startDate = DateTime.tryParse(startVal);
      }

      final endVal = med['end_date'] ?? med['endDate'];
      if (endVal is DateTime) {
        endDate = endVal;
      } else if (endVal is String) {
        endDate = DateTime.tryParse(endVal);
      }

      // If medicine has neither start_date nor end_date, check fallback date fields
      if (startDate == null && endDate == null) {
        final fallbackVal =
            med['created_at'] ?? med['createdAt'] ?? med['date'];
        DateTime? fallbackDate;
        if (fallbackVal is DateTime) {
          fallbackDate = fallbackVal;
        } else if (fallbackVal is String) {
          fallbackDate = DateTime.tryParse(fallbackVal);
        }

        if (fallbackDate == null) {
          // Completely undated medicine must be excluded in bounded date ranges
          return false;
        }

        return !fallbackDate.isBefore(start) && !fallbackDate.isAfter(end);
      }

      // If start date is after the range end, medicine had not started yet
      if (startDate != null && startDate.isAfter(end)) {
        return false;
      }

      // If end date is before the range start, medicine was already stopped
      if (endDate != null && endDate.isBefore(start)) {
        return false;
      }

      return true;
    }).toList();
  }
}
