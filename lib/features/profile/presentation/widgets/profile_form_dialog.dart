import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/utils/form_submit_runner.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/forms/custom_text_field.dart';
import '../../../../shared/widgets/sheets/app_bottom_sheet.dart';
import '../../data/models/profile_model.dart';
import '../providers/profile_providers.dart';
import 'profile_demographics_input_section.dart';

/// ProfileFormDialog provides an interactive form for creating and editing family profiles.
class ProfileFormDialog extends ConsumerStatefulWidget {
  final ProfileModel? profileToEdit;

  const ProfileFormDialog({super.key, this.profileToEdit});

  static Future<void> show(
    BuildContext context, {
    ProfileModel? profileToEdit,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      builder: (context) => ProfileFormDialog(profileToEdit: profileToEdit),
    );
  }

  @override
  ConsumerState<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends ConsumerState<ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _relationshipOtherController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _notesController;

  late String _selectedRelationship;
  String? _selectedGender;
  String? _selectedBloodGroup;
  DateTime? _selectedDob;
  bool _isPrimary = false;
  bool _allergiesConfirmedNone = false;
  bool _chronicConditionsConfirmedNone = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profileToEdit;
    _nameController = TextEditingController(text: p?.fullName ?? '');
    _relationshipOtherController = TextEditingController(
      text: p?.relationshipOther ?? '',
    );
    _heightController = TextEditingController(
      text: p?.height != null ? p!.height!.toStringAsFixed(0) : '',
    );
    _weightController = TextEditingController(
      text: p?.weight != null ? p!.weight!.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');
    _selectedRelationship = p?.relationship ?? ProfileRelationships.father;
    _selectedGender = p?.gender;
    _selectedBloodGroup = p?.bloodGroup;
    _isPrimary = p?.isPrimary ?? false;

    final existingAllergies = p?.allergies ?? const [];
    final existingConditions = p?.chronicConditions ?? const [];

    // If existing data contains a contradictory list/flag combination,
    // preserve the entries and normalize the flag to false.
    _allergiesConfirmedNone = existingAllergies.isNotEmpty
        ? false
        : (p?.allergiesConfirmedNone ?? false);
    _chronicConditionsConfirmedNone = existingConditions.isNotEmpty
        ? false
        : (p?.chronicConditionsConfirmedNone ?? false);

    if (p?.dateOfBirth != null && p!.dateOfBirth!.isNotEmpty) {
      _selectedDob = DateTime.tryParse(p.dateOfBirth!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationshipOtherController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initialDate =
        _selectedDob ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _submit() async {
    final dobStr = _selectedDob != null
        ? "${_selectedDob!.year.toString().padLeft(4, '0')}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}"
        : null;

    final double? parsedHeight = _heightController.text.trim().isNotEmpty
        ? double.tryParse(_heightController.text.trim())
        : null;

    final double? parsedWeight = _weightController.text.trim().isNotEmpty
        ? double.tryParse(_weightController.text.trim())
        : null;

    final String? relOther = _selectedRelationship == ProfileRelationships.other
        ? _relationshipOtherController.text.trim()
        : null;

    await FormSubmitRunner.run<void>(
      context: context,
      isMounted: () => mounted,
      setLoading: (val) => setState(() => _isSubmitting = val),
      formKey: _formKey,
      defaultErrorMessage: "Couldn't save profile. Please try again.",
      action: () async {
        final notifier = ref.read(profilesListProvider.notifier);

        if (widget.profileToEdit != null) {
          final updated = widget.profileToEdit!.copyWith(
            fullName: _nameController.text.trim(),
            relationship: _selectedRelationship,
            relationshipOther: relOther,
            clearRelationshipOther: relOther == null,
            gender: _selectedGender,
            clearGender: _selectedGender == null,
            dateOfBirth: dobStr,
            clearDateOfBirth: dobStr == null,
            bloodGroup: _selectedBloodGroup,
            clearBloodGroup: _selectedBloodGroup == null,
            height: parsedHeight,
            clearHeight: parsedHeight == null,
            weight: parsedWeight,
            clearWeight: parsedWeight == null,
            isPrimary: _isPrimary,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            clearNotes: _notesController.text.trim().isEmpty,
            allergies: widget.profileToEdit!.allergies,
            allergiesConfirmedNone:
                widget.profileToEdit!.allergies.isEmpty &&
                    _allergiesConfirmedNone,
            chronicConditions: widget.profileToEdit!.chronicConditions,
            chronicConditionsConfirmedNone:
                widget.profileToEdit!.chronicConditions.isEmpty &&
                    _chronicConditionsConfirmedNone,
          );
          await notifier.updateProfile(updated);
        } else {
          await notifier.createProfile(
            fullName: _nameController.text.trim(),
            relationship: _selectedRelationship,
            relationshipOther: relOther,
            gender: _selectedGender,
            dateOfBirth: dobStr,
            bloodGroup: _selectedBloodGroup,
            height: parsedHeight,
            weight: parsedWeight,
            isPrimary: _isPrimary,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            allergies: const [],
            allergiesConfirmedNone: _allergiesConfirmedNone,
            chronicConditions: const [],
            chronicConditionsConfirmedNone: _chronicConditionsConfirmedNone,
          );
        }
      },
      onSuccess: (_) {
        Navigator.of(context).pop();
        context.showSnackBar(
          widget.profileToEdit != null
              ? 'Profile updated successfully'
              : 'Family profile created successfully',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.profileToEdit != null;
    final hasExistingAllergies =
        widget.profileToEdit?.allergies.isNotEmpty ?? false;
    final hasExistingConditions =
        widget.profileToEdit?.chronicConditions.isNotEmpty ?? false;
    final canToggleAllergies = !hasExistingAllergies;
    final canToggleConditions = !hasExistingConditions;
    final mediaQuery = MediaQuery.of(context);
    final availableHeight =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    // Leave room for AppBottomSheet's drag handle, title row, and padding (~100dp)
    final maxSheetHeight = (availableHeight * 0.68).clamp(
      200.0,
      (availableHeight - 110.0).clamp(200.0, 680.0),
    );

    return AppBottomSheet(
      title: isEditing ? 'Edit Profile' : 'Add Family Profile',
      showCloseButton: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  label: 'Full Name',
                  hint: 'e.g. Eleanor Vance',
                  controller: _nameController,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Relationship',
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRelationship,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                  items:
                      (isEditing && widget.profileToEdit?.isPrimary == true
                              ? ProfileRelationships.values
                              : ProfileRelationships.familyMemberValues)
                          .map((rel) {
                            return DropdownMenuItem(
                              value: rel,
                              child: Text(
                                rel,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                            );
                          })
                          .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRelationship = ProfileRelationships.normalize(
                          val,
                        );
                      });
                    }
                  },
                ),
                if (_selectedRelationship == ProfileRelationships.other) ...[
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Specify Relationship',
                    hint: 'e.g. Cousin, Guardian',
                    controller: _relationshipOtherController,
                    validator: (val) {
                      if (_selectedRelationship == ProfileRelationships.other &&
                          (val == null || val.trim().isEmpty)) {
                        return 'Please specify the relationship';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                ProfileDemographicsInputSection(
                  selectedGender: _selectedGender,
                  onGenderChanged: (val) =>
                      setState(() => _selectedGender = val),
                  selectedBloodGroup: _selectedBloodGroup,
                  onBloodGroupChanged: (val) =>
                      setState(() => _selectedBloodGroup = val),
                  selectedDob: _selectedDob,
                  onPickDob: _pickDob,
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isTwoColumn = constraints.maxWidth >= 280;
                    if (isTwoColumn) {
                      return Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              label: 'Height (cm)',
                              hint: 'e.g. 175',
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              label: 'Weight (kg)',
                              hint: 'e.g. 60',
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        CustomTextField(
                          label: 'Height (cm)',
                          hint: 'e.g. 175',
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'Weight (kg)',
                          hint: 'e.g. 60',
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Medical Status',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'No known allergies',
                    style: AppTypography.bodyMedium.copyWith(
                      color: canToggleAllergies
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6),
                    ),
                  ),
                  value: _allergiesConfirmedNone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: canToggleAllergies
                      ? (val) {
                          setState(() {
                            _allergiesConfirmedNone = val ?? false;
                          });
                        }
                      : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'No chronic conditions',
                    style: AppTypography.bodyMedium.copyWith(
                      color: canToggleConditions
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6),
                    ),
                  ),
                  value: _chronicConditionsConfirmedNone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: canToggleConditions
                      ? (val) {
                          setState(() {
                            _chronicConditionsConfirmedNone = val ?? false;
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Notes (Optional)',
                  hint: 'Known allergies, medical conditions, etc.',
                  controller: _notesController,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: isEditing ? 'Save Changes' : 'Create Profile',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
