import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../doctors/presentation/widgets/doctor_card.dart';
import '../../data/models/hospital_model.dart';
import '../providers/hospitals_providers.dart';

class HospitalProfileContactSection extends StatelessWidget {
  final HospitalModel hospital;

  const HospitalProfileContactSection({super.key, required this.hospital});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final hospitalAccent = context.semanticColors.hospitalAccent;

    if (hospital.address != null && hospital.address!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: Icons.location_on_outlined,
          iconColor: hospitalAccent,
          label: 'ADDRESS',
          value: hospital.address!,
          showDivider:
              (hospital.phone != null && hospital.phone!.isNotEmpty) ||
              (hospital.email != null && hospital.email!.isNotEmpty),
        ),
      );
    }

    if (hospital.phone != null && hospital.phone!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.phone,
          iconColor: hospitalAccent,
          label: 'PHONE',
          value: hospital.phone!,
          showDivider: hospital.email != null && hospital.email!.isNotEmpty,
        ),
      );
    }

    if (hospital.email != null && hospital.email!.isNotEmpty) {
      rows.add(
        DetailInfoRow(
          icon: AppIcons.mail,
          iconColor: hospitalAccent,
          label: 'EMAIL',
          value: hospital.email!,
          showDivider: false,
        ),
      );
    }

    if (rows.isEmpty) {
      return const DetailNoteBox(
        notes: null,
        fallbackText: 'No facility contact details recorded.',
      );
    }

    return DetailInfoCard(rows: rows);
  }
}

class HospitalProfileAssociatedDoctorsSection extends ConsumerWidget {
  final String hospitalId;

  const HospitalProfileAssociatedDoctorsSection({
    super.key,
    required this.hospitalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doctorsAsync = ref.watch(hospitalDoctorsProvider(hospitalId));

    return doctorsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const DetailNoteBox(
        notes: null,
        fallbackText: 'No doctors linked yet.',
      ),
      data: (doctors) {
        if (doctors.isEmpty) {
          return const DetailNoteBox(
            notes: null,
            fallbackText: 'No doctors linked to this facility yet.',
          );
        }
        return Column(
          children: doctors
              .map(
                (doc) => DoctorCard(
                  doctor: doc,
                  onTap: () =>
                      context.pushGuarded(AppRoutes.doctorProfile(doc.id)),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class HospitalProfileConsultationsSection extends ConsumerWidget {
  final HospitalModel hospital;

  const HospitalProfileConsultationsSection({
    super.key,
    required this.hospital,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consultationsAsync = ref.watch(
      hospitalConsultationsProvider(hospital),
    );

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
            fallbackText: 'No consultations logged at ${hospital.name}.',
          );
        }
        return Column(
          children: consultations
              .map(
                (c) => DetailLinkedConsultationCard(
                  consultation: c,
                  contextLabel:
                      c.doctorName.isNotEmpty ? c.doctorName : 'Doctor',
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class HospitalProfileAppointmentsSection extends ConsumerWidget {
  final HospitalModel hospital;

  const HospitalProfileAppointmentsSection({super.key, required this.hospital});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(hospitalAppointmentsProvider(hospital));

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
            fallbackText: 'No appointments scheduled at ${hospital.name}.',
          );
        }
        return Column(
          children: appointments
              .map(
                (a) => DetailLinkedAppointmentCard(
                  appointment: a,
                  contextLabel:
                      a.doctorName.isNotEmpty ? a.doctorName : null,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class HospitalProfileReportsSection extends ConsumerWidget {
  final HospitalModel hospital;

  const HospitalProfileReportsSection({super.key, required this.hospital});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(hospitalReportsProvider(hospital));

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
            fallbackText:
                'No medical reports associated with ${hospital.name}.',
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
