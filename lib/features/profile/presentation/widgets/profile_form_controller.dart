import 'package:flutter/material.dart';
import '../../data/models/profile_model.dart';

class ProfileFormController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController allergyInputController = TextEditingController();
  final TextEditingController conditionInputController =
      TextEditingController();

  DateTime? selectedDob;
  String? selectedGender;
  String? selectedBloodGroup;
  String? photoPath;

  List<String> allergies = [];
  bool allergiesConfirmedNone = false;
  List<String> chronicConditions = [];
  bool chronicConditionsConfirmedNone = false;

  void populateFromProfile(ProfileModel profile) {
    nameController.text = profile.fullName;
    heightController.text = profile.height != null
        ? profile.height!.toStringAsFixed(0)
        : '';
    weightController.text = profile.weight != null
        ? profile.weight!.toStringAsFixed(0)
        : '';
    selectedGender = profile.gender;
    selectedBloodGroup = profile.bloodGroup;
    photoPath = profile.photo;
    allergies = List<String>.from(profile.allergies);
    allergiesConfirmedNone = profile.allergiesConfirmedNone;
    chronicConditions = List<String>.from(profile.chronicConditions);
    chronicConditionsConfirmedNone = profile.chronicConditionsConfirmedNone;

    if (profile.dateOfBirth != null && profile.dateOfBirth!.isNotEmpty) {
      selectedDob = DateTime.tryParse(profile.dateOfBirth!);
    }
  }

  void addAllergy() {
    final text = allergyInputController.text.trim();
    if (text.isEmpty) return;
    if (!allergies.any((a) => a.toLowerCase() == text.toLowerCase())) {
      allergies.add(text);
      allergiesConfirmedNone = false;
    }
    allergyInputController.clear();
  }

  void removeAllergy(String allergy) {
    allergies.remove(allergy);
  }

  void addCondition() {
    final text = conditionInputController.text.trim();
    if (text.isEmpty) return;
    if (!chronicConditions.any((c) => c.toLowerCase() == text.toLowerCase())) {
      chronicConditions.add(text);
      chronicConditionsConfirmedNone = false;
    }
    conditionInputController.clear();
  }

  void removeCondition(String condition) {
    chronicConditions.remove(condition);
  }

  void dispose() {
    nameController.dispose();
    heightController.dispose();
    weightController.dispose();
    allergyInputController.dispose();
    conditionInputController.dispose();
  }
}
