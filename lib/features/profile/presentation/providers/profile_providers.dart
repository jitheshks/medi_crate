import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/utils/id_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/local/profile_local_data_source.dart';
import '../../data/datasources/remote/profile_remote_data_source.dart';
import '../../data/datasources/remote/user_remote_data_source.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/profile_repository.dart';

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  final client = ref.watch(apiClientProvider);
  return UserRemoteDataSource(apiClient: client);
});

final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return ProfileLocalDataSource(hiveService: hive);
});

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>((
  ref,
) {
  final client = ref.watch(apiClientProvider);
  return ProfileRemoteDataSource(apiClient: client);
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final local = ref.watch(profileLocalDataSourceProvider);
  final remote = ref.watch(profileRemoteDataSourceProvider);
  final userRemote = ref.watch(userRemoteDataSourceProvider);
  final connectivity = ref.watch(connectivityServiceProvider);
  final sync = ref.watch(syncServiceProvider);
  final hive = ref.watch(hiveServiceProvider);

  return ProfileRepository(
    localDataSource: local,
    remoteDataSource: remote,
    userRemoteDataSource: userRemote,
    connectivityService: connectivity,
    syncService: sync,
    hiveService: hive,
  );
});

final familyDashboardProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return [];
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getFamilyDashboard(user.id);
});

final familyAnalyticsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).user;
  if (user == null) return [];
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getFamilyAnalytics(user.id);
});

/// ProfilesListNotifier manages fetching and modifying the list of family profiles.
class ProfilesListNotifier extends AsyncNotifier<List<ProfileModel>> {
  @override
  Future<List<ProfileModel>> build() async {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return [];

    final repo = ref.watch(profileRepositoryProvider);
    var profiles = await repo.getProfiles(user.id);
    if (profiles.isEmpty) {
      final defaultProf = await repo.ensureDefaultProfile(user);
      profiles = [defaultProf];
    }

    // Trigger non-blocking background profile pull-sync
    unawaited(_pullAndRefresh(user.id));

    return profiles;
  }

  Future<void> _pullAndRefresh(String userId) async {
    try {
      final repo = ref.read(profileRepositoryProvider);
      await repo.pullProfiles(userId);
      final currentUser = ref.read(authControllerProvider).user;
      if (currentUser?.id == userId) {
        final updatedProfiles = await repo.getProfiles(userId);
        if (updatedProfiles.isNotEmpty) {
          state = AsyncData(updatedProfiles);
        }
      }
    } catch (_) {
      // Safe background unawaited execution - failures do not leak or overwrite local data
    }
  }

  void setProfiles(List<ProfileModel> profiles) {
    state = AsyncData(profiles);
  }

  Future<void> refreshProfiles() async {
    state = const AsyncLoading<List<ProfileModel>>();
    state = await AsyncValue.guard(() async {
      final user = ref.read(authControllerProvider).user;
      if (user == null) return [];
      final repo = ref.read(profileRepositoryProvider);
      await repo.pullProfiles(user.id);
      final profiles = await repo.getProfiles(user.id);
      if (profiles.isEmpty) {
        final defaultProf = await repo.ensureDefaultProfile(user);
        return [defaultProf];
      }
      return profiles;
    });
  }

  Future<ProfileModel> createProfile({
    required String fullName,
    required String relationship,
    String? relationshipOther,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? photo,
    double? height,
    double? weight,
    bool isPrimary = false,
    String? notes,
    List<String> allergies = const [],
    bool allergiesConfirmedNone = false,
    List<String> chronicConditions = const [],
    bool chronicConditionsConfirmedNone = false,
  }) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      throw const UnauthorizedException(
        'Cannot create profile without an active authenticated session.',
      );
    }
    final ownerId = user.id;
    final repo = ref.read(profileRepositoryProvider);
    final clientUuid = UuidUtils.generateV4();

    final newProfile = ProfileModel(
      profileId: 'prof_${DateTime.now().microsecondsSinceEpoch}',
      ownerUserId: ownerId,
      fullName: fullName,
      relationship: relationship,
      relationshipOther: relationshipOther,
      clientUuid: clientUuid,
      gender: gender,
      dateOfBirth: dateOfBirth,
      bloodGroup: bloodGroup,
      photo: photo,
      height: height,
      weight: weight,
      isPrimary: isPrimary,
      notes: notes,
      allergies: allergies,
      allergiesConfirmedNone: allergiesConfirmedNone,
      chronicConditions: chronicConditions,
      chronicConditionsConfirmedNone: chronicConditionsConfirmedNone,
    );

    final created = await repo.createProfile(newProfile);
    await refreshProfiles();

    if (isPrimary || (state.value != null && state.value!.length == 1)) {
      ref.read(activeProfileProvider.notifier).selectProfile(created);
    }

    return created;
  }

  Future<ProfileModel> updateProfile(ProfileModel updated) async {
    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.updateProfile(updated);
    await refreshProfiles();

    final active = ref.read(activeProfileProvider);
    if (active?.profileId == updated.profileId) {
      ref.read(activeProfileProvider.notifier).selectProfile(result);
    }

    return result;
  }

  Future<ProfileModel> uploadPhoto(String profileId, File photoFile) async {
    final repo = ref.read(profileRepositoryProvider);
    final result = await repo.uploadProfilePhoto(profileId, photoFile);
    await refreshProfiles();

    final active = ref.read(activeProfileProvider);
    if (active?.profileId == profileId) {
      ref.read(activeProfileProvider.notifier).selectProfile(result);
    }

    return result;
  }

  Future<void> deleteProfile(String profileId) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.deleteProfile(profileId);
    await refreshProfiles();

    final active = ref.read(activeProfileProvider);
    if (active?.profileId == profileId) {
      final remaining = state.value ?? [];
      if (remaining.isNotEmpty) {
        final primary = remaining.firstWhere(
          (p) => p.isPrimary,
          orElse: () => remaining.first,
        );
        ref.read(activeProfileProvider.notifier).selectProfile(primary);
      }
    }
  }

  Future<void> markAsPrimary(ProfileModel profile) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.setPrimaryProfile(profile);
    await refreshProfiles();
  }
}

final profilesListProvider =
    AsyncNotifierProvider<ProfilesListNotifier, List<ProfileModel>>(
      ProfilesListNotifier.new,
    );

/// ActiveProfileNotifier holds the globally active selected family health profile.
class ActiveProfileNotifier extends Notifier<ProfileModel?> {
  @override
  ProfileModel? build() {
    final user = ref.watch(authControllerProvider).user;
    if (user == null) return null;

    final profilesAsync = ref.watch(profilesListProvider);
    return profilesAsync.when(
      data: (profiles) {
        if (profiles.isEmpty) return null;

        final repo = ref.watch(profileRepositoryProvider);
        final activeId = repo.localDataSource.getActiveProfileIdSync();

        final activeProfile =
            (activeId != null && profiles.any((p) => p.profileId == activeId))
            ? profiles.firstWhere((p) => p.profileId == activeId)
            : profiles.firstWhere(
                (p) => p.isPrimary,
                orElse: () => profiles.first,
              );

        return activeProfile;
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }

  Future<void> selectProfile(ProfileModel profile) async {
    state = profile;
    final repo = ref.read(profileRepositoryProvider);
    await repo.setActiveProfileId(profile.profileId);
  }

  Future<void> switchProfileById(String profileId) async {
    final profiles = ref.read(profilesListProvider).value ?? [];
    if (profiles.isEmpty) return;
    final match = profiles.firstWhere(
      (p) => p.profileId == profileId,
      orElse: () => profiles.first,
    );
    await selectProfile(match);
  }
}

final activeProfileProvider =
    NotifierProvider<ActiveProfileNotifier, ProfileModel?>(
      ActiveProfileNotifier.new,
    );
