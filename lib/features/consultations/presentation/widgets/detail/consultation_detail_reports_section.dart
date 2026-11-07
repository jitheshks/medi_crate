import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';

class ConsultationDetailReportsSection extends ConsumerWidget {
  final ConsultationModel consultation;

  const ConsultationDetailReportsSection({
    super.key,
    required this.consultation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reportsAsync = ref.watch(
      consultationReportsProvider(consultation.id),
    );

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => DashedCard(
        child: Center(
          child: Text(
            'No reports linked with this consultation.',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return DashedCard(
            child: Center(
              child: Text(
                'No diagnostic reports linked with this consultation.',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }
        return Column(
          children: reports
              .map((r) => DetailLinkedReportCard(report: r))
              .toList(),
        );
      },
    );
  }
}
