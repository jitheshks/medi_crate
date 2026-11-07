import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/models/home_summary_model.dart';
import '../../data/repositories/home_repository.dart';
import 'clinical_sync_coordinator.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final hive = ref.watch(hiveServiceProvider);
  return HomeRepository(hiveService: hive);
});

class HomeSummaryNotifier extends AsyncNotifier<HomeSummaryModel> {
  @override
  Future<HomeSummaryModel> build() async {
    // Trigger the one-shot background clinical pull for the active profile and
    // recompute once it lands, so a fresh/cleared cache populates without the
    // user opening every feature screen.
    ref.watch(clinicalSyncCoordinatorProvider);
    ref.watch(clinicalCacheRevisionProvider);
    final repository = ref.watch(homeRepositoryProvider);
    final active = ref.watch(activeProfileProvider);

    if (active != null) {
      return await repository.getHomeSummary(active);
    }

    final profilesAsync = ref.watch(profilesListProvider);
    if (profilesAsync.hasError) {
      Error.throwWithStackTrace(
        profilesAsync.error!,
        profilesAsync.stackTrace ?? StackTrace.current,
      );
    }

    final profiles = profilesAsync.hasValue
        ? profilesAsync.value!
        : await ref.watch(profilesListProvider.future);
    if (profiles.isEmpty) {
      return HomeSummaryModel.initial();
    }

    final activeProfile =
        active ??
        profiles.firstWhere((p) => p.isPrimary, orElse: () => profiles.first);

    return await repository.getHomeSummary(activeProfile);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<HomeSummaryModel>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      var activeProfile = ref.read(activeProfileProvider);
      if (activeProfile == null) {
        await ref.read(profilesListProvider.notifier).refreshProfiles();
        final profiles = await ref.read(profilesListProvider.future);
        if (profiles.isEmpty) return HomeSummaryModel.initial();
        activeProfile =
            ref.read(activeProfileProvider) ??
            profiles.firstWhere(
              (p) => p.isPrimary,
              orElse: () => profiles.first,
            );
      }
      final repository = ref.read(homeRepositoryProvider);
      return await repository.getHomeSummary(activeProfile);
    });
  }
}

final homeSummaryProvider =
    AsyncNotifierProvider<HomeSummaryNotifier, HomeSummaryModel>(
      HomeSummaryNotifier.new,
    );

/// Total supported clinical records held locally for the active profile --
/// the same profile-scoped, prefix-scoped aggregate Home itself computes
/// (HomeRepository.getHomeSummary), reused here for the Data & Sync screen's
/// "Total Local Records" figure so the two screens can never disagree.
///
/// Deliberately does NOT watch [clinicalSyncCoordinatorProvider]: this is a
/// read of what Hive already holds, not a trigger to fetch more. It reacts to
/// the same profile-switch and post-sync signals Home reacts to
/// ([activeProfileProvider], [clinicalCacheRevisionProvider]) without pulling
/// every clinical repository/API dependency into a screen whose job is only
/// to report local counts.
final localVaultRecordsCountProvider = FutureProvider<int>((ref) async {
  ref.watch(clinicalCacheRevisionProvider);
  final repository = ref.watch(homeRepositoryProvider);
  final active = ref.watch(activeProfileProvider);

  if (active != null) {
    final summary = await repository.getHomeSummary(active);
    return summary.totalVaultRecords;
  }

  final profiles = await ref.watch(profilesListProvider.future);
  if (profiles.isEmpty) return 0;

  final resolved =
      active ??
      profiles.firstWhere((p) => p.isPrimary, orElse: () => profiles.first);
  final summary = await repository.getHomeSummary(resolved);
  return summary.totalVaultRecords;
});
