import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Container for Google Sign-In diagnostic result.
class GoogleAuthResult {
  final String? idToken;
  final String? failureStage; // 'A_ACCOUNT_SELECTION' | 'B_ID_TOKEN_RETRIEVAL'
  final String? errorMessage;
  final bool isCancelled;

  const GoogleAuthResult.success(this.idToken)
    : failureStage = null,
      errorMessage = null,
      isCancelled = false;

  const GoogleAuthResult.cancelled()
    : idToken = null,
      failureStage = null,
      errorMessage = null,
      isCancelled = true;

  const GoogleAuthResult.failure({
    required this.failureStage,
    required this.errorMessage,
  }) : idToken = null,
       isCancelled = false;

  /// Backwards-compatible getter for legacy code.
  String? get firebaseIdToken => idToken;
}

/// GoogleAuthService orchestrates device-level Google Sign-In and
/// extracts the raw Google ID token for direct exchange with Supabase GoTrue.
class GoogleAuthService {
  final GoogleSignIn? _googleSignIn;
  static bool _isInitialized = false;
  static Object? _lastInitError;
  static String? _serverClientId;

  GoogleAuthService({
    GoogleSignIn? googleSignInInstance,
    Object? firebaseAuth, // Retained for backwards compatibility; ignored
  }) : _googleSignIn = googleSignInInstance;

  GoogleSignIn get googleSignIn => _googleSignIn ?? GoogleSignIn.instance;

  /// Returns whether the GoogleSignIn plugin has successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the last initialization error, or null if initialization succeeded.
  static Object? get lastInitError => _lastInitError;

  /// Returns the configured Web Client ID, if any.
  static String? get serverClientId => _serverClientId;

  /// Initializes the underlying GoogleSignIn plugin with a MediCrate Web Client ID.
  /// Strict configuration: requires a valid non-empty [serverClientId]; does NOT silently
  /// fall back to old MediVault client IDs.
  static Future<void> initialize({
    String? serverClientId,
    @visibleForTesting Future<void> Function(String clientId)? platformInitializer,
  }) async {
    final resolved = serverClientId?.trim();
    if (resolved == null || resolved.isEmpty) {
      _isInitialized = false;
      _serverClientId = null;
      _lastInitError =
          'Google Sign-In is unconfigured: GOOGLE_WEB_CLIENT_ID environment variable is missing or empty. '
          'Please configure GOOGLE_WEB_CLIENT_ID in your .env or environment configuration.';
      debugPrint('[GoogleAuthService] $_lastInitError');
      return;
    }

    try {
      if (platformInitializer != null) {
        await platformInitializer(resolved);
      } else {
        await GoogleSignIn.instance.initialize(serverClientId: resolved);
      }
      _isInitialized = true;
      _serverClientId = resolved;
      _lastInitError = null;
      debugPrint(
        '[GoogleAuthService] Initialized with Web Client ID: $resolved',
      );
    } catch (e, st) {
      _isInitialized = false;
      _serverClientId = null;
      _lastInitError = e;
      debugPrint('GoogleAuthService.initialize failed: $e\n$st');
    }
  }

  /// Resets initialization state (primarily for test tearDown).
  @visibleForTesting
  static void resetForTesting() {
    _isInitialized = false;
    _serverClientId = null;
    _lastInitError = null;
  }

  /// Executes full Google Sign-In with structured diagnostic reporting.
  Future<GoogleAuthResult> authenticateWithGoogle() async {
    if (_googleSignIn == null) {
      if (!_isInitialized) {
        return GoogleAuthResult.failure(
          failureStage: 'A_ACCOUNT_SELECTION',
          errorMessage: _lastInitError?.toString() ?? 'Google Sign-In is not configured. Missing GOOGLE_WEB_CLIENT_ID environment variable.',
        );
      }
    }

    // Stage A: Google account selection
    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        return const GoogleAuthResult.cancelled();
      }
      return GoogleAuthResult.failure(
        failureStage: 'A_ACCOUNT_SELECTION',
        errorMessage:
            'Google Sign-In failed (${e.code}): ${e.description ?? e.toString()}',
      );
    } catch (e) {
      return GoogleAuthResult.failure(
        failureStage: 'A_ACCOUNT_SELECTION',
        errorMessage: 'Google Sign-In error (${e.runtimeType}): $e',
      );
    }

    // Stage B: Obtain Google ID Token directly
    String? idToken;
    try {
      idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const GoogleAuthResult.failure(
          failureStage: 'B_ID_TOKEN_RETRIEVAL',
          errorMessage: 'Google ID Token was empty or null',
        );
      }
    } catch (e) {
      return GoogleAuthResult.failure(
        failureStage: 'B_ID_TOKEN_RETRIEVAL',
        errorMessage: 'ID token retrieval error (${e.runtimeType}): $e',
      );
    }

    return GoogleAuthResult.success(idToken);
  }

  /// Backward-compatible method returning token string or throwing.
  Future<String?> signInWithGoogle() async {
    final result = await authenticateWithGoogle();
    if (result.isCancelled) return null;
    if (result.failureStage != null) {
      throw Exception(
        'Google Sign-In failed [${result.failureStage}]: ${result.errorMessage}',
      );
    }
    return result.firebaseIdToken;
  }

  /// Signs out from Google session.
  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
    } catch (_) {}
  }
}
