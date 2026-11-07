import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../consultations/data/models/consultation_model.dart';

class LinkedConsultationCard extends StatelessWidget {
  final AsyncValue<List<ConsultationModel>> consultationsAsync;
  final String? consultationId;
  final String? consultationTitle;
  final VoidCallback onOpenConsultationPicker;
  final VoidCallback onClearConsultation;

  const LinkedConsultationCard({
    super.key,
    required this.consultationsAsync,
    required this.consultationId,
    required this.consultationTitle,
    required this.onOpenConsultationPicker,
    required this.onClearConsultation,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLinked = consultationId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LINKED CONSULTATION',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        consultationsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (err, stack) => const SizedBox.shrink(),
          data: (consultations) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    side: BorderSide(
                      color: isLinked
                          ? colorScheme.primary
                          : colorScheme.outline,
                    ),
                  ),
                  color: colorScheme.surface,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    onTap: onOpenConsultationPicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.fileText,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Consultation',
                                  style: AppTypography.caption.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  consultationTitle ?? 'Not linked',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isLinked
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLinked)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: onClearConsultation,
                            )
                          else
                            Icon(
                              Icons.arrow_drop_down,
                              color: colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isLinked) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Auto-filled from this consultation — tap either field to change it.',
                            style: AppTypography.caption.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
