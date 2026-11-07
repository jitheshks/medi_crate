/// SettingsSubRoute defines the sub-route destinations under Settings.
enum SettingsSubRoute {
  accountSecurity('/settings/account-security', 'Account & Security'),
  notifications('/settings/notifications', 'Notifications'),
  appearance('/settings/appearance', 'Appearance'),
  currency('/settings/currency', 'Currency'),
  storage('/settings/storage', 'Storage'),
  dataSync('/settings/data-sync', 'Data & Sync'),
  exportRecords('/settings/export-records', 'Export Health Records'),
  about('/settings/about', 'About'),
  helpSupport('/settings/help-support', 'Help & Support');

  final String path;
  final String title;

  const SettingsSubRoute(this.path, this.title);
}
