import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../settings/presentation/providers/settings_providers.dart';
import '../../providers/consultation_form_providers.dart';
import '../consultation_section_header.dart';

class ConsultationTagsExpenseSection extends ConsumerWidget {
  final TextEditingController tagsController;
  final TextEditingController feeController;
  final List<String> parsedTags;

  const ConsultationTagsExpenseSection({
    super.key,
    required this.tagsController,
    required this.feeController,
    required this.parsedTags,
  });

  InputDecoration _buildInputDecoration(
    BuildContext context, {
    required String hintText,
    String? prefixText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      prefixStyle: AppTypography.bodyMedium.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
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
    final globalCurrency = ref.watch(appCurrencyProvider);
    final selectedCurrency =
        ref.watch(selectedCurrencyProvider) ?? globalCurrency;
    final currencyCode = selectedCurrency.toUpperCase();
    final currencySymbol = AppCurrency.getSymbol(selectedCurrency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 7. TAGS SECTION
        const ConsultationSectionHeader(label: 'Tags (Optional)'),
        TextFormField(
          controller: tagsController,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: _buildInputDecoration(
            context,
            hintText: 'Cardiology, Diabetes, Blood Pressure',
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Comma-separated tags',
            style: AppTypography.caption.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        if (parsedTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: parsedTags.map((tag) {
              return Chip(
                label: Text(
                  tag,
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: colorScheme.primaryContainer,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 20),

        // 8. EXPENSE SECTION
        const ConsultationSectionHeader(label: 'Expense (Optional)'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONSULTATION FEE ($currencyCode)',
              style: AppTypography.labelSmall.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 10.5,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: feeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: colorScheme.onSurface),
              decoration: _buildInputDecoration(
                context,
                hintText: 'e.g. 800',
                prefixText: '$currencySymbol   ',
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                'Change your currency in Settings → Currency.',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
