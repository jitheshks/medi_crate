import '../../../../core/providers/mutable_state_notifier.dart';

/// selectedTabProvider manages the active bottom navigation tab index in DashboardScreen shell.
final selectedTabProvider = mutableStateProvider<int>(0, name: 'selectedTabProvider');
