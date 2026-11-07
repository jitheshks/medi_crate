import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_crate/app/routes/app_routes.dart';
import 'package:medi_crate/core/constants/app_spacing.dart';
import 'package:medi_crate/core/constants/app_typography.dart';
import 'package:medi_crate/core/extensions/build_context_extensions.dart';
import 'package:medi_crate/features/hospitals/data/models/hospital_model.dart';
import 'package:medi_crate/features/hospitals/presentation/providers/hospitals_providers.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/form/hospital_form_controller.dart';
import 'package:medi_crate/features/hospitals/presentation/widgets/hospital_form_fields.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/shared/utils/form_submit_runner.dart';
import 'package:medi_crate/shared/widgets/buttons/primary_button.dart';

/// AddEditHospitalScreen handles creation and modification of healthcare facilities.
class AddEditHospitalScreen extends ConsumerStatefulWidget {
  final String? hospitalIdToEdit;

  const AddEditHospitalScreen({super.key, this.hospitalIdToEdit});

  @override
  ConsumerState<AddEditHospitalScreen> createState() =>
      _AddEditHospitalScreenState();
}

class _AddEditHospitalScreenState extends ConsumerState<AddEditHospitalScreen> {
  late final HospitalFormController _formController;

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  HospitalModel? _originalHospital;

  @override
  void initState() {
    super.initState();
    _isEditing =
        widget.hospitalIdToEdit != null && widget.hospitalIdToEdit!.isNotEmpty;

    _formController = HospitalFormController();

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadHospitalForEditing();
      });
    }
  }

  Future<void> _loadHospitalForEditing() async {
    setState(() => _isLoading = true);
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null || widget.hospitalIdToEdit == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasLoaded = true;
        });
      }
      return;
    }

    final repository = ref.read(hospitalRepositoryProvider);
    final hospital = await repository.getHospitalById(
      activeProfile.profileId,
      widget.hospitalIdToEdit!,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasLoaded = true;
        if (hospital != null) {
          _originalHospital = hospital;
          _formController.populateFromHospital(hospital);
        }
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    super.dispose();
  }

  Future<void> _saveHospital() async {
    await FormSubmitRunner.run<HospitalModel?>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSaving = val),
      formKey: _formController.formKey,
      defaultErrorMessage: "Couldn't save hospital. Please try again.",
      action: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile == null) {
          throw Exception('No active profile selected.');
        }

        if (_isEditing && _originalHospital == null) {
          throw Exception(
            'Cannot update hospital: target record could not be resolved.',
          );
        }

        final newHospital = _formController.buildHospitalModel(
          profileId: activeProfile.profileId,
          originalHospital: _originalHospital,
          hospitalIdToEdit: widget.hospitalIdToEdit,
        );

        return await ref
            .read(hospitalsListProvider.notifier)
            .saveHospital(newHospital);
      },
      onSuccess: (saved) {
        context.showSuccessSnackBar(
          _isEditing
              ? 'Hospital updated successfully.'
              : 'Hospital saved successfully.',
        );
        context.popOrGo(AppRoutes.hospitals, saved);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (_isEditing && !_hasLoaded && next != null) {
        _loadHospitalForEditing();
      }
    });

    final title = _isEditing ? 'Edit Hospital' : 'Add Hospital / Clinic';
    final colorScheme = Theme.of(context).colorScheme;

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
          onPressed: () => context.popOrGo(AppRoutes.hospitals),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_isEditing && _hasLoaded && _originalHospital == null)
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      size: 48,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Hospital record not found.',
                      style: AppTypography.h3.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ElevatedButton(
                      onPressed: () => context.popOrGo(AppRoutes.hospitals),
                      child: const Text('Back to Hospitals'),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Form(
                      key: _formController.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HospitalFormFields(controller: _formController),
                          const SizedBox(height: AppSpacing.xl),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: PrimaryButton(
                              text: _isEditing
                                  ? 'SAVE CHANGES'
                                  : 'SAVE HOSPITAL',
                              isLoading: _isSaving,
                              onPressed: _saveHospital,
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
