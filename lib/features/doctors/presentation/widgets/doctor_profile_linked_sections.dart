import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../data/models/doctor_hospital_relation.dart';
import '../../data/models/doctor_model.dart';
import '../providers/doctors_providers.dart';

class DoctorProfileHospitalsSection extends ConsumerWidget {
  final DoctorModel doctor;

  const DoctorProfileHospitalsSection({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorHospitalsAsync = ref.watch(doctorHospitalsProvider(doctor));

    return doctorHospitalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => _buildHospitalFallback(doctor),
      data: (practicingList) {
        if (practicingList.isEmpty) {
          return _buildHospitalFallback(doctor);
        }
        return Column(
          children: practicingList
              .map((item) => _buildHospitalTile(context, item))
              .toList(),
        );
      },
    );
  }

  Widget _buildHospitalTile(BuildContext context, PracticingHospitalInfo item) {
    final hospital = item.hospital;
    final semanticColors = context.semanticColors;
    final subtitleText =
        hospital.address != null && hospital.address!.isNotEmpty
        ? hospital.address!
        : (hospital.type ?? 'Facility');

    return DetailLinkedRecordCard(
      title: hospital.name,
      subtitle: '$subtitleText • ${item.relationshipLabel}',
      onTap: () => context.pushGuarded(AppRoutes.hospitalProfile(hospital.id)),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: semanticColors.hospitalAccentContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          AppIcons.hospital,
          color: semanticColors.hospitalAccent,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildHospitalFallback(DoctorModel doctor) {
    final fallbackName = doctor.hospitalName;
    return DetailNoteBox(
      notes: (fallbackName != null && fallbackName.isNotEmpty) ? fallbackName : null,
      fallbackText: 'No affiliated hospitals recorded.',
    );
  }
}

class DoctorProfileContactSection extends StatelessWidget {
  final DoctorModel doctor;

  const DoctorProfileContactSection({super.key, required this.doctor});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (doctor.phone != null && doctor.phone!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.phone,
          label: 'PHONE',
          value: doctor.phone!,
          showDivider: doctor.email != null && doctor.email!.isNotEmpty,
        ),
      );
    }

    if (doctor.email != null && doctor.email!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.mail,
          label: 'EMAIL',
          value: doctor.email!,
          showDivider: false,
        ),
      );
    }

    if (rows.isEmpty) {
      return const DetailNoteBox(
        notes: null,
        fallbackText: 'No phone or email recorded.',
      );
    }

    return DetailInfoCard(rows: rows);
  }
}

class DoctorProfileConsultationsSection extends ConsumerWidget {
  final DoctorModel doctor;

  const DoctorProfileConsultationsSection({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(doctorConsultationsProvider(doctor));

    return consultationsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const DetailNoteBox(
        notes: null,
        fallbackText: 'No consultations logged.',
      ),
      data: (consultations) {
        if (consultations.isEmpty) {
          return DetailNoteBox(
            notes: null,
            fallbackText: 'No consultations logged with ${doctor.name}.',
          );
        }
        return Column(
          children: consultations
              .map(
                (c) => DetailLinkedConsultationCard(
                  consultation: c,
                  contextLabel: c.hospitalName ?? 'Clinic',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DoctorProfileAppointmentsSection extends ConsumerWidget {
  final DoctorModel doctor;

  const DoctorProfileAppointmentsSection({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(doctorAppointmentsProvider(doctor));

    return appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const DetailNoteBox(
        notes: null,
        fallbackText: 'No appointments scheduled.',
      ),
      data: (appointments) {
        if (appointments.isEmpty) {
          return DetailNoteBox(
            notes: null,
            fallbackText: 'No appointments scheduled with ${doctor.name}.',
          );
        }
        return Column(
          children: appointments
              .map(
                (a) => DetailLinkedAppointmentCard(
                  appointment: a,
                  contextLabel:
                      (a.hospitalName != null && a.hospitalName!.isNotEmpty)
                      ? a.hospitalName
                      : null,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DoctorProfileReportsSection extends ConsumerWidget {
  final DoctorModel doctor;

  const DoctorProfileReportsSection({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(doctorReportsProvider(doctor));

    return reportsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const DetailNoteBox(
        notes: null,
        fallbackText: 'No reports recorded.',
      ),
      data: (reports) {
        if (reports.isEmpty) {
          return DetailNoteBox(
            notes: null,
            fallbackText: 'No medical reports associated with ${doctor.name}.',
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
