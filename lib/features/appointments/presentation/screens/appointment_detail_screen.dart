import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../providers/appointment_providers.dart';
import '../widgets/detail/appointment_deletion_helper.dart';
import '../widgets/detail/appointment_linked_consultation_card.dart';
import '../widgets/detail/appointment_status_action_buttons.dart';
import '../widgets/detail/appointment_visit_details_card.dart';

/// AppointmentDetailScreen displays appointment details, doctor/hospital info,
/// date & time, reminders, status-driven actions, and edit/delete capabilities
/// using the shared MediCrate detail framework.
class AppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentAsync = ref.watch(
      appointmentDetailsProvider(appointmentId),
    );
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return appointmentAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: PulsingVaultLogo()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Appointment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.popOrGo(AppRoutes.appointments),
          ),
        ),
        body: AppErrorState(
          error: err,
          title: 'Unable to Load Appointment',
          onRetry: () =>
              ref.invalidate(appointmentDetailsProvider(appointmentId)),
        ),
      ),
      data: (appointment) {
        if (appointment == null) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              title: const Text('Appointment'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.popOrGo(AppRoutes.appointments),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Appointment not found.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.go(AppRoutes.appointments),
                    child: const Text('Back to Appointments'),
                  ),
                ],
              ),
            ),
          );
        }

        // Status styling resolution
        final semanticColors = context.semanticColors;
        final colorScheme = Theme.of(context).colorScheme;
        Color statusColor;
        Color statusBg;
        String statusLabel;

        switch (appointment.status.toLowerCase()) {
          case 'completed':
            statusColor = semanticColors.success;
            statusBg = semanticColors.successContainer;
            statusLabel = 'COMPLETED';
            break;
          case 'cancelled':
            statusColor = colorScheme.error;
            statusBg = colorScheme.errorContainer;
            statusLabel = 'CANCELLED';
            break;
          case 'missed':
            statusColor = colorScheme.error;
            statusBg = colorScheme.errorContainer;
            statusLabel = 'MISSED';
            break;
          default:
            statusColor = colorScheme.primary;
            statusBg = colorScheme.primaryContainer.withValues(alpha: 0.4);
            statusLabel = 'UPCOMING';
        }

        final formattedDateTime =
            '${dateFormat.format(appointment.date)} at ${timeFormat.format(appointment.date)}';

        final linkedConsultation = ref.watch(
          convertedConsultationForAppointmentProvider(appointment.id),
        );

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.popOrGo(AppRoutes.appointments),
            ),
            title: const Text('Appointment'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: DetailScreenScaffold(
              hero: DetailHero(
                icon: AppIcons.calendar,
                iconColor: statusColor,
                iconBackground: statusBg,
                title: appointment.title,
                subtitle: formattedDateTime,
                statusPill: DetailStatusPill(
                  label: statusLabel,
                  color: statusColor,
                  backgroundColor: statusBg,
                ),
              ),
              sections: [
                // 1. Linked Converted Consultation Section (State A)
                if (linkedConsultation != null)
                  DetailSection(
                    title: 'LINKED CONSULTATION',
                    topPadding: 16,
                    child: AppointmentLinkedConsultationCard(
                      consultation: linkedConsultation,
                    ),
                  ),

                // 2. Cancelled Explanation State (State B)
                if (appointment.isCancelled && linkedConsultation == null)
                  DetailSection(
                    title: 'CONVERSION',
                    topPadding: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Cancelled appointments can't be converted.",
                              style: AppTypography.caption.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Visit Details
                DetailSection(
                  title: 'VISIT DETAILS',
                  topPadding:
                      (linkedConsultation != null || appointment.isCancelled)
                      ? 8
                      : 16,
                  child: AppointmentVisitDetailsCard(
                    appointment: appointment,
                    formattedDateTime: formattedDateTime,
                  ),
                ),

                // 4. Notes Section
                if (appointment.notes != null && appointment.notes!.isNotEmpty)
                  DetailSection(
                    title: 'NOTES',
                    child: DetailNoteBox(
                      notes: appointment.notes,
                      fallbackText: 'No notes.',
                    ),
                  ),

                // 5. Status Action Buttons
                DetailSection(
                  title: 'ACTIONS',
                  child: AppointmentStatusActionButtons(
                    appointment: appointment,
                  ),
                ),
              ],
              actions: DetailActionRow(
                onEdit: () => context.pushGuarded(
                  AppRoutes.editAppointment(appointment.id),
                ),
                onDelete: () => AppointmentDeletionHelper.confirmDelete(
                  context,
                  ref,
                  appointment,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
