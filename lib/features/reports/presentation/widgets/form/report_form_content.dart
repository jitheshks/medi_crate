import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_spacing.dart';
import '../../../../../core/constants/app_typography.dart';
import '../../../../consultations/data/models/consultation_model.dart';
import '../../../../doctors/data/models/doctor_model.dart';
import '../../../../hospitals/data/models/hospital_model.dart';
import '../../../../profile/data/models/profile_model.dart';
import '../../../../settings/presentation/providers/settings_providers.dart';
import 'report_attachments_section.dart';
import 'report_category_chips.dart';
import 'report_date_picker_tile.dart';
import 'report_entity_picker_helper.dart';
import 'report_expense_section.dart';
import 'report_form_controller.dart';
import 'report_linked_entity_cards.dart';
import 'report_profile_banner.dart';
import 'report_text_inputs.dart';

class ReportFormContent extends ConsumerWidget {
  final ProfileModel? activeProfile;
  final ReportFormController controller;
  final VoidCallback onStateChanged;
  final AsyncValue<List<ConsultationModel>> consultationsAsync;
  final AsyncValue<List<DoctorModel>> doctorsAsync;
  final AsyncValue<List<HospitalModel>> hospitalsAsync;

  const ReportFormContent({
    super.key,
    required this.activeProfile,
    required this.controller,
    required this.onStateChanged,
    required this.consultationsAsync,
    required this.doctorsAsync,
    required this.hospitalsAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (activeProfile != null) ReportProfileBanner(profile: activeProfile!),

        // TITLE FIELD (REQUIRED)
        ReportTitleField(controller: controller.titleController),
        const SizedBox(height: AppSpacing.md),

        // CATEGORY SELECTION (REQUIRED)
        Text(
          'CATEGORY *',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        ReportCategoryChips(
          selectedCategory: controller.selectedCategory,
          onCategoryChanged: (cat) {
            controller.selectedCategory = cat;
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // DATE SELECTION (REQUIRED)
        Text(
          'REPORT DATE *',
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        ReportDatePickerTile(
          selectedDate: controller.selectedDate,
          onDateSelected: (date) {
            controller.selectedDate = date;
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // LINKED ENTITIES (CONSULTATION, DOCTOR, HOSPITAL)
        ReportLinkedEntityCards(
          consultationsAsync: consultationsAsync,
          doctorsAsync: doctorsAsync,
          hospitalsAsync: hospitalsAsync,
          consultationId: controller.consultationId,
          consultationTitle: controller.consultationTitle,
          doctorName: controller.doctorName,
          hospitalName: controller.hospitalName,
          onOpenConsultationPicker: () {
            final docs = doctorsAsync.value ?? [];
            final hosps = hospitalsAsync.value ?? [];
            final consults = consultationsAsync.value ?? [];
            ReportEntityPickerHelper.openConsultationPicker(
              context: context,
              consultations: consults,
              doctors: docs,
              hospitals: hosps,
              consultationId: controller.consultationId,
              onSelected:
                  ({
                    required id,
                    required title,
                    required doctorId,
                    required doctorName,
                    required hospitalId,
                    required hospitalName,
                  }) {
                    controller.consultationId = id;
                    controller.consultationTitle = title;
                    controller.doctorId = doctorId;
                    controller.doctorName = doctorName;
                    controller.hospitalId = hospitalId;
                    controller.hospitalName = hospitalName;
                    onStateChanged();
                  },
            );
          },
          onClearConsultation: () {
            controller.consultationId = null;
            controller.consultationTitle = null;
            onStateChanged();
          },
          onOpenDoctorPicker: () {
            ReportEntityPickerHelper.openDoctorPicker(
              context: context,
              currentDoctorId: controller.doctorId,
              currentDoctorName: controller.doctorName,
              onSelected: (doctor) {
                controller.doctorName = doctor.name;
                controller.doctorId = doctor.id;
                onStateChanged();
              },
            );
          },
          onClearDoctor: () {
            controller.doctorId = null;
            controller.doctorName = null;
            onStateChanged();
          },
          onOpenHospitalPicker: () {
            ReportEntityPickerHelper.openHospitalPicker(
              context: context,
              currentHospitalId: controller.hospitalId,
              currentHospitalName: controller.hospitalName,
              onSelected: (hospital) {
                controller.hospitalName = hospital.name;
                controller.hospitalId = hospital.id;
                onStateChanged();
              },
            );
          },
          onClearHospital: () {
            controller.hospitalId = null;
            controller.hospitalName = null;
            onStateChanged();
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // NOTES FIELD
        ReportNotesField(controller: controller.notesController),
        const SizedBox(height: AppSpacing.lg),

        // ATTACHMENTS SECTION
        ReportAttachmentsSection(
          attachments: controller.attachments,
          onAddAttachment: () {
            if (activeProfile != null) {
              controller.addAttachment(
                activeProfile!.profileId,
                onStateChanged,
              );
            }
          },
          onRemoveAttachment: (idx) {
            controller.removeAttachment(idx, onStateChanged);
          },
        ),
        const SizedBox(height: AppSpacing.lg),

        // EXPENSE SECTION
        ReportExpenseSection(
          enableExpense: controller.enableExpense,
          onEnableExpenseChanged: (val) {
            controller.enableExpense = val;
            onStateChanged();
          },
          amountController: controller.expenseAmountController,
          expenseStatus: controller.expenseStatus,
          onStatusChanged: (st) {
            controller.expenseStatus = st;
            onStateChanged();
          },
          currency:
              controller.expenseCurrency ?? ref.watch(appCurrencyProvider),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
