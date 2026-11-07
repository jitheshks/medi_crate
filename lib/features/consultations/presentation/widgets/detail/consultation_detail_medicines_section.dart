import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/routes/app_routes.dart';
import '../../../../../core/constants/app_icons.dart';
import '../../../../../core/extensions/build_context_extensions.dart';
import '../../../../../core/theme/app_semantic_colors.dart';
import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../medicines/data/models/medicine_model.dart';
import '../../../data/models/consultation_model.dart';
import '../../providers/consultation_providers.dart';

class ConsultationDetailMedicinesSection extends ConsumerWidget {
  final ConsultationModel consultation;

  const ConsultationDetailMedicinesSection({
    super.key,
    required this.consultation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(
      consultationMedicinesProvider(consultation.id),
    );

    return medicinesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Text('Failed to load medicines'),
      data: (medicines) {
        if (medicines.isEmpty) {
          return const Text('No linked medicines.');
        }

        return Column(
          children: medicines
              .map((m) => _buildMedicineCard(context, m))
              .toList(),
        );
      },
    );
  }

  Widget _buildMedicineCard(BuildContext context, MedicineModel medicine) {
    final semanticColors = context.semanticColors;
    final subtitle = [
      medicine.dosage,
      if (medicine.frequency != null && medicine.frequency!.isNotEmpty)
        medicine.frequency,
      if (medicine.form != null && medicine.form!.isNotEmpty) medicine.form,
    ].where((e) => e != null && e.isNotEmpty).join(' · ');

    return DetailLinkedRecordCard(
      title: medicine.medicineName,
      subtitle: subtitle.isNotEmpty ? subtitle : 'Medication schedule',
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: semanticColors.medicineAccentContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          AppIcons.pill,
          color: semanticColors.medicineAccent,
          size: 20,
        ),
      ),
      onTap: () => context.pushGuarded(AppRoutes.medicineDetail(medicine.id)),
    );
  }
}
