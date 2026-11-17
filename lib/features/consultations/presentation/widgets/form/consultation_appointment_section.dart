import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../../core/utils/id_utils.dart';
import '../../../../appointments/data/models/appointment_model.dart';
import '../../../../appointments/presentation/providers/appointment_providers.dart';
import '../../providers/consultation_form_providers.dart';
import '../appointment_picker_sheet.dart';
import '../consultation_section_header.dart';
import '../consultation_selection_tile.dart';

class ConsultationAppointmentSection extends ConsumerWidget {
  final TextEditingController feeController;
  final bool isEditing;

  const ConsultationAppointmentSection({
    super.key,
    required this.feeController,
    this.isEditing = false,
  });

  void _openAppointmentPicker(
    BuildContext context,
    WidgetRef ref,
    String? currentAppointmentId,
  ) {
    AppointmentPickerSheet.show(
      context: context,
      currentAppointmentId: currentAppointmentId,
      onSelected: (AppointmentModel app) {
        ref.read(selectedAppointmentIdProvider.notifier).state = app.id;

        // Auto-fill overlapping fields from the selected appointment
        if (app.doctorName.isNotEmpty) {
          ref.read(selectedDoctorProvider.notifier).state = app.doctorName;
        }
        if (app.doctorId != null && app.doctorId!.isNotEmpty) {
          ref.read(selectedDoctorIdProvider.notifier).state = IdUtils.unprefix(
            app.doctorId!,
          );
        }
        if (app.doctorSpecialty != null && app.doctorSpecialty!.isNotEmpty) {
          ref.read(selectedDoctorSpecialtyProvider.notifier).state =
              app.doctorSpecialty;
        }
        if (app.hospitalName != null && app.hospitalName!.isNotEmpty) {
          ref.read(selectedHospitalProvider.notifier).state = app.hospitalName;
        }
        if (app.hospitalId != null && app.hospitalId!.isNotEmpty) {
          ref.read(selectedHospitalIdProvider.notifier).state =
              IdUtils.unprefix(app.hospitalId!);
        }
        if (app.department != null && app.department!.isNotEmpty) {
          ref.read(selectedDepartmentProvider.notifier).state = app.department;
        }
        if (app.departmentId != null && app.departmentId!.isNotEmpty) {
          ref.read(selectedDepartmentIdProvider.notifier).state =
              IdUtils.unprefix(app.departmentId!);
        }
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final appDateOnly = DateTime(
          app.date.year,
          app.date.month,
          app.date.day,
        );
        if (!appDateOnly.isAfter(today)) {
          ref.read(visitDateProvider.notifier).state = app.date;
          ref.read(visitTimeProvider.notifier).state = TimeOfDay(
            hour: app.date.hour,
            minute: app.date.minute,
          );
        }
        if (app.cost != null && app.cost! > 0) {
          feeController.text = app.cost! % 1 == 0
              ? app.cost!.toInt().toString()
              : app.cost!.toString();
        }
        if (app.currency.isNotEmpty) {
          ref.read(selectedCurrencyProvider.notifier).state = app.currency;
        }
        // Note: chiefComplaint and diagnosis are NEVER auto-filled.
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedAppointmentId = ref.watch(selectedAppointmentIdProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    AppointmentModel? linkedAppointment;
    if (selectedAppointmentId != null && selectedAppointmentId.isNotEmpty) {
      final appointments = ref.watch(appointmentsListProvider).value ?? [];
      linkedAppointment = appointments
          .where((a) => IdUtils.matches(a.id, selectedAppointmentId))
          .firstOrNull;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ConsultationSectionHeader(label: 'Linked Appointment (Optional)'),
        if (selectedAppointmentId != null && selectedAppointmentId.isNotEmpty)
          _buildLinkedCard(
            context,
            ref,
            theme,
            colorScheme,
            selectedAppointmentId,
            linkedAppointment,
          )
        else
          ConsultationSelectionTile(
            icon: AppIcons.calendar,
            label: 'Scheduled Appointment',
            value: null,
            placeholder: 'Link an appointment to prefill details',
            onTap: () => _openAppointmentPicker(context, ref, null),
          ),
      ],
    );
  }

  Widget _buildLinkedCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme colorScheme,
    String appointmentId,
    AppointmentModel? appointment,
  ) {
    final title = appointment?.title.isNotEmpty == true
        ? appointment!.title
        : 'Linked Appointment';
    final subtitle = appointment != null
        ? '${appointment.doctorName} • ${DateFormat("MMM d, yyyy").format(appointment.date)}'
        : 'ID: $appointmentId';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppIcons.calendar,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'LINKED APPOINTMENT',
                      style: AppTypography.labelSmall.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.link, size: 14, color: colorScheme.primary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.link_off, color: colorScheme.error, size: 22),
            tooltip: 'Unlink appointment',
            onPressed: () {
              // Rule 12: Unlinking removes only the relationship and does not revert fields
              ref.read(selectedAppointmentIdProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}
