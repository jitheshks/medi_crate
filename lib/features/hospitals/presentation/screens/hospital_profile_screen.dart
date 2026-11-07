import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/theme/app_semantic_colors.dart';
import '../../../../shared/widgets/detail/detail_widgets.dart';
import '../../../../shared/widgets/dialogs/deletion_impact_dialog.dart';
import '../../../../shared/widgets/feedback/app_error_state.dart';
import '../../../../shared/widgets/feedback/pulsing_vault_logo.dart';
import '../../../doctors/data/models/doctor_hospital_relation.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/hospital_model.dart';
import '../providers/hospitals_providers.dart';
import '../widgets/hospital_profile_linked_sections.dart';

/// HospitalProfileScreen displays facility details and derived associated doctors,
/// consultations, appointments, reports, and actions using the shared MediCrate detail framework.
class HospitalProfileScreen extends ConsumerStatefulWidget {
  final String hospitalId;

  const HospitalProfileScreen({super.key, required this.hospitalId});

  @override
  ConsumerState<HospitalProfileScreen> createState() =>
      _HospitalProfileScreenState();
}

class _HospitalProfileScreenState extends ConsumerState<HospitalProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _doctorsKey = GlobalKey();
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
    if (deps.doctors > 0) {
      targetKey = _doctorsKey;
      section = 'doctors';
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
    final hospitalAsync = ref.watch(hospitalDetailsProvider(widget.hospitalId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Hospital Profile',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        backgroundColor: colorScheme.surface,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.hospitals),
        ),
      ),
      body: SafeArea(
        child: hospitalAsync.when(
          loading: () => const Center(child: PulsingVaultLogo()),
          error: (err, stack) => AppErrorState(
            error: err,
            title: 'Failed to load hospital profile',
            onRetry: () =>
                ref.invalidate(hospitalDetailsProvider(widget.hospitalId)),
          ),
          data: (hospital) {
            if (hospital == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Hospital record not found.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.go(AppRoutes.hospitals),
                      child: const Text('Back to Hospitals'),
                    ),
                  ],
                ),
              );
            }

            final semanticColors = context.semanticColors;
            final heroIconColor = semanticColors.hospitalAccent;
            final heroIconBg = semanticColors.hospitalAccentContainer;

            return DetailScreenScaffold(
              scrollController: _scrollController,
              hero: DetailHero(
                icon: AppIcons.hospital,
                iconColor: heroIconColor,
                iconBackground: heroIconBg,
                title: hospital.name,
                subtitle: hospital.type,
                isCircular: true,
                iconSize: 36,
                iconBoxSize: 72,
              ),
              sections: [
                DetailSection(
                  title: 'FACILITY DETAILS',
                  topPadding: 16,
                  child: HospitalProfileContactSection(hospital: hospital),
                ),
                DetailSection(
                  key: _doctorsKey,
                  title: 'ASSOCIATED DOCTORS',
                  isHighlighted: _highlightedSection == 'doctors',
                  child: HospitalProfileAssociatedDoctorsSection(
                    hospitalId: hospital.id,
                  ),
                ),
                DetailSection(
                  key: _consultationsKey,
                  title: 'CONSULTATIONS',
                  isHighlighted: _highlightedSection == 'consultations',
                  child: HospitalProfileConsultationsSection(
                    hospital: hospital,
                  ),
                ),
                DetailSection(
                  key: _appointmentsKey,
                  title: 'APPOINTMENTS',
                  isHighlighted: _highlightedSection == 'appointments',
                  child: HospitalProfileAppointmentsSection(hospital: hospital),
                ),
                DetailSection(
                  key: _reportsKey,
                  title: 'REPORTS',
                  isHighlighted: _highlightedSection == 'reports',
                  child: HospitalProfileReportsSection(hospital: hospital),
                ),
                if (hospital.notes != null && hospital.notes!.isNotEmpty)
                  DetailSection(
                    title: 'NOTES',
                    child: DetailNoteBox(
                      notes: hospital.notes,
                      fallbackText: 'No notes.',
                    ),
                  ),
              ],
              actions: DetailActionRow(
                onEdit: () =>
                    context.pushGuarded(AppRoutes.editHospital(hospital.id)),
                onDelete: () => _showDeleteConfirmation(context, ref, hospital),
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
    HospitalModel hospital,
  ) async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;
    final hospitalRepo = ref.read(hospitalRepositoryProvider);
    final deps = await hospitalRepo.getHospitalDependencies(
      activeProfile.profileId,
      hospital.id,
    );

    if (!context.mounted) return;

    await DeletionImpactDialog.showDependencyAware(
      context,
      recordName: hospital.name,
      recordType: 'Hospital',
      dependencies: deps,
      onViewLinkedRecords: () {
        _scrollToFirstDependency(deps);
      },
      onConfirm: () async {
        try {
          await ref
              .read(hospitalsListProvider.notifier)
              .deleteHospital(hospital.id);
          if (context.mounted) {
            context.showSuccessSnackBar('Hospital deleted successfully.');
            context.popOrGo(AppRoutes.hospitals);
          }
        } on ResourceHasDependenciesException catch (e) {
          if (context.mounted) {
            DeletionImpactDialog.show409Conflict(
              context,
              recordType: 'Hospital',
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
              "Couldn't delete hospital. Please try again.",
            );
          }
        }
      },
    );
  }
}
