import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/doctor_summary_model.dart';
import '../../data/repositories/doctor_summary_repository.dart';

enum DoctorSummaryMode {
  dateRange('Date Range'),
  specificConsultation('Specific Consultation');

  final String label;
  const DoctorSummaryMode(this.label);
}

enum DoctorSummaryDatePreset {
  today('Today'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  last3Months('Last 3 Months'),
  last1Year('Last 1 Year'),
  allTime('All Time'),
  custom('Custom Range');

  final String label;
  const DoctorSummaryDatePreset(this.label);
}

enum DoctorSummaryCategory {
  medications('Medications', Icons.medication_outlined),
  vitals('Vitals', Icons.favorite_outline),
  consultations('Consultations', Icons.assignment_outlined),
  reports('Reports', Icons.description_outlined),
  appointments('Appointments', Icons.calendar_month_outlined),
  doctors('Doctors', Icons.person_search_outlined),
  hospitals('Hospitals', Icons.local_hospital_outlined);

  final String label;
  final IconData icon;
  const DoctorSummaryCategory(this.label, this.icon);
}

final doctorSummaryRepositoryProvider = Provider<DoctorSummaryRepository>((
  ref,
) {
  final hive = ref.watch(hiveServiceProvider);
  return DoctorSummaryRepository(hiveService: hive);
});

final doctorSummaryModeProvider = StateProvider<DoctorSummaryMode>(
  (ref) => DoctorSummaryMode.dateRange,
);

final doctorSummaryDatePresetProvider = StateProvider<DoctorSummaryDatePreset>(
  (ref) => DoctorSummaryDatePreset.allTime,
);

final doctorSummaryCustomDateRangeProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);

final doctorSummaryFocusedConsultationIdProvider = StateProvider<String?>(
  (ref) => null,
);

final doctorSummarySelectedConsultationIdsProvider = StateProvider<Set<String>>(
  (ref) => <String>{},
);

class DoctorSummarySelectedCategoriesNotifier
    extends Notifier<Set<DoctorSummaryCategory>> {
  @override
  Set<DoctorSummaryCategory> build() {
    ref.watch(activeProfileProvider);
    return DoctorSummaryCategory.values.toSet();
  }

  void setCategories(Set<DoctorSummaryCategory> categories) {
    state = categories;
  }

  void selectAll() {
    state = DoctorSummaryCategory.values.toSet();
  }

  void clearAll() {
    state = <DoctorSummaryCategory>{};
  }

  void toggleCategory(DoctorSummaryCategory category, bool isSelected) {
    if (isSelected) {
      state = {...state, category};
    } else {
      state = state.where((c) => c != category).toSet();
    }
  }
}

final doctorSummarySelectedCategoriesProvider =
    NotifierProvider<
      DoctorSummarySelectedCategoriesNotifier,
      Set<DoctorSummaryCategory>
    >(DoctorSummarySelectedCategoriesNotifier.new);

class DoctorSummaryDeselectedItemIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(activeProfileProvider);
    return <String>{};
  }

  void toggleItem(String itemId, bool isSelected) {
    if (isSelected) {
      state = state.where((id) => id != itemId).toSet();
    } else {
      state = {...state, itemId};
    }
  }

  void clear() {
    state = <String>{};
  }

  void setDeselected(Set<String> ids) {
    state = ids;
  }

  /// Removes any IDs from the deselected set that are not present in the currently eligible items.
  void pruneIneligible(Set<String> eligibleItemIds) {
    state = state.intersection(eligibleItemIds);
  }
}

final doctorSummaryDeselectedItemIdsProvider =
    NotifierProvider<DoctorSummaryDeselectedItemIdsNotifier, Set<String>>(
      DoctorSummaryDeselectedItemIdsNotifier.new,
    );

final doctorSummaryEffectiveDateRangeProvider = Provider<DateTimeRange?>((ref) {
  final preset = ref.watch(doctorSummaryDatePresetProvider);
  final now = DateTime.now();

  switch (preset) {
    case DoctorSummaryDatePreset.allTime:
      return null;
    case DoctorSummaryDatePreset.today:
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return DateTimeRange(start: start, end: end);
    case DoctorSummaryDatePreset.last7Days:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );
    case DoctorSummaryDatePreset.last30Days:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
    case DoctorSummaryDatePreset.last3Months:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 90)),
        end: now,
      );
    case DoctorSummaryDatePreset.last1Year:
      return DateTimeRange(
        start: now.subtract(const Duration(days: 365)),
        end: now,
      );
    case DoctorSummaryDatePreset.custom:
      return ref.watch(doctorSummaryCustomDateRangeProvider);
  }
});

final doctorSummaryDateRangeLabelProvider = Provider<String>((ref) {
  final selectedIds = ref.watch(doctorSummarySelectedConsultationIdsProvider);
  final singleFocusedId = ref.watch(doctorSummaryFocusedConsultationIdProvider);
  final effectiveIds = selectedIds.isNotEmpty
      ? selectedIds
      : (singleFocusedId != null && singleFocusedId.isNotEmpty
            ? {singleFocusedId}
            : <String>{});

  if (effectiveIds.isNotEmpty) {
    final baseSummary = ref.watch(baseDoctorSummaryProvider).value;
    if (baseSummary != null) {
      if (effectiveIds.length == 1) {
        final focusedId = effectiveIds.first;
        final consultation = baseSummary.consultations.firstWhere(
          (c) =>
              getSummaryItemId(c, DoctorSummaryCategory.consultations) ==
              focusedId,
          orElse: () => <String, dynamic>{},
        );
        if (consultation.isNotEmpty) {
          final diag = consultation['diagnosis'] ?? 'Consultation';
          final doc = consultation['doctor_name'] ?? 'Doctor';
          final date = consultation['visit_date']?.toString();
          final formattedDate = date != null && date.isNotEmpty
              ? (date.contains('T') ? date.split('T')[0] : date)
              : '';
          return 'Consultation: $diag · $doc ${formattedDate.isNotEmpty ? "($formattedDate)" : ""}';
        }
      } else {
        return '${effectiveIds.length} Consultations Selected';
      }
    }
    return '${effectiveIds.length} Consultations Selected';
  }

  final preset = ref.watch(doctorSummaryDatePresetProvider);
  if (preset == DoctorSummaryDatePreset.allTime) {
    return 'All Time';
  }
  if (preset == DoctorSummaryDatePreset.today) {
    final now = DateTime.now();
    final d = now.day.toString().padLeft(2, '0');
    final m = now.month.toString().padLeft(2, '0');
    final y = (now.year % 100).toString().padLeft(2, '0');
    return 'Today ($d-$m-$y)';
  }
  if (preset != DoctorSummaryDatePreset.custom) {
    return preset.label;
  }
  final range = ref.watch(doctorSummaryCustomDateRangeProvider);
  if (range == null) return 'Custom Range';
  final startStr =
      '${range.start.day.toString().padLeft(2, '0')}/${range.start.month.toString().padLeft(2, '0')}/${range.start.year}';
  final endStr =
      '${range.end.day.toString().padLeft(2, '0')}/${range.end.month.toString().padLeft(2, '0')}/${range.end.year}';
  return '$startStr – $endStr';
});

/// Unique ID extractor for clinical records
String getSummaryItemId(
  Map<String, dynamic> item,
  DoctorSummaryCategory category,
) {
  final idVal =
      item['id'] ??
      item['client_uuid'] ??
      item['uuid'] ??
      item['measurement_id'] ??
      item['medicine_id'] ??
      item['consultation_id'] ??
      item['report_id'] ??
      item['appointment_id'] ??
      item['doctor_id'] ??
      item['hospital_id'];

  if (idVal != null && idVal.toString().isNotEmpty) {
    return idVal.toString();
  }

  // Fallback composite key
  final nameVal =
      item['medication_name'] ??
      item['title'] ??
      item['diagnosis'] ??
      item['name'] ??
      'item';
  final dateVal =
      item['date'] ??
      item['visit_date'] ??
      item['recorded_at'] ??
      item['created_at'] ??
      '';
  return '${category.name}_${nameVal}_$dateVal';
}

/// Base summary provider fetching all-time data for the active profile from Hive
final baseDoctorSummaryProvider = FutureProvider<DoctorSummaryModel?>((
  ref,
) async {
  ref.watch(clinicalCacheRevisionProvider);
  final activeProfile = ref.watch(activeProfileProvider);
  if (activeProfile == null) return null;

  final repo = ref.watch(doctorSummaryRepositoryProvider);
  return await repo.getDoctorSummary(activeProfile);
});

/// Pure synchronous provider applying date-range filtering in-memory
final dateFilteredDoctorSummaryProvider =
    Provider<AsyncValue<DoctorSummaryModel?>>((ref) {
      final baseAsync = ref.watch(baseDoctorSummaryProvider);
      final dateRange = ref.watch(doctorSummaryEffectiveDateRangeProvider);
      final dateRangeLabel = ref.watch(doctorSummaryDateRangeLabelProvider);
      final repo = ref.watch(doctorSummaryRepositoryProvider);

      return baseAsync.whenData((baseModel) {
        if (baseModel == null) return null;
        return repo.filterSummaryByDate(
          baseModel,
          dateRange: dateRange,
          dateRangeLabel: dateRangeLabel,
        );
      });
    });

final combinedFilteredDoctorSummaryProvider =
    Provider<AsyncValue<DoctorSummaryModel?>>((ref) {
      final baseAsync = ref.watch(baseDoctorSummaryProvider);
      final dateFilteredAsync = ref.watch(dateFilteredDoctorSummaryProvider);

      final selectedConsultationIds = ref.watch(
        doctorSummarySelectedConsultationIdsProvider,
      );

      if (selectedConsultationIds.isEmpty) {
        return dateFilteredAsync;
      }

      return baseAsync.whenData((baseModel) {
        if (baseModel == null) return null;

        final selectedConsultations = baseModel.consultations
            .where(
              (c) => selectedConsultationIds.contains(
                getSummaryItemId(c, DoctorSummaryCategory.consultations),
              ),
            )
            .toList();

        if (selectedConsultations.isEmpty) {
          return baseModel.copyWith(
            consultations: const [],
            medicines: const [],
            vitals: const [],
            reports: const [],
            appointments: const [],
            doctors: const [],
            hospitals: const [],
          );
        }

        final docNames = <String>{};
        final hospNames = <String>{};
        final visitDates = <String>{};
        final consIdStrings = <String>{};
        final apptIds = <String>{};

        for (final consultation in selectedConsultations) {
          final dName = consultation['doctor_name']
              ?.toString()
              .toLowerCase()
              .trim();
          if (dName != null && dName.isNotEmpty) docNames.add(dName);

          final hName = consultation['hospital_name']
              ?.toString()
              .toLowerCase()
              .trim();
          if (hName != null && hName.isNotEmpty) hospNames.add(hName);

          final vDate = consultation['visit_date']?.toString().split('T')[0];
          if (vDate != null && vDate.isNotEmpty) visitDates.add(vDate);

          final cId = (consultation['id'] ?? consultation['client_uuid'] ?? '')
              ?.toString();
          if (cId != null && cId.isNotEmpty) consIdStrings.add(cId);

          final aId = consultation['appointment_id']?.toString();
          if (aId != null && aId.isNotEmpty) apptIds.add(aId);
        }

        final medicines = baseModel.medicines.where((m) {
          final linkedConsId =
              (m['linked_consultation_id'] ??
                      m['consultation_id'] ??
                      m['consultationId'])
                  ?.toString();
          if (consIdStrings.isNotEmpty &&
              linkedConsId != null &&
              linkedConsId.isNotEmpty) {
            return consIdStrings.contains(linkedConsId);
          }
          return false;
        }).toList();

        final reports = baseModel.reports.where((r) {
          final linkedConsId = (r['consultation_id'] ?? r['consultationId'])
              ?.toString();
          final rDate = r['date']?.toString().split('T')[0];
          if (consIdStrings.isNotEmpty &&
              linkedConsId != null &&
              linkedConsId.isNotEmpty) {
            return consIdStrings.contains(linkedConsId);
          }
          if (visitDates.isNotEmpty && rDate != null) {
            return visitDates.contains(rDate);
          }
          return false;
        }).toList();

        final vitals = baseModel.vitals.where((v) {
          final rawDate = v['recorded_at'] ?? v['date'] ?? v['created_at'];
          final vDateStr = rawDate?.toString().split('T')[0];
          if (visitDates.isNotEmpty && vDateStr != null) {
            return visitDates.contains(vDateStr);
          }
          return false;
        }).toList();

        final appointments = baseModel.appointments.where((a) {
          final aId = (a['id'] ?? a['appointment_id'])?.toString();
          final aDoc = a['doctor_name']?.toString().toLowerCase().trim();
          final aHosp = a['hospital_name']?.toString().toLowerCase().trim();
          return (aId != null && aId.isNotEmpty && apptIds.contains(aId)) ||
              (aDoc != null && docNames.contains(aDoc)) ||
              (aHosp != null && hospNames.contains(aHosp));
        }).toList();

        final doctors = docNames.isNotEmpty
            ? baseModel.doctors.where((d) {
                final dName = d['name']?.toString().toLowerCase().trim();
                return dName != null && docNames.contains(dName);
              }).toList()
            : baseModel.doctors;

        final hospitals = hospNames.isNotEmpty
            ? baseModel.hospitals.where((h) {
                final hName = h['name']?.toString().toLowerCase().trim();
                return hName != null && hospNames.contains(hName);
              }).toList()
            : baseModel.hospitals;

        return baseModel.copyWith(
          consultations: selectedConsultations,
          medicines: medicines,
          vitals: vitals,
          reports: reports,
          appointments: appointments,
          doctors: doctors,
          hospitals: hospitals,
        );
      });
    });

final doctorSummaryProvider = Provider<AsyncValue<DoctorSummaryModel?>>((ref) {
  final combinedAsync = ref.watch(combinedFilteredDoctorSummaryProvider);

  return combinedAsync.whenData((combinedModel) {
    if (combinedModel == null) return null;

    final selectedCategories = ref.watch(
      doctorSummarySelectedCategoriesProvider,
    );
    final deselectedIds = ref.watch(doctorSummaryDeselectedItemIdsProvider);

    List<Map<String, dynamic>> filterCategoryItems(
      List<Map<String, dynamic>> items,
      DoctorSummaryCategory category,
    ) {
      if (!selectedCategories.contains(category)) {
        return const [];
      }
      return items.where((item) {
        final id = getSummaryItemId(item, category);
        return !deselectedIds.contains(id);
      }).toList();
    }

    return combinedModel.copyWith(
      consultations: filterCategoryItems(
        combinedModel.consultations,
        DoctorSummaryCategory.consultations,
      ),
      medicines: filterCategoryItems(
        combinedModel.medicines,
        DoctorSummaryCategory.medications,
      ),
      vitals: filterCategoryItems(
        combinedModel.vitals,
        DoctorSummaryCategory.vitals,
      ),
      reports: filterCategoryItems(
        combinedModel.reports,
        DoctorSummaryCategory.reports,
      ),
      appointments: filterCategoryItems(
        combinedModel.appointments,
        DoctorSummaryCategory.appointments,
      ),
      doctors: filterCategoryItems(
        combinedModel.doctors,
        DoctorSummaryCategory.doctors,
      ),
      hospitals: filterCategoryItems(
        combinedModel.hospitals,
        DoctorSummaryCategory.hospitals,
      ),
    );
  });
});

final doctorSummarySelectedCountProvider = Provider<int>((ref) {
  final summaryAsync = ref.watch(doctorSummaryProvider);
  return summaryAsync.value?.totalClinicalItems ?? 0;
});

/// Collects all eligible summary item IDs from a DoctorSummaryModel
Set<String> getEligibleItemIds(DoctorSummaryModel model) {
  final ids = <String>{};
  for (final c in model.consultations) {
    ids.add(getSummaryItemId(c, DoctorSummaryCategory.consultations));
  }
  for (final m in model.medicines) {
    ids.add(getSummaryItemId(m, DoctorSummaryCategory.medications));
  }
  for (final v in model.vitals) {
    ids.add(getSummaryItemId(v, DoctorSummaryCategory.vitals));
  }
  for (final r in model.reports) {
    ids.add(getSummaryItemId(r, DoctorSummaryCategory.reports));
  }
  for (final a in model.appointments) {
    ids.add(getSummaryItemId(a, DoctorSummaryCategory.appointments));
  }
  for (final d in model.doctors) {
    ids.add(getSummaryItemId(d, DoctorSummaryCategory.doctors));
  }
  for (final h in model.hospitals) {
    ids.add(getSummaryItemId(h, DoctorSummaryCategory.hospitals));
  }
  return ids;
}

/// Sets selected consultation IDs and clears focus when empty
void applyMultipleConsultationFocus({
  required WidgetRef ref,
  required DoctorSummaryModel baseModel,
  required Set<String> consultationIds,
}) {
  ref.read(doctorSummarySelectedConsultationIdsProvider.notifier).state =
      consultationIds;
  ref.read(doctorSummaryFocusedConsultationIdProvider.notifier).state =
      consultationIds.length == 1 ? consultationIds.first : null;
}

/// Backward compatibility wrapper for single consultation focus
void applyConsultationFocus({
  required WidgetRef ref,
  required DoctorSummaryModel baseModel,
  required String? consultationId,
}) {
  if (consultationId == null || consultationId.isEmpty) {
    applyMultipleConsultationFocus(
      ref: ref,
      baseModel: baseModel,
      consultationIds: <String>{},
    );
  } else {
    applyMultipleConsultationFocus(
      ref: ref,
      baseModel: baseModel,
      consultationIds: {consultationId},
    );
  }
}
