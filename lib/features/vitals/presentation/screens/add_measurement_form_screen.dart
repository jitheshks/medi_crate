import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/measurement_model.dart';
import '../providers/measurement_providers.dart';
import '../widgets/form/bmi_calculation_view.dart';
import '../widgets/form/measurement_date_time_picker.dart';
import '../widgets/form/measurement_form_values_builder.dart';
import '../widgets/form/measurement_notes_source_section.dart';
import '../widgets/form/vital_adult_reference_notice.dart';
import '../widgets/form/vital_input_fields.dart';
import '../widgets/form/vital_type_banner.dart';

/// AddMeasurementFormScreen handles creating or editing a health measurement reading
/// with dynamic forms per vital type (e.g. side-by-side Systolic + Diastolic for BP).
class AddMeasurementFormScreen extends ConsumerStatefulWidget {
  final String? type;
  final MeasurementModel? initialMeasurement;

  const AddMeasurementFormScreen({
    super.key,
    this.type,
    this.initialMeasurement,
  });

  @override
  ConsumerState<AddMeasurementFormScreen> createState() =>
      _AddMeasurementFormScreenState();
}

class _AddMeasurementFormScreenState
    extends ConsumerState<AddMeasurementFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedType;
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _source = 'Manual';
  String _glucoseContext = 'fasting';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialMeasurement;
    if (item != null) {
      _selectedType = item.type;
      _glucoseContext = item.glucoseContext ?? 'fasting';
      if (item.type == MeasurementTypes.bloodPressure) {
        _systolicController.text = item.systolic != null
            ? item.systolic!.toInt().toString()
            : '';
        _diastolicController.text = item.diastolic != null
            ? item.diastolic!.toInt().toString()
            : '';
      } else {
        _valueController.text = item.numericValue != null
            ? (item.numericValue! % 1 == 0
                  ? item.numericValue!.toInt().toString()
                  : item.numericValue!.toString())
            : item.value;
      }
      _selectedDate = item.recordedAt;
      _selectedTime = TimeOfDay.fromDateTime(item.recordedAt);
      _notesController.text = item.notes ?? '';
      _source = item.source;
    } else {
      _selectedType = widget.type ?? MeasurementTypes.bloodPressure;
    }
  }

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBp = _selectedType == MeasurementTypes.bloodPressure;
    final unit = MeasurementTypes.getDefaultUnit(_selectedType);
    final title = MeasurementTypes.getDisplayName(_selectedType);

    final activeProfile = ref.watch(activeProfileProvider);
    final isAdultProfile = activeProfile?.isAdult ?? true;

    final isEditing = widget.initialMeasurement != null;
    final appBarTitle = isEditing ? 'Edit $title' : 'Add $title';

    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Semantics(
          label: 'Back',
          button: true,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
            onPressed: () => context.popOrGo(AppRoutes.measurements),
          ),
        ),
        title: Text(
          appBarTitle,
          style: AppTypography.h2.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VitalTypeBanner(title: title, unit: unit),

                if ((isBp ||
                        _selectedType == MeasurementTypes.respiratoryRate ||
                        _selectedType == MeasurementTypes.heartRate) &&
                    !isAdultProfile) ...[
                  const SizedBox(height: 12),
                  VitalAdultReferenceNotice(title: title),
                ],

                const SizedBox(height: 24),

                // Form Inputs according to type
                if (_selectedType == MeasurementTypes.bmi) ...[
                  BmiCalculationView(activeProfile: activeProfile),
                ] else ...[
                  VitalInputFields(
                    selectedType: _selectedType,
                    systolicController: _systolicController,
                    diastolicController: _diastolicController,
                    valueController: _valueController,
                    glucoseContext: _glucoseContext,
                    onGlucoseContextChanged: (ctx) {
                      setState(() => _glucoseContext = ctx);
                    },
                  ),
                ],
                const SizedBox(height: 20),

                if (_selectedType != MeasurementTypes.bmi ||
                    (activeProfile?.height != null &&
                        activeProfile?.weight != null)) ...[
                  if (_selectedType != MeasurementTypes.bmi) ...[
                    MeasurementDateTimePicker(
                      selectedDate: _selectedDate,
                      selectedTime: _selectedTime,
                      onPickDate: _pickDate,
                      onPickTime: _pickTime,
                    ),
                    const SizedBox(height: 20),
                  ],

                  MeasurementNotesSourceSection(
                    notesController: _notesController,
                    selectedType: _selectedType,
                  ),
                  const SizedBox(height: 32),

                  Semantics(
                    label: _selectedType == MeasurementTypes.bmi
                        ? 'Log Current BMI'
                        : 'Save Measurement',
                    button: true,
                    child: PrimaryButton(
                      text: _selectedType == MeasurementTypes.bmi
                          ? 'LOG CURRENT BMI'
                          : 'SAVE MEASUREMENT',
                      icon: Icons.bookmark_border,
                      isLoading: _isSaving,
                      onPressed: _saveMeasurement,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(now) ? now : _selectedDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveMeasurement() async {
    if (_isSaving) return;

    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    if (_selectedType != MeasurementTypes.bmi &&
        !_formKey.currentState!.validate()) {
      return;
    }

    final DateTime recordedAt;
    if (_selectedType == MeasurementTypes.bmi) {
      recordedAt = widget.initialMeasurement?.recordedAt ?? DateTime.now();
    } else {
      recordedAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (recordedAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        context.showSnackBar(
          'Measurement date and time cannot be in the future.',
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final newModel = MeasurementFormValuesBuilder.buildModel(
        initialId: widget.initialMeasurement?.id,
        clientUuid: widget.initialMeasurement?.clientUuid,
        activeProfile: activeProfile,
        selectedType: _selectedType,
        systolicText: _systolicController.text,
        diastolicText: _diastolicController.text,
        valueText: _valueController.text,
        notesText: _notesController.text,
        glucoseContext: _glucoseContext,
        source: widget.initialMeasurement?.source ?? _source,
        recordedAt: recordedAt,
      );

      await ref
          .read(measurementsListProvider.notifier)
          .addMeasurement(newModel);

      if (mounted) {
        context.popOrGo(AppRoutes.measurements);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
