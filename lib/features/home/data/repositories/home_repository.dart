import '../../../../core/storage/hive_service.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../../../consultations/data/models/consultation_model.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../reports/data/models/report_model.dart';
import '../../../vitals/data/models/measurement_model.dart';
import '../models/home_summary_model.dart';

/// HomeRepository provides aggregated health metrics and overview models scoped to an active Profile.
/// Aggregates all domain metrics in a single traversal over Hive userBox keys.
class HomeRepository {
  final HiveService hiveService;

  HomeRepository({required this.hiveService});

  Future<HomeSummaryModel> getHomeSummary(ProfileModel profile) async {
    final pid = profile.profileId;
    final box = hiveService.userBox;

    int doctorCount = 0;
    int hospitalCount = 0;
    int consultationCount = 0;
    int appointmentCount = 0;
    int upcomingAppointmentsCount = 0;
    int reportCount = 0;
    int medicineCount = 0;

    ConsultationModel? recentConsultation;
    ConsultationModel? nextFollowUp;
    AppointmentModel? nextAppointment;
    ReportModel? recentReport;
    Map<String, dynamic>? firstActiveMedicine;
    Map<String, dynamic>? firstMedicine;
    final profileMeasurements = <MeasurementModel>[];

    // Single-pass traversal over userBox keys
    for (final keyObj in box.keys) {
      final key = keyObj.toString();
      final val = box.get(keyObj);
      if (val is! Map) continue;

      final map = Map<String, dynamic>.from(val);
      final rawPid =
          map['profile_id']?.toString() ?? map['profileId']?.toString();
      if (rawPid == null) continue;
      final matches = IdUtils.matchesProfileId(
        rawPid,
        pid,
        profileBox: hiveService.profileBox,
      );
      if (!matches) continue;

      if (key.startsWith('doctor_')) {
        doctorCount++;
      } else if (key.startsWith('hospital_')) {
        hospitalCount++;
      } else if (key.startsWith('consultation_')) {
        consultationCount++;
        try {
          final c = ConsultationModel.fromJson(map);
          if (recentConsultation == null ||
              c.visitDate.isAfter(recentConsultation.visitDate)) {
            recentConsultation = c;
          }
          if (c.isFollowUpRequired &&
              !c.isFollowUpDone &&
              c.followUpDate != null) {
            if (nextFollowUp == null ||
                c.followUpDate!.isBefore(nextFollowUp.followUpDate!)) {
              nextFollowUp = c;
            }
          }
        } catch (_) {}
      } else if (key.startsWith('appointment_')) {
        appointmentCount++;
        try {
          final a = AppointmentModel.fromJson(map);
          if (a.isUpcoming) {
            upcomingAppointmentsCount++;
            if (nextAppointment == null ||
                a.date.isBefore(nextAppointment.date)) {
              nextAppointment = a;
            }
          }
        } catch (_) {}
      } else if (key.startsWith('report_')) {
        reportCount++;
        try {
          final r = ReportModel.fromJson(map);
          if (recentReport == null || r.date.isAfter(recentReport.date)) {
            recentReport = r;
          }
        } catch (_) {}
      } else if (key.startsWith('medicine_')) {
        medicineCount++;
        final isActive =
            map['is_active'] == true ||
            (map['status']?.toString().toLowerCase() == 'active');
        if (isActive) {
          firstActiveMedicine ??= map;
        }
        firstMedicine ??= map;
      } else if (key.startsWith('measurement_')) {
        try {
          profileMeasurements.add(MeasurementModel.fromMap(map));
        } catch (_) {}
      }
    }

    // Process vitals snapshot (up to 4 unique types, newest first)
    profileMeasurements.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final recentVitals = <VitalReadingSummary>[];
    final seenTypes = <String>{};

    for (final m in profileMeasurements) {
      final type = m.type.toLowerCase();
      if (!seenTypes.contains(type) && seenTypes.length < 4) {
        seenTypes.add(type);
        recentVitals.add(
          VitalReadingSummary(
            id: m.id,
            type: m.type,
            title: m.title.isNotEmpty ? m.title : _formatVitalTitle(m.type),
            value: m.value,
            unit: m.unit,
            status: m.status.toUpperCase(),
            recordedAt: m.recordedAt,
          ),
        );
      }
    }

    final currentMedicine = firstActiveMedicine ?? firstMedicine;

    return HomeSummaryModel(
      totalConsultations: consultationCount,
      totalDoctors: doctorCount,
      totalHospitals: hospitalCount,
      totalMedicines: medicineCount,
      totalReports: reportCount,
      totalAppointments: appointmentCount,
      totalVitalsRecorded: profileMeasurements.length,
      recentVitals: recentVitals,
      upcomingAppointmentsCount: upcomingAppointmentsCount,
      nextAppointmentId: nextAppointment?.id,
      nextAppointmentTitle: nextAppointment?.title,
      nextAppointmentDate: nextAppointment?.date,
      nextAppointmentDoctor: nextAppointment?.doctorName,
      upcomingFollowUpTitle:
          (nextFollowUp?.diagnosis != null &&
              nextFollowUp!.diagnosis.isNotEmpty)
          ? nextFollowUp.diagnosis
          : nextFollowUp?.chiefComplaint,
      upcomingFollowUpDate: nextFollowUp?.followUpDate,
      upcomingFollowUpDoctor: nextFollowUp?.doctorName,
      recentConsultationId: recentConsultation?.id,
      recentConsultationDiagnosis:
          (recentConsultation?.diagnosis != null &&
              recentConsultation!.diagnosis.isNotEmpty)
          ? recentConsultation.diagnosis
          : recentConsultation?.chiefComplaint,
      recentConsultationDate: recentConsultation?.visitDate,
      recentConsultationDoctor: recentConsultation?.doctorName,
      currentMedicineId: currentMedicine?['id']?.toString(),
      currentMedicineName:
          currentMedicine?['medication_name']?.toString() ??
          currentMedicine?['medicine_name']?.toString() ??
          currentMedicine?['name']?.toString(),
      currentMedicineTiming:
          currentMedicine?['timing']?.toString() ??
          currentMedicine?['frequency']?.toString(),
      recentReportId: recentReport?.id,
      recentReportTitle: recentReport?.title,
      recentReportDate: recentReport?.date,
      recentReportCategory: recentReport?.category,
      recentReportDoctor: recentReport?.doctorName,
      recentReportHospital: recentReport?.hospitalName,
    );
  }

  String _formatVitalTitle(String type) {
    switch (type.toLowerCase()) {
      case 'blood_pressure':
        return 'Blood Pressure';
      case 'blood_glucose':
      case 'glucose':
        return 'Blood Glucose';
      case 'heart_rate':
        return 'Heart Rate';
      case 'spo2':
        return 'SpO₂';
      case 'temperature':
        return 'Body Temperature';
      case 'weight':
        return 'Weight';
      case 'bmi':
        return 'BMI';
      default:
        return type;
    }
  }
}
