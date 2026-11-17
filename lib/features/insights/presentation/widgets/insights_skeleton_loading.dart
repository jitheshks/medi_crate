import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_spacing.dart';

/// InsightsSkeletonLoading provides an animated skeleton placeholder layout
/// while Insights data is loading asynchronously.
class InsightsSkeletonLoading extends StatefulWidget {
  const InsightsSkeletonLoading({super.key});

  @override
  State<InsightsSkeletonLoading> createState() =>
      _InsightsSkeletonLoadingState();
}

class _InsightsSkeletonLoadingState extends State<InsightsSkeletonLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Skeleton
            _skeletonBox(context, width: 180, height: 28),
            const SizedBox(height: 8),
            _skeletonBox(context, width: 260, height: 16),
            const SizedBox(height: AppSpacing.lg),

            // Filter Chips Skeleton
            Row(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _skeletonBox(
                    context,
                    width: 70,
                    height: 32,
                    radius: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Health Score Hero Card Skeleton
            _skeletonBox(
              context,
              width: double.infinity,
              height: 160,
              radius: 16,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Vitals Grid Skeleton
            Row(
              children: [
                Expanded(
                  child: _skeletonBox(
                    context,
                    width: double.infinity,
                    height: 110,
                    radius: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _skeletonBox(
                    context,
                    width: double.infinity,
                    height: 110,
                    radius: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Healthcare Activity Skeleton
            _skeletonBox(
              context,
              width: double.infinity,
              height: 180,
              radius: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox(
    BuildContext context, {
    required double width,
    required double height,
    double radius = 8,
  }) {
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: placeholderColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
