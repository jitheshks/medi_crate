import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_icons.dart';
import '../models/timeline_event_model.dart';

class TimelineEventMapper {
  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.isUtc ? raw.toLocal() : raw;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    return parsed != null ? (parsed.isUtc ? parsed.toLocal() : parsed) : null;
  }

  static TimelineEventModel mapConsultationToEvent(
    String profileId,
    Map<String, dynamic> c,
  ) {
    final date = _parseDate(
      c['visit_date'] ?? c['consultation_date'] ?? c['date'] ?? c['created_at'],
    );

    return TimelineEventModel(
      id: 'c_${c['id']}',
      profileId: profileId,
      type: 'consultation',
      title:
          c['diagnosis'] as String? ??
          c['title'] as String? ??
          'Consultation Record',
      summary:
          c['clinical_notes'] as String? ??
          (c['doctor_name'] != null
              ? 'Dr. ${c['doctor_name']}'
              : 'Clinical visit'),
      eventDate: date,
      badgeText: 'CONSULTATION',
      icon: AppIcons.stethoscope,
      color: AppColors.primary,
      targetRoute: '/consultations/${c['id']}',
      targetId: c['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapAppointmentToEvent(
    String profileId,
    Map<String, dynamic> a,
  ) {
    final date = _parseDate(a['date'] ?? a['created_at']);

    return TimelineEventModel(
      id: 'apt_${a['id']}',
      profileId: profileId,
      type: 'appointment',
      title: a['title'] as String? ?? 'Scheduled Appointment',
      summary: a['doctor_name'] != null
          ? '${a['doctor_name']} · ${a['status'] ?? "Scheduled"}'
          : (a['status'] as String? ?? 'Upcoming appointment'),
      eventDate: date,
      badgeText: 'APPOINTMENT',
      icon: AppIcons.calendar,
      color: AppColors.primary,
      targetRoute: '/appointments/${a['id']}',
      targetId: a['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapMeasurementToEvent(
    String profileId,
    Map<String, dynamic> m,
  ) {
    final date = _parseDate(m['recorded_at'] ?? m['date'] ?? m['created_at']);
    final type = m['type']?.toString() ?? '';

    String title = '${m['title'] ?? "Vital"} logged';
    if (type == 'blood_pressure') title = 'Blood Pressure logged';
    if (type == 'weight') title = 'Weight logged';

    String summary = '${m['value'] ?? ""} ${m['unit'] ?? ""}';

    return TimelineEventModel(
      id: 'm_${m['id']}',
      profileId: profileId,
      type: 'measurement',
      title: title,
      summary: summary.trim(),
      eventDate: date,
      badgeText: 'MEASUREMENT',
      icon: AppIcons.activity,
      color: AppColors.link,
      targetRoute: '/measurements/${m['id']}',
      targetId: m['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapReportToEvent(String profileId, dynamic r) {
    return TimelineEventModel(
      id: 'r_${r.id}',
      profileId: profileId,
      type: 'report',
      title: r.title,
      summary: r.notes ?? '${r.category} Document',
      eventDate: _parseDate(r.date),
      badgeText: r.category,
      icon: AppIcons.fileText,
      color: AppColors.hospitalAccent,
      targetRoute: '/reports/${r.id}',
      targetId: r.id,
    );
  }

  static TimelineEventModel mapMedicineToEvent(
    String profileId,
    Map<String, dynamic> med,
  ) {
    final date = _parseDate(
      med['start_date'] ?? med['created_at'] ?? med['date'],
    );

    return TimelineEventModel(
      id: 'med_${med['id']}',
      profileId: profileId,
      type: 'medicine',
      title: med['medication_name'] as String? ?? 'Prescription Medicine',
      summary: '${med['dosage'] ?? ""} ${med['frequency'] ?? ""}'.trim(),
      eventDate: date,
      badgeText: 'MEDICINE',
      icon: AppIcons.pill,
      color: AppColors.medicineAccent,
      targetRoute: '/medicines/${med['id']}',
      targetId: med['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapExpenseToEvent(
    String profileId,
    Map<String, dynamic> exp,
  ) {
    final date = _parseDate(exp['date'] ?? exp['created_at']);

    return TimelineEventModel(
      id: 'exp_${exp['id']}',
      profileId: profileId,
      type: 'expense',
      title: exp['title'] as String? ?? 'Healthcare Expense',
      summary: 'INR ${exp['amount']} · ${exp['category'] ?? "Medical"}',
      eventDate: date,
      badgeText: 'EXPENSE',
      icon: Icons.payments_outlined,
      color: AppColors.departmentAccent,
      targetRoute: '/expenses/${exp['id']}',
      targetId: exp['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapDoctorToEvent(
    String profileId,
    Map<String, dynamic> doc,
  ) {
    final date = _parseDate(
      doc['created_at'] ?? doc['updated_at'] ?? doc['date'],
    );

    return TimelineEventModel(
      id: 'doc_${doc['id']}',
      profileId: profileId,
      type: 'doctor',
      title: doc['name'] as String? ?? 'Doctor Entry',
      summary: '${doc['specialty'] ?? "Specialist"} added to directory',
      eventDate: date,
      badgeText: 'DOCTOR',
      icon: Icons.person_outline,
      color: AppColors.primary,
      targetRoute: '/doctors/${doc['id']}',
      targetId: doc['id']?.toString() ?? '',
    );
  }

  static TimelineEventModel mapHospitalToEvent(
    String profileId,
    Map<String, dynamic> hosp,
  ) {
    final date = _parseDate(
      hosp['created_at'] ?? hosp['updated_at'] ?? hosp['date'],
    );

    return TimelineEventModel(
      id: 'hosp_${hosp['id']}',
      profileId: profileId,
      type: 'hospital',
      title: hosp['name'] as String? ?? 'Hospital Entry',
      summary: '${hosp['city'] ?? "Medical Facility"} saved',
      eventDate: date,
      badgeText: 'HOSPITAL',
      icon: AppIcons.hospital,
      color: AppColors.hospitalAccent,
      targetRoute: '/hospitals/${hosp['id']}',
      targetId: hosp['id']?.toString() ?? '',
    );
  }

  /// Maps a server T1 timeline item to [TimelineEventModel] with canonical Flutter routing.
  static TimelineEventModel mapServerItemToEvent(
    String profileId,
    Map<String, dynamic> item,
  ) {
    final rawType = (item['type']?.toString() ?? 'other').toLowerCase();
    final rawId = item['id']?.toString() ?? '';
    final date = _parseDate(
      item['event_date'] ?? item['date'] ?? item['created_at'],
    );

    final title = item['title']?.toString() ?? 'Timeline Event';
    final summary =
        item['summary']?.toString() ?? item['description']?.toString() ?? '';
    final rawTargetId =
        item['target_id']?.toString() ?? item['targetId']?.toString() ?? rawId;

    String resolvedRoute;
    IconData icon;
    Color color;
    String badgeText;

    switch (rawType) {
      case 'consultation':
        final cleanId = rawTargetId
            .replaceFirst('consultation_', '')
            .replaceFirst('c_', '');
        resolvedRoute = '/consultations/$cleanId';
        icon = AppIcons.stethoscope;
        color = AppColors.primary;
        badgeText = 'CONSULTATION';
        break;
      case 'appointment':
        final cleanId = rawTargetId
            .replaceFirst('appointment_', '')
            .replaceFirst('apt_', '');
        resolvedRoute = '/appointments/$cleanId';
        icon = AppIcons.calendar;
        color = AppColors.primary;
        badgeText = 'APPOINTMENT';
        break;
      case 'report':
        final cleanId = rawTargetId
            .replaceFirst('report_', '')
            .replaceFirst('r_', '');
        resolvedRoute = '/reports/$cleanId';
        icon = AppIcons.fileText;
        color = AppColors.hospitalAccent;
        badgeText = item['badge_text']?.toString() ?? 'REPORT';
        break;
      case 'medicine':
        final cleanId = rawTargetId
            .replaceFirst('medicine_', '')
            .replaceFirst('med_', '');
        resolvedRoute = '/medicines/$cleanId';
        icon = AppIcons.pill;
        color = AppColors.medicineAccent;
        badgeText = 'MEDICINE';
        break;
      case 'measurement':
      case 'vital':
        resolvedRoute = '/measurements';
        icon = AppIcons.activity;
        color = AppColors.link;
        badgeText = 'MEASUREMENT';
        break;
      case 'expense':
        icon = Icons.payments_outlined;
        color = AppColors.departmentAccent;
        badgeText = 'EXPENSE';
        if (rawId.startsWith('exp_c') || rawTargetId.startsWith('c_')) {
          final cId = rawId.replaceFirst('exp_c', '').replaceFirst('c_', '');
          resolvedRoute = '/consultations/$cId';
        } else if (rawId.startsWith('exp_r') || rawTargetId.startsWith('r_')) {
          final rId = rawId.replaceFirst('exp_r', '').replaceFirst('r_', '');
          resolvedRoute = '/reports/$rId';
        } else {
          resolvedRoute = '/insights';
        }
        break;
      case 'doctor':
        final cleanId = rawTargetId
            .replaceFirst('doctor_', '')
            .replaceFirst('doc_', '');
        resolvedRoute = '/doctors/$cleanId';
        icon = Icons.person_outline;
        color = AppColors.primary;
        badgeText = 'DOCTOR';
        break;
      case 'hospital':
        final cleanId = rawTargetId
            .replaceFirst('hospital_', '')
            .replaceFirst('hosp_', '');
        resolvedRoute = '/hospitals/$cleanId';
        icon = AppIcons.hospital;
        color = AppColors.hospitalAccent;
        badgeText = 'HOSPITAL';
        break;
      default:
        resolvedRoute = '/timeline';
        icon = AppIcons.calendar;
        color = AppColors.primary;
        badgeText = item['badge_text']?.toString().toUpperCase() ?? 'EVENT';
        break;
    }

    return TimelineEventModel(
      id: rawId,
      profileId: profileId,
      type: rawType,
      title: title,
      summary: summary,
      eventDate: date,
      badgeText: badgeText,
      icon: icon,
      color: color,
      targetRoute: resolvedRoute,
      targetId: rawTargetId,
    );
  }
}
