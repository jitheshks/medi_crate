import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/export/export_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/doctor_summary_model.dart';

enum _DoctorSummaryExportAction { none, share, print }

/// Renders the sticky bottom action buttons (Share Summary and Print) for Doctor Summary
/// and manages the local, transient export loading and error feedback state.
class DoctorSummaryBottomBar extends ConsumerStatefulWidget {
  final int selectedCount;
  final DoctorSummaryModel summary;
  final dynamic profile;
  final String? dateLabel;

  const DoctorSummaryBottomBar({
    super.key,
    required this.selectedCount,
    required this.summary,
    required this.profile,
    this.dateLabel,
  });

  @override
  ConsumerState<DoctorSummaryBottomBar> createState() =>
      _DoctorSummaryBottomBarState();
}

class _DoctorSummaryBottomBarState
    extends ConsumerState<DoctorSummaryBottomBar> {
  _DoctorSummaryExportAction _exportingAction = _DoctorSummaryExportAction.none;

  Future<void> _handleExport(_DoctorSummaryExportAction action) async {
    if (_exportingAction != _DoctorSummaryExportAction.none) return;
    setState(() => _exportingAction = action);
    try {
      final hive = ref.read(hiveServiceProvider);
      final exportService = ExportService(hiveService: hive);
      final pdfBytes = await exportService.generateDoctorSummaryPdf(
        widget.summary,
        dateRangeLabel: widget.dateLabel,
      );
      final fullName = widget.profile?.fullName?.toString() ?? 'Patient';
      final filename =
          'MediVault_Doctor_Summary_${fullName.replaceAll(" ", "_")}.pdf';
      if (action == _DoctorSummaryExportAction.print) {
        await exportService.previewOrPrintPdf(pdfBytes, filename);
      } else if (action == _DoctorSummaryExportAction.share) {
        await exportService.sharePdf(pdfBytes, filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF summary: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _exportingAction = _DoctorSummaryExportAction.none);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExportingShare =
        _exportingAction == _DoctorSummaryExportAction.share;
    final isExportingPrint =
        _exportingAction == _DoctorSummaryExportAction.print;
    final isBusy = isExportingShare || isExportingPrint;
    final canExport = widget.selectedCount > 0 && !isBusy;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canExport
                      ? () => _handleExport(_DoctorSummaryExportAction.share)
                      : null,
                  icon: isExportingShare
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : const Icon(Icons.share_outlined, size: 18),
                  label: const Text(
                    'SHARE SUMMARY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canExport
                      ? () => _handleExport(_DoctorSummaryExportAction.print)
                      : null,
                  icon: isExportingPrint
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: const Text(
                    'PRINT',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
