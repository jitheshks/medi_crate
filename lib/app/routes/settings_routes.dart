import 'package:go_router/go_router.dart';
import '../../features/settings/presentation/screens/about_settings_screen.dart';
import '../../features/settings/presentation/screens/account_security_screen.dart';
import '../../features/settings/presentation/screens/appearance_settings_screen.dart';
import '../../features/settings/presentation/screens/currency_settings_screen.dart';
import '../../features/settings/presentation/screens/data_sync_settings_screen.dart';
import '../../features/settings/presentation/screens/export_records_screen.dart';
import '../../features/settings/presentation/screens/help_support_settings_screen.dart';
import '../../features/settings/presentation/screens/notification_settings_screen.dart';
import '../../features/settings/presentation/screens/privacy_settings_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/storage_settings_screen.dart';
import 'app_routes.dart';

final List<RouteBase> settingsRoutes = [
  GoRoute(
    path: AppRoutes.settings,
    builder: (context, state) => const SettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAccount,
    builder: (context, state) => const AccountSecurityScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsSecurity,
    builder: (context, state) => const AccountSecurityScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsChangePassword,
    builder: (context, state) => const AccountSecurityScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAccountSecurity,
    builder: (context, state) => const AccountSecurityScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsSecuritySub,
    builder: (context, state) => const AccountSecurityScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAppearance,
    builder: (context, state) => const AppearanceSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsCurrency,
    builder: (context, state) => const CurrencySettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsDataSync,
    builder: (context, state) => const DataSyncSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsStorage,
    builder: (context, state) => const StorageSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsPrivacy,
    builder: (context, state) => const PrivacySettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsAbout,
    builder: (context, state) => const AboutSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsHelpSupport,
    builder: (context, state) => const HelpSupportSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsNotifications,
    builder: (context, state) => const NotificationSettingsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsExportRecords,
    builder: (context, state) => const ExportRecordsScreen(),
  ),
  GoRoute(
    path: AppRoutes.settingsExport,
    builder: (context, state) => const ExportRecordsScreen(),
  ),
];
