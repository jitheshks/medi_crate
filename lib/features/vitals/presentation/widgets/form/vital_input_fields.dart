import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/widgets/forms/custom_text_field.dart';
import '../../../data/models/measurement_model.dart';
import 'blood_glucose_input_field.dart';
import 'blood_pressure_input_field.dart';

class VitalInputFields extends StatelessWidget {
  final String selectedType;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController valueController;
  final String glucoseContext;
  final ValueChanged<String> onGlucoseContextChanged;

  const VitalInputFields({
    super.key,
    required this.selectedType,
    required this.systolicController,
    required this.diastolicController,
    required this.valueController,
    required this.glucoseContext,
    required this.onGlucoseContextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final title = MeasurementTypes.getDisplayName(selectedType);
    final unit = MeasurementTypes.getDefaultUnit(selectedType);

    if (selectedType == MeasurementTypes.bloodPressure) {
      return BloodPressureInputField(
        systolicController: systolicController,
        diastolicController: diastolicController,
      );
    } else if (selectedType == MeasurementTypes.bloodGlucose) {
      return BloodGlucoseInputField(
        valueController: valueController,
        glucoseContext: glucoseContext,
        onGlucoseContextChanged: onGlucoseContextChanged,
      );
    } else if (selectedType == MeasurementTypes.spo2) {
      return Semantics(
        label: 'Oxygen saturation SpO₂ percentage value',
        child: CustomTextField(
          controller: valueController,
          label: 'VALUE (%)',
          hint: 'e.g. 98',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter an SpO₂ value.';
            }
            final num = double.tryParse(val.trim());
            if (num == null) {
              return 'Please enter a valid number.';
            }
            if (num < 0 || num > 100) {
              return 'SpO₂ must be between 0% and 100%.';
            }
            return null;
          },
        ),
      );
    } else if (selectedType == MeasurementTypes.respiratoryRate) {
      return Semantics(
        label: 'Respiratory rate in breaths per minute',
        child: CustomTextField(
          controller: valueController,
          label: 'VALUE (BR/MIN)',
          hint: 'e.g. 16',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter a respiratory rate.';
            }
            final num = double.tryParse(val.trim());
            if (num == null) {
              return 'Please enter a valid number.';
            }
            if (num < 1 || num > 100) {
              return 'Respiratory rate must be between 1 and 100 br/min.';
            }
            return null;
          },
        ),
      );
    } else if (selectedType == MeasurementTypes.heartRate) {
      return Semantics(
        label: 'Heart rate in beats per minute',
        child: CustomTextField(
          controller: valueController,
          label: 'VALUE (BPM)',
          hint: 'e.g. 72',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter a heart rate.';
            }
            final num = double.tryParse(val.trim());
            if (num == null) {
              return 'Please enter a valid number.';
            }
            if (num < 1 || num > 250) {
              return 'Heart rate must be between 1 and 250 bpm.';
            }
            return null;
          },
        ),
      );
    } else if (selectedType == MeasurementTypes.temperature) {
      return Semantics(
        label: 'Body temperature in degrees Celsius',
        child: CustomTextField(
          controller: valueController,
          label: 'VALUE (°C)',
          hint: 'e.g. 37',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter a temperature.';
            }
            final num = double.tryParse(val.trim());
            if (num == null) {
              return 'Please enter a valid number.';
            }
            if (num < 30 || num > 45) {
              return 'Temperature must be between 30°C and 45°C.';
            }
            return null;
          },
        ),
      );
    } else {
      return Semantics(
        label: '$title value in $unit',
        child: CustomTextField(
          controller: valueController,
          label: 'VALUE (${unit.toUpperCase()})',
          hint: _getHintForType(selectedType),
          keyboardType: selectedType == MeasurementTypes.temperature
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          inputFormatters: selectedType == MeasurementTypes.temperature
              ? []
              : [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter value';
            }
            final num = double.tryParse(val.trim());
            if (num == null || num < 0) {
              return 'Please enter a valid positive number';
            }
            return null;
          },
        ),
      );
    }
  }

  String _getHintForType(String type) {
    switch (type.toLowerCase()) {
      case 'blood_glucose':
      case 'glucose':
        return 'e.g. 100';
      case 'heart_rate':
        return 'e.g. 72';
      case 'spo2':
        return 'e.g. 98';
      case 'temperature':
        return 'e.g. 37';
      case 'weight':
        return 'e.g. 70';
      case 'respiratory_rate':
        return 'e.g. 16';
      default:
        return 'e.g. 98';
    }
  }
}
