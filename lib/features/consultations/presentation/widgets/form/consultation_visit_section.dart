import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../providers/consultation_form_providers.dart';
import '../consultation_section_header.dart';

class ConsultationVisitSection extends ConsumerWidget {
  const ConsultationVisitSection({super.key});

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh : mm  a').format(dt).toLowerCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final visitDate = ref.watch(visitDateProvider);
    final visitTime = ref.watch(visitTimeProvider);
    final formattedVisitDate = DateFormat('dd / MM / yyyy').format(visitDate);
    final formattedVisitTime = _formatTimeOfDay(visitTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConsultationSectionHeader(label: 'Visit'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visit Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VISIT DATE *',
                    style: AppTypography.labelSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final initial = visitDate.isAfter(today)
                          ? today
                          : visitDate;
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: initial,
                        firstDate: DateTime(1900),
                        lastDate: today,
                      );
                      if (picked != null) {
                        ref.read(visitDateProvider.notifier).state = picked;
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input),
                        border: Border.all(color: colorScheme.outline),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              formattedVisitDate,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
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

            // Visit Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIME',
                    style: AppTypography.labelSmall.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: visitTime,
                      );
                      if (picked != null) {
                        ref.read(visitTimeProvider.notifier).state = picked;
                      }
                    },
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
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
                            formattedVisitTime,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Icon(
                            Icons.access_time,
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
      ],
    );
  }
}
