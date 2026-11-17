import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../settings/presentation/providers/settings_providers.dart';
import 'appointment_date_time_picker.dart';
import 'appointment_expense_fields.dart';
import 'appointment_form_controller.dart';
import 'appointment_selector_tile.dart';
import 'appointment_title_field.dart';

class AppointmentFormContent extends ConsumerWidget {
  final AppointmentFormController controller;
  final VoidCallback onStateChanged;
  final VoidCallback onOpenDoctorPicker;
  final VoidCallback onAddDoctor;
  final VoidCallback? onClearDoctor;
  final VoidCallback onOpenHospitalPicker;
  final VoidCallback? onClearHospital;
  final VoidCallback onAddHospital;
  final VoidCallback onOpenDepartmentPicker;
  final VoidCallback? onClearDepartment;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final bool isEditing;
  final bool isSaving;
  final VoidCallback onSave;

  const AppointmentFormContent({
    super.key,
    required this.controller,
    required this.onStateChanged,
    required this.onOpenDoctorPicker,
    required this.onAddDoctor,
    this.onClearDoctor,
    required this.onOpenHospitalPicker,
    required this.onClearHospital,
    required this.onAddHospital,
    required this.onOpenDepartmentPicker,
    required this.onClearDepartment,
    required this.onPickDate,
    required this.onPickTime,
    required this.isEditing,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorDisplayValue =
        controller.selectedDoctorName != null &&
            controller.selectedDoctorName!.isNotEmpty
        ? (controller.selectedDoctorSpecialty != null &&
                  controller.selectedDoctorSpecialty!.isNotEmpty &&
                  controller.selectedDoctorSpecialty != 'General Practice'
              ? '${controller.selectedDoctorName} (${controller.selectedDoctorSpecialty})'
              : controller.selectedDoctorName!)
        : 'Select doctor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECTION 1: TITLE
        AppointmentTitleField(
          controller: controller.titleController,
          suggestions: controller.titleSuggestions,
          onSuggestionSelected: (sug) {
            controller.titleController.text = sug;
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // SECTION 2: DOCTOR & HOSPITAL
        Text(
          'DOCTOR & HOSPITAL',
          style: AppTypography.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Doctor Picker Tile
        AppointmentSelectorTile(
          icon: AppIcons.stethoscope,
          label: 'DOCTOR *',
          valueText: doctorDisplayValue,
          isSet:
              controller.selectedDoctorName != null &&
              controller.selectedDoctorName!.isNotEmpty,
          onTap: onOpenDoctorPicker,
          onClear: onClearDoctor,
          onActionPressed: onAddDoctor,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: 'Add new doctor',
        ),
        const SizedBox(height: 12),

        // Hospital Picker Tile
        AppointmentSelectorTile(
          icon: AppIcons.hospital,
          label: 'HOSPITAL (OPTIONAL)',
          valueText: controller.selectedHospitalName ?? 'Select hospital',
          isSet:
              controller.selectedHospitalName != null &&
              controller.selectedHospitalName!.isNotEmpty,
          onTap: onOpenHospitalPicker,
          onClear: onClearHospital,
          onActionPressed: onAddHospital,
          actionIcon: Icons.add_circle_outline,
          actionTooltip: 'Add new hospital',
        ),
        const SizedBox(height: 12),

        // Department Selector Tile
        AppointmentSelectorTile(
          icon: AppIcons.calendar,
          label: 'DEPARTMENT (OPTIONAL)',
          valueText: controller.selectedDepartment ?? 'Select department',
          isSet:
              controller.selectedDepartment != null &&
              controller.selectedDepartment!.isNotEmpty,
          onTap: onOpenDepartmentPicker,
          onClear: onClearDepartment,
        ),
        const SizedBox(height: AppSpacing.lg),

        // SECTION 3: DATE & TIME
        AppointmentDateTimePicker(
          selectedDate: controller.selectedDate,
          selectedTime: controller.selectedTime,
          reminderEnabled: controller.reminderEnabled,
          onPickDate: onPickDate,
          onPickTime: onPickTime,
          onReminderChanged: (val) {
            controller.reminderEnabled = val;
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // SECTION 4: NOTES
        Text(
          'NOTES',
          style: AppTypography.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller.notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Anything to remember for this visit...',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // SECTION 5: EXPENSE (OPTIONAL)
        AppointmentExpenseFields(
          costController: controller.costController,
          currency:
              controller.selectedCurrency ?? ref.watch(appCurrencyProvider),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // SAVE BUTTON
        PrimaryButton(
          text: isEditing ? 'UPDATE APPOINTMENT' : 'SAVE APPOINTMENT',
          icon: Icons.save,
          isLoading: isSaving,
          onPressed: onSave,
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
