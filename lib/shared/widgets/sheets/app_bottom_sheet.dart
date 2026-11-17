import 'package:material_ui/material_ui.dart';

import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_typography.dart';

/// Presentation shell and static presenter for modal bottom sheets.
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final bool showDragHandle;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const AppBottomSheet({
    super.key,
    this.title,
    this.titleWidget,
    this.trailing,
    this.showCloseButton = true,
    this.onClose,
    this.showDragHandle = true,
    this.padding,
    required this.child,
  });

  static DateTime _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _cooldown = Duration(milliseconds: 500);

  /// Displays a modal bottom sheet with standardized presentation defaults
  /// and protection against duplicate concurrent presentations.
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useRootNavigator = true,
    bool useSafeArea = true,
    bool isDismissible = true,
    bool enableDrag = true,
  }) async {
    final now = DateTime.now();
    if (now.difference(_lastOpenTime) < _cooldown) {
      return null;
    }
    _lastOpenTime = now;
    return await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: builder,
    );
  }

  @visibleForTesting
  static void reset() {
    _lastOpenTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: theme.scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final effectiveBottomPadding =
                constraints.maxHeight <= bottomInset + 100
                    ? 20.0
                    : bottomInset + 20.0;

            return Padding(
              padding:
                  padding ??
                  EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: effectiveBottomPadding,
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDragHandle) ...[
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (title != null || titleWidget != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child:
                              titleWidget ??
                              Text(
                                title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.h2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                        ),
                        if (trailing != null)
                          trailing!
                        else if (showCloseButton)
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: 20,
                              color: colorScheme.onSurface,
                            ),
                            onPressed:
                                onClose ?? () => Navigator.of(context).pop(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Flexible(child: child),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
