import 'package:flutter/material.dart';
import '../../../../../core/constants/app_currency.dart';
import '../../../../../core/constants/app_radius.dart';
import '../../../../../core/constants/app_typography.dart';

class ReportExpenseSection extends StatelessWidget {
  final bool enableExpense;
  final ValueChanged<bool> onEnableExpenseChanged;
  final TextEditingController amountController;
  final String expenseStatus;
  final ValueChanged<String> onStatusChanged;
  final String currency;

  const ReportExpenseSection({
    super.key,
    required this.enableExpense,
    required this.onEnableExpenseChanged,
    required this.amountController,
    required this.expenseStatus,
    required this.onStatusChanged,
    this.currency = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyCode = currency.toUpperCase();
    final currencySymbol = AppCurrency.getSymbol(currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Checkbox(
              value: enableExpense,
              onChanged: (val) => onEnableExpenseChanged(val ?? false),
            ),
            Text(
              'Add Expense for this Report',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        if (enableExpense) ...[
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: colorScheme.outline),
            ),
            color: colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AMOUNT ($currencyCode)',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1500',
                      prefixText: '$currencySymbol   ',
                      prefixStyle: AppTypography.bodyMedium.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Change your currency in Settings → Currency.',
                      style: AppTypography.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: amountController,
                    builder: (context, value, _) {
                      final hasAmount = value.text.trim().isNotEmpty;
                      if (!hasAmount) return const SizedBox.shrink();

                      final reduceMotion = MediaQuery.of(
                        context,
                      ).disableAnimations;
                      final duration = reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 180);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            'PAYMENT STATUS',
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: ['PAID', 'PENDING', 'INSURANCE'].map((
                              st,
                            ) {
                              final isSel = expenseStatus == st;
                              return ChoiceChip(
                                label: AnimatedDefaultTextStyle(
                                  duration: duration,
                                  curve: Curves.easeInOut,
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurface,
                                  ),
                                  child: Text(st),
                                ),
                                selected: isSel,
                                onSelected: (_) => onStatusChanged(st),
                              );
                            }).toList(),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
