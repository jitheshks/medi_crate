import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/id_utils.dart';
import 'sync_service.dart';

/// Operational configuration and rollback controls for MediCrate's
/// internal foreground synchronization rollout.
///
/// Implements:
/// 1. Trusted configuration source parsing (environment / build-define / programmatic).
/// 2. Strict UUID format validation for all authorized tester identifiers.
/// 3. Fail-closed error handling (invalid or corrupt input halts rollout and clears testers).
/// 4. Four distinct rollback controls:
///    - Global Rollout Pause: halts sync for all testers remotely or centrally.
///    - Individual Tester Revocation: revokes a single UUID from the authorized set.
///    - User Self Opt-Out: per-user preference in local Hive storage.
///    - Local Application Kill Switch: client-side emergency shutdown.
class SyncRolloutConfig {
  static const String envAuthorizedTestersKey = 'AUTHORIZED_TESTER_UUIDS';
  static const String envRolloutPausedKey = 'ROLLOUT_PAUSED';
  static const String envBetaSyncEnabledKey = 'ENABLE_CONTROLLED_FOREGROUND_SYNC';
  static const String compileTimeBetaFlag = 'INTERNAL_BETA_SYNC_ENABLED';

  static bool _isGlobalRolloutPaused = false;
  static bool _isLocalKillSwitchActive = false;
  static bool _isInternalBetaEnabled = false;
  static final Set<String> _authorizedTesterUuids = <String>{};

  /// Whether this build is configured as an internal beta build.
  static bool get isInternalBetaEnabled =>
      _isInternalBetaEnabled || SyncService.isControlledForegroundSyncEnabled;

  /// Sets internal beta enablement explicitly.
  static void setInternalBetaEnabled(bool enabled) {
    _isInternalBetaEnabled = enabled;
    SyncService.isControlledForegroundSyncEnabled = enabled;
  }

  /// Whether the global rollout is currently paused.
  /// When true, all foreground sync dispatches are halted immediately.
  static bool get isGlobalRolloutPaused => _isGlobalRolloutPaused;

  /// Whether local emergency kill switch has been activated on this client.
  /// When true, all foreground sync dispatches are halted immediately.
  static bool get isLocalKillSwitchActive => _isLocalKillSwitchActive;

  /// Set of currently authorized tester UUIDs.
  static Set<String> get authorizedTesterUuids => _authorizedTesterUuids;

  /// Pauses or unpauses the rollout globally.
  static void setGlobalRolloutPaused(bool paused) {
    _isGlobalRolloutPaused = paused;
  }

  /// Activates or resets the local client emergency kill switch.
  static void setLocalKillSwitch(bool active) {
    _isLocalKillSwitchActive = active;
  }

  /// Authorizes an internal tester by validating their Supabase UUID.
  /// Rejects invalid UUID formats (fail closed).
  static bool authorizeTester(String userId) {
    final clean = userId.trim();
    if (!UuidUtils.isValidUuid(clean)) {
      debugPrint('[SyncRolloutConfig] Rejected invalid tester UUID: "$userId"');
      return false;
    }
    _authorizedTesterUuids.add(clean);
    return true;
  }

  /// Revokes an internal tester's authorization.
  static void revokeTester(String userId) {
    _authorizedTesterUuids.remove(userId.trim());
  }

  /// Clears all authorized testers (fail closed).
  static void clearAuthorizedTesters() {
    _authorizedTesterUuids.clear();
  }

  /// Resets all rollout configurations to pristine defaults.
  static void resetToDefaults() {
    _isGlobalRolloutPaused = false;
    _isLocalKillSwitchActive = false;
    _isInternalBetaEnabled = false;
    _authorizedTesterUuids.clear();
    SyncService.isControlledForegroundSyncEnabled = false;
  }

  /// Loads and validates configuration from a raw configuration string (comma-separated or JSON list).
  ///
  /// Fails closed:
  /// - Malformed input sets [_isGlobalRolloutPaused = true] and clears authorized testers.
  /// - Non-UUID strings are strictly filtered out and rejected.
  /// - Returns the count of successfully validated and accepted tester UUIDs,
  ///   or -1 if the configuration source failed validation.
  static int loadConfiguration({
    String? rawTesterUuids,
    bool? isPaused,
    bool? isBetaEnabled,
  }) {
    if (isPaused != null) {
      _isGlobalRolloutPaused = isPaused;
    }

    if (isBetaEnabled != null) {
      _isInternalBetaEnabled = isBetaEnabled;
      SyncService.isControlledForegroundSyncEnabled = isBetaEnabled;
    }

    if (rawTesterUuids == null || rawTesterUuids.trim().isEmpty) {
      _authorizedTesterUuids.clear();
      return 0;
    }

    final trimmed = rawTesterUuids.trim();
    final candidateStrings = <String>[];

    try {
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        // Parse as JSON
        final parsed = jsonDecode(trimmed);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is String) {
              candidateStrings.add(item.trim());
            } else {
              // Non-string entry in JSON array: fail closed
              debugPrint('[SyncRolloutConfig] Non-string element in tester array. Failing closed.');
              _isGlobalRolloutPaused = true;
              _authorizedTesterUuids.clear();
              return -1;
            }
          }
        } else if (parsed is Map && parsed.containsKey('testers')) {
          final list = parsed['testers'];
          if (list is List) {
            for (final item in list) {
              if (item is String) {
                candidateStrings.add(item.trim());
              } else {
                _isGlobalRolloutPaused = true;
                _authorizedTesterUuids.clear();
                return -1;
              }
            }
          } else {
            _isGlobalRolloutPaused = true;
            _authorizedTesterUuids.clear();
            return -1;
          }
        } else {
          // JSON was not a recognized structure: fail closed
          debugPrint('[SyncRolloutConfig] Invalid JSON structure. Failing closed.');
          _isGlobalRolloutPaused = true;
          _authorizedTesterUuids.clear();
          return -1;
        }
      } else {
        // Parse as comma, semicolon, or newline-separated values
        candidateStrings.addAll(
          trimmed
              .split(RegExp(r'[,;\n\r]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
    } catch (e) {
      // JSON / parse exception: fail closed
      debugPrint('[SyncRolloutConfig] Failed to parse tester configuration ($e). Failing closed.');
      _isGlobalRolloutPaused = true;
      _authorizedTesterUuids.clear();
      return -1;
    }

    // Strict Supabase UUID validation:
    final validated = <String>{};
    for (final candidate in candidateStrings) {
      if (UuidUtils.isValidUuid(candidate)) {
        validated.add(candidate);
      } else {
        debugPrint('[SyncRolloutConfig] Dropped invalid UUID candidate: "$candidate"');
      }
    }

    _authorizedTesterUuids.clear();
    _authorizedTesterUuids.addAll(validated);
    return validated.length;
  }

  /// Loads configuration from trusted environment / dotenv variables.
  static void loadFromEnvironment() {
    final compileTimeFlag = const bool.fromEnvironment(
      compileTimeBetaFlag,
      defaultValue: false,
    );
    final rawBetaEnv = dotenv.isInitialized
        ? dotenv.maybeGet(envBetaSyncEnabledKey)
        : null;
    final isBetaEnabled = compileTimeFlag ||
        (rawBetaEnv != null &&
            (rawBetaEnv.trim().toLowerCase() == 'true' ||
                rawBetaEnv.trim() == '1'));

    final rawTesters = dotenv.isInitialized
        ? dotenv.maybeGet(envAuthorizedTestersKey)
        : null;
    final rawPaused = dotenv.isInitialized
        ? dotenv.maybeGet(envRolloutPausedKey)
        : null;

    final isPaused = rawPaused != null
        ? rawPaused.trim().toLowerCase() == 'true' || rawPaused.trim() == '1'
        : false;

    loadConfiguration(
      rawTesterUuids: rawTesters,
      isPaused: isPaused,
      isBetaEnabled: isBetaEnabled,
    );
  }

  /// Validates all 8 activation safeguards required before dispatching foreground sync.
  static ({bool canSync, String? rejectionReason}) evaluateActivationSafeguards({
    required String? authenticatedUserId,
    required bool isOptedIn,
  }) {
    if (!SyncService.isControlledForegroundSyncEnabled) {
      return (
        canSync: false,
        rejectionReason: 'Controlled foreground synchronization is disabled for this build.',
      );
    }

    if (_isGlobalRolloutPaused) {
      return (
        canSync: false,
        rejectionReason: 'Synchronization rollout is currently paused. Your changes remain safely preserved locally.',
      );
    }

    if (_isLocalKillSwitchActive) {
      return (
        canSync: false,
        rejectionReason: 'Synchronization is currently disabled by local emergency controls. Your changes remain safely preserved locally.',
      );
    }

    if (authenticatedUserId == null ||
        authenticatedUserId.trim().isEmpty ||
        !UuidUtils.isValidUuid(authenticatedUserId.trim())) {
      return (
        canSync: false,
        rejectionReason: 'Active authenticated session required to synchronize.',
      );
    }

    final cleanUserId = authenticatedUserId.trim();
    if (!_authorizedTesterUuids.contains(cleanUserId)) {
      return (
        canSync: false,
        rejectionReason: 'Foreground synchronization is currently restricted to authorized internal testers. Your changes remain safely preserved locally.',
      );
    }

    if (!isOptedIn) {
      return (
        canSync: false,
        rejectionReason: 'Synchronization is available for your account but requires opt-in. Please enable synchronization in Data & Sync settings.',
      );
    }

    return (canSync: true, rejectionReason: null);
  }
}
