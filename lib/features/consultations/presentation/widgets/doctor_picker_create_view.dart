import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_radius.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../../shared/widgets/pickers/picker_action_buttons.dart';
import '../../../../shared/widgets/pickers/picker_duplicate_warning_banner.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/presentation/providers/doctors_providers.dart';
import '../../../home/presentation/providers/clinical_sync_coordinator.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../../../insights/presentation/providers/insights_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

/// DoctorPickerCreateView provides the inline form for creating a new doctor,
/// including duplicate name checking, validation, and repository persistence.
class DoctorPickerCreateView extends ConsumerStatefulWidget {
  final ValueChanged<DoctorModel> onDoctorSelected;
  final VoidCallback onBack;

  const DoctorPickerCreateView({
    super.key,
    required this.onDoctorSelected,
    required this.onBack,
  });

  @override
  ConsumerState<DoctorPickerCreateView> createState() =>
      _DoctorPickerCreateViewState();
}

class _DoctorPickerCreateViewState
    extends ConsumerState<DoctorPickerCreateView> {
  late final TextEditingController _nameController;
  late final TextEditingController _specialtyController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _specialtyController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  DoctorModel? _findDuplicate(List<DoctorModel> doctors, String rawName) {
    final clean = rawName.trim().toLowerCase();
    if (clean.isEmpty) return null;
    return doctors
        .where((d) => d.name.trim().toLowerCase() == clean)
        .firstOrNull;
  }

  Future<void> _saveAndSelectNewDoctor() async {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;

    final rawSpecialty = _specialtyController.text.trim();
    final specialty = rawSpecialty.isNotEmpty
        ? rawSpecialty
        : 'General Practice';

    setState(() => _isSaving = true);

    try {
      final activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) {
        throw const UnknownApiException('No active profile selected.');
      }

      final docRepo = ref.read(doctorRepositoryProvider);
      final newDoctor = DoctorModel(
        id: '',
        profileId: activeProfile.profileId,
        name: rawName,
        specialty: specialty,
        clientUuid: UuidUtils.generateV4(),
      );

      final savedDoctor = await docRepo.saveDoctorModel(
        activeProfile.profileId,
        newDoctor,
      );

      // Invalidate list provider and dashboard summaries so subsequent lookups and counts are in sync
      ref.invalidate(doctorsListProvider);
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(insightsSummaryProvider);
      try {
        ref.read(clinicalCacheRevisionProvider.notifier).bump();
      } catch (_) {}

      if (!mounted) return;
      widget.onDoctorSelected(savedDoctor);
      Navigator.of(context).pop();
    } on AppException catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      context.showErrorSnackBar('Failed to save doctor: ${e.toString()}');
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
    final doctorsAsync = ref.watch(doctorsListProvider);
    final allDoctors = doctorsAsync.value ?? <DoctorModel>[];

    final duplicateDoctor = _findDuplicate(allDoctors, _nameController.text);
    final isNameEmpty = _nameController.text.trim().isEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // FULL NAME *
        Text(
          'FULL NAME *',
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
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Dr. Priya Kaur',
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
        if (duplicateDoctor != null) ...[
          const SizedBox(height: 12),
          PickerDuplicateWarningBanner(
            duplicateName: duplicateDoctor.name,
            entityNoun: 'doctor',
            onUseDuplicate: () {
              widget.onDoctorSelected(duplicateDoctor);
              Navigator.of(context).pop();
            },
          ),
        ],

        const SizedBox(height: 12),

        // SPECIALTY (Optional)
        Text(
          'SPECIALTY',
          style: AppTypography.labelSmall.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _specialtyController,
          decoration: InputDecoration(
            hintText: 'Cardiologist',
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
          onSubmit: isNameEmpty ? null : _saveAndSelectNewDoctor,
          onBack: () {
            _nameController.clear();
            _specialtyController.clear();
            widget.onBack();
          },
        ),
      ],
    );
  }
}
