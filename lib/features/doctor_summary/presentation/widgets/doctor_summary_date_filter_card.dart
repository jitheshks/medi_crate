import 'package:flutter/material.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../providers/doctor_summary_providers.dart';

/// Renders the horizontal date filter preset chips bar for Doctor Summary.
class DoctorSummaryDateFilterCard extends StatelessWidget {
  final DoctorSummaryDatePreset selectedPreset;
  final DateTimeRange? customDateRange;
  final ValueChanged<DoctorSummaryDatePreset> onPresetSelected;
  final VoidCallback onPickCustomRange;

  const DoctorSummaryDateFilterCard({
    super.key,
    required this.selectedPreset,
    required this.customDateRange,
    required this.onPresetSelected,
    required this.onPickCustomRange,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'DATE FILTER',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: const [
              DoctorSummaryDatePreset.allTime,
              DoctorSummaryDatePreset.last7Days,
              DoctorSummaryDatePreset.last30Days,
              DoctorSummaryDatePreset.last3Months,
              DoctorSummaryDatePreset.last1Year,
              DoctorSummaryDatePreset.custom,
            ].map((preset) {
              final isSelected = selectedPreset == preset;
              final label = preset == DoctorSummaryDatePreset.custom &&
                      customDateRange != null
                  ? DateFormatter.formatDateRange(
                      customDateRange!.start,
                      customDateRange!.end,
                    )
                  : preset.label;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (preset == DoctorSummaryDatePreset.custom) {
                      onPickCustomRange();
                    } else {
                      onPresetSelected(preset);
                    }
                  },
                  selectedColor: colorScheme.primary,
                  labelStyle: AppTypography.caption.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
