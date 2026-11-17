import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_icons.dart';
import '../../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../data/models/consultation_model.dart';

class ConsultationDetailVisitCard extends ConsumerWidget {
  final ConsultationModel consultation;

  const ConsultationDetailVisitCard({super.key, required this.consultation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve doctor name & specialty
    String doctorDisplay = '—';
    if (consultation.doctorId != null &&
        consultation.doctorId!.trim().isNotEmpty) {
      final docAsync = ref.watch(doctorDetailsProvider(consultation.doctorId!));
      final resolvedName = docAsync.value?.name;
      final resolvedSpecialty = docAsync.value?.specialty;
      if (resolvedName != null && resolvedName.isNotEmpty) {
        doctorDisplay =
            (resolvedSpecialty != null && resolvedSpecialty.isNotEmpty)
            ? '$resolvedName · $resolvedSpecialty'
            : resolvedName;
      }
    }
    if (doctorDisplay == '—' && consultation.doctorName.trim().isNotEmpty) {
      final spec = consultation.doctorSpecialty;
      doctorDisplay = (spec != null && spec.trim().isNotEmpty)
          ? '${consultation.doctorName} · $spec'
          : consultation.doctorName;
    }

    // Resolve hospital name
    String hospitalDisplay = '—';
    if (consultation.hospitalId != null &&
        consultation.hospitalId!.trim().isNotEmpty) {
      final hospitalsList = ref.watch(hospitalsListProvider).value ?? [];
      final match = hospitalsList
          .where((h) => h.id == consultation.hospitalId)
          .firstOrNull;
      if (match != null && match.name.isNotEmpty) {
        hospitalDisplay = match.name;
      }
    }
    if (hospitalDisplay == '—' &&
        consultation.hospitalName != null &&
        consultation.hospitalName!.trim().isNotEmpty) {
      hospitalDisplay = consultation.hospitalName!;
    }

    // Resolve department
    final departmentDisplay =
        (consultation.department != null &&
            consultation.department!.trim().isNotEmpty)
        ? consultation.department!.trim()
        : '—';

    return DetailInfoCard(
      rows: [
        DetailInfoRow(
          icon: AppIcons.userCheck,
          label: 'DOCTOR',
          value: doctorDisplay,
          showDivider: true,
        ),
        DetailInfoRow(
          icon: AppIcons.hospital,
          label: 'HOSPITAL',
          value: hospitalDisplay,
          showDivider: true,
        ),
        DetailInfoRow(
          icon: Icons.domain_outlined,
          label: 'DEPARTMENT',
          value: departmentDisplay,
          showDivider: false,
        ),
      ],
    );
  }
}
