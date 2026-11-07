import 'package:flutter/material.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';

/// TermsPrivacySheet displays the Terms of Service & Privacy Policy acceptance modal.
class TermsPrivacySheet extends StatefulWidget {
  final VoidCallback onAccept;

  const TermsPrivacySheet({super.key, required this.onAccept});

  static Future<void> show({
    required BuildContext context,
    required VoidCallback onAccept,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => TermsPrivacySheet(onAccept: onAccept),
    );
  }

  @override
  State<TermsPrivacySheet> createState() => _TermsPrivacySheetState();
}

class _TermsPrivacySheetState extends State<TermsPrivacySheet> {
  bool _agreed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBottomSheet(
      title: 'Terms & Privacy Policy',
      showCloseButton: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MediCrate prioritizes your health record privacy. By using MediCrate, you acknowledge that your health data is encrypted and stored locally on your device.',
            style: AppTypography.subtitle.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              context.pushGuarded(AppRoutes.termsPrivacy);
            },
            child: Text(
              'Read Full Terms of Service & Privacy Policy →',
              style: AppTypography.caption.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Checkbox(
                value: _agreed,
                activeColor: colorScheme.primary,
                onChanged: (val) => setState(() => _agreed = val ?? false),
              ),
              Expanded(
                child: Text(
                  'I agree to the Terms of Service and Privacy Policy',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Accept & Continue',
            onPressed: _agreed
                ? () {
                    Navigator.pop(context);
                    widget.onAccept();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
