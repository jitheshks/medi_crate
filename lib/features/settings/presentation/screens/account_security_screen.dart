import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/email_change_section.dart';
import '../widgets/oauth_deletion_request_dialog.dart';
import '../widgets/password_change_section.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// AccountSecurityScreen handles password update, email update, and account deletion.
class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).user;
    final isOAuthUser = user?.authProvider.isOAuth ?? false;

    return SettingsSubScaffold(
      title: 'Account & Security',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PasswordChangeSection(),
          const SizedBox(height: 16),
          const EmailChangeSection(),
          const SizedBox(height: 20),
          SettingsGroupCard(
            title: 'Danger Zone',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isOAuthUser ? Icons.launch : Icons.delete_forever,
                  color: colorScheme.error,
                ),
                title: Text(
                  isOAuthUser ? 'Request Account Deletion' : 'Delete Account',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  isOAuthUser
                      ? 'Submit an account deletion request'
                      : 'Permanently remove account and data',
                  style: AppTypography.caption.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                onTap: () {
                  if (isOAuthUser) {
                    OAuthDeletionRequestDialog.show(
                      context,
                      email: user?.email,
                    );
                  } else {
                    DeleteAccountDialog.show(context);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
