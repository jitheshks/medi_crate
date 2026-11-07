import 'package:flutter/material.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../profile/data/models/profile_model.dart';
import 'medicine_chips_selector.dart';
import 'medicine_consultation_picker.dart';
import 'medicine_date_range_picker.dart';
import 'medicine_form_controller.dart';

class MedicineFormContent extends StatelessWidget {
  final MedicineFormController controller;
  final ProfileModel? activeProfile;
  final VoidCallback onOpenConsultationPicker;
  final VoidCallback onStateChanged;

  const MedicineFormContent({
    super.key,
    required this.controller,
    required this.activeProfile,
    required this.onOpenConsultationPicker,
    required this.onStateChanged,
  });

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
      filled: true,
      fillColor: colorScheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active Profile info banner
        if (activeProfile != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.userCheck, size: 18, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recording for profile: ${activeProfile!.fullName} (${activeProfile!.relationship})',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 1. Medicine Name *
        Text(
          'MEDICINE NAME *',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller.nameController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: _buildInputDecoration(
            context,
            hintText: 'e.g. Paracetamol',
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Medicine name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 2. Dosage *
        Text(
          'DOSAGE *',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller.dosageController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: _buildInputDecoration(context, hintText: 'e.g. 500 mg'),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Dosage is required';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 3 & 4. Form & Frequency Chips
        MedicineChipsSelector(
          selectedForm: controller.selectedForm,
          onFormSelected: (form) {
            controller.selectedForm = form;
            onStateChanged();
          },
          selectedFrequency: controller.selectedFrequency,
          onFrequencySelected: (freq) {
            controller.onFrequencyChanged(freq);
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 5 & 6. Start & End Dates
        MedicineDateRangePicker(
          startDate: controller.startDate,
          endDate: controller.endDate,
          endDateError: controller.endDateError,
          onStartDateChanged: (d) {
            controller.startDate = d;
            controller.validateEndDate();
            onStateChanged();
          },
          onEndDateChanged: (d) {
            controller.endDate = d;
            controller.validateEndDate();
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // 7. Reminder Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(AppIcons.bell, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Reminder',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Switch(
                value: controller.reminder,
                activeThumbColor: colorScheme.primary,
                onChanged: (val) {
                  controller.reminder = val;
                  onStateChanged();
                },
              ),
            ],
          ),
        ),

        // 7b. Specific Reminder Times
        if (controller.reminder) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMINDER TIMES',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (controller.reminderTimes.length < 6)
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                          );
                          if (picked != null) {
                            controller.reminderTimes.add(picked);
                            onStateChanged();
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Add Time',
                                style: AppTypography.caption.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(controller.reminderTimes.length, (
                    idx,
                  ) {
                    final time = controller.reminderTimes[idx];
                    final formattedTime = time.format(context);
                    return InputChip(
                      avatar: Icon(
                        Icons.access_time_filled,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        formattedTime,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor: colorScheme.surface,
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: time,
                        );
                        if (picked != null) {
                          controller.reminderTimes[idx] = picked;
                          onStateChanged();
                        }
                      },
                      onDeleted: controller.reminderTimes.length > 1
                          ? () {
                              controller.reminderTimes.removeAt(idx);
                              onStateChanged();
                            }
                          : null,
                      deleteIcon: const Icon(Icons.close, size: 14),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),

        // 8. Linked Consultation
        MedicineConsultationPicker(
          linkedConsultationTitle: controller.linkedConsultationTitle,
          onOpenPicker: onOpenConsultationPicker,
        ),
        const SizedBox(height: AppSpacing.md),

        // 9. Notes
        Text(
          'NOTES',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller.notesController,
          maxLines: 3,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: _buildInputDecoration(
            context,
            hintText: 'Any notes about this medicine…',
          ),
        ),
      ],
    );
  }
}
