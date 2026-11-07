import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Web OAuth 2.0 client ID from the `oauth_client` entry with `client_type: 3`
/// in `android/app/google-services.json` (project `medivault-428b2`).
/// Required by google_sign_in 7.x on Android (Credential Manager) as `serverClientId`.
const String kGoogleWebServerClientId =
    '147675311808-e7nh1pk2a214rhak4un8uvme0rr7a5fr.apps.googleusercontent.com';

/// Container for Google Sign-In diagnostic result.
class GoogleAuthResult {
  final String? firebaseIdToken;
  final String? failureStage; // 'A_ACCOUNT_SELECTION' | 'B_FIREBASE_AUTH' | 'C_TOKEN_GENERATION'
  final String? errorMessage;
  final bool isCancelled;

  const GoogleAuthResult.success(this.firebaseIdToken)
    : failureStage = null,
      errorMessage = null,
      isCancelled = false;

  const GoogleAuthResult.cancelled()
    : firebaseIdToken = null,
      failureStage = null,
      errorMessage = null,
      isCancelled = true;

  const GoogleAuthResult.failure({
    required this.failureStage,
    required this.errorMessage,
  }) : firebaseIdToken = null,
       isCancelled = false;
}

/// GoogleAuthService orchestrates device-level Google Sign-In and
/// Firebase Authentication credential exchange with stage diagnostics.
class GoogleAuthService {
  final GoogleSignIn? _googleSignIn;
  final FirebaseAuth? _customFirebaseAuth;
  static bool _isInitialized = false;
  static Object? _lastInitError;

  GoogleAuthService({
    GoogleSignIn? googleSignInInstance,
    FirebaseAuth? firebaseAuth,
  }) : _googleSignIn = googleSignInInstance,
       _customFirebaseAuth = firebaseAuth;

  GoogleSignIn get googleSignIn => _googleSignIn ?? GoogleSignIn.instance;
  FirebaseAuth get firebaseAuth => _customFirebaseAuth ?? FirebaseAuth.instance;

  /// Returns whether the GoogleSignIn plugin has successfully initialized.
  static bool get isInitialized => _isInitialized;

  /// Returns the last initialization error, or null if initialization succeeded.
  static Object? get lastInitError => _lastInitError;

  /// Initializes the underlying GoogleSignIn plugin platform interface.
  static Future<void> initialize({String? serverClientId}) async {
    if (_isInitialized) return;
    final resolved = serverClientId ?? kGoogleWebServerClientId;
    try {
      await GoogleSignIn.instance.initialize(serverClientId: resolved);
      _isInitialized = true;
      _lastInitError = null;
    } catch (e, st) {
      _isInitialized = false;
      _lastInitError = e;
      debugPrint('GoogleAuthService.initialize failed: $e\n$st');
    }
  }

  /// Executes full Google Sign-In with structured diagnostic reporting.
  Future<GoogleAuthResult> authenticateWithGoogle() async {
    if (_googleSignIn == null) {
      if (!_isInitialized) {
        await initialize();
      }
      if (!_isInitialized) {
        return GoogleAuthResult.failure(
          failureStage: 'A_ACCOUNT_SELECTION',
          errorMessage:
              'Google Sign-In not configured (init failed'
              '${_lastInitError != null ? ': $_lastInitError' : ''}).',
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

    // Stage B: Firebase Authentication credential exchange
    UserCredential? userCredential;
    try {
      final String? idToken = account.authentication.idToken;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      userCredential = await firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      return GoogleAuthResult.failure(
        failureStage: 'B_FIREBASE_AUTH',
        errorMessage:
            'Firebase Auth error (${e.code}): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      return GoogleAuthResult.failure(
        failureStage: 'B_FIREBASE_AUTH',
        errorMessage: 'Firebase Auth error (${e.runtimeType}): $e',
      );
    }

    // Stage C: Obtain Firebase ID Token
    String? firebaseIdToken;
    try {
      firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        return const GoogleAuthResult.failure(
          failureStage: 'C_TOKEN_GENERATION',
          errorMessage: 'Firebase ID Token was empty or null',
        );
      }
    } catch (e) {
      return GoogleAuthResult.failure(
        failureStage: 'C_TOKEN_GENERATION',
        errorMessage: 'Token retrieval error (${e.runtimeType}): $e',
      );
    }

    return GoogleAuthResult.success(firebaseIdToken);
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

  /// Signs out from Google and Firebase auth sessions.
  Future<void> signOut() async {
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    try {
      await firebaseAuth.signOut();
    } catch (_) {}
  }
}
