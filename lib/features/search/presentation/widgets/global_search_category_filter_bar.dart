import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../data/models/global_search_result.dart';
import '../providers/global_search_providers.dart';

/// GlobalSearchCategoryFilterBar renders the horizontal list of category filter chips
/// with live result counts and animated selection states.
class GlobalSearchCategoryFilterBar extends ConsumerWidget {
  const GlobalSearchCategoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(globalSearchQueryProvider);
    final selectedCategory = ref.watch(globalSearchCategoryFilterProvider);
    final categoryCounts = ref.watch(globalSearchCategoryCountsProvider);
    final totalResultsCount = ref.watch(allGlobalSearchResultsProvider).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _CategoryFilterChipItem(
            label:
                'All${searchQuery.isNotEmpty ? " ($totalResultsCount)" : ""}',
            isSelected: selectedCategory == null,
            onTap: () {
              ref.read(globalSearchCategoryFilterProvider.notifier).state =
                  null;
            },
          ),
          ...SearchEntityType.values.map((type) {
            final count = categoryCounts[type] ?? 0;
            final label = searchQuery.isNotEmpty
                ? '${type.filterChipLabel} ($count)'
                : type.filterChipLabel;

            return _CategoryFilterChipItem(
              label: label,
              icon: type.icon,
              isSelected: selectedCategory == type,
              onTap: () {
                ref.read(globalSearchCategoryFilterProvider.notifier).state =
                    selectedCategory == type ? null : type;
              },
            );
          }),
        ],
      ),
    );
  }
}

class _CategoryFilterChipItem extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterChipItem({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: icon != null
            ? TweenAnimationBuilder<Color?>(
                duration: duration,
                curve: Curves.easeInOut,
                tween: ColorTween(
                  end: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                builder: (context, animatedColor, child) {
                  return Icon(icon, size: 14, color: animatedColor);
                },
              )
            : null,
        label: AnimatedDefaultTextStyle(
          duration: duration,
          curve: Curves.easeInOut,
          style: AppTypography.caption.copyWith(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(label),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primary,
        checkmarkColor: colorScheme.onPrimary,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          side: BorderSide(
            color: isSelected ? colorScheme.primary : colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
