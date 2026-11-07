import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../data/models/medicine_model.dart';
import '../providers/medicine_providers.dart';

/// MedicineDetailScreen displays medicine schedule, dosages, linked consultations,
/// notes, and management actions using the shared MediCrate detail framework.
class MedicineDetailScreen extends ConsumerWidget {
  final String medicineId;

  const MedicineDetailScreen({super.key, required this.medicineId});

  String _formatDate(DateTime d) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _handleDelete(
    BuildContext context,
    WidgetRef ref,
    MedicineModel medicine,
  ) async {
    final confirmed = await DeletionImpactDialog.showReassuranceDelete(
      context,
      title: 'Delete this medicine?',
      recordName: medicine.medicineName,
      recordType: 'Medicine',
      reassuranceMessage: 'This will remove the medicine record only.\nThe linked consultation will remain unchanged.',
      onConfirm: () {},
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(medicinesListNotifierProvider.notifier)
            .deleteMedicine(medicine.id);

        if (context.mounted) {
          context.showSuccessSnackBar('Medicine deleted');
          context.popOrGo(AppRoutes.medicines);
        }
      } on AppException catch (appErr) {
        if (context.mounted) {
          context.showErrorSnackBar(appErr.message);
        }
      } catch (_) {
        if (context.mounted) {
          context.showErrorSnackBar(
            "Couldn't delete medicine. Please try again.",
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final medicineAsync = ref.watch(medicineDetailProvider(medicineId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft),
          onPressed: () => context.popOrGo(AppRoutes.medicines),
        ),
        title: const Text('Medicine Details'),
      ),
      body: SafeArea(
        child: medicineAsync.when(
          loading: () => const Center(child: PulsingVaultLogo()),
          error: (err, stack) => AppErrorState(
            error: err,
            title: 'Unable to Load Medicine',
            onRetry: () => ref.invalidate(medicineDetailProvider(medicineId)),
          ),
          data: (medicine) {
            if (medicine == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Medicine record not found'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.medicines),
                      child: const Text('Back to Medicines'),
                    ),
                  ],
                ),
              );
            }

            final isActive = medicine.isActive;
            final statusBgColor = isActive
                ? context.semanticColors.successContainer
                : colorScheme.surfaceContainerHighest;
            final statusTextColor = isActive
                ? context.semanticColors.success
                : colorScheme.onSurfaceVariant;

            final subtitle = [
              medicine.dosage,
              if (medicine.form != null && medicine.form!.isNotEmpty)
                medicine.form,
            ].join(' · ');

            return DetailScreenScaffold(
              hero: DetailHero(
                icon: AppIcons.pill,
                iconColor: context.semanticColors.medicineAccent,
                iconBackground: context.semanticColors.medicineAccentContainer,
                title: medicine.medicineName,
                subtitle: subtitle,
                statusPill: DetailStatusPill(
                  label: medicine.status,
                  color: statusTextColor,
                  backgroundColor: statusBgColor,
                ),
              ),
              sections: [
                // 1. Schedule Details
                DetailSection(
                  title: 'SCHEDULE DETAILS',
                  topPadding: 16,
                  child: DetailInfoCard(
                    rows: [
                      DetailInfoRow(
                        icon: AppIcons.calendar,
                        label: 'FREQUENCY',
                        value: medicine.frequency ?? 'Not specified',
                        showDivider: true,
                      ),
                      DetailInfoRow(
                        icon: AppIcons.calendar,
                        label: 'START DATE',
                        value: _formatDate(medicine.startDate),
                        showDivider: true,
                      ),
                      DetailInfoRow(
                        icon: AppIcons.calendar,
                        label: 'END DATE',
                        value: medicine.endDate != null
                            ? _formatDate(medicine.endDate!)
                            : 'Ongoing',
                        showDivider: true,
                      ),
                      DetailInfoRow(
                        icon: AppIcons.bell,
                        label: 'REMINDER',
                        value: medicine.reminder ? 'ON' : 'OFF',
                        valueColor: medicine.reminder
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),

                // 2. Linked Consultation (If set)
                if (medicine.linkedConsultationTitle != null ||
                    medicine.linkedConsultationId != null)
                  DetailSection(
                    title: 'PRESCRIBED AT',
                    child: DetailLinkedRecordCard(
                      title:
                          medicine.linkedConsultationTitle ??
                          'Consultation Record',
                      subtitle: 'Prescribed consultation',
                      onTap: () {
                        if (medicine.linkedConsultationId != null) {
                          context.pushGuarded(
                            AppRoutes.consultationDetail(
                              medicine.linkedConsultationId!,
                            ),
                          );
                        } else {
                          context.pushGuarded(AppRoutes.consultations);
                        }
                      },
                    ),
                  ),

                // 3. Notes (If set)
                if (medicine.notes != null && medicine.notes!.isNotEmpty)
                  DetailSection(
                    title: 'NOTES',
                    child: DetailNoteBox(
                      notes: medicine.notes,
                      fallbackText: 'No notes.',
                    ),
                  ),
              ],
              actions: DetailActionRow(
                onEdit: () =>
                    context.pushGuarded(AppRoutes.editMedicine(medicine.id)),
                onDelete: () => _handleDelete(context, ref, medicine),
              ),
            );
          },
        ),
      ),
    );
  }
}
