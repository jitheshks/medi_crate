import 'package:flutter/material.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';

class MedicineDateRangePicker extends StatelessWidget {
  final DateTime startDate;
  final DateTime? endDate;
  final String? endDateError;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  const MedicineDateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.endDateError,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  static String formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Start Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'START DATE *',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        onStartDateChanged(picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDate(startDate),
                            style: AppTypography.bodyMedium.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            AppIcons.calendar,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // End Date (optional)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'END DATE (OPTIONAL)',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate ?? startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        onEndDateChanged(picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(
                          color: endDateError != null
                              ? colorScheme.error
                              : colorScheme.outline,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            endDate != null
                                ? formatDate(endDate!)
                                : 'dd / mm / yyyy',
                            style: AppTypography.bodyMedium.copyWith(
                              color: endDate != null
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.6,
                                    ),
                              fontWeight: endDate != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (endDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => onEndDateChanged(null),
                            )
                          else
                            Icon(
                              AppIcons.calendar,
                              size: 18,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (endDateError != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              endDateError!,
              style: AppTypography.caption.copyWith(color: colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
