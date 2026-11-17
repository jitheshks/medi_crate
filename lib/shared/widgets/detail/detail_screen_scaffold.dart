import 'package:material_ui/material_ui.dart';

/// DetailScreenScaffold provides the unified, responsive scrollable container for all MediCrate detail screens.
class DetailScreenScaffold extends StatelessWidget {
  final Widget hero;
  final List<Widget> sections;
  final Widget? actions;
  final double topSpacing;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final ScrollPhysics? physics;

  const DetailScreenScaffold({
    super.key,
    required this.hero,
    required this.sections,
    this.actions,
    this.topSpacing = 24.0,
    this.maxWidth = 600.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0),
    this.scrollController,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      physics: physics,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topSpacing),
              hero,
              const SizedBox(height: 12),
              ...sections,
              ?actions,
            ],
          ),
        ),
      ),
    );
  }
}
