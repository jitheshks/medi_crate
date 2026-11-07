import 'package:flutter/material.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../consultations/data/models/consultation_model.dart';
import '../../../../consultations/presentation/widgets/consultation_picker_sheet.dart';
import 'medicine_date_range_picker.dart';

class MedicineConsultationPicker extends StatelessWidget {
  final String? linkedConsultationTitle;
  final VoidCallback onOpenPicker;

  const MedicineConsultationPicker({
    super.key,
    required this.linkedConsultationTitle,
    required this.onOpenPicker,
  });

  static void showConsultationPicker({
    required BuildContext context,
    required List<Map<String, dynamic>> consultations,
    required String? currentTitle,
    required Function(String? id, String? title) onSelected,
  }) {
    List<String> options = ['None (Not linked)'];
    final consultMap = <String, ConsultationModel>{};

    for (final rawMap in consultations) {
      final model = ConsultationModel.fromJson(rawMap);
      final displayLabel =
          '${model.diagnosis} (${MedicineDateRangePicker.formatDate(model.visitDate)})';
      options.add(displayLabel);
      consultMap[displayLabel] = model;
    }

    ConsultationPickerSheet.show(
      context: context,
      title: 'Select Linked Consultation',
      placeholderHint: 'Search consultation by diagnosis...',
      options: options,
      currentValue: currentTitle != null
          ? options.firstWhere(
              (opt) => opt.contains(currentTitle),
              orElse: () => currentTitle,
            )
          : 'None (Not linked)',
      onSelected: (val) {
        if (val == 'None (Not linked)') {
          onSelected(null, null);
        } else {
          final selected = consultMap[val];
          if (selected != null) {
            onSelected(selected.id, selected.diagnosis);
          } else {
            onSelected(null, val);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKED CONSULTATION (OPTIONAL)',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onOpenPicker,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(color: colorScheme.outline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    linkedConsultationTitle ?? 'Not linked',
                    style: AppTypography.bodyMedium.copyWith(
                      color: linkedConsultationTitle != null
                          ? colorScheme.onSurface
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      fontWeight: linkedConsultationTitle != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  AppIcons.chevronRight,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
