import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';

/// OtpInputRow renders responsive OTP input boxes with focus traversal and paste handling.
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
    final count = controllers.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final spacing = count > 5 ? 6.0 : 8.0;
        final availableWidth = totalWidth - (spacing * (count - 1));
        final boxWidth = (availableWidth / count).clamp(38.0, 54.0);
        final boxHeight = (boxWidth * 1.18).clamp(46.0, 60.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (index) {
            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : spacing / 2,
                right: index == count - 1 ? 0 : spacing / 2,
              ),
              child: SizedBox(
                width: boxWidth,
                height: boxHeight,
                child: TextFormField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: count,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  style: (count > 5 ? AppTypography.h2 : AppTypography.h1)
                      .copyWith(color: colorScheme.onSurface),
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
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
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
      },
    );
  }
}
