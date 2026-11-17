import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../data/models/doctor_summary_model.dart';
import '../providers/doctor_summary_providers.dart';
import 'doctor_summary_category_tile.dart';

/// Renders the Customize Content accordion with 7 clinical categories and disclaimer banner.
class DoctorSummaryCategorySection extends StatelessWidget {
  final DoctorSummaryModel combinedSummary;
  final Set<DoctorSummaryCategory> selectedCategories;
  final Set<String> deselectedIds;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;
  final void Function(
    DoctorSummaryCategory category,
    bool? currentTristate,
    List<Map<String, dynamic>> items,
  )
  onToggleCategory;
  final void Function(
    String itemId,
    bool isSelected,
    DoctorSummaryCategory category,
  )
  onToggleItem;

  const DoctorSummaryCategorySection({
    super.key,
    required this.combinedSummary,
    required this.selectedCategories,
    required this.deselectedIds,
    required this.onSelectAll,
    required this.onClearAll,
    required this.onToggleCategory,
    required this.onToggleItem,
  });

  static String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    if (rawDate is DateTime) {
      return DateFormatter.formatShortDate(rawDate);
    }
    final dt = DateTime.tryParse(rawDate.toString());
    if (dt != null) {
      return DateFormatter.formatShortDate(dt);
    }
    return rawDate.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CUSTOMIZE CONTENT Section Header
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Text(
              'CUSTOMIZE CONTENT',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: onSelectAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: onClearAll,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ],
        ),
        Text(
          'Choose which sections and records to include in the generated summary.',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Enclosing Card with 7 Category Rows
        Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.6)),
          ),
          child: Column(
            children: [
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.medications,
                items: combinedSummary.medicines,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.medications,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (m) =>
                    (m['name'] ?? m['medication_name'] ?? 'Medication')
                        .toString(),
                subtitleBuilder: (m) => [
                  if (m['dosage'] != null) m['dosage']?.toString(),
                  if (m['frequency'] != null) m['frequency']?.toString(),
                  if (m['doctor_name'] != null) 'Dr. ${m['doctor_name']}',
                  if (m['prescribed_date'] != null || m['created_at'] != null)
                    _formatDate(m['prescribed_date'] ?? m['created_at']),
                ].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.consultations,
                items: combinedSummary.consultations,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.consultations,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (c) {
                  final doc = c['doctor_name'] ?? 'Doctor';
                  final spec =
                      c['specialization'] ?? c['doctor_specialization'] ?? '';
                  return spec.toString().isNotEmpty
                      ? 'Dr. $doc ($spec)'
                      : 'Dr. $doc';
                },
                subtitleBuilder: (c) => [
                  _formatDate(
                    c['consultation_date'] ?? c['date'] ?? c['created_at'],
                  ),
                  if (c['diagnosis'] != null || c['reason_for_visit'] != null)
                    (c['diagnosis'] ?? c['reason_for_visit'])?.toString(),
                ].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.reports,
                items: combinedSummary.reports,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.reports,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (r) =>
                    (r['test_name'] ?? r['title'] ?? 'Medical Report')
                        .toString(),
                subtitleBuilder: (r) => [
                  _formatDate(r['test_date'] ?? r['date'] ?? r['created_at']),
                  if (r['category'] != null) r['category']?.toString(),
                  if (r['facility'] != null || r['hospital_name'] != null)
                    (r['facility'] ?? r['hospital_name'])?.toString(),
                  if (r['notes'] != null && r['notes'].toString().isNotEmpty)
                    'Patient-entered note: ${r['notes']}',
                ].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.appointments,
                items: combinedSummary.appointments,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.appointments,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (a) {
                  final doc = a['doctor_name'] ?? a['doctor'] ?? 'Doctor';
                  return 'Appointment: $doc';
                },
                subtitleBuilder: (a) => [
                  _formatDate(
                    a['appointment_date'] ?? a['date'] ?? a['created_at'],
                  ),
                  if (a['status'] != null) a['status']?.toString(),
                  if (a['department'] != null) a['department']?.toString(),
                ].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.vitals,
                items: combinedSummary.vitals,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.vitals,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (v) {
                  final type = v['title'] ?? v['type'] ?? 'Vital';
                  final val = v['value'] ?? v['reading'] ?? '--';
                  final unit = v['unit'] != null ? ' ${v['unit']}' : '';
                  return '$type: $val$unit';
                },
                subtitleBuilder: (v) => _formatDate(
                  v['recorded_at'] ?? v['date'] ?? v['created_at'],
                ),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.doctors,
                items: combinedSummary.doctors,
                isLast: false,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.doctors,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (d) => (d['name'] ?? 'Doctor').toString(),
                subtitleBuilder: (d) => [
                  if (d['specialization'] != null)
                    d['specialization']?.toString(),
                  if (d['hospital'] != null || d['clinic'] != null)
                    (d['hospital'] ?? d['clinic'])?.toString(),
                ].where((s) => s != null && s.isNotEmpty).join(' · '),
              ),
              DoctorSummaryCategoryTile(
                category: DoctorSummaryCategory.hospitals,
                items: combinedSummary.hospitals,
                isLast: true,
                isCategorySelected: selectedCategories.contains(
                  DoctorSummaryCategory.hospitals,
                ),
                deselectedIds: deselectedIds,
                onToggleCategory: onToggleCategory,
                onToggleItem: onToggleItem,
                titleBuilder: (h) =>
                    (h['name'] ?? 'Hospital / Clinic').toString(),
                subtitleBuilder: (h) =>
                    (h['location'] ?? h['address'] ?? '').toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Disclaimer Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 16, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disclaimer: For reference only. Not a medical diagnosis. Confidentially generated client-side from MediCrate.',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
