import 'package:flutter_riverpod/flutter_riverpod.dart';

/// selectedTabProvider manages the active bottom navigation tab index in DashboardScreen shell.
final selectedTabProvider = StateProvider<int>((ref) => 0);
