import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// ExportRecordsScreen allows users to select export types and generate real PDF record files.
class ExportRecordsScreen extends ConsumerStatefulWidget {
  const ExportRecordsScreen({super.key});

  @override
  ConsumerState<ExportRecordsScreen> createState() =>
      _ExportRecordsScreenState();
}

class _ExportRecordsScreenState extends ConsumerState<ExportRecordsScreen> {
  final Map<String, bool> _selectedTypes = {
    'Consultation Summary': true,
    'Medical History': true,
    'Medicines': false,
    'Reports': false,
    'Appointments': true,
    'Complete Record': false,
  };

  bool _isGenerating = false;

  Future<void> _handleGeneratePdf() async {
    if (_isGenerating) return;

    final activeTypes = _selectedTypes.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (activeTypes.isEmpty) {
      context.showSnackBar('Please select at least one record type to export.');
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final authState = ref.read(authControllerProvider);
      final exportService = ref.read(exportServiceProvider);

      final pdfBytes = await exportService.generateHealthRecordsPdf(
        selectedTypes: activeTypes,
        userName: authState.user?.name ?? 'User',
        userEmail: authState.user?.email ?? '',
      );

      await exportService.previewOrPrintPdf(
        pdfBytes,
        'MediCrate_Health_Export.pdf',
      );
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(
          'Failed to generate PDF export: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SettingsSubScaffold(
      title: 'Export Health Records',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'PRIVACY WARNING: Exported PDF documents contain sensitive medical information. Keep exported files stored securely.',
                    style: AppTypography.caption.copyWith(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsGroupCard(
            title: 'Select Export Content',
            children: _selectedTypes.keys.map((type) {
              return CheckboxListTile(
                value: _selectedTypes[type],
                activeColor: colorScheme.primary,
                title: Text(
                  type,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                onChanged: (val) {
                  setState(() => _selectedTypes[type] = val ?? false);
                },
              );
            }).toList(),
          ),
          PrimaryButton(
            text: _isGenerating ? 'Generating PDF...' : 'Generate PDF Document',
            isLoading: _isGenerating,
            onPressed: _handleGeneratePdf,
          ),
        ],
      ),
    );
  }
}
