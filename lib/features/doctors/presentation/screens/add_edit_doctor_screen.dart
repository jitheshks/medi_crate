import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_crate/app/routes/app_routes.dart';
import 'package:medi_crate/core/constants/app_spacing.dart';
import 'package:medi_crate/core/constants/app_typography.dart';
import 'package:medi_crate/core/extensions/build_context_extensions.dart';
import 'package:medi_crate/features/doctors/data/models/doctor_model.dart';
import 'package:medi_crate/features/doctors/presentation/providers/doctors_providers.dart';
import 'package:medi_crate/features/doctors/presentation/widgets/doctor_form_fields.dart';
import 'package:medi_crate/features/doctors/presentation/widgets/form/doctor_form_controller.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/hospital_selection_sheet.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/shared/utils/form_submit_runner.dart';
import 'package:medi_crate/shared/widgets/buttons/primary_button.dart';
import 'package:medi_crate/shared/widgets/sheets/app_bottom_sheet.dart';

/// AddEditDoctorScreen handles creation and modification of doctor records with hospital relations.
class AddEditDoctorScreen extends ConsumerStatefulWidget {
  final String? doctorIdToEdit;

  const AddEditDoctorScreen({super.key, this.doctorIdToEdit});

  @override
  ConsumerState<AddEditDoctorScreen> createState() =>
      _AddEditDoctorScreenState();
}

class _AddEditDoctorScreenState extends ConsumerState<AddEditDoctorScreen> {
  late final DoctorFormController _formController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  DoctorModel? _originalDoctor;

  @override
  void initState() {
    super.initState();
    _isEditing =
        widget.doctorIdToEdit != null && widget.doctorIdToEdit!.isNotEmpty;

    _formController = DoctorFormController();

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDoctorForEditing();
      });
    }
  }

  Future<void> _loadDoctorForEditing() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null || widget.doctorIdToEdit == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(doctorRepositoryProvider);
      final doctor = await repository.getDoctorById(
        activeProfile.profileId,
        widget.doctorIdToEdit!,
      );

      if (mounted) {
        setState(() {
          _originalDoctor = doctor;
          if (doctor != null) {
            _formController.populateFromDoctor(doctor);
          }
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasLoaded = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _saveDoctor() async {
    await FormSubmitRunner.run<DoctorModel?>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSaving = val),
      formKey: _formController.formKey,
      defaultErrorMessage: "Couldn't save doctor. Please try again.",
      action: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile == null) {
          throw Exception('No active profile selected.');
        }

        if (_isEditing && _originalDoctor == null) {
          throw Exception(
            'Cannot update doctor: target record could not be resolved.',
          );
        }

        final newDoctor = _formController.buildDoctorModel(
          profileId: activeProfile.profileId,
          originalDoctor: _originalDoctor,
          doctorIdToEdit: widget.doctorIdToEdit,
        );

        return await ref
            .read(doctorsListProvider.notifier)
            .saveDoctor(newDoctor);
      },
      onSuccess: (_) {
        context.showSuccessSnackBar(
          _isEditing
              ? 'Doctor updated successfully.'
              : 'Doctor saved successfully.',
        );
        context.popOrGo(AppRoutes.doctors);
      },
    );
  }

  void _openHospitalPicker() {
    Set<String> consultationHospitalIds = {};
    if (_originalDoctor != null) {
      final practicingAsync = ref.read(
        doctorHospitalsProvider(_originalDoctor!),
      );
      final practicing = practicingAsync.value ?? [];
      consultationHospitalIds = practicing
          .where((p) => p.isFromConsultation)
          .map((p) => p.hospital.id)
          .toSet();
    }

    AppBottomSheet.show(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => HospitalSelectionSheet(
        selectedHospitalIds: _formController.selectedHospitalIds,
        consultationHospitalIds: consultationHospitalIds,
        onSelectionConfirmed: (updatedIds) {
          setState(() {
            _formController.selectedHospitalIds = updatedIds;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (_isEditing && !_hasLoaded && next != null) {
        _loadDoctorForEditing();
      }
    });

    final title = _isEditing ? 'Edit Doctor' : 'Add Doctor';
    final colorScheme = Theme.of(context).colorScheme;

    if (_isEditing && _isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            title,
            style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
          ),
          backgroundColor: colorScheme.surface,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.popOrGo(AppRoutes.doctors),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEditing && _hasLoaded && _originalDoctor == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            title,
            style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
          ),
          backgroundColor: colorScheme.surface,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.popOrGo(AppRoutes.doctors),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Doctor not found',
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton(
                onPressed: () => context.popOrGo(AppRoutes.doctors),
                child: const Text('Back to Doctors'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          title,
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
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _formController.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DoctorFormFields(
                      controller: _formController,
                      originalDoctor: _originalDoctor,
                      onOpenHospitalPicker: _openHospitalPicker,
                      onRemoveHospital: (hospId) {
                        setState(() {
                          _formController.selectedHospitalIds.remove(hospId);
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: PrimaryButton(
                        text: _isEditing ? 'SAVE CHANGES' : 'SAVE DOCTOR',
                        isLoading: _isSaving,
                        onPressed: _saveDoctor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
