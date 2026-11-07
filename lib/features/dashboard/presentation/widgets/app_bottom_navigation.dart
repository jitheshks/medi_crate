import 'package:flutter/material.dart';

import '../../../../core/constants/app_icons.dart';
import 'quick_create_sheet.dart';

/// AppBottomNavigation is the single canonical bottom navigation bar for the Application Shell.
class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context,
                index: 0,
                icon: AppIcons.home,
                label: 'Home',
              ),
              _buildNavItem(
                context,
                index: 1,
                icon: AppIcons.calendar,
                label: 'Timeline',
              ),
              _buildFabSlot(context),
              _buildNavItem(
                context,
                index: 2,
                icon: AppIcons.fileText,
                label: 'Reports',
              ),
              _buildNavItem(
                context,
                index: 3,
                icon: AppIcons.activity,
                label: 'Insights',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = index == currentIndex;
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.08 : 1.0,
                duration: duration,
                curve: Curves.easeOutBack,
                child: TweenAnimationBuilder<Color?>(
                  duration: duration,
                  curve: Curves.easeInOut,
                  tween: ColorTween(end: color),
                  builder: (context, animatedColor, child) {
                    return Icon(icon, color: animatedColor, size: 22);
                  },
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: duration,
                  curve: Curves.easeInOut,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                  ),
                  child: Text(label, maxLines: 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabSlot(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(Icons.add, color: colorScheme.onPrimary, size: 24),
        onPressed: () => QuickCreateSheet.show(context),
      ),
    );
  }
}
