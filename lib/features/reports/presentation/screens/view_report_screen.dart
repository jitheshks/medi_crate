import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_currency.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../data/models/report_model.dart';
import '../providers/reports_providers.dart';
import '../widgets/report_attachment_row.dart';
import '../widgets/report_type_badge.dart';

/// ViewReportScreen renders complete details of a single report, including linked consultation,
/// doctor & hospital details, notes, file attachments, associated expenses, and edit/delete actions
/// using the shared MediVault detail framework.
class ViewReportScreen extends ConsumerWidget {
  final String reportId;

  const ViewReportScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportStateAsync = ref.watch(viewReportProvider(reportId));
    final colorScheme = Theme.of(context).colorScheme;
    final currentReport = reportStateAsync.value?.report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.popOrGo(AppRoutes.reports),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Report',
            onPressed: currentReport == null
                ? null
                : () => _confirmDelete(context, ref, currentReport),
          ),
        ],
      ),
      body: reportStateAsync.when(
        data: (state) {
          if (state == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Report not found',
                    style: AppTypography.h2.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.popOrGo(AppRoutes.reports),
                    child: const Text('Back to Reports'),
                  ),
                ],
              ),
            );
          }

          final report = state.report;
          final formattedDate = DateFormat('d MMM yyyy').format(report.date);
          final categoryColor = ReportTypeBadge.categoryColor(
            report.category,
            context,
          );
          final categoryIcon = ReportTypeBadge.categoryIcon(report.category);
          final doctorText =
              (report.doctorName != null &&
                  report.doctorName!.trim().isNotEmpty)
              ? report.doctorName!
              : 'Unassigned';
          final hospitalText =
              (report.hospitalName != null &&
                  report.hospitalName!.trim().isNotEmpty)
              ? report.hospitalName!
              : 'Unassigned';

          return DetailScreenScaffold(
            hero: DetailHero(
              icon: categoryIcon,
              iconColor: categoryColor,
              iconBackground: categoryColor.withValues(alpha: 0.1),
              title: report.title,
              subtitle: formattedDate,
              badge: ReportTypeBadge(category: report.category),
              iconBoxRadius: 22,
              iconSize: 36,
              iconBoxSize: 72,
            ),
            sections: [
              // 1. Linked Consultation (If linked)
              if (state.linkedConsultationTitle != null ||
                  report.consultationId != null)
                DetailSection(
                  title: 'LINKED CONSULTATION',
                  topPadding: 16,
                  child: DetailLinkedRecordCard(
                    title:
                        state.linkedConsultationTitle ?? 'Consultation Record',
                    subtitle:
                        '${state.linkedConsultationDate ?? formattedDate} · ${state.linkedConsultationDoctor ?? doctorText}',
                    onTap: () {
                      if (report.consultationId != null) {
                        context.pushGuarded(
                          AppRoutes.consultationDetail(report.consultationId!),
                        );
                      } else {
                        context.pushGuarded(AppRoutes.consultations);
                      }
                    },
                  ),
                ),

              // 2. Doctor & Hospital Grouped Card
              DetailSection(
                title: 'DOCTOR & HOSPITAL',
                child: DetailInfoCard(
                  rows: [
                    DetailInfoRow(
                      icon: AppIcons.stethoscope,
                      label: 'DOCTOR',
                      value: doctorText,
                      showDivider: true,
                    ),
                    DetailInfoRow(
                      icon: AppIcons.hospital,
                      label: 'HOSPITAL',
                      value: hospitalText,
                      showDivider: false,
                    ),
                  ],
                ),
              ),

              // 3. Notes Card
              DetailSection(
                title: 'NOTES',
                child: DetailNoteBox(
                  notes: report.notes,
                  fallbackText: 'No notes.',
                ),
              ),

              // 4. Attachments Card
              DetailSection(
                title: 'ATTACHMENTS (${report.attachments.length})',
                child: report.attachments.isEmpty
                    ? DashedCard(
                        child: Center(
                          child: Text(
                            'No attachments on this report.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : DetailInfoCard(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        rows: report.attachments
                            .map(
                              (att) => ReportAttachmentRow(
                                attachment: att,
                                reportId: report.id,
                                profileId: report.profileId,
                              ),
                            )
                            .toList(),
                      ),
              ),

              // 5. Expense Card (If present)
              if (report.expense != null)
                DetailSection(
                  title: 'EXPENSE',
                  child: DetailExpenseCard(
                    amountText:
                        '${AppCurrency.getSymbol(report.expense!.currency)} ${report.expense!.amount.toStringAsFixed(0)}',
                    category:
                        report.expense!.description ?? 'Test / document cost',
                    status: report.expense!.status.toUpperCase(),
                    statusColor: _getExpenseStatusFg(
                      context,
                      report.expense!.status,
                    ),
                    statusBackgroundColor: _getExpenseStatusBg(
                      context,
                      report.expense!.status,
                    ),
                  ),
                ),
            ],
            actions: DetailActionRow(
              onEdit: () =>
                  context.pushGuarded(AppRoutes.editReport(report.id)),
              onDelete: () => _confirmDelete(context, ref, report),
            ),
          );
        },
        loading: () => const Center(child: PulsingVaultLogo()),
        error: (err, stack) => AppErrorState(
          error: err,
          title: 'Unable to Load Report',
          onRetry: () => ref.invalidate(viewReportProvider(reportId)),
        ),
      ),
    );
  }

  Color _getExpenseStatusBg(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return context.semanticColors.successContainer;
      case 'pending':
        return context.semanticColors.warningContainer;
      case 'unpaid':
      default:
        return Theme.of(context).colorScheme.errorContainer;
    }
  }

  Color _getExpenseStatusFg(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return context.semanticColors.success;
      case 'pending':
        return context.semanticColors.vitalTemperature;
      case 'unpaid':
      default:
        return Theme.of(context).colorScheme.error;
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ReportModel report,
  ) async {
    final confirmed = await DeletionImpactDialog.showReassuranceDelete(
      context,
      title: 'Delete this report?',
      recordName: report.title,
      recordType: 'Report',
      reassuranceMessage:
          'Deleting this report will not delete the linked doctor, hospital, or consultation.',
      onConfirm: () {},
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(reportsListNotifierProvider.notifier)
            .deleteReport(report.id);

        if (context.mounted) {
          context.showSnackBar('Report deleted');
          context.popOrGo(AppRoutes.reports);
        }
      } catch (_) {
        if (context.mounted) {
          context.showErrorSnackBar(
            "Couldn't delete report. Please try again.",
          );
        }
      }
    }
  }
}
