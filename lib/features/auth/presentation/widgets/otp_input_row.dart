import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// OtpInputRow renders the 4 separate OTP input boxes with focus traversal and paste handling.
class OtpInputRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final Function(int index, String value) onChanged;

  const OtpInputRow({
    super.key,
    required this.controllers,
    required this.focusNodes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 8,
            right: index == 3 ? 0 : 8,
          ),
          child: SizedBox(
            width: 56,
            height: 60,
            child: TextFormField(
              controller: controllers[index],
              focusNode: focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              autofillHints: const [AutofillHints.oneTimeCode],
              style: AppTypography.h1.copyWith(color: colorScheme.onSurface),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(color: colorScheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: AppRadius.mdBorder,
                  borderSide: BorderSide(color: colorScheme.error),
                ),
              ),
              onChanged: (val) => onChanged(index, val),
            ),
          ),
        );
      }),
    );
  }
}
