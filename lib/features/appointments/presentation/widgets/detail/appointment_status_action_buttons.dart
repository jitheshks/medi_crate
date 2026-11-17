import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../consultations/data/models/consultation_model.dart';
import '../../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../data/models/appointment_model.dart';
import '../../providers/appointment_providers.dart';

class AppointmentStatusActionButtons extends StatelessWidget {
  final AppointmentModel appointment;

  const AppointmentStatusActionButtons({super.key, required this.appointment});

  void _navigateToConvert(BuildContext context) {
    final timeFormat = DateFormat('hh:mm a');
    final formattedTime = timeFormat.format(appointment.date);

    final prefillConsultation = ConsultationModel(
      id: '',
      profileId: appointment.profileId,
      appointmentId: appointment.id,
      doctorId: appointment.doctorId,
      doctorName: appointment.doctorName,
      doctorSpecialty: appointment.doctorSpecialty,
      hospitalId: appointment.hospitalId,
      hospitalName: appointment.hospitalName,
      departmentId: appointment.departmentId,
      department: appointment.department,
      visitDate: appointment.date,
      visitTime: formattedTime,
      chiefComplaint: '',
      diagnosis: '',
      consultationFee: appointment.cost,
      currency: appointment.currency,
      createdAt: DateTime.now(),
    );

    context.pushGuarded(AppRoutes.newConsultation, extra: prefillConsultation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors = context.semanticColors;

    return Consumer(
      builder: (context, ref, child) {
        final convertedConsultation = ref.watch(
          convertedConsultationForAppointmentProvider(appointment.id),
        );
        final isConverted = convertedConsultation != null;

        if (appointment.isUpcoming) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(appointmentsListProvider.notifier)
                            .updateStatus(appointment.id, 'completed');
                        if (context.mounted) {
                          context.popOrGo(AppRoutes.appointments);
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: semanticColors.success,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(appointmentsListProvider.notifier)
                            .updateStatus(appointment.id, 'cancelled');
                        if (context.mounted) {
                          context.popOrGo(AppRoutes.appointments);
                        }
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Visit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (!isConverted) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _navigateToConvert(context),
                  icon: const Icon(Icons.medical_services_outlined, size: 18),
                  label: const Text('Convert to Consultation'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    side: BorderSide(color: colorScheme.primary),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ],
            ],
          );
        } else if (appointment.isCompleted) {
          return Column(
            children: [
              if (!isConverted) ...[
                ElevatedButton.icon(
                  onPressed: () => _navigateToConvert(context),
                  icon: const Icon(Icons.medical_services_outlined, size: 18),
                  label: const Text('Create Consultation for this visit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  await ref
                      .read(appointmentsListProvider.notifier)
                      .updateStatus(appointment.id, 'upcoming');
                  if (context.mounted) {
                    context.popOrGo(AppRoutes.appointments);
                  }
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reopen Appointment'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.primary,
                  side: BorderSide(color: colorScheme.primary),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          );
        } else {
          return ElevatedButton.icon(
            onPressed: () {
              context.pushGuarded(AppRoutes.editAppointment(appointment.id));
            },
            icon: const Icon(Icons.edit_calendar, size: 18),
            label: const Text('Reschedule Appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          );
        }
      },
    );
  }
}
