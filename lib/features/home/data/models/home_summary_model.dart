/// VitalReadingSummary represents a snapshot of a single health measurement reading.
class VitalReadingSummary {
  final String id;
  final String type; // "blood_pressure", "heart_rate", "spo2", "weight", etc.
  final String title;
  final String value;
  final String unit;
  final String status; // "NORMAL", "ELEVATED", "LOW"
  final DateTime recordedAt;

  VitalReadingSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.recordedAt,
  });
}

/// HomeSummaryModel aggregates overview stats and section previews.
class HomeSummaryModel {
  final int totalConsultations;
  final int totalDoctors;
  final int totalHospitals;
  final int totalMedicines;
  final int totalReports;
  final int totalAppointments;
  final int totalVitalsRecorded;
  final List<VitalReadingSummary> recentVitals;
  final int upcomingAppointmentsCount;
  final String? nextAppointmentId;
  final String? nextAppointmentTitle;
  final DateTime? nextAppointmentDate;
  final String? nextAppointmentDoctor;
  final String? upcomingFollowUpTitle;
  final DateTime? upcomingFollowUpDate;
  final String? upcomingFollowUpDoctor;
  final String? recentConsultationId;
  final String? recentConsultationDiagnosis;
  final DateTime? recentConsultationDate;
  final String? recentConsultationDoctor;
  final String? currentMedicineId;
  final String? currentMedicineName;
  final String? currentMedicineTiming;
  final String? recentReportId;
  final String? recentReportTitle;
  final DateTime? recentReportDate;
  final String? recentReportCategory;
  final String? recentReportDoctor;
  final String? recentReportHospital;

  HomeSummaryModel({
    required this.totalConsultations,
    required this.totalDoctors,
    required this.totalHospitals,
    required this.totalMedicines,
    required this.totalReports,
    required this.recentVitals,
    this.totalAppointments = 0,
    this.totalVitalsRecorded = 0,
    this.upcomingAppointmentsCount = 0,
    this.nextAppointmentId,
    this.nextAppointmentTitle,
    this.nextAppointmentDate,
    this.nextAppointmentDoctor,
    this.upcomingFollowUpTitle,
    this.upcomingFollowUpDate,
    this.upcomingFollowUpDoctor,
    this.recentConsultationId,
    this.recentConsultationDiagnosis,
    this.recentConsultationDate,
    this.recentConsultationDoctor,
    this.currentMedicineId,
    this.currentMedicineName,
    this.currentMedicineTiming,
    this.recentReportId,
    this.recentReportTitle,
    this.recentReportDate,
    this.recentReportCategory,
    this.recentReportDoctor,
    this.recentReportHospital,
  });

  /// Total supported clinical records (consultations, appointments, doctors,
  /// hospitals, medicines, reports, vitals) held locally for the active
  /// profile. Mirrors exactly the record types/prefixes Home itself counts,
  /// so this and the on-screen dashboard counts can never disagree.
  int get totalVaultRecords =>
      totalConsultations +
      totalAppointments +
      totalDoctors +
      totalHospitals +
      totalMedicines +
      totalReports +
      totalVitalsRecorded;

  factory HomeSummaryModel.initial() {
    return HomeSummaryModel(
      totalConsultations: 0,
      totalDoctors: 0,
      totalHospitals: 0,
      totalMedicines: 0,
      totalReports: 0,
      recentVitals: [],
      upcomingAppointmentsCount: 0,
    );
  }
}
