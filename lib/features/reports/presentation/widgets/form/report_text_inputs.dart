import 'package:flutter/material.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';

class ReportTitleField extends StatelessWidget {
  final TextEditingController controller;

  const ReportTitleField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REPORT TITLE *',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'e.g. Complete Blood Count (CBC)',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Report title is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}

class ReportNotesField extends StatelessWidget {
  final TextEditingController controller;

  const ReportNotesField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Any notes or medical comments about this report...',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
            ),
          ),
        ),
      ],
    );
  }
}
