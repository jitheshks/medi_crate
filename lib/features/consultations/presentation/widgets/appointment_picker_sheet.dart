import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_icons.dart';
import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/forms/app_search_field.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../../appointments/data/models/appointment_model.dart';
import '../providers/consultation_providers.dart';

/// Modal bottom sheet for selecting a convertible appointment to link with a consultation.
class AppointmentPickerSheet extends ConsumerStatefulWidget {
  final String? currentAppointmentId;
  final ValueChanged<AppointmentModel> onSelected;

  const AppointmentPickerSheet({
    super.key,
    this.currentAppointmentId,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    String? currentAppointmentId,
    required ValueChanged<AppointmentModel> onSelected,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) {
        return AppointmentPickerSheet(
          currentAppointmentId: currentAppointmentId,
          onSelected: onSelected,
        );
      },
    );
  }

  @override
  ConsumerState<AppointmentPickerSheet> createState() =>
      _AppointmentPickerSheetState();
}

class _AppointmentPickerSheetState
    extends ConsumerState<AppointmentPickerSheet> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointmentsAsync = ref.watch(convertibleAppointmentsProvider);
    final allAppointments = appointmentsAsync.value ?? <AppointmentModel>[];

    final filteredAppointments = allAppointments.where((app) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final titleMatch = app.title.toLowerCase().contains(q);
      final docMatch = app.doctorName.toLowerCase().contains(q);
      final hospMatch = (app.hospitalName ?? '').toLowerCase().contains(q);
      final deptMatch = (app.department ?? '').toLowerCase().contains(q);
      return titleMatch || docMatch || hospMatch || deptMatch;
    }).toList();

    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    return AppBottomSheet(
      title: 'Link Appointment',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          AppSearchField(
            controller: _searchController,
            hintText: 'Search by title, doctor, or hospital...',
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          ),
          const SizedBox(height: 12),

          // List / States
          if (appointmentsAsync.isLoading && allAppointments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredAppointments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 36,
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No matching appointments found.'
                          : 'No convertible appointments available.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 300,
              child: ListView.separated(
                itemCount: filteredAppointments.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: theme.dividerColor),
                itemBuilder: (context, index) {
                  final app = filteredAppointments[index];
                  final isSelected =
                      widget.currentAppointmentId != null &&
                      widget.currentAppointmentId!.isNotEmpty &&
                      IdUtils.matches(app.id, widget.currentAppointmentId);

                  final dateStr =
                      '${dateFormat.format(app.date)} • ${timeFormat.format(app.date)}';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.input),
                      ),
                      child: Icon(
                        AppIcons.calendar,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      app.title.isNotEmpty ? app.title : 'Appointment',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          '${app.doctorName}${app.hospitalName != null ? " • ${app.hospitalName}" : ""}',
                          style: AppTypography.caption.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: AppTypography.caption.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: 22,
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                    onTap: () {
                      widget.onSelected(app);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
