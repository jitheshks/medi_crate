import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/offline_banner.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/care_directory_section.dart';
import '../widgets/current_medicines_section.dart';
import '../widgets/dashboard_stat_grid.dart';
import '../widgets/recent_consultations_section.dart';
import '../widgets/recent_reports_section.dart';
import '../widgets/share_with_doctor_card.dart';
import '../widgets/upcoming_appointments_section.dart';
import '../widgets/upcoming_followup_section.dart';
import '../widgets/vitals_snapshot_section.dart';

/// HomeScreen presents health statistics, vitals snapshot, and record previews with its own SingleChildScrollView layout.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider).value ?? true;
    final summaryAsync = ref.watch(homeSummaryProvider);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          key: const PageStorageKey('home_tab_scroll_key'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isOnline) const OfflineBanner(),
              summaryAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: PulsingVaultLogo(),
                  ),
                ),
                error: (err, stack) => AppErrorState(
                  error: err,
                  onRetry: () =>
                      ref.read(homeSummaryProvider.notifier).refresh(),
                ),
                data: (summary) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardStatGrid(summary: summary),
                    const SizedBox(height: 20),
                    const ShareWithDoctorCard(),
                    const SizedBox(height: 24),
                    VitalsSnapshotSection(vitals: summary.recentVitals),
                    const SizedBox(height: 24),
                    CareDirectorySection(
                      doctorCount: summary.totalDoctors,
                      hospitalCount: summary.totalHospitals,
                    ),
                    const SizedBox(height: 24),
                    UpcomingAppointmentsSection(
                      appointmentId: summary.nextAppointmentId,
                      title: summary.nextAppointmentTitle,
                      date: summary.nextAppointmentDate,
                      doctorName: summary.nextAppointmentDoctor,
                      upcomingCount: summary.upcomingAppointmentsCount,
                    ),
                    const SizedBox(height: 24),
                    UpcomingFollowUpSection(
                      title: summary.upcomingFollowUpTitle,
                      date: summary.upcomingFollowUpDate,
                      doctorName: summary.upcomingFollowUpDoctor,
                    ),
                    const SizedBox(height: 24),
                    RecentConsultationsSection(
                      consultationId: summary.recentConsultationId,
                      diagnosis: summary.recentConsultationDiagnosis,
                      date: summary.recentConsultationDate,
                      doctorName: summary.recentConsultationDoctor,
                    ),
                    const SizedBox(height: 24),
                    CurrentMedicinesSection(
                      medicineId: summary.currentMedicineId,
                      medicineName: summary.currentMedicineName,
                      timing: summary.currentMedicineTiming,
                    ),
                    const SizedBox(height: 24),
                    RecentReportsSection(
                      reportId: summary.recentReportId,
                      title: summary.recentReportTitle,
                      date: summary.recentReportDate,
                      category: summary.recentReportCategory,
                      doctorName: summary.recentReportDoctor,
                      hospitalName: summary.recentReportHospital,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
