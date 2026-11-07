import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';

/// Renders the expandable "Focus on a Specific Consultation" selector card.
class DoctorSummaryConsultationFocusCard extends StatefulWidget {
  final List<Map<String, dynamic>> consultations;
  final Set<String> selectedConsultationIds;
  final void Function(String id, bool isSelected) onToggleConsultation;
  final VoidCallback onSelectAll;
  final VoidCallback onClearAll;

  const DoctorSummaryConsultationFocusCard({
    super.key,
    required this.consultations,
    required this.selectedConsultationIds,
    required this.onToggleConsultation,
    required this.onSelectAll,
    required this.onClearAll,
  });

  @override
  State<DoctorSummaryConsultationFocusCard> createState() =>
      _DoctorSummaryConsultationFocusCardState();
}

class _DoctorSummaryConsultationFocusCardState
    extends State<DoctorSummaryConsultationFocusCard> {
  bool _isExpanded = false;

  String _formatDate(dynamic rawDate) {
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
    final selectedConsultationIds = widget.selectedConsultationIds;

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selectedConsultationIds.isNotEmpty
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedConsultationIds.isEmpty
                              ? 'Focus on a Specific Consultation'
                              : 'Specific Consultations (${selectedConsultationIds.length} selected)',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedConsultationIds.isEmpty
                              ? 'Filter entire summary to records linked to selected visit(s)'
                              : '${selectedConsultationIds.length} consultation(s) active · Tap to change',
                          style: AppTypography.caption.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    'Select Consultations',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: widget.onSelectAll,
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        onPressed: widget.onClearAll,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.consultations.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No consultations recorded for this profile.',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...widget.consultations.map((c) {
                final id = c['id']?.toString() ?? c['uuid']?.toString() ?? '';
                final isSelected = selectedConsultationIds.contains(id);
                final docName = c['doctor_name'] ?? 'Doctor';
                final spec =
                    c['specialization'] ?? c['doctor_specialization'] ?? '';
                final dateStr = _formatDate(
                  c['consultation_date'] ?? c['date'] ?? c['created_at'],
                );
                final diagnosis =
                    c['diagnosis'] ?? c['reason_for_visit'] ?? c['notes'] ?? '';

                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  onChanged: (val) {
                    widget.onToggleConsultation(id, val ?? false);
                  },
                  title: Text(
                    spec.toString().isNotEmpty
                        ? 'Dr. $docName ($spec)'
                        : 'Dr. $docName',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    diagnosis.toString().isNotEmpty
                        ? '$dateStr · $diagnosis'
                        : dateStr,
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
