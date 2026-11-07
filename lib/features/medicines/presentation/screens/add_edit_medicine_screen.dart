import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../consultations/presentation/providers/consultation_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../../shared/utils/form_submit_runner.dart';
import '../../data/models/medicine_model.dart';
import '../providers/medicine_providers.dart';
import '../widgets/form/medicine_consultation_picker.dart';
import '../widgets/form/medicine_form_content.dart';
import '../widgets/form/medicine_form_controller.dart';
import '../widgets/form/medicine_form_save_helper.dart';

class AddEditMedicineScreen extends ConsumerStatefulWidget {
  final String? medicineIdToEdit;
  final MedicineModel? initialMedicine;

  const AddEditMedicineScreen({
    super.key,
    this.medicineIdToEdit,
    this.initialMedicine,
  });

  @override
  ConsumerState<AddEditMedicineScreen> createState() =>
      _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends ConsumerState<AddEditMedicineScreen> {
  final MedicineFormController _formCtrl = MedicineFormController();

  bool _isSaving = false;
  bool _isLoadingInitial = false;
  bool _hasLoaded = false;
  MedicineModel? _originalMedicine;

  @override
  void initState() {
    super.initState();
    _originalMedicine = widget.initialMedicine;
    if (widget.initialMedicine != null) {
      _formCtrl.populateFromModel(widget.initialMedicine!);
      _hasLoaded = true;
    } else if (widget.medicineIdToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitial();
      });
    }
  }

  Future<void> _loadInitial() async {
    if (widget.initialMedicine != null) {
      _originalMedicine = widget.initialMedicine;
      _formCtrl.populateFromModel(widget.initialMedicine!);
      _hasLoaded = true;
    } else if (widget.medicineIdToEdit != null) {
      setState(() => _isLoadingInitial = true);
      try {
        final loaded = await MedicineFormSaveHelper.loadInitial(
          ref: ref,
          medicineIdToEdit: widget.medicineIdToEdit,
          initialMedicine: widget.initialMedicine,
          formCtrl: _formCtrl,
        );
        if (mounted) {
          setState(() {
            _originalMedicine = loaded;
            _hasLoaded = true;
            _isLoadingInitial = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _hasLoaded = true;
            _isLoadingInitial = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _formCtrl.dispose();
    super.dispose();
  }

  Future<void> _openConsultationPicker() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final repo = ref.read(consultationRepositoryProvider);
    final consultations = await repo.getConsultations(activeProfile.profileId);

    if (!mounted) return;

    MedicineConsultationPicker.showConsultationPicker(
      context: context,
      consultations: consultations,
      currentTitle: _formCtrl.linkedConsultationTitle,
      onSelected: (id, title) {
        setState(() {
          _formCtrl.linkedConsultationId = id;
          _formCtrl.linkedConsultationTitle = title;
        });
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formCtrl.validateEndDate()) {
      setState(() {});
      return;
    }

    final isEdit = widget.medicineIdToEdit != null;

    await FormSubmitRunner.run<MedicineModel>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSaving = val),
      formKey: _formCtrl.formKey,
      defaultErrorMessage: "Couldn't save medicine. Please try again.",
      action: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile == null) {
          throw Exception('No active profile selected.');
        }

        if (isEdit && _originalMedicine == null) {
          throw Exception(
            'Cannot update medicine: target record could not be resolved.',
          );
        }

        final modelToSave = MedicineFormSaveHelper.buildModel(
          formCtrl: _formCtrl,
          profileId: activeProfile.profileId,
          medicineIdToEdit: widget.medicineIdToEdit,
          initialMedicine: _originalMedicine ?? widget.initialMedicine,
        );

        return await ref
            .read(medicinesListNotifierProvider.notifier)
            .saveMedicine(modelToSave);
      },
      onSuccess: (saved) {
        context.showSuccessSnackBar(
          isEdit
              ? 'Medicine updated successfully'
              : 'Medicine saved successfully',
        );
        if (isEdit) {
          context.pop(saved);
        } else {
          context.pushReplacement(AppRoutes.medicineDetail(saved.id));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicineIdToEdit != null;
    ref.listen(activeProfileProvider, (prev, next) {
      if (isEdit && !_hasLoaded && next != null) {
        _loadInitial();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoadingInitial) {
      return Scaffold(
        appBar: AppBar(title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (isEdit && _hasLoaded && _originalMedicine == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Edit Medicine',
            style: AppTypography.h3.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(AppIcons.arrowLeft, color: colorScheme.onSurface),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Medicine not found',
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Medicines'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Medicine' : 'Add Medicine',
          style: AppTypography.h3.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: _formCtrl.formKey,
                child: MedicineFormContent(
                  controller: _formCtrl,
                  activeProfile: ref.watch(activeProfileProvider),
                  onOpenConsultationPicker: _openConsultationPicker,
                  onStateChanged: () => setState(() {}),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                  icon: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(AppIcons.check, size: 20),
                  label: Text(
                    isEdit ? 'UPDATE MEDICINE' : 'SAVE MEDICINE',
                    style: AppTypography.button.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
