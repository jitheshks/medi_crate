import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../consultations/data/models/consultation_model.dart';
import '../../../../doctors/data/models/doctor_model.dart';
import '../../../../hospitals/data/models/hospital_model.dart';
import 'linked_consultation_card.dart';
import 'linked_doctor_card.dart';
import 'linked_hospital_card.dart';

class ReportLinkedEntityCards extends StatelessWidget {
  final AsyncValue<List<ConsultationModel>> consultationsAsync;
  final AsyncValue<List<DoctorModel>> doctorsAsync;
  final AsyncValue<List<HospitalModel>> hospitalsAsync;
  final String? consultationId;
  final String? consultationTitle;
  final String? doctorName;
  final String? hospitalName;
  final VoidCallback onOpenConsultationPicker;
  final VoidCallback onClearConsultation;
  final VoidCallback onOpenDoctorPicker;
  final VoidCallback onClearDoctor;
  final VoidCallback onOpenHospitalPicker;
  final VoidCallback onClearHospital;

  const ReportLinkedEntityCards({
    super.key,
    required this.consultationsAsync,
    required this.doctorsAsync,
    required this.hospitalsAsync,
    required this.consultationId,
    required this.consultationTitle,
    required this.doctorName,
    required this.hospitalName,
    required this.onOpenConsultationPicker,
    required this.onClearConsultation,
    required this.onOpenDoctorPicker,
    required this.onClearDoctor,
    required this.onOpenHospitalPicker,
    required this.onClearHospital,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinkedConsultationCard(
          consultationsAsync: consultationsAsync,
          consultationId: consultationId,
          consultationTitle: consultationTitle,
          onOpenConsultationPicker: onOpenConsultationPicker,
          onClearConsultation: onClearConsultation,
        ),
        const SizedBox(height: AppSpacing.md),
        LinkedDoctorCard(
          doctorsAsync: doctorsAsync,
          doctorName: doctorName,
          onOpenDoctorPicker: onOpenDoctorPicker,
          onClearDoctor: onClearDoctor,
        ),
        const SizedBox(height: AppSpacing.md),
        LinkedHospitalCard(
          hospitalsAsync: hospitalsAsync,
          hospitalName: hospitalName,
          onOpenHospitalPicker: onOpenHospitalPicker,
          onClearHospital: onClearHospital,
        ),
      ],
    );
  }
}
