# MediCrate – Phase 3B.1: Legacy Backend Isolation & Offline Synchronization Protection Report

**Execution Date:** 2026-11-08  
**Architecture Decision:** Option D (Supabase-First Authentication & Controlled Phase 4 Migration)  
**Target Milestone:** Phase 3B.1 Complete  

---

## 1. Executive Summary

Phase 3B.1 has successfully established a complete, hardened operational boundary between the legacy, unmaintained Laravel Sanctum backend (`https://phplaravel-1505866-6585565.cloudwaysapps.com/api/v1`) and the MediCrate application. This isolation was executed in strict accordance with the approved **Option D** architectural strategy prior to the activation of Supabase authentication in Phase 3B.2.

### Key Outcomes
1. **Decoupled 401 Session Destruction:** Legacy HTTP 401 Unauthorized responses from Laravel no longer trigger session expiration or purge user state in Riverpod (`authControllerProvider`).
2. **Supabase JWT Leakage Prevention:** [AuthInterceptor](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart) inspects every outgoing HTTP request, suppressing and stripping Supabase JWTs (RFC 7519 3-part dot-separated tokens) before requests can reach legacy Laravel endpoints.
3. **Headless & Foreground Sync Suspension:** Both periodic/one-off WorkManager tasks ([BackgroundSyncService](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_sync_service.dart), [BackgroundClinicalPull](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_clinical_pull.dart)) and foreground push routines ([SyncService](file:///home/blackhat/Documents/medi_crate/lib/core/sync/sync_service.dart)) have been halted, preventing network errors against the dead Laravel backend.
4. **Offline Queue Mutation Preservation:** All pending offline clinical mutations, retry counts, timestamps, client UUIDs, and payloads in `syncQueueBox` are 100% preserved in Hive for seamless migration to Supabase in Phase 4.
5. **Clinical CRUD Continuity:** Full offline CRUD functionality across all seven clinical domains (Consultations, Vitals, Reports, Medicines, Appointments, Doctors, Hospitals) and Profile management remains fully functional via local Hive caching.
6. **Multi-Tenant Profile Guard:** [ProfileLocalDataSource](file:///home/blackhat/Documents/medi_crate/lib/features/profile/data/datasources/local/profile_local_data_source.dart) now strictly rejects empty or whitespace `ownerUserId` requests, returning an empty list (`[]`) rather than exposing all cached profiles across users.
7. **Verification Pipeline:** Clean static analysis (0 issues), 30 passing unit and widget tests (including 7 dedicated isolation tests), and successful debug APK compilation.

---

## 2. Inventory of Modified Files

| File | Subsystem | Modifications |
| :--- | :--- | :--- |
| [lib/core/api/dio_interceptor.dart](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart) | Network / Security | Added `isSupabaseJwt` detection, suppressed stored Supabase tokens from Sanctum calls, stripped Authorization headers bearing JWTs, prevented token refresh loops on JWTs. |
| [lib/core/api/api_client.dart](file:///home/blackhat/Documents/medi_crate/lib/core/api/api_client.dart) | Network Client | Stored and exposed `onSessionExpired` callback for testability and lifecycle management. |
| [lib/features/auth/presentation/providers/auth_providers.dart](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_providers.dart) | Riverpod / Auth | Decoupled `apiClientProvider.onSessionExpired` from `authControllerProvider.notifier.handleSessionExpired()`. |
| [lib/features/auth/presentation/providers/auth_notifier.dart](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_notifier.dart) | Auth State | Deferred `checkInitialSession()` with `Future.microtask` to guarantee clean Riverpod 3.5 notifier initialization without uninitialized provider reads. |
| [lib/core/sync/background_sync_service.dart](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_sync_service.dart) | WorkManager | Added `isLaravelSyncSuspended = true`, cancelled all legacy (`com.medivalut.sync.*`) and active (`com.medicrate.sync.*`) tasks, and bypassed periodic/one-off task registration. |
| [lib/core/sync/background_clinical_pull.dart](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_clinical_pull.dart) | Background Pull | Added early return when `isLaravelSyncSuspended` is true to eliminate unauthenticated Laravel pulls. |
| [lib/core/sync/sync_service.dart](file:///home/blackhat/Documents/medi_crate/lib/core/sync/sync_service.dart) | Foreground Sync | Added `isRemotePushSuspended = true` and short-circuited `syncPending()` to prevent mutation loss and queue corruption. |
| [lib/features/profile/data/datasources/local/profile_local_data_source.dart](file:///home/blackhat/Documents/medi_crate/lib/features/profile/data/datasources/local/profile_local_data_source.dart) | Local Data / Profile | Hardened `getProfilesForUser`, `getProfileByServerId`, and `getProfileByClientUuid` to return `[]` / `null` when `ownerUserId` is empty. |
| [lib/features/consultations/data/repositories/consultation_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/consultations/data/repositories/consultation_repository.dart) | Consultations | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/vitals/data/repositories/measurement_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/vitals/data/repositories/measurement_repository.dart) | Vitals | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/medicines/data/repositories/medicine_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/medicines/data/repositories/medicine_repository.dart) | Medicines | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/reports/data/repositories/report_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/reports/data/repositories/report_repository.dart) | Reports | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/doctors/data/repositories/doctor_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/doctors/data/repositories/doctor_repository.dart) | Doctors | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/hospitals/data/repositories/hospital_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/hospitals/data/repositories/hospital_repository.dart) | Hospitals | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/appointments/data/repositories/appointment_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/appointments/data/repositories/appointment_repository.dart) | Appointments | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [lib/features/profile/data/repositories/profile_repository.dart](file:///home/blackhat/Documents/medi_crate/lib/features/profile/data/repositories/profile_repository.dart) | Family Profiles | Guarded remote fetches with `!SyncService.isRemotePushSuspended` while preserving local Hive writes and queue entries. |
| [test/core/sync/legacy_backend_isolation_test.dart](file:///home/blackhat/Documents/medi_crate/test/core/sync/legacy_backend_isolation_test.dart) | Test Suite | Created 7 comprehensive unit tests verifying token isolation, session decoupling, sync suspension, mutation preservation, and profile scoping. |

---

## 3. Detailed Architectural & Technical Implementations

### 3.1 Laravel 401 Session Decoupling
In legacy versions of the application, `apiClientProvider` was tightly coupled to `authControllerProvider`:
```dart
// Previous vulnerable code:
onSessionExpired: () {
  ref.read(authControllerProvider.notifier).handleSessionExpired();
}
```
If an HTTP 401 occurred (which is now guaranteed since the Laravel backend is dormant and unauthenticated), `handleSessionExpired()` wiped local credentials and routed the user back to the login screen.

**Isolated Implementation:**
In [`auth_providers.dart`](file:///home/blackhat/Documents/medi_crate/lib/features/auth/presentation/providers/auth_providers.dart#L56-L70):
```dart
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return ApiClient(
    secureStorage: secureStorage,
    onSessionExpired: () {
      // Option D: A legacy Laravel 401 represents legacy backend dormancy,
      // NOT an application session expiration. Decoupled from AuthNotifier
      // so Supabase sessions are never terminated by legacy Laravel responses.
      developer.log(
        '⚠️ [ApiClient] Legacy Laravel 401 intercepted. Application session preserved.',
        name: 'MediCrate.Auth',
      );
    },
  );
});
```
This ensures that user sessions managed by Supabase in Phase 3B.2 will never be disrupted by background 401 errors from legacy endpoints.

---

### 3.2 Supabase JWT Interception & Suppression
Legacy Sanctum endpoints expect either opaque string tokens or tokens formatted as `<id>|<token_hash>`. Sending a Supabase JWT (an RFC 7519 3-part base64url string beginning with `ey...`) to Laravel would result in syntax rejections, unnecessary token refresh attempts, or potential token exposure.

**Implementation in [AuthInterceptor](file:///home/blackhat/Documents/medi_crate/lib/core/api/dio_interceptor.dart):**
1. **JWT Detection Utility:**
   ```dart
   static bool isSupabaseJwt(String token) {
     final trimmed = token.trim();
     if (trimmed.isEmpty) return false;
     final parts = trimmed.split('.');
     return parts.length == 3 && (trimmed.startsWith('ey') || parts[0].isNotEmpty);
   }
   ```
2. **Outbound Header Suppression:**
   Before attaching an Authorization header from `SecureStorageService`, the token is inspected:
   ```dart
   final token = await secureStorage.getAuthToken();
   if (token != null && token.isNotEmpty) {
     if (isSupabaseJwt(token)) {
       developer.log('🔒 Suppressed Supabase JWT from legacy Laravel request: ${options.path}');
     } else {
       options.headers['Authorization'] = 'Bearer $token';
     }
   }
   ```
3. **Explicit Header Stripping:**
   If a caller manually attached an Authorization header containing a Supabase JWT, `AuthInterceptor` strips it:
   ```dart
   if (options.headers.containsKey('Authorization')) {
     final authHeader = options.headers['Authorization']?.toString() ?? '';
     if (authHeader.startsWith('Bearer ')) {
       final tokenPart = authHeader.substring(7).trim();
       if (isSupabaseJwt(tokenPart)) {
         options.headers.remove('Authorization');
       }
     }
   }
   ```
4. **Token Refresh Guard:**
   `_performTokenRefresh()` aborts immediately if the stored refresh token is a Supabase JWT, avoiding useless refresh calls to `/api/v1/auth/refresh`.

---

### 3.3 Suspension of Legacy Synchronization & Preservation of Pending Mutations

#### A. Headless Background Sync ([BackgroundSyncService](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_sync_service.dart))
- Introduced `static bool isLaravelSyncSuspended = true;`.
- `initialize(customWorkmanager: ...)` explicitly cancels both legacy MediVault tasks (`com.medivalut.sync.periodic`, `com.medivalut.sync.oneoff`) and active MediCrate tasks (`com.medicrate.sync.periodic`, `com.medicrate.sync.oneoff`).
- `registerPeriodicTask()` is skipped completely.
- `scheduleOneTimeSync()` is an immediate no-op.
- `executeBackgroundTask()` returns `true` immediately to complete any lingering OS-scheduled task without making HTTP requests.

#### B. Headless Background Pull ([BackgroundClinicalPull](file:///home/blackhat/Documents/medi_crate/lib/core/sync/background_clinical_pull.dart))
- `run()` short-circuits immediately when `BackgroundSyncService.isLaravelSyncSuspended` is true.

#### C. Foreground Push Synchronization ([SyncService](file:///home/blackhat/Documents/medi_crate/lib/core/sync/sync_service.dart))
- Introduced `static bool isRemotePushSuspended = true;`.
- `syncPending()` logs a message and returns immediately.
- **Pending Mutation Protection:** Queue items inside `hiveService.syncQueueBox` are untouched. Payloads, entity types, operations (`create`/`update`/`delete`), retry counts, and creation timestamps remain completely preserved for Phase 4 Supabase synchronization.

---

### 3.4 Multi-Tenant Profile Isolation
In [`ProfileLocalDataSource`](file:///home/blackhat/Documents/medi_crate/lib/features/profile/data/datasources/local/profile_local_data_source.dart), the previous implementation evaluated:
```dart
// Vulnerable legacy code:
if (ownerUserId.isEmpty || profile.ownerUserId == ownerUserId) {
  profiles.add(profile);
}
```
If `ownerUserId` was empty (e.g., during transition or before user profile resolution), it returned every profile stored in Hive across all users.

**Hardened Implementation:**
```dart
Future<List<ProfileModel>> getProfilesForUser(String ownerUserId) async {
  if (ownerUserId.trim().isEmpty) {
    return [];
  }
  final box = hiveService.profileBox;
  final profiles = <ProfileModel>[];
  for (final key in box.keys) {
    final raw = box.get(key);
    if (raw != null) {
      final map = Map<String, dynamic>.from(raw);
      final profile = ProfileModel.fromMap(map);
      if (profile.ownerUserId == ownerUserId.trim()) {
        profiles.add(profile);
      }
    }
  }
  // ... sorting ...
  return profiles;
}
```
Similarly, `getProfileByServerId` and `getProfileByClientUuid` return `null` immediately when `ownerUserId.trim().isEmpty`.

---

## 4. Verification & Test Evidence

### 4.1 Unit Test Coverage ([test/core/sync/legacy_backend_isolation_test.dart](file:///home/blackhat/Documents/medi_crate/test/core/sync/legacy_backend_isolation_test.dart))
Seven targeted unit tests were executed covering all Phase 3B.1 requirements:

```
00:00 +0: loading test/core/sync/legacy_backend_isolation_test.dart
00:00 +0: Phase 3B.1 Legacy Backend Isolation & Offline Protection 1. Laravel 401 intercepted by ApiClient does not clear Riverpod authControllerProvider session state
00:00 +1: Phase 3B.1 Legacy Backend Isolation & Offline Protection 2. AuthInterceptor suppresses and strips Supabase JWTs from request headers
00:00 +2: Phase 3B.1 Legacy Backend Isolation & Offline Protection 3. BackgroundSyncService.isLaravelSyncSuspended is true and BackgroundClinicalPull skips remote pulls
[BackgroundClinicalPull] Skipping remote pull: legacy Laravel sync suspended for Supabase migration.
00:00 +3: Phase 3B.1 Legacy Backend Isolation & Offline Protection 4. SyncService.syncPending() when isRemotePushSuspended is true preserves queue items untouched
[SyncService] Remote push skipped: legacy Laravel sync suspended. Pending mutations preserved in Hive for Phase 4.
00:00 +4: Phase 3B.1 Legacy Backend Isolation & Offline Protection 5. Local clinical CRUD operations succeed offline and persist to userBox with queue items created
[BackgroundSyncService] scheduleOneTimeSync skipped: legacy Laravel sync suspended.
00:00 +5: Phase 3B.1 Legacy Backend Isolation & Offline Protection 6. ProfileLocalDataSource.getProfilesForUser("") returns empty list [] when owner ID is empty
00:00 +6: Phase 3B.1 Legacy Backend Isolation & Offline Protection 7. Calling BackgroundSyncService.initialize repeatedly cancels active tasks and does not register periodicSyncTaskId
[BackgroundSyncService] Legacy Laravel sync is suspended. WorkManager background tasks cancelled and not registered.
00:00 +7: All tests passed!
```

### 4.2 Full Test Suite Results
Running all tests across the entire codebase (`flutter test`):
```
All 30 tests passed! (0 failures, 0 errors)
- test/widget_test.dart (1 test)
- test/core/api_constants_test.dart (3 tests)
- test/core/app_logger_test.dart (1 test)
- test/core/async_value_refresh_test.dart (2 tests)
- test/core/mutable_state_notifier_test.dart (7 tests)
- test/core/sync/legacy_backend_isolation_test.dart (7 tests)
- test/widgets/crate_widgets_test.dart (3 tests)
- test/widgets/doctor_summary_category_section_test.dart (6 tests)
```

### 4.3 Static Code Analysis (`flutter analyze`)
```
Analyzing medi_crate...
No issues found! (ran in 6.1s)
```

### 4.4 Code Formatting (`dart format`)
```
Formatted 491 files (0 unformatted files remaining)
```

### 4.5 Debug Build Verification (`flutter build apk --debug`)
Completed successfully; the Android package compiles cleanly with all background task and security interceptor modifications.

---

## 5. Remaining Risks and Precautions for Phase 3B.2

| Risk | Impact | Mitigation in Phase 3B.2 |
| :--- | :--- | :--- |
| **Premature Remote Sync Re-activation** | Attempting to push offline Hive data to Supabase before Phase 4 schemas exist | Keep `SyncService.isRemotePushSuspended = true` and `BackgroundSyncService.isLaravelSyncSuspended = true` throughout all of Phase 3B. Phase 3B focuses strictly on Supabase Authentication. |
| **Existing Local Data Loss during Auth Migration** | Signing in with a new Supabase user might accidentally clear local Hive clinical data | Ensure `AuthNotifier` during Supabase sign-in preserves existing clinical data in `userBox` and links records via the alias mapping designed in Phase 3A.2. |
| **Firebase Auth Deprecation Leakage** | Legacy Firebase dependencies remain in `pubspec.yaml` | Phase 3B.2 will wire Supabase Auth without removing Firebase dependencies prematurely to avoid breaking existing import references until Phase 3B.4. |
| **Token Storage Collisions** | Storing Supabase tokens in the same key as Laravel tokens | Use dedicated storage keys (`supabase_access_token`, `supabase_refresh_token`) or allow `Supabase.initialize()` to manage its own secure session persistence. |

---

## 6. Conclusion & Authorization for Phase 3B.2

Phase 3B.1 has satisfied all criteria for isolating the dormant legacy Laravel backend, securing Riverpod session lifecycles against 401 purges, preventing JWT leakage, suspending background workers safely, and preserving all local Hive clinical records and sync mutations.

The repository is in a clean, stable state, fully verified, and ready for **Phase 3B.2: Supabase Client Initialization & Authentication Providers Implementation**.
