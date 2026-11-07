import 'package:flutter/material.dart';

/// AppSpacing defines standard padding, margins, and gaps.
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;

  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: 20.0,
    vertical: 16.0,
  );
  static const EdgeInsets cardPadding = EdgeInsets.all(16.0);
}
