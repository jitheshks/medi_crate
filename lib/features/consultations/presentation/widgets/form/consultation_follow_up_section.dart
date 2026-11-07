import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../providers/consultation_form_providers.dart';
import '../consultation_section_header.dart';

class ConsultationFollowUpSection extends ConsumerWidget {
  final TextEditingController followUpNotesController;

  const ConsultationFollowUpSection({
    super.key,
    required this.followUpNotesController,
  });

  String _formatTimeOfDay(TimeOfDay tod) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
    return DateFormat('hh : mm  a').format(dt).toLowerCase();
  }

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isFollowUpEnabled = ref.watch(isFollowUpEnabledProvider);
    final followUpDate = ref.watch(followUpDateProvider);
    final followUpTime = ref.watch(followUpTimeProvider);
    final followUpReminder = ref.watch(followUpReminderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConsultationSectionHeader(label: 'Follow-up'),
        Material(
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(color: colorScheme.outline),
          ),
          child: Column(
            children: [
              SwitchListTile.adaptive(
                value: isFollowUpEnabled,
                onChanged: (enabled) {
                  ref.read(isFollowUpEnabledProvider.notifier).state = enabled;
                  if (enabled && followUpDate == null) {
                    ref.read(followUpDateProvider.notifier).state =
                        DateTime.now().add(const Duration(days: 30));
                    ref.read(followUpTimeProvider.notifier).state =
                        const TimeOfDay(hour: 10, minute: 30);
                  }
                },
                title: Text(
                  'Schedule a follow-up',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                activeTrackColor: colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: isFollowUpEnabled
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 1, color: colorScheme.outline),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Follow-up Date Picker
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final now = DateTime.now();
                                    final today = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    final initial =
                                        (followUpDate != null &&
                                            !followUpDate.isBefore(today))
                                        ? followUpDate
                                        : today.add(const Duration(days: 30));
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: initial,
                                      firstDate: today,
                                      lastDate: DateTime(2100),
                                    );
                                    if (picked != null) {
                                      ref
                                              .read(
                                                followUpDateProvider.notifier,
                                              )
                                              .state =
                                          picked;
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.input,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.input,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            followUpDate != null
                                                ? DateFormat('dd / MM / yyyy')
                                                      .format(followUpDate)
                                                : 'Select Date',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          AppIcons.calendar,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Follow-up Time Picker
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          followUpTime ??
                                          const TimeOfDay(hour: 10, minute: 30),
                                    );
                                    if (picked != null) {
                                      ref
                                              .read(
                                                followUpTimeProvider.notifier,
                                              )
                                              .state =
                                          picked;
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.input,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.input,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.outline,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            followUpTime != null
                                                ? _formatTimeOfDay(followUpTime)
                                                : 'Select Time',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme.onSurface,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Reminder switch
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Reminder Notification',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Switch.adaptive(
                                value: followUpReminder,
                                onChanged: (val) {
                                  ref
                                          .read(
                                            followUpReminderProvider.notifier,
                                          )
                                          .state =
                                      val;
                                },
                                activeTrackColor: colorScheme.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Follow-up Notes
                          TextFormField(
                            controller: followUpNotesController,
                            maxLines: 2,
                            style: TextStyle(color: colorScheme.onSurface),
                            decoration: _buildInputDecoration(
                              context,
                              hintText: 'Follow-up instructions or notes...',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
