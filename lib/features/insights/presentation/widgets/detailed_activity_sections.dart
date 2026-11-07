import 'package:flutter/material.dart';

import '../../../../core/constants/app_spacing.dart';
import '../../data/models/insights_summary_model.dart';
import 'activity/appointments_activity_card.dart';
import 'activity/care_directory_activity_card.dart';
import 'activity/consultations_activity_card.dart';
import 'activity/medicines_activity_card.dart';
import 'activity/reports_activity_card.dart';

/// DetailedActivitySections presents exact card designs matching reference screens
/// (Ui_refereance/insights 3.png - 5.png) for Consultations, Appointments, Medicines, Reports, and Care Directory.
class DetailedActivitySections extends StatelessWidget {
  final InsightsSummaryModel summary;

  const DetailedActivitySections({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Consultations Section
        ConsultationsActivityCard(summary: summary.consultationSummary),

        const SizedBox(height: AppSpacing.xl),

        // 2. Appointments Section
        AppointmentsActivityCard(summary: summary.appointmentSummary),

        const SizedBox(height: AppSpacing.xl),

        // 3. Medicines Section
        MedicinesActivityCard(summary: summary.medicineSummary),

        const SizedBox(height: AppSpacing.xl),

        // 4. Reports Section
        ReportsActivityCard(summary: summary.reportSummary),

        const SizedBox(height: AppSpacing.xl),

        // 5. Care Directory Section
        CareDirectoryActivityCard(summary: summary.careDirectorySummary),
      ],
    );
  }
}
