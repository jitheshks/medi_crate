import 'package:currency_picker/currency_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_currency.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/settings_sub_scaffold.dart';

/// CurrencySettingsScreen handles global application currency selection (INR, USD, EUR, GBP).
class CurrencySettingsScreen extends ConsumerWidget {
  const CurrencySettingsScreen({super.key});

  void _openCurrencyPicker(BuildContext context, WidgetRef ref) {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      currencyFilter: AppCurrency.codes,
      onSelect: (Currency currency) async {
        await ref
            .read(settingsControllerProvider.notifier)
            .setAppCurrency(currency.code);
        if (context.mounted) {
          context.showSnackBar('Currency set to ${currency.code}.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);

    return SettingsSubScaffold(
      title: 'Currency',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsGroupCard(
            title: 'Application Currency',
            children: [
              for (
                int i = 0;
                i < AppCurrency.supportedCurrencies.length;
                i++
              ) ...[
                if (i > 0) const Divider(),
                _buildCurrencyTile(
                  context,
                  ref,
                  currency: AppCurrency.supportedCurrencies[i],
                  selectedCurrency: settings.appCurrency,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SettingsGroupCard(
            title: 'Currency Picker',
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.travel_explore,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Select via Currency Picker',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  'Search with flags and country metadata',
                  style: AppTypography.caption.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => _openCurrencyPicker(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyTile(
    BuildContext context,
    WidgetRef ref, {
    required AppCurrency currency,
    required String selectedCurrency,
  }) {
    final isSelected =
        currency.code.toUpperCase() == selectedCurrency.toUpperCase();
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: () async {
        await ref
            .read(settingsControllerProvider.notifier)
            .setAppCurrency(currency.code);
        if (context.mounted) {
          context.showSnackBar('Currency set to ${currency.code}.');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? primaryColor : unselectedColor,
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${currency.symbol} ${currency.code} — ${currency.name}',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
