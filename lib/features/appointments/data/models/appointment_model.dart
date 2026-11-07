import '../../../../core/utils/id_utils.dart';

/// AppointmentModel represents a doctor appointment record in MediCrate.
class AppointmentModel {
  final String id;
  final String profileId;
  final String title;
  final String doctorName;
  final String? doctorId;
  final String? doctorSpecialty;
  final String? hospitalName;
  final String? hospitalId;
  final String? departmentId;
  final String? department;
  final DateTime date;
  final bool reminderEnabled;
  final String? notes;
  final double? cost;
  final String currency;
  final String status; // 'upcoming', 'completed', 'cancelled', 'missed'
  final String? clientUuid;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppointmentModel({
    required this.id,
    required this.profileId,
    required this.title,
    required this.doctorName,
    this.doctorId,
    this.doctorSpecialty,
    this.hospitalName,
    this.hospitalId,
    this.departmentId,
    this.department,
    required this.date,
    this.reminderEnabled = true,
    this.notes,
    this.cost,
    this.currency = 'INR',
    this.status = 'upcoming',
    this.clientUuid,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isUpcoming {
    final lower = status.toLowerCase();
    if (lower != 'upcoming' && lower != 'scheduled' && lower != 'confirmed') {
      return false;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(date.year, date.month, date.day);
    return !apptDay.isBefore(today);
  }

  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isMissed => status.toLowerCase() == 'missed';

  AppointmentModel copyWith({
    String? id,
    String? profileId,
    String? title,
    String? doctorName,
    String? doctorId,
    String? doctorSpecialty,
    String? hospitalName,
    String? hospitalId,
    String? departmentId,
    String? department,
    DateTime? date,
    bool? reminderEnabled,
    String? notes,
    double? cost,
    String? currency,
    String? status,
    String? clientUuid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      title: title ?? this.title,
      doctorName: doctorName ?? this.doctorName,
      doctorId: doctorId ?? this.doctorId,
      doctorSpecialty: doctorSpecialty ?? this.doctorSpecialty,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalId: hospitalId ?? this.hospitalId,
      departmentId: departmentId ?? this.departmentId,
      department: department ?? this.department,
      date: date ?? this.date,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      notes: notes ?? this.notes,
      cost: cost ?? this.cost,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      clientUuid: clientUuid ?? this.clientUuid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'title': title,
      'doctor_name': doctorName,
      'doctor_id': doctorId,
      if (doctorSpecialty != null) 'doctor_specialty': doctorSpecialty,
      'hospital_name': hospitalName,
      'hospital_id': hospitalId,
      'department_id': departmentId,
      'department': department,
      'date': date.toIso8601String(),
      'reminder_enabled': reminderEnabled,
      'notes': notes,
      'cost': cost,
      'currency': currency,
      'status': status,
      if (clientUuid != null) 'client_uuid': clientUuid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts to canonical server-compliant JSON for AP2/AP4 endpoints.
  ///
  /// Supports both integer `department_id` and string `department` according to the API contract.
  /// Note: [consultation_id] is NOT part of the Appointment API contract.
  Map<String, dynamic> toServerJson() {
    final serverProfileId =
        IdUtils.toServerIntId(profileId) ?? int.tryParse(profileId);
    final serverDoctorId = IdUtils.toServerIntId(doctorId);
    final serverHospitalId = IdUtils.toServerIntId(hospitalId);
    final serverDepartmentId = IdUtils.toServerIntId(departmentId);

    final payload = <String, dynamic>{
      'profile_id': serverProfileId,
      'title': title,
      'doctor_name': doctorName,
      'date': date.toUtc().toIso8601String(),
      'reminder_enabled': reminderEnabled,
      'status': status.toLowerCase(),
    };

    if (serverDoctorId != null) {
      payload['doctor_id'] = serverDoctorId;
    }
    if (hospitalName != null && hospitalName!.trim().isNotEmpty) {
      payload['hospital_name'] = hospitalName!.trim();
    }
    if (serverHospitalId != null) {
      payload['hospital_id'] = serverHospitalId;
    }
    if (serverDepartmentId != null) {
      payload['department_id'] = serverDepartmentId;
    }
    if (department != null && department!.trim().isNotEmpty) {
      payload['department'] = department!.trim();
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      payload['notes'] = notes!.trim();
    }
    if (cost != null) {
      payload['cost'] = cost;
    }
    if (currency.trim().isNotEmpty) {
      payload['currency'] = currency.trim();
    }
    if (clientUuid != null && clientUuid!.trim().isNotEmpty) {
      payload['client_uuid'] = clientUuid!.trim();
    }

    return payload;
  }

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    DateTime parsedCreated;
    if (json['created_at'] != null) {
      parsedCreated =
          DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    if (json['updated_at'] != null) {
      parsedUpdated =
          DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now();
    } else {
      parsedUpdated = parsedCreated;
    }

    double? parsedCost;
    if (json['cost'] != null) {
      parsedCost = double.tryParse(json['cost'].toString());
    }

    final cUuid =
        json['client_uuid']?.toString() ?? json['clientUuid']?.toString();

    return AppointmentModel(
      id: json['id']?.toString() ?? '',
      profileId: json['profile_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Appointment',
      doctorName: json['doctor_name']?.toString() ?? 'Doctor',
      doctorId: json['doctor_id']?.toString(),
      doctorSpecialty:
          json['doctor_specialty']?.toString() ??
          json['doctorSpecialty']?.toString(),
      hospitalName: json['hospital_name']?.toString(),
      hospitalId: json['hospital_id']?.toString(),
      departmentId: json['department_id']?.toString(),
      department: json['department']?.toString(),
      date: parsedDate,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      notes: json['notes']?.toString(),
      cost: parsedCost,
      currency: json['currency']?.toString() ?? 'INR',
      status: json['status']?.toString() ?? 'upcoming',
      clientUuid: cUuid,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
    );
  }
}
