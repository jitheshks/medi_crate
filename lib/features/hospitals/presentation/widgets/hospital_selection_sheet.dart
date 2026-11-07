import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:medivalut/app/routes/app_routes.dart';
import 'package:medivalut/core/constants/app_icons.dart';
import 'package:medivalut/core/constants/app_spacing.dart';
import 'package:medivalut/core/constants/app_typography.dart';
import 'package:medivalut/core/extensions/build_context_extensions.dart';
import 'package:medivalut/features/hospitals/data/models/hospital_model.dart';
import 'package:medivalut/features/hospitals/presentation/providers/hospitals_providers.dart';
import 'package:medivalut/shared/widgets/buttons/primary_button.dart';
import 'package:medivalut/shared/widgets/forms/app_search_field.dart';
import 'package:medivalut/shared/widgets/sheets/app_bottom_sheet.dart';

/// HospitalSelectionSheet presents a multi-select bottom modal for choosing or creating hospitals.
class HospitalSelectionSheet extends ConsumerStatefulWidget {
  final List<String> selectedHospitalIds;
  final Set<String> consultationHospitalIds;
  final ValueChanged<List<String>> onSelectionConfirmed;

  const HospitalSelectionSheet({
    super.key,
    required this.selectedHospitalIds,
    this.consultationHospitalIds = const {},
    required this.onSelectionConfirmed,
  });

  static Future<void> show({
    required BuildContext context,
    required List<String> selectedHospitalIds,
    Set<String> consultationHospitalIds = const {},
    required ValueChanged<List<String>> onSelectionConfirmed,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => HospitalSelectionSheet(
        selectedHospitalIds: selectedHospitalIds,
        consultationHospitalIds: consultationHospitalIds,
        onSelectionConfirmed: onSelectionConfirmed,
      ),
    );
  }

  @override
  ConsumerState<HospitalSelectionSheet> createState() =>
      _HospitalSelectionSheetState();
}

class _HospitalSelectionSheetState
    extends ConsumerState<HospitalSelectionSheet> {
  late List<String> _tempSelectedIds;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tempSelectedIds = List.from(widget.selectedHospitalIds);
  }

  @override
  Widget build(BuildContext context) {
    final hospitalsAsync = ref.watch(hospitalsListProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primaryColor = colorScheme.primary;

    return AppBottomSheet(
      title: 'Select Hospitals / Clinics',
      showCloseButton: true,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Associate this doctor with one or more facilities.',
              style: AppTypography.caption.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Search Field
            AppSearchField(
              hintText: 'Search hospital or clinic...',
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim().toLowerCase()),
              onClear: () => setState(() => _searchQuery = ''),
            ),
            const SizedBox(height: AppSpacing.md),

            // Create New Hospital Button
            OutlinedButton.icon(
              onPressed: () async {
                final created = await context.pushGuarded<HospitalModel>(
                  AppRoutes.addHospital,
                );
                if (created != null && mounted) {
                  setState(() {
                    if (!_tempSelectedIds.contains(created.id)) {
                      _tempSelectedIds.add(created.id);
                    }
                  });
                }
              },
              icon: Icon(Icons.add, size: 18, color: primaryColor),
              label: Text(
                '+ Create New Hospital / Clinic',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                side: BorderSide(color: primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Hospital List
            Expanded(
              child: hospitalsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) =>
                    const Center(child: Text('Failed to load hospitals.')),
                data: (hospitals) {
                  final filtered = hospitals.where((h) {
                    if (_searchQuery.isEmpty) return true;
                    final name = h.name.toLowerCase();
                    final type = (h.type ?? '').toLowerCase();
                    return name.contains(_searchQuery) ||
                        type.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No matching facilities found.'
                            : 'No hospitals created yet.',
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final hospital = filtered[index];
                      final isSelected = _tempSelectedIds.contains(hospital.id);

                      return Material(
                        color: Colors.transparent,
                        child: CheckboxListTile(
                          value: isSelected,
                          activeColor: primaryColor,
                          title: Text(
                            hospital.name,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Text(
                            widget.consultationHospitalIds.contains(hospital.id)
                                ? '${hospital.type ?? 'Hospital'} • Linked via consultation'
                                : (hospital.type ?? 'Hospital'),
                            style: AppTypography.caption.copyWith(
                              color:
                                  widget.consultationHospitalIds.contains(
                                    hospital.id,
                                  )
                                  ? primaryColor
                                  : colorScheme.onSurfaceVariant,
                              fontWeight:
                                  widget.consultationHospitalIds.contains(
                                    hospital.id,
                                  )
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              AppIcons.hospital,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                if (!_tempSelectedIds.contains(hospital.id)) {
                                  _tempSelectedIds.add(hospital.id);
                                }
                              } else {
                                _tempSelectedIds.remove(hospital.id);
                              }
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: AppSpacing.md),
            // Done Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: PrimaryButton(
                text: 'CONFIRM SELECTION (${_tempSelectedIds.length})',
                onPressed: () {
                  widget.onSelectionConfirmed(_tempSelectedIds);
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
