import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/extensions/build_context_extensions.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_avatar_picker.dart';
import '../widgets/profile_medical_history_section.dart';
import '../widgets/profile_medical_info_section.dart';
import '../widgets/profile_personal_info_section.dart';
import '../widgets/profile_save_helper.dart';

/// ProfileScreen displays and edits personal health profile details
/// according to MediCrate UI specification.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  final TextEditingController _allergyInputController = TextEditingController();
  final TextEditingController _conditionInputController =
      TextEditingController();

  DateTime? _selectedDob;
  String? _selectedGender;
  String? _selectedBloodGroup;
  String? _photoPath;
  bool _isSaving = false;

  List<String> _allergies = [];
  bool _allergiesConfirmedNone = false;
  List<String> _chronicConditions = [];
  bool _chronicConditionsConfirmedNone = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _heightController = TextEditingController();
    _weightController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  void _loadProfileData() {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) return;

    setState(() {
      _nameController.text = profile.fullName;
      _heightController.text = profile.height != null
          ? profile.height!.toStringAsFixed(0)
          : '';
      _weightController.text = profile.weight != null
          ? profile.weight!.toStringAsFixed(0)
          : '';
      _selectedGender = profile.gender;
      _selectedBloodGroup = profile.bloodGroup;
      _photoPath = profile.photo;
      _allergies = List<String>.from(profile.allergies);
      // Normalize contradictory state: if list has entries, confirmed-none must be false
      _allergiesConfirmedNone = _allergies.isNotEmpty
          ? false
          : profile.allergiesConfirmedNone;
      _chronicConditions = List<String>.from(profile.chronicConditions);
      _chronicConditionsConfirmedNone = _chronicConditions.isNotEmpty
          ? false
          : profile.chronicConditionsConfirmedNone;

      if (profile.dateOfBirth != null && profile.dateOfBirth!.isNotEmpty) {
        _selectedDob = DateTime.tryParse(profile.dateOfBirth!);
      } else {
        final userDob = ref.read(authControllerProvider).user?.dateOfBirth;
        if (userDob != null && userDob.isNotEmpty) {
          _selectedDob = DateTime.tryParse(userDob);
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _allergyInputController.dispose();
    _conditionInputController.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final text = _allergyInputController.text.trim();
    if (text.isEmpty) return;
    if (!_allergies.any((a) => a.toLowerCase() == text.toLowerCase())) {
      setState(() {
        _allergies.add(text);
        _allergiesConfirmedNone = false;
        _allergyInputController.clear();
      });
    } else {
      _allergyInputController.clear();
    }
  }

  void _removeAllergy(String a) {
    setState(() {
      _allergies.remove(a);
      // Removing an entry must not automatically confirm that the list is empty
      if (_allergies.isNotEmpty) {
        _allergiesConfirmedNone = false;
      }
    });
  }

  void _onAllergiesConfirmedNoneChanged(bool? val) {
    setState(() {
      // Cannot set confirmed-none to true while list contains entries
      if (val == true && _allergies.isNotEmpty) {
        _allergiesConfirmedNone = false;
      } else {
        _allergiesConfirmedNone = val ?? false;
      }
    });
  }

  void _addCondition() {
    final text = _conditionInputController.text.trim();
    if (text.isEmpty) return;
    if (!_chronicConditions.any((c) => c.toLowerCase() == text.toLowerCase())) {
      setState(() {
        _chronicConditions.add(text);
        _chronicConditionsConfirmedNone = false;
        _conditionInputController.clear();
      });
    } else {
      _conditionInputController.clear();
    }
  }

  void _removeCondition(String c) {
    setState(() {
      _chronicConditions.remove(c);
      // Removing an entry must not automatically confirm that the list is empty
      if (_chronicConditions.isNotEmpty) {
        _chronicConditionsConfirmedNone = false;
      }
    });
  }

  void _onChronicConditionsConfirmedNoneChanged(bool? val) {
    setState(() {
      // Cannot set confirmed-none to true while list contains entries
      if (val == true && _chronicConditions.isNotEmpty) {
        _chronicConditionsConfirmedNone = false;
      } else {
        _chronicConditionsConfirmedNone = val ?? false;
      }
    });
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final initial = _selectedDob ?? DateTime(now.year - 30, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    setState(() => _isSaving = true);

    await ProfileSaveHelper.saveProfile(
      context: context,
      ref: ref,
      activeProfile: activeProfile,
      nameText: _nameController.text,
      heightText: _heightController.text,
      weightText: _weightController.text,
      selectedDob: _selectedDob,
      selectedGender: _selectedGender,
      selectedBloodGroup: _selectedBloodGroup,
      photoPath: _photoPath,
      allergies: _allergies,
      allergiesConfirmedNone: _allergies.isEmpty && _allergiesConfirmedNone,
      chronicConditions: _chronicConditions,
      chronicConditionsConfirmedNone:
          _chronicConditions.isEmpty && _chronicConditionsConfirmedNone,
    );

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeProfileProvider, (prev, next) {
      if (next != null &&
          (prev == null ||
              prev.profileId != next.profileId ||
              prev.photo != next.photo ||
              prev.dateOfBirth != next.dateOfBirth ||
              (_selectedDob == null && next.dateOfBirth != null) ||
              _nameController.text.isEmpty)) {
        _loadProfileData();
      }
    });

    final activeProfile = ref.watch(activeProfileProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Profile',
          style: AppTypography.h2.copyWith(color: colorScheme.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => context.popOrGo(AppRoutes.profiles),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: colorScheme.outline),
        ),
      ),
      body: activeProfile == null
          ? const Center(child: Text('No active profile selected.'))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ProfileAvatarPicker(
                            photoPath: _photoPath,
                            profileId: activeProfile.profileId,
                            onPhotoChanged: (path) =>
                                setState(() => _photoPath = path),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionLabel(context, 'PERSONAL INFORMATION'),
                          const SizedBox(height: 12),
                          ProfilePersonalInfoSection(
                            nameController: _nameController,
                            selectedDob: _selectedDob,
                            selectedGender: _selectedGender,
                            onPickDob: _selectDob,
                            onGenderChanged: (gender) =>
                                setState(() => _selectedGender = gender),
                          ),
                          const SizedBox(height: 28),
                          _buildSectionLabel(context, 'MEDICAL INFORMATION'),
                          const SizedBox(height: 16),
                          ProfileMedicalInfoSection(
                            selectedBloodGroup: _selectedBloodGroup,
                            heightController: _heightController,
                            weightController: _weightController,
                            onBloodGroupChanged: (bg) =>
                                setState(() => _selectedBloodGroup = bg),
                          ),
                          const SizedBox(height: 28),
                          _buildSectionLabel(context, 'MEDICAL HISTORY'),
                          const SizedBox(height: 16),
                          ProfileMedicalHistorySection(
                            allergyInputController: _allergyInputController,
                            allergies: _allergies,
                            allergiesConfirmedNone: _allergiesConfirmedNone,
                            onAddAllergy: _addAllergy,
                            onRemoveAllergy: _removeAllergy,
                            onAllergiesConfirmedNoneChanged:
                                _onAllergiesConfirmedNoneChanged,
                            conditionInputController: _conditionInputController,
                            chronicConditions: _chronicConditions,
                            chronicConditionsConfirmedNone:
                                _chronicConditionsConfirmedNone,
                            onAddCondition: _addCondition,
                            onRemoveCondition: _removeCondition,
                            onChronicConditionsConfirmedNoneChanged:
                                _onChronicConditionsConfirmedNoneChanged,
                          ),
                          const SizedBox(height: 32),
                          PrimaryButton(
                            text: 'SAVE PROFILE',
                            icon: Icons.save_outlined,
                            isLoading: _isSaving,
                            onPressed: _handleSave,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
