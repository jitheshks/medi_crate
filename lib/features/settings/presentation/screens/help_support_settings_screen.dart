import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// HelpSupportSettingsScreen displays an expandable FAQ list and email support launcher.
class HelpSupportSettingsScreen extends StatelessWidget {
  const HelpSupportSettingsScreen({super.key});

  Future<void> _launchSupportEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@medivault.app',
      queryParameters: {'subject': 'MediVault Support Inquiry'},
    );
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (context.mounted) {
          context.showSnackBar(
            'Could not launch email app. Contact support@medivault.app',
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        context.showSnackBar('Contact support@medivault.app');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final faqs = [
      {
        'q': 'Is my medical data safe in MediVault?',
        'a':
            'Yes. All health records are stored locally in Hive encrypted storage on your device. MediVault operates on an offline-first architecture.',
      },
      {
        'q': 'How does offline synchronization work?',
        'a':
            'When you are offline, all changes are saved to your local Hive queue. As soon as connectivity returns, SyncService drains the queue in the background.',
      },
      {
        'q': 'Can I export my medical records?',
        'a':
            'Yes. You can generate client-side PDF summaries anytime from Settings > Export Health Records without needing server access.',
      },
      {
        'q': 'What platforms are supported?',
        'a':
            'MediVault runs natively across Android, iOS, Windows, macOS, Linux, and modern Web browsers with responsive layouts.',
      },
    ];

    return SettingsSubScaffold(
      title: 'Help & Support',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroupCard(
            title: 'Frequently Asked Questions',
            children: faqs.map((faq) {
              return ExpansionTile(
                title: Text(
                  faq['q']!,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      faq['a']!,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          SettingsGroupCard(
            title: 'Contact Support',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help with your vault?',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Our support team is available to help resolve issues or take feedback.',
                      style: AppTypography.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    PrimaryButton(
                      text: 'Email Support (support@medivault.app)',
                      onPressed: () => _launchSupportEmail(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
