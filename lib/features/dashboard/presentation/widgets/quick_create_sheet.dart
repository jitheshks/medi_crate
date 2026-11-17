import 'package:material_ui/material_ui.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import 'quick_create_item.dart';

/// QuickCreateSheet renders the Material 3 modal bottom sheet for one-tap health record creation navigation.
class QuickCreateSheet extends StatelessWidget {
  const QuickCreateSheet({super.key});

  /// Displays the Quick Create Bottom Sheet in the current BuildContext.
  static void show(BuildContext context) {
    AppBottomSheet.show<void>(
      context: context,
      builder: (context) => const QuickCreateSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.70;
    final colorScheme = Theme.of(context).colorScheme;

    return AppBottomSheet(
      title: 'Quick create',
      showCloseButton: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600, maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Choose what you'd like to add.",
                style: AppTypography.subtitle.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 16),

              // 1. Log Vitals
              QuickCreateItem(
                icon: AppIcons.activity,
                title: 'Log Vitals',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addMeasurement,
                  'Log Vitals',
                ),
              ),
              _buildDivider(context),

              // 2. Add Doctor
              QuickCreateItem(
                icon: Icons.person_add_outlined,
                title: 'Add Doctor',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addDoctor,
                  'Add Doctor',
                ),
              ),
              _buildDivider(context),

              // 3. Add Hospital
              QuickCreateItem(
                icon: AppIcons.hospital,
                title: 'Add Hospital',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addHospital,
                  'Add Hospital',
                ),
              ),
              _buildDivider(context),

              // 4. New Consultation
              QuickCreateItem(
                icon: AppIcons.stethoscope,
                title: 'New Consultation',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addConsultation,
                  'New Consultation',
                ),
              ),
              _buildDivider(context),

              // 5. Upload Report
              QuickCreateItem(
                icon: AppIcons.fileText,
                title: 'Upload Report',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addReport,
                  'Upload Report',
                ),
              ),
              _buildDivider(context),

              // 6. Add Medicine
              QuickCreateItem(
                icon: AppIcons.pill,
                title: 'Add Medicine',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.addMedicine,
                  'Add Medicine',
                ),
              ),
              _buildDivider(context),

              // 7. Schedule Appointment
              QuickCreateItem(
                icon: AppIcons.calendar,
                title: 'Schedule Appointment',
                onTap: () => _handleNavigation(
                  context,
                  AppRoutes.newAppointment,
                  'Schedule Appointment',
                ),
              ),
              const SizedBox(height: 20),

              // CANCEL Button
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 48,
                  minWidth: double.infinity,
                ),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'CANCEL',
                    style: AppTypography.button.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
    );
  }

  void _handleNavigation(
    BuildContext context,
    String routePath,
    String itemName,
  ) {
    // 1. Dismiss Bottom Sheet first
    Navigator.of(context).pop();

    // 2. Schedule navigation after modal pop transition to prevent _debugLocked
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      try {
        context.pushGuarded(routePath);
      } catch (e) {
        context.showSnackBar('Unable to open screen. Please try again.');
      }
    });
  }
}
