import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../appointments/presentation/providers/appointment_providers.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../medicines/presentation/providers/medicine_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../../../vitals/presentation/providers/measurement_providers.dart';
import '../../data/models/global_search_result.dart';

/// Global Search query state provider.
final globalSearchQueryProvider = StateProvider<String>((ref) => '');

/// Category filter provider for global search (null represents 'ALL').
final globalSearchCategoryFilterProvider = StateProvider<SearchEntityType?>(
  (ref) => null,
);

/// Calculates local relevance matching score for a search item.
int _calculateRelevanceScore(
  String query,
  String title,
  List<String> secondaryFields,
) {
  final cleanTitle = title.trim().toLowerCase();
  int score = 0;

  if (cleanTitle.isNotEmpty) {
    if (cleanTitle == query) {
      score += 100;
    } else if (cleanTitle.startsWith(query)) {
      score += 75;
    } else {
      final words = cleanTitle.split(RegExp(r'\s+'));
      if (words.any((w) => w.startsWith(query))) {
        score += 50;
      } else if (cleanTitle.contains(query)) {
        score += 30;
      }
    }
  }

  for (final field in secondaryFields) {
    final clean = field.trim().toLowerCase();
    if (clean.isEmpty) continue;
    if (clean == query) {
      score += 25;
    } else if (clean.startsWith(query)) {
      score += 20;
    } else {
      final words = clean.split(RegExp(r'\s+'));
      if (words.any((w) => w.startsWith(query))) {
        score += 15;
      } else if (clean.contains(query)) {
        score += 10;
      }
    }
  }

  return score;
}

/// Unfiltered global search results matching the active query across all clinical entities.
final allGlobalSearchResultsProvider = Provider<List<GlobalSearchResult>>((
  ref,
) {
  final rawQuery = ref.watch(globalSearchQueryProvider).trim().toLowerCase();
  if (rawQuery.isEmpty) return const [];

  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return const [];
  final activeProfileId = activeProfile.profileId;

  final results = <GlobalSearchResult>[];

  // 1. Consultations
  final consultations =
      ref.watch(consultationsListNotifierProvider).value ?? const [];
  for (final c in consultations) {
    if (c.profileId != activeProfileId && c.profileId.isNotEmpty) continue;
    final title = c.diagnosis.isNotEmpty
        ? c.diagnosis
        : (c.chiefComplaint.isNotEmpty ? c.chiefComplaint : 'Consultation');
    final secondary = <String>[
      c.doctorName,
      c.doctorSpecialty ?? '',
      c.hospitalName ?? '',
      c.department ?? '',
      c.chiefComplaint,
      c.diagnosis,
      c.clinicalNotes ?? '',
      ...c.tags,
      c.followUpNotes ?? '',
    ];
    final score = _calculateRelevanceScore(rawQuery, title, secondary);
    if (score > 0) {
      final subtitle = [
        if (c.doctorName.isNotEmpty) 'Dr. ${c.doctorName}',
        if (c.hospitalName != null && c.hospitalName!.isNotEmpty)
          c.hospitalName!
        else if (c.department != null && c.department!.isNotEmpty)
          c.department!,
      ].join(' · ');

      results.add(
        GlobalSearchResult(
          id: c.id,
          profileId: c.profileId,
          type: SearchEntityType.consultation,
          title: title,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Clinical visit',
          supportingText:
              c.chiefComplaint != c.diagnosis && c.chiefComplaint.isNotEmpty
              ? c.chiefComplaint
              : c.clinicalNotes,
          targetRoute: '/consultations/${c.id}',
          date: c.visitDate,
          relevanceScore: score,
        ),
      );
    }
  }

  // 2. Doctors
  final doctors = ref.watch(doctorsListProvider).value ?? const [];
  for (final doc in doctors) {
    if (doc.profileId != activeProfileId && doc.profileId.isNotEmpty) continue;
    final secondary = <String>[
      doc.specialty,
      doc.hospitalName ?? '',
      doc.phone ?? '',
      doc.email ?? '',
      doc.notes ?? '',
    ];
    final score = _calculateRelevanceScore(rawQuery, doc.name, secondary);
    if (score > 0) {
      final subtitle = [
        doc.specialty,
        if (doc.hospitalName != null && doc.hospitalName!.isNotEmpty)
          doc.hospitalName!,
      ].where((s) => s.isNotEmpty).join(' · ');

      results.add(
        GlobalSearchResult(
          id: doc.id,
          profileId: doc.profileId,
          type: SearchEntityType.doctor,
          title: doc.name,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Healthcare Specialist',
          supportingText: doc.phone ?? doc.email ?? doc.notes,
          targetRoute: '/doctors/${doc.id}',
          date: doc.createdAt,
          relevanceScore: score,
        ),
      );
    }
  }

  // 3. Hospitals
  final hospitals = ref.watch(hospitalsListProvider).value ?? const [];
  for (final hosp in hospitals) {
    if (hosp.profileId != activeProfileId && hosp.profileId.isNotEmpty) {
      continue;
    }
    final secondary = <String>[
      hosp.type ?? '',
      hosp.address ?? '',
      hosp.city ?? '',
      hosp.state ?? '',
      hosp.country ?? '',
      hosp.phone ?? '',
      hosp.email ?? '',
      hosp.notes ?? '',
    ];
    final score = _calculateRelevanceScore(rawQuery, hosp.name, secondary);
    if (score > 0) {
      final subtitle = [
        hosp.type ?? 'Hospital',
        if (hosp.city != null && hosp.city!.isNotEmpty)
          hosp.city!
        else if (hosp.address != null && hosp.address!.isNotEmpty)
          hosp.address!,
      ].where((s) => s.isNotEmpty).join(' · ');

      results.add(
        GlobalSearchResult(
          id: hosp.id,
          profileId: hosp.profileId,
          type: SearchEntityType.hospital,
          title: hosp.name,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Medical Facility',
          supportingText: hosp.address ?? hosp.phone ?? hosp.notes,
          targetRoute: '/hospitals/${hosp.id}',
          date: hosp.createdAt,
          relevanceScore: score,
        ),
      );
    }
  }

  // 4. Medicines
  final medicines = ref.watch(medicinesListNotifierProvider).value ?? const [];
  for (final med in medicines) {
    if (med.profileId != activeProfileId && med.profileId.isNotEmpty) continue;
    final secondary = <String>[
      med.medicineName,
      med.dosage,
      med.form ?? '',
      med.frequency ?? '',
      med.notes ?? '',
      med.linkedConsultationTitle ?? '',
      med.status,
    ];
    final score = _calculateRelevanceScore(
      rawQuery,
      med.medicineName,
      secondary,
    );
    if (score > 0) {
      final subtitle = [
        med.dosage,
        if (med.frequency != null && med.frequency!.isNotEmpty) med.frequency!,
        if (med.form != null && med.form!.isNotEmpty) med.form!,
      ].where((s) => s.isNotEmpty).join(' · ');

      results.add(
        GlobalSearchResult(
          id: med.id,
          profileId: med.profileId,
          type: SearchEntityType.medicine,
          title: med.medicineName,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Prescription Medicine',
          supportingText:
              med.notes ??
              (med.linkedConsultationTitle != null &&
                      med.linkedConsultationTitle!.isNotEmpty
                  ? 'Linked: ${med.linkedConsultationTitle}'
                  : null),
          targetRoute: '/medicines/${med.id}',
          date: med.startDate,
          relevanceScore: score,
        ),
      );
    }
  }

  // 5. Medical Reports
  final reports = ref.watch(reportsListNotifierProvider).value ?? const [];
  for (final rep in reports) {
    if (rep.profileId != activeProfileId && rep.profileId.isNotEmpty) continue;
    final secondary = <String>[
      rep.title,
      rep.category,
      rep.doctorName ?? '',
      rep.hospitalName ?? '',
      rep.consultationTitle ?? '',
      rep.notes ?? '',
      ...rep.attachments.map((a) => a.name),
    ];
    final score = _calculateRelevanceScore(rawQuery, rep.title, secondary);
    if (score > 0) {
      final subtitle = [
        rep.category,
        if (rep.doctorName != null && rep.doctorName!.isNotEmpty)
          'Dr. ${rep.doctorName}'
        else if (rep.hospitalName != null && rep.hospitalName!.isNotEmpty)
          rep.hospitalName!,
      ].where((s) => s.isNotEmpty).join(' · ');

      results.add(
        GlobalSearchResult(
          id: rep.id,
          profileId: rep.profileId,
          type: SearchEntityType.report,
          title: rep.title,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Medical Document',
          supportingText:
              rep.notes ??
              (rep.consultationTitle != null &&
                      rep.consultationTitle!.isNotEmpty
                  ? 'Linked: ${rep.consultationTitle}'
                  : null),
          targetRoute: '/reports/${rep.id}',
          date: rep.date,
          relevanceScore: score,
        ),
      );
    }
  }

  // 6. Appointments
  final appointments = ref.watch(appointmentsListProvider).value ?? const [];
  for (final apt in appointments) {
    if (apt.profileId != activeProfileId && apt.profileId.isNotEmpty) continue;
    final title = apt.title.isNotEmpty ? apt.title : 'Dr. ${apt.doctorName}';
    final secondary = <String>[
      apt.title,
      apt.doctorName,
      apt.hospitalName ?? '',
      apt.department ?? '',
      apt.notes ?? '',
      apt.status,
    ];
    final score = _calculateRelevanceScore(rawQuery, title, secondary);
    if (score > 0) {
      final subtitle = [
        if (apt.doctorName.isNotEmpty) 'Dr. ${apt.doctorName}',
        if (apt.hospitalName != null && apt.hospitalName!.isNotEmpty)
          apt.hospitalName!
        else if (apt.department != null && apt.department!.isNotEmpty)
          apt.department!,
      ].where((s) => s.isNotEmpty).join(' · ');

      results.add(
        GlobalSearchResult(
          id: apt.id,
          profileId: apt.profileId,
          type: SearchEntityType.appointment,
          title: title,
          subtitle: subtitle.isNotEmpty ? subtitle : 'Medical Appointment',
          supportingText:
              '${apt.status.toUpperCase()}${apt.notes != null && apt.notes!.isNotEmpty ? " · ${apt.notes}" : ""}',
          targetRoute: '/appointments/${apt.id}',
          date: apt.date,
          relevanceScore: score,
        ),
      );
    }
  }

  // 7. Vitals / Measurements
  final measurements = ref.watch(measurementsListProvider).value ?? const [];
  for (final m in measurements) {
    if (m.profileId != activeProfileId && m.profileId.isNotEmpty) continue;
    final title = m.title.isNotEmpty ? m.title : '${m.type} Reading';
    final secondary = <String>[
      m.title,
      m.type,
      m.value,
      m.unit,
      m.status,
      m.notes ?? '',
      m.glucoseContext ?? '',
    ];
    final score = _calculateRelevanceScore(rawQuery, title, secondary);
    if (score > 0) {
      final subtitle = '${m.value} ${m.unit} · ${m.status}';

      results.add(
        GlobalSearchResult(
          id: m.id,
          profileId: m.profileId,
          type: SearchEntityType.vital,
          title: title,
          subtitle: subtitle,
          supportingText: m.notes ?? m.glucoseContext,
          targetRoute: '/measurements',
          date: m.recordedAt,
          relevanceScore: score,
        ),
      );
    }
  }

  // Sort by relevance score descending, then date descending
  results.sort((a, b) {
    final scoreCompare = b.relevanceScore.compareTo(a.relevanceScore);
    if (scoreCompare != 0) return scoreCompare;
    final aDate = a.date ?? DateTime(1970);
    final bDate = b.date ?? DateTime(1970);
    return bDate.compareTo(aDate);
  });

  return results;
});

/// Category match counts provider for filter chip badges.
final globalSearchCategoryCountsProvider = Provider<Map<SearchEntityType, int>>(
  (ref) {
    final allResults = ref.watch(allGlobalSearchResultsProvider);
    final counts = <SearchEntityType, int>{};
    for (final result in allResults) {
      counts[result.type] = (counts[result.type] ?? 0) + 1;
    }
    return counts;
  },
);

/// Filtered global search results applying the active category filter.
final globalSearchResultsProvider = Provider<List<GlobalSearchResult>>((ref) {
  final allResults = ref.watch(allGlobalSearchResultsProvider);
  final filterCategory = ref.watch(globalSearchCategoryFilterProvider);

  if (filterCategory == null) return allResults;
  return allResults.where((r) => r.type == filterCategory).toList();
});
