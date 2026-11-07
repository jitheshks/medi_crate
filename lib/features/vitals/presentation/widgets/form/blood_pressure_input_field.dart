import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../shared/widgets/forms/custom_text_field.dart';

class BloodPressureInputField extends StatelessWidget {
  final TextEditingController systolicController;
  final TextEditingController diastolicController;

  const BloodPressureInputField({
    super.key,
    required this.systolicController,
    required this.diastolicController,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            label: 'Systolic blood pressure in mmHg',
            child: CustomTextField(
              controller: systolicController,
              label: 'SYSTOLIC (MMHG)',
              hint: 'e.g. 120',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Enter systolic';
                }
                final num = double.tryParse(val.trim());
                if (num == null) {
                  return 'Must be a number';
                }
                if (num < 40 || num > 300) {
                  return 'Must be 40-300';
                }
                final diaVal = double.tryParse(diastolicController.text.trim());
                if (diaVal != null && num <= diaVal) {
                  return 'Must be > diastolic';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: 'Diastolic blood pressure in mmHg',
            child: CustomTextField(
              controller: diastolicController,
              label: 'DIASTOLIC (MMHG)',
              hint: 'e.g. 80',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Enter diastolic';
                }
                final num = double.tryParse(val.trim());
                if (num == null) {
                  return 'Must be a number';
                }
                if (num < 20 || num > 200) {
                  return 'Must be 20-200';
                }
                final sysVal = double.tryParse(systolicController.text.trim());
                if (sysVal != null && sysVal <= num) {
                  return 'Must be < systolic';
                }
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }
}
