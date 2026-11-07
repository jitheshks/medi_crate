import '../../../../core/constants/app_icons.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../consultations/data/models/consultation_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../reports/data/models/report_model.dart';
import '../../../vitals/data/models/measurement_model.dart';
import '../models/insights_summary_model.dart';

/// Aggregates activity data into strongly-typed summary models for insights.
class ActivitySummaryBuilder {
  static List<VitalOverviewItem> buildVitalsOverview(
    List<Map<String, dynamic>> measurements,
  ) {
    Map<String, dynamic>? bp;
    Map<String, dynamic>? hr;
    Map<String, dynamic>? spo2;
    Map<String, dynamic>? weight;

    for (final m in measurements) {
      final type = m['type']?.toString().toLowerCase();
      if (type == 'blood_pressure') bp = m;
      if (type == 'heart_rate') hr = m;
      if (type == 'spo2' || type == 'oximeter') spo2 = m;
      if (type == 'weight') weight = m;
    }

    return [
      VitalOverviewItem(
        title: 'Blood Pressure',
        value: bp?['value']?.toString() ?? '--',
        unit: bp != null ? (bp['unit']?.toString() ?? 'mmHg') : '',
        status: bp != null ? (bp['status']?.toString() ?? 'NORMAL') : 'NO DATA',
        icon: AppIcons.activity,
        recordedAt: bp?['recorded_at'] != null
            ? DateTime.tryParse(bp!['recorded_at'].toString())
            : (bp?['date'] != null
                  ? DateTime.tryParse(bp!['date'].toString())
                  : null),
      ),
      VitalOverviewItem(
        title: 'Heart Rate',
        value: hr?['value']?.toString() ?? '--',
        unit: hr != null ? (hr['unit']?.toString() ?? 'bpm') : '',
        status: hr != null ? (hr['status']?.toString() ?? 'NORMAL') : 'NO DATA',
        icon: AppIcons.heart,
        recordedAt: hr?['recorded_at'] != null
            ? DateTime.tryParse(hr!['recorded_at'].toString())
            : (hr?['date'] != null
                  ? DateTime.tryParse(hr!['date'].toString())
                  : null),
      ),
      VitalOverviewItem(
        title: 'SpO₂',
        value: spo2?['value']?.toString() ?? '--',
        unit: spo2 != null ? (spo2['unit']?.toString() ?? '%') : '',
        status: spo2 != null
            ? (spo2['status']?.toString() ?? 'OPTIMAL')
            : 'NO DATA',
        icon: AppIcons.shield,
        recordedAt: spo2?['recorded_at'] != null
            ? DateTime.tryParse(spo2!['recorded_at'].toString())
            : (spo2?['date'] != null
                  ? DateTime.tryParse(spo2!['date'].toString())
                  : null),
      ),
      VitalOverviewItem(
        title: 'Weight',
        value: weight?['value']?.toString() ?? '--',
        unit: weight != null ? (weight['unit']?.toString() ?? 'kg') : '',
        status: weight != null
            ? (weight['status']?.toString() ?? 'STABLE')
            : 'NO DATA',
        icon: AppIcons.activity,
        recordedAt: weight?['recorded_at'] != null
            ? DateTime.tryParse(weight!['recorded_at'].toString())
            : (weight?['date'] != null
                  ? DateTime.tryParse(weight!['date'].toString())
                  : null),
      ),
    ];
  }

  static List<VitalTrendSeries> buildVitalTrends(
    List<MeasurementModel> models,
  ) {
    final supportedTypes = [
      MeasurementTypes.bloodPressure,
      MeasurementTypes.bloodGlucose,
      MeasurementTypes.heartRate,
      MeasurementTypes.spo2,
      MeasurementTypes.temperature,
      MeasurementTypes.bmi,
      MeasurementTypes.respiratoryRate,
    ];

    final seriesList = <VitalTrendSeries>[];

    for (final type in supportedTypes) {
      final matching = models.where((m) {
        final lower = m.type.toLowerCase();
        if (type == MeasurementTypes.bloodGlucose) {
          return lower == 'blood_glucose' || lower == 'glucose';
        }
        return lower == type;
      }).toList();

      final title = MeasurementTypes.getDisplayName(type);

      if (matching.isEmpty) continue;

      matching.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

      final latest = matching.last;
      final unit = latest.unit.isNotEmpty
          ? latest.unit
          : MeasurementTypes.getDefaultUnit(type);

      seriesList.add(
        VitalTrendSeries(
          type: type,
          title: title,
          unit: unit,
          latestValue: latest.value,
          latestStatus: latest.status,
          latestRecordedAt: latest.recordedAt,
          readings: matching,
        ),
      );
    }

    return seriesList;
  }

  static ConsultationSummaryData buildConsultationSummary(
    List<ConsultationModel> consultations,
  ) {
    if (consultations.isEmpty) {
      return const ConsultationSummaryData(totalCount: 0);
    }

    ConsultationModel? latest;
    if (consultations.isNotEmpty) {
      latest = consultations.first;
    }

    String? topDoctor;
    final docMap = <String, int>{};
    for (final c in consultations) {
      if (c.doctorName.trim().isNotEmpty) {
        docMap[c.doctorName] = (docMap[c.doctorName] ?? 0) + 1;
      }
    }
    if (docMap.isNotEmpty) {
      final sorted = docMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (sorted.first.value >= 2) {
        topDoctor = sorted.first.key;
      }
    }

    return ConsultationSummaryData(
      totalCount: consultations.length,
      latestConsultation: latest,
      topDoctorName: topDoctor,
    );
  }

  static AppointmentSummaryData buildAppointmentSummary(
    List<AppointmentModel> appointments,
  ) {
    if (appointments.isEmpty) {
      return const AppointmentSummaryData(
        upcomingCount: 0,
        completedCount: 0,
        cancelledCount: 0,
        missedCount: 0,
      );
    }

    int upcoming = 0;
    int completed = 0;
    int cancelled = 0;
    int missed = 0;
    AppointmentModel? nextUpcoming;
    for (final a in appointments) {
      if (a.isUpcoming) {
        upcoming++;
        if (nextUpcoming == null || a.date.isBefore(nextUpcoming.date)) {
          nextUpcoming = a;
        }
      } else if (a.isCompleted) {
        completed++;
      } else if (a.isCancelled) {
        cancelled++;
      } else if (a.isMissed) {
        missed++;
      }
    }

    return AppointmentSummaryData(
      upcomingCount: upcoming,
      completedCount: completed,
      cancelledCount: cancelled,
      missedCount: missed,
      nextUpcomingAppointment: nextUpcoming,
    );
  }

  static MedicineSummaryData buildMedicineSummary(
    List<Map<String, dynamic>> medicines,
  ) {
    if (medicines.isEmpty) {
      return const MedicineSummaryData(activeCount: 0, completedCount: 0);
    }

    int active = 0;
    int completed = 0;
    Map<String, dynamic>? latest;

    for (final m in medicines) {
      final isActive = m['is_active'] as bool? ?? true;
      if (isActive) {
        active++;
      } else {
        completed++;
      }
    }

    if (medicines.isNotEmpty) {
      latest = medicines.first;
    }

    return MedicineSummaryData(
      activeCount: active,
      completedCount: completed,
      latestMedicine: latest,
    );
  }

  static ReportSummaryData buildReportSummary(List<ReportModel> reports) {
    if (reports.isEmpty) {
      return const ReportSummaryData(totalCount: 0, categoryCounts: {});
    }

    final categoryMap = <String, int>{};
    for (final r in reports) {
      final cat = r.category.trim().isNotEmpty ? r.category : 'General';
      categoryMap[cat] = (categoryMap[cat] ?? 0) + 1;
    }

    return ReportSummaryData(
      totalCount: reports.length,
      categoryCounts: categoryMap,
      latestReport: reports.isNotEmpty ? reports.first : null,
    );
  }

  static CareDirectorySummaryData buildCareDirectorySummary(
    List<DoctorModel> doctors,
    List<HospitalModel> hospitals,
  ) {
    return CareDirectorySummaryData(
      doctorsCount: doctors.length,
      hospitalsCount: hospitals.length,
      mostRecentlyConsultedDoctor: doctors.isNotEmpty
          ? doctors.first.name
          : null,
    );
  }
}
