import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/forms/custom_date_range_panel.dart';
import '../../data/models/insights_summary_model.dart';
import '../providers/insights_providers.dart';

/// InsightsTimeFilterChips renders Material 3 FilterChips for selecting analytics time range,
/// including a Custom date range option that anchors an unclipped date selector panel.
class InsightsTimeFilterChips extends ConsumerStatefulWidget {
  const InsightsTimeFilterChips({super.key});

  @override
  ConsumerState<InsightsTimeFilterChips> createState() =>
      _InsightsTimeFilterChipsState();
}

class _InsightsTimeFilterChipsState
    extends ConsumerState<InsightsTimeFilterChips> {
  bool _showCustomPanel = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedRange = ref.watch(selectedTimeRangeProvider);
    final customStart = ref.watch(insightsCustomStartDateProvider);
    final customEnd = ref.watch(insightsCustomEndDateProvider);

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: InsightsTimeRange.values.map((range) {
              final isSelected = (range == selectedRange);

              String chipLabel = range.label;
              if (range == InsightsTimeRange.custom &&
                  isSelected &&
                  customStart != null &&
                  customEnd != null) {
                chipLabel = DateFormatter.formatDateRange(
                  customStart,
                  customEnd,
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  selected: isSelected,
                  label: AnimatedDefaultTextStyle(
                    duration: duration,
                    curve: Curves.easeInOut,
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    child: Text(chipLabel),
                  ),
                  selectedColor: colorScheme.primary,
                  backgroundColor: colorScheme.surface,
                  showCheckmark: false,
                  side: BorderSide(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outline,
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  onSelected: (_) {
                    if (range == InsightsTimeRange.custom) {
                      setState(() {
                        _showCustomPanel = true;
                      });
                    } else {
                      setState(() {
                        _showCustomPanel = false;
                      });
                      ref.read(selectedTimeRangeProvider.notifier).state =
                          range;
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (_showCustomPanel) ...[
          const SizedBox(height: AppSpacing.sm),
          CustomDateRangePanel(
            initialStartDate: customStart,
            initialEndDate: customEnd,
            onApply: (start, end) {
              ref.read(selectedTimeRangeProvider.notifier).state =
                  InsightsTimeRange.custom;
              ref.read(insightsCustomStartDateProvider.notifier).state = start;
              ref.read(insightsCustomEndDateProvider.notifier).state = end;
              setState(() {
                _showCustomPanel = false;
              });
            },
            onCancel: () {
              setState(() {
                _showCustomPanel = false;
              });
            },
          ),
        ],
      ],
    );
  }
}
