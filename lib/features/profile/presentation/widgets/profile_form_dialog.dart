import 'package:flutter/material.dart';
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
    _selectedGender = p?.gender ?? 'Male';
    _selectedBloodGroup = p?.bloodGroup ?? 'O+';
    _isPrimary = p?.isPrimary ?? false;
    _allergiesConfirmedNone = p?.allergiesConfirmedNone ?? false;
    _chronicConditionsConfirmedNone =
        p?.chronicConditionsConfirmedNone ?? false;

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
            gender: _selectedGender,
            dateOfBirth: dobStr,
            bloodGroup: _selectedBloodGroup,
            height: parsedHeight,
            weight: parsedWeight,
            isPrimary: _isPrimary,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
            allergies: widget.profileToEdit!.allergies,
            allergiesConfirmedNone: _allergiesConfirmedNone,
            chronicConditions: widget.profileToEdit!.chronicConditions,
            chronicConditionsConfirmedNone: _chronicConditionsConfirmedNone,
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
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return AppBottomSheet(
      title: isEditing ? 'Edit Profile' : 'Add Family Profile',
      showCloseButton: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
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
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
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
                Row(
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  value: _allergiesConfirmedNone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _allergiesConfirmedNone = val ?? false;
                    });
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'No chronic conditions',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  value: _chronicConditionsConfirmedNone,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _chronicConditionsConfirmedNone = val ?? false;
                    });
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Notes (Optional)',
                  hint: 'Known allergies, medical conditions, etc.',
                  controller: _notesController,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Mark as Primary Profile',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Default profile loaded upon opening MediVault',
                    style: AppTypography.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: _isPrimary,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) {
                    setState(() {
                      _isPrimary = val;
                    });
                  },
                ),
                const SizedBox(height: 20),
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
