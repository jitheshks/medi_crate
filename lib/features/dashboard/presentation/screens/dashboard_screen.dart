import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/dialogs/exit_confirmation_dialog.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../insights/presentation/screens/insights_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../timeline/presentation/screens/timeline_screen.dart';
import '../providers/dashboard_shell_provider.dart';
import '../widgets/account_drawer.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/dashboard_app_bar.dart';

/// DashboardScreen is the Application Shell managing global header, bottom navigation, and tab switching via IndexedStack.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final selectedTab = ref.watch(selectedTabProvider);
    final userName = authState.user?.name ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (selectedTab != 0) {
          ref.read(selectedTabProvider.notifier).state = 0;
          return;
        }

        final shouldExit = await ExitConfirmationDialog.show(context);
        if (shouldExit == true) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: const AccountDrawer(),
        appBar: DashboardAppBar(userName: userName),
        body: SafeArea(
          child: IndexedStack(
            index: selectedTab,
            children: const [
              HomeScreen(),
              TimelineScreen(),
              ReportsScreen(),
              InsightsScreen(),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: selectedTab,
          onTabSelected: (index) {
            ref.read(selectedTabProvider.notifier).state = index;
          },
        ),
      ),
    );
  }
}
