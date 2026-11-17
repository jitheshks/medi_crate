import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../../shared/utils/form_submit_runner.dart';
import '../../data/models/appointment_model.dart';
import '../providers/appointment_providers.dart';
import '../widgets/form/appointment_entity_picker_helper.dart';
import '../widgets/form/appointment_form_content.dart';
import '../widgets/form/appointment_form_controller.dart';
import '../widgets/form/appointment_form_save_helper.dart';

/// AddEditAppointmentScreen enables creation and editing of profile-scoped doctor appointments.
class AddEditAppointmentScreen extends ConsumerStatefulWidget {
  final String? appointmentIdToEdit;

  const AddEditAppointmentScreen({super.key, this.appointmentIdToEdit});

  @override
  ConsumerState<AddEditAppointmentScreen> createState() =>
      _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState
    extends ConsumerState<AddEditAppointmentScreen> {
  final AppointmentFormController _formCtrl = AppointmentFormController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _hasLoaded = false;
  AppointmentModel? _originalAppointment;

  @override
  void initState() {
    super.initState();
    _isEditing =
        widget.appointmentIdToEdit != null &&
        widget.appointmentIdToEdit!.isNotEmpty;

    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadInitial();
      });
    }
  }

  @override
  void dispose() {
    _formCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    if (_isEditing) {
      setState(() => _isLoading = true);
    }

    try {
      final orig = await AppointmentFormSaveHelper.loadInitialData(
        ref: ref,
        profileId: activeProfile.profileId,
        appointmentIdToEdit: widget.appointmentIdToEdit,
        formCtrl: _formCtrl,
      );

      if (mounted) {
        setState(() {
          _originalAppointment = orig;
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

  void _openDoctorPicker() {
    AppointmentEntityPickerHelper.openDoctorPicker(
      context: context,
      currentDoctorId: _formCtrl.selectedDoctorId,
      currentDoctorName: _formCtrl.selectedDoctorName,
      onSelected: (DoctorModel doc) {
        setState(() {
          _formCtrl.selectedDoctorName = doc.name;
          _formCtrl.selectedDoctorId = IdUtils.unprefix(doc.id);
          _formCtrl.selectedDoctorSpecialty = doc.specialty;

          if (doc.specialty.isNotEmpty &&
              doc.specialty != 'General Practice' &&
              (_formCtrl.selectedDepartment == null ||
                  _formCtrl.selectedDepartment!.isEmpty)) {
            _formCtrl.selectedDepartment = doc.specialty;
          }

          if ((_formCtrl.selectedHospitalName == null ||
                  _formCtrl.selectedHospitalName!.isEmpty) &&
              doc.hospitalName != null &&
              doc.hospitalName!.isNotEmpty) {
            _formCtrl.selectedHospitalName = doc.hospitalName;
            if (doc.hospitalIds.isNotEmpty) {
              _formCtrl.selectedHospitalId = IdUtils.unprefix(
                doc.hospitalIds.first,
              );
            }
          }
        });
      },
    );
  }

  void _openHospitalPicker() {
    AppointmentEntityPickerHelper.openHospitalPicker(
      context: context,
      currentHospitalId: _formCtrl.selectedHospitalId,
      currentHospitalName: _formCtrl.selectedHospitalName,
      onSelected: (HospitalModel hosp) {
        setState(() {
          _formCtrl.selectedHospitalName = hosp.name;
          _formCtrl.selectedHospitalId = IdUtils.unprefix(hosp.id);
        });
      },
    );
  }

  Future<void> _saveAppointment() async {
    if (_formCtrl.selectedDoctorName == null ||
        _formCtrl.selectedDoctorName!.isEmpty) {
      context.showErrorSnackBar('Please select or enter a doctor.');
      return;
    }

    await FormSubmitRunner.run<void>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSaving = val),
      formKey: _formCtrl.formKey,
      defaultErrorMessage: "Couldn't save appointment. Please try again.",
      action: () async {
        final activeProfile = ref.read(activeProfileProvider);
        if (activeProfile == null) {
          throw Exception('No active profile selected.');
        }

        if (_isEditing && _originalAppointment == null) {
          throw Exception(
            'Cannot update appointment: target record could not be resolved.',
          );
        }

        final model = AppointmentFormSaveHelper.buildAppointmentModel(
          formCtrl: _formCtrl,
          profileId: activeProfile.profileId,
          originalAppointment: _originalAppointment,
          defaultCurrency: ref.read(appCurrencyProvider),
        );

        if (_isEditing) {
          await ref
              .read(appointmentsListProvider.notifier)
              .updateAppointment(model);
        } else {
          await ref
              .read(appointmentsListProvider.notifier)
              .addAppointment(model);
        }
      },
      onSuccess: (_) {
        context.showSuccessSnackBar(
          _isEditing
              ? 'Appointment updated successfully'
              : 'Appointment scheduled successfully',
        );
        context.popOrGo(AppRoutes.appointments);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (_isEditing && !_hasLoaded && next != null) {
        _loadInitial();
      }
    });

    final colorScheme = Theme.of(context).colorScheme;

    if (_isEditing && _isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.popOrGo(AppRoutes.appointments),
          ),
          title: Text(
            'Edit Appointment',
            style: AppTypography.h2.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isEditing && _hasLoaded && _originalAppointment == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.popOrGo(AppRoutes.appointments),
          ),
          title: Text(
            'Edit Appointment',
            style: AppTypography.h2.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Appointment not found',
                style: AppTypography.h3.copyWith(color: colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.popOrGo(AppRoutes.appointments),
                child: const Text('Back to Appointments'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.appointments),
        ),
        title: Text(
          _isEditing ? 'Edit Appointment' : 'New Appointment',
          style: AppTypography.h2.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Form(
            key: _formCtrl.formKey,
            child: AppointmentFormContent(
              controller: _formCtrl,
              onStateChanged: () => setState(() {}),
              onOpenDoctorPicker: _openDoctorPicker,
              onAddDoctor: () async {
                await context.pushGuarded(AppRoutes.addDoctor);
                _loadInitial();
              },
              onClearDoctor: _formCtrl.selectedDoctorName != null
                  ? () {
                      setState(() {
                        _formCtrl.selectedDoctorName = null;
                        _formCtrl.selectedDoctorId = null;
                        _formCtrl.selectedDoctorSpecialty = null;
                      });
                    }
                  : null,
              onOpenHospitalPicker: _openHospitalPicker,
              onClearHospital: _formCtrl.selectedHospitalName != null
                  ? () {
                      setState(() {
                        _formCtrl.selectedHospitalName = null;
                        _formCtrl.selectedHospitalId = null;
                      });
                    }
                  : null,
              onAddHospital: () async {
                await context.pushGuarded(AppRoutes.addHospital);
                _loadInitial();
              },
              onOpenDepartmentPicker: () {
                final currentId = _formCtrl.selectedDepartmentId != null
                    ? int.tryParse(_formCtrl.selectedDepartmentId!)
                    : null;
                AppointmentEntityPickerHelper.openDepartmentPicker(
                  context: context,
                  currentDepartment: _formCtrl.selectedDepartment,
                  currentDepartmentId: currentId,
                  onSelected: (dept) {
                    setState(() {
                      _formCtrl.selectedDepartment = dept.name;
                      _formCtrl.selectedDepartmentId = dept.id.toString();
                    });
                  },
                );
              },
              onClearDepartment: _formCtrl.selectedDepartment != null
                  ? () {
                      setState(() {
                        _formCtrl.selectedDepartment = null;
                        _formCtrl.selectedDepartmentId = null;
                      });
                    }
                  : null,
              onPickDate: () async {
                final p = await AppointmentFormSaveHelper.pickDate(
                  context,
                  _formCtrl.selectedDate,
                  isEditing: _isEditing,
                );
                if (p != null) setState(() => _formCtrl.selectedDate = p);
              },
              onPickTime: () async {
                final p = await AppointmentFormSaveHelper.pickTime(
                  context,
                  _formCtrl.selectedTime,
                );
                if (p != null) setState(() => _formCtrl.selectedTime = p);
              },
              isEditing: _isEditing,
              isSaving: _isSaving,
              onSave: _saveAppointment,
            ),
          ),
        ),
      ),
    );
  }
}
