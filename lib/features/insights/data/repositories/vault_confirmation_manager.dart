import '../../../../core/storage/hive_service.dart';

/// Manages profile-scoped Health Vault confirmation state stored in Hive.
class VaultConfirmationManager {
  final HiveService hiveService;

  const VaultConfirmationManager({required this.hiveService});

  bool isNoMedicinesConfirmed(String profileId) {
    final val = hiveService.userBox.get(
      'vault_confirm_no_medicines_$profileId',
    );
    return val is Map && val['confirmed'] == true;
  }

  Future<void> setNoMedicinesConfirmed(String profileId, bool confirmed) async {
    await hiveService.userBox.put('vault_confirm_no_medicines_$profileId', {
      'confirmed': confirmed,
    });
  }

  bool isNoConsultationsConfirmed(String profileId) {
    final val = hiveService.userBox.get(
      'vault_confirm_no_consultations_$profileId',
    );
    return val is Map && val['confirmed'] == true;
  }

  Future<void> setNoConsultationsConfirmed(
    String profileId,
    bool confirmed,
  ) async {
    await hiveService.userBox.put('vault_confirm_no_consultations_$profileId', {
      'confirmed': confirmed,
    });
  }

  bool isNoReportsConfirmed(String profileId) {
    final val = hiveService.userBox.get('vault_confirm_no_reports_$profileId');
    return val is Map && val['confirmed'] == true;
  }

  Future<void> setNoReportsConfirmed(String profileId, bool confirmed) async {
    await hiveService.userBox.put('vault_confirm_no_reports_$profileId', {
      'confirmed': confirmed,
    });
  }

  bool isNoAllergiesConfirmed(String profileId) {
    final val = hiveService.userBox.get(
      'vault_confirm_no_allergies_$profileId',
    );
    return val is Map && val['confirmed'] == true;
  }

  Future<void> setNoAllergiesConfirmed(String profileId, bool confirmed) async {
    await hiveService.userBox.put('vault_confirm_no_allergies_$profileId', {
      'confirmed': confirmed,
    });
  }

  bool isNoChronicConditionsConfirmed(String profileId) {
    final val = hiveService.userBox.get(
      'vault_confirm_no_conditions_$profileId',
    );
    return val is Map && val['confirmed'] == true;
  }

  Future<void> setNoChronicConditionsConfirmed(
    String profileId,
    bool confirmed,
  ) async {
    await hiveService.userBox.put('vault_confirm_no_conditions_$profileId', {
      'confirmed': confirmed,
    });
  }
}
