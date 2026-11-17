import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Diagnostic result container for Apple Sign-In — mirrors GoogleAuthResult.
class AppleAuthResult {
  final String? firebaseIdToken;

  /// Stage label when failure occurred:
  /// 'A_APPLE_AUTHORIZATION' | 'B_FIREBASE_AUTH' | 'C_TOKEN_GENERATION'
  final String? failureStage;
  final String? errorMessage;
  final bool isCancelled;

  const AppleAuthResult.success(this.firebaseIdToken)
    : failureStage = null,
      errorMessage = null,
      isCancelled = false;

  const AppleAuthResult.cancelled()
    : firebaseIdToken = null,
      failureStage = null,
      errorMessage = null,
      isCancelled = true;

  const AppleAuthResult.failure({
    required this.failureStage,
    required this.errorMessage,
  }) : firebaseIdToken = null,
       isCancelled = false;
}

/// AppleAuthService orchestrates device-level Apple Sign-In and Firebase
/// credential exchange, mirroring GoogleAuthService (A8).
///
/// **Android**: Firebase-native `signInWithProvider(AppleAuthProvider())` —
/// Firebase opens Apple's login page in a Custom Tab and handles the callback
/// entirely; no Apple Services ID or redirect URI constant is required here.
///
/// **iOS/macOS**: Native ASAuthorizationController sheet via sign_in_with_apple
/// (nonce + identityToken → OAuthCredential → signInWithCredential).
///
/// Both paths return authentication credentials that flow through
/// AuthNotifier and AuthRepository.
class AppleAuthService {
  final FirebaseAuth? _customFirebaseAuth;

  AppleAuthService({FirebaseAuth? firebaseAuth})
    : _customFirebaseAuth = firebaseAuth;

  FirebaseAuth get firebaseAuth => _customFirebaseAuth ?? FirebaseAuth.instance;

  // ---------------------------------------------------------------------------
  // Nonce helpers — iOS/macOS only
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically secure random nonce string.
  /// The raw nonce is passed to Firebase; the SHA-256 hash is sent to Apple.
  /// Used only by the iOS/macOS native sign-in path.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// Returns the lowercase hex SHA-256 digest of [input].
  /// Used only by the iOS/macOS native sign-in path.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ---------------------------------------------------------------------------
  // Main authentication flow
  // ---------------------------------------------------------------------------

  /// Executes the full Apple Sign-In with structured diagnostic reporting.
  ///
  /// Returns [AppleAuthResult.success] with a Firebase ID token on success.
  /// Returns [AppleAuthResult.cancelled] when the user dismisses the sheet.
  /// Returns [AppleAuthResult.failure] with a stage label on any error.
  Future<AppleAuthResult> authenticateWithApple() async {
    debugPrint('[AppleAuth] authenticateWithApple() started');
    debugPrint(
      '[AppleAuth] platform=${defaultTargetPlatform.name} kIsWeb=$kIsWeb',
    );

    // -------------------------------------------------------------------------
    // Android: Firebase-native Apple provider via signInWithProvider()
    // Firebase manages the Custom Tab, OAuth redirect, and callback entirely.
    // No Apple Services ID or redirect URI constant is required here.
    // -------------------------------------------------------------------------
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return _authenticateAndroid();
    }

    // -------------------------------------------------------------------------
    // iOS / macOS: native ASAuthorizationController sheet
    // -------------------------------------------------------------------------
    return _authenticateAppleNative();
  }

  // ---------------------------------------------------------------------------
  // Android — Firebase-native path
  // ---------------------------------------------------------------------------

  Future<AppleAuthResult> _authenticateAndroid() async {
    debugPrint('[AppleAuth] platform=android');
    debugPrint('[AppleAuth] Using Firebase-native Apple provider');

    // Stage A — Firebase Apple authorization via signInWithProvider()
    UserCredential userCredential;
    try {
      debugPrint('[AppleAuth] Calling FirebaseAuth.signInWithProvider()');
      final appleProvider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      userCredential = await firebaseAuth.signInWithProvider(appleProvider);
      debugPrint('[AppleAuth] Firebase Apple authentication succeeded');
    } on FirebaseAuthException catch (e) {
      // Treat user-initiated cancellation as non-error
      if (e.code == 'canceled' || e.code == 'web-context-canceled') {
        debugPrint('[AppleAuth] User cancelled Apple Sign-In');
        return const AppleAuthResult.cancelled();
      }
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION '
        'errorType=FirebaseAuthException error=${e.code}',
      );
      return AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage:
            'Apple Sign-In failed (${e.code}): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      // Handle any unexpected cancellation signal from the platform layer
      final msg = e.toString().toLowerCase();
      if (msg.contains('canceled') || msg.contains('cancelled')) {
        debugPrint('[AppleAuth] User cancelled Apple Sign-In');
        return const AppleAuthResult.cancelled();
      }
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION '
        'errorType=${e.runtimeType}',
      );
      return AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage: 'Apple Sign-In error (${e.runtimeType}): $e',
      );
    }

    // Stage B — Firebase authentication is completed by Firebase itself (above).
    // Stage C — Get Firebase ID token.
    debugPrint('[AppleAuth] Obtaining Firebase ID token');
    String? firebaseIdToken;
    try {
      firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        debugPrint(
          '[AppleAuth] FAILED stage=C_TOKEN_GENERATION '
          'error=firebase-id-token-empty-or-null',
        );
        return const AppleAuthResult.failure(
          failureStage: 'C_TOKEN_GENERATION',
          errorMessage: 'Firebase ID Token was empty or null after Apple auth',
        );
      }
    } catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=C_TOKEN_GENERATION errorType=${e.runtimeType}',
      );
      return AppleAuthResult.failure(
        failureStage: 'C_TOKEN_GENERATION',
        errorMessage: 'Token retrieval error (${e.runtimeType}): $e',
      );
    }

    debugPrint(
      '[AppleAuth] Firebase ID token obtained (length=${firebaseIdToken.length})',
    );
    debugPrint('[AppleAuth] Returning AppleAuthResult.success()');
    return AppleAuthResult.success(firebaseIdToken);
  }

  // ---------------------------------------------------------------------------
  // iOS / macOS — native ASAuthorizationController path (unchanged)
  // ---------------------------------------------------------------------------

  Future<AppleAuthResult> _authenticateAppleNative() async {
    debugPrint('[AppleAuth] platform=${defaultTargetPlatform.name}');
    debugPrint('[AppleAuth] Using native Apple ASAuthorizationController');

    // Stage A — Apple ID credential request
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    AuthorizationCredentialAppleID appleCredential;
    try {
      debugPrint('[AppleAuth] Calling getAppleIDCredential()');
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      debugPrint('[AppleAuth] Apple authorization returned');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('[AppleAuth] User cancelled Apple Sign-In');
        return const AppleAuthResult.cancelled();
      }
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION '
        'errorType=${e.runtimeType} error=authorization/${e.code.name}',
      );
      return AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage: 'Apple Sign-In failed (${e.code.name}): ${e.message}',
      );
    } on SignInWithAppleNotSupportedException catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION '
        'errorType=${e.runtimeType} error=not-supported-on-device',
      );
      return AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage: 'Sign in with Apple is not supported on this device: $e',
      );
    } catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION errorType=${e.runtimeType}',
      );
      return AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage: 'Apple Sign-In error (${e.runtimeType}): $e',
      );
    }

    final identityToken = appleCredential.identityToken;
    if (identityToken == null || identityToken.isEmpty) {
      debugPrint(
        '[AppleAuth] FAILED stage=A_APPLE_AUTHORIZATION '
        'error=identity-token-empty-or-null',
      );
      return const AppleAuthResult.failure(
        failureStage: 'A_APPLE_AUTHORIZATION',
        errorMessage: 'Apple Sign-In failed: identity token was empty or null',
      );
    }

    // Stage B — Firebase credential creation + sign-in
    UserCredential? userCredential;
    try {
      debugPrint('[AppleAuth] Stage B: Firebase Apple credential + sign-in');
      final oauthCredential = OAuthProvider('apple.com')
          .credential(idToken: identityToken, rawNonce: rawNonce);
      userCredential = await firebaseAuth.signInWithCredential(oauthCredential);
      debugPrint('[AppleAuth] Firebase authentication succeeded');
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=B_FIREBASE_AUTH '
        'errorType=FirebaseAuthException error=${e.code}',
      );
      return AppleAuthResult.failure(
        failureStage: 'B_FIREBASE_AUTH',
        errorMessage:
            'Firebase Auth error (${e.code}): ${e.message ?? e.toString()}',
      );
    } catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=B_FIREBASE_AUTH errorType=${e.runtimeType}',
      );
      return AppleAuthResult.failure(
        failureStage: 'B_FIREBASE_AUTH',
        errorMessage: 'Firebase Auth error (${e.runtimeType}): $e',
      );
    }

    // Stage C — Firebase ID token retrieval
    String? firebaseIdToken;
    try {
      debugPrint('[AppleAuth] Obtaining Firebase ID token');
      firebaseIdToken = await userCredential.user?.getIdToken();
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        debugPrint(
          '[AppleAuth] FAILED stage=C_TOKEN_GENERATION '
          'error=firebase-id-token-empty-or-null',
        );
        return const AppleAuthResult.failure(
          failureStage: 'C_TOKEN_GENERATION',
          errorMessage: 'Firebase ID Token was empty or null after Apple auth',
        );
      }
    } catch (e) {
      debugPrint(
        '[AppleAuth] FAILED stage=C_TOKEN_GENERATION errorType=${e.runtimeType}',
      );
      return AppleAuthResult.failure(
        failureStage: 'C_TOKEN_GENERATION',
        errorMessage: 'Token retrieval error (${e.runtimeType}): $e',
      );
    }

    debugPrint(
      '[AppleAuth] Firebase ID token obtained (len=${firebaseIdToken.length}); '
      'handing to AuthNotifier → backend appleLogin()',
    );
    return AppleAuthResult.success(firebaseIdToken);
  }

  /// Signs out from Firebase auth session (Apple does not have a client-side
  /// SDK sign-out beyond revoking server-side tokens).
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
    } catch (_) {}
  }
}
