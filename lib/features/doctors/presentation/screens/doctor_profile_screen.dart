import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/doctor_hospital_relation.dart';
import '../../data/models/doctor_model.dart';
import '../providers/doctors_providers.dart';
import '../widgets/doctor_profile_linked_sections.dart';

/// DoctorProfileScreen displays complete doctor details, contact info,
/// linked hospitals, clinical notes, matching consultations, appointments, reports,
/// and actions using the shared MediCrate detail framework.
class DoctorProfileScreen extends ConsumerStatefulWidget {
  final String doctorId;

  const DoctorProfileScreen({super.key, required this.doctorId});

  @override
  ConsumerState<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _hospitalsKey = GlobalKey();
  final GlobalKey _consultationsKey = GlobalKey();
  final GlobalKey _appointmentsKey = GlobalKey();
  final GlobalKey _reportsKey = GlobalKey();
  String? _highlightedSection;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToFirstDependency(EntityDependencies deps) {
    GlobalKey? targetKey;
    String? section;
    if (deps.hospitals > 0) {
      targetKey = _hospitalsKey;
      section = 'hospitals';
    } else if (deps.consultations > 0) {
      targetKey = _consultationsKey;
      section = 'consultations';
    } else if (deps.appointments > 0) {
      targetKey = _appointmentsKey;
      section = 'appointments';
    } else if (deps.reports > 0) {
      targetKey = _reportsKey;
      section = 'reports';
    }

    if (targetKey != null) {
      if (mounted) {
        setState(() => _highlightedSection = section);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final targetContext = targetKey?.currentContext;
        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
            alignment: 0.05,
          );
        }
      });
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) {
          setState(() => _highlightedSection = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctorAsync = ref.watch(doctorDetailsProvider(widget.doctorId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Doctor Profile',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.doctors),
        ),
      ),
      body: SafeArea(
        child: doctorAsync.when(
          loading: () => const Center(child: PulsingVaultLogo()),
          error: (err, stack) => AppErrorState(
            error: err,
            title: 'Failed to load doctor profile',
            onRetry: () =>
                ref.invalidate(doctorDetailsProvider(widget.doctorId)),
          ),
          data: (doctor) {
            if (doctor == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Doctor record not found.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.doctors),
                      child: const Text('Back to Doctors'),
                    ),
                  ],
                ),
              );
            }

            final colorScheme = Theme.of(context).colorScheme;

            return DetailScreenScaffold(
              scrollController: _scrollController,
              hero: DetailHero(
                icon: AppIcons.stethoscope,
                iconColor: colorScheme.primary,
                iconBackground: colorScheme.primaryContainer,
                title: doctor.name,
                subtitle: doctor.specialty,
                isCircular: true,
                iconSize: 36,
                iconBoxSize: 72,
              ),
              sections: [
                DetailSection(
                  key: _hospitalsKey,
                  title: 'HOSPITALS / CLINICS',
                  topPadding: 16,
                  isHighlighted: _highlightedSection == 'hospitals',
                  child: DoctorProfileHospitalsSection(doctor: doctor),
                ),
                DetailSection(
                  key: _consultationsKey,
                  title: 'CONSULTATIONS',
                  isHighlighted: _highlightedSection == 'consultations',
                  child: DoctorProfileConsultationsSection(doctor: doctor),
                ),
                DetailSection(
                  key: _appointmentsKey,
                  title: 'APPOINTMENTS',
                  isHighlighted: _highlightedSection == 'appointments',
                  child: DoctorProfileAppointmentsSection(doctor: doctor),
                ),
                DetailSection(
                  key: _reportsKey,
                  title: 'REPORTS',
                  isHighlighted: _highlightedSection == 'reports',
                  child: DoctorProfileReportsSection(doctor: doctor),
                ),
                DetailSection(
                  title: 'CONTACT DETAILS',
                  child: DoctorProfileContactSection(doctor: doctor),
                ),
                if (doctor.notes != null && doctor.notes!.isNotEmpty)
                  DetailSection(
                    title: 'NOTES',
                    child: DetailNoteBox(
                      notes: doctor.notes,
                      fallbackText: 'No notes.',
                    ),
                  ),
              ],
              actions: DetailActionRow(
                onEdit: () =>
                    context.pushGuarded(AppRoutes.doctorEdit(doctor.id)),
                onDelete: () => _showDeleteConfirmation(context, ref, doctor),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    DoctorModel doctor,
  ) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;
    final doctorRepo = ref.read(doctorRepositoryProvider);
    final deps = await doctorRepo.getDoctorDependencies(
      activeProfile.profileId,
      doctor.id,
    );

    if (!context.mounted) return;

    await DeletionImpactDialog.showDependencyAware(
      context,
      recordName: doctor.name,
      recordType: 'Doctor',
      dependencies: deps,
      onViewLinkedRecords: () {
        _scrollToFirstDependency(deps);
      },
      onConfirm: () async {
        try {
          await ref.read(doctorsListProvider.notifier).deleteDoctor(doctor.id);
          if (context.mounted) {
            context.showSuccessSnackBar('Doctor deleted successfully.');
            context.popOrGo(AppRoutes.doctors);
          }
        } on ResourceHasDependenciesException catch (e) {
          if (context.mounted) {
            DeletionImpactDialog.show409Conflict(
              context,
              recordType: 'Doctor',
              customMessage: e.message,
              onViewLinkedRecords: () {
                _scrollToFirstDependency(deps);
              },
            );
          }
        } on AppException catch (e) {
          if (context.mounted) {
            context.showErrorSnackBar(e.message);
          }
        } catch (_) {
          if (context.mounted) {
            context.showErrorSnackBar(
              "Couldn't delete doctor. Please try again.",
            );
          }
        }
      },
    );
  }
}
