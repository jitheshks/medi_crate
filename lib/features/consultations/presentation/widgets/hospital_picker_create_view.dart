import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/pickers/picker_action_buttons.dart';
import '../../../../shared/widgets/pickers/picker_duplicate_warning_banner.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../hospitals/data/models/hospital_model.dart';
import '../../../hospitals/presentation/providers/hospitals_providers.dart';
import '../../../hospitals/presentation/widgets/hospital_form_fields.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// HospitalPickerCreateView provides the inline form for creating a new hospital/clinic,
/// including duplicate name checking, validation, and repository persistence.
class HospitalPickerCreateView extends ConsumerStatefulWidget {
  final ValueChanged<HospitalModel> onHospitalSelected;
  final VoidCallback onBack;

  const HospitalPickerCreateView({
    super.key,
    required this.onHospitalSelected,
    required this.onBack,
  });

  @override
  ConsumerState<HospitalPickerCreateView> createState() =>
      _HospitalPickerCreateViewState();
}

class _HospitalPickerCreateViewState
    extends ConsumerState<HospitalPickerCreateView> {
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _addressController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _typeController = TextEditingController(text: 'Hospital');
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  HospitalModel? _findDuplicate(List<HospitalModel> hospitals, String rawName) {
    final clean = rawName.trim().toLowerCase();
    if (clean.isEmpty) return null;
    return hospitals
        .where((h) => h.name.trim().toLowerCase() == clean)
        .firstOrNull;
  }

  Future<void> _saveAndSelectNewHospital() async {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;

    final rawType = _typeController.text.trim();
    final type = rawType.isNotEmpty ? rawType : 'Hospital';
    final rawAddress = _addressController.text.trim();

    setState(() => _isSaving = true);

    try {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) {
        throw const UnknownApiException('No active profile selected.');
      }

      final hospRepo = ref.read(hospitalRepositoryProvider);
      final newHospital = HospitalModel(
        id: '',
        profileId: activeProfile.profileId,
        name: rawName,
        type: type,
        address: rawAddress.isNotEmpty ? rawAddress : null,
        clientUuid: UuidUtils.generateV4(),
      );

      final savedHospital = await hospRepo.saveHospitalModel(
        activeProfile.profileId,
        newHospital,
      );

      // Invalidate list provider and dashboard summaries so subsequent lookups and counts are synchronized
      ref.invalidate(hospitalsListProvider);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(insightsSummaryProvider);
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}

      if (!mounted) return;
      widget.onHospitalSelected(savedHospital);
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar('Failed to save hospital: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hospitalsAsync = ref.watch(hospitalsListProvider);
    final allHospitals = hospitalsAsync.value ?? <HospitalModel>[];

    final duplicateHospital = _findDuplicate(
      allHospitals,
      _nameController.text,
    );
    final isNameEmpty = _nameController.text.trim().isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FULL NAME *
        Text(
          'HOSPITAL / FACILITY NAME *',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _nameController,
          autofocus: true,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'City Care Hospital',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),

        // Live Duplicate Warning Banner
        if (duplicateHospital != null) ...[
          const SizedBox(height: 12),
          PickerDuplicateWarningBanner(
            duplicateName: duplicateHospital.name,
            entityNoun: 'facility',
            actionLabel: 'Use this hospital instead',
            onUseDuplicate: () {
              widget.onHospitalSelected(duplicateHospital);
              Navigator.of(context).pop();
            },
          ),
        ],

        const SizedBox(height: 12),

        // TYPE / FACILITY CATEGORY
        Text(
          'TYPE / FACILITY CATEGORY',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              HospitalFormFields.facilityTypes.contains(_typeController.text)
              ? _typeController.text
              : 'Hospital',
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
          items: HospitalFormFields.facilityTypes.map((t) {
            return DropdownMenuItem(value: t, child: Text(t));
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _typeController.text = val);
            }
          },
        ),
        const SizedBox(height: 12),

        // ADDRESS / LOCATION (Optional)
        Text(
          'ADDRESS / LOCATION',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _addressController,
          style: AppTypography.bodyMedium.copyWith(
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: 'e.g. MG Road, Kochi',
            hintStyle: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input),
              borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Bottom Action Buttons
        PickerActionButtons(
          isSaving: _isSaving,
          onSubmit: isNameEmpty ? null : _saveAndSelectNewHospital,
          onBack: widget.onBack,
        ),
      ],
    );
  }
}
