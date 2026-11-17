import 'package:material_ui/material_ui.dart';

/// AppRadius defines standard border radius tokens.
abstract class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double pill = 999.0;

  static const double input = 12.0;
  static const double card = 16.0;
  static const double chip = 20.0;
  static const double dialog = 24.0;
  static const double sheet = 26.0;

  static final BorderRadius smBorder = BorderRadius.circular(sm);
  static final BorderRadius mdBorder = BorderRadius.circular(md);
  static final BorderRadius lgBorder = BorderRadius.circular(lg);
  static final BorderRadius xlBorder = BorderRadius.circular(xl);
  static final BorderRadius pillBorder = BorderRadius.circular(pill);
}
