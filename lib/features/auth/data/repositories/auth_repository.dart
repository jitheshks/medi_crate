import '../../../../core/connectivity/connectivity_service.dart';
import '../../../../core/exceptions/app_exception.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../profile/data/datasources/remote/user_remote_data_source.dart';
import '../datasources/local/auth_local_data_source.dart';
import '../datasources/remote/auth_remote_data_source.dart';
import '../models/requests/auth_request_models.dart';
import '../models/responses/auth_response_models.dart';
import '../models/user_model.dart';

/// AuthRepository orchestrates authentication business logic and coordinates
/// between remote REST APIs (A1–A10, B3–B5), local secure token storage, and Hive caching.
class AuthRepository {
  final AuthLocalDataSource localDataSource;
  final AuthRemoteDataSource remoteDataSource;
  final SecureStorageService secureStorage;
  final ConnectivityService connectivityService;
  final UserRemoteDataSource? userRemoteDataSource;

  AuthRepository({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.secureStorage,
    required this.connectivityService,
    this.userRemoteDataSource,
  });

  /// Checks if a valid active session exists locally.
  Future<bool> checkSession() async {
    final token = await secureStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    final user = await localDataSource.getUser();
    return user != null;
  }

  /// Retrieves the currently cached authenticated user profile.
  Future<UserModel?> getCurrentUser() async {
    return await localDataSource.getUser();
  }

  /// A1 — Sign Up
  Future<SignUpResult> signUp({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String dob,
    String? gender,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to create your account.',
      );
    }

    final request = SignUpRequest(
      name: name,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      dob: dob,
      gender: gender,
    );

    return await remoteDataSource.signUp(request);
  }

  /// A2 — Verify Email (OTP)
  Future<UserModel> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to verify your email.',
      );
    }

    final request = VerifyEmailRequest(email: email, otp: otp);
    final authData = await remoteDataSource.verifyEmail(request);

    // Save tokens securely
    await secureStorage.saveTokens(
      accessToken: authData.accessToken,
      refreshToken: authData.refreshToken,
    );

    // Create & save local user profile
    final user = UserModel(
      id: authData.userId?.toString() ?? '',
      email: email,
      name: authData.name ?? email.split('@').first,
      authProvider: AuthProviderType.emailPassword,
    );
    await localDataSource.saveUser(user);

    return user;
  }

  /// A3 — Resend OTP
  Future<MessageResponseData> resendOtp({
    required String email,
    required String type,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to resend verification code.',
      );
    }

    final request = ResendOtpRequest(email: email, type: type);
    return await remoteDataSource.resendOtp(request);
  }

  /// A4 — Sign In / Login
  Future<LoginResult> signIn({
    required String email,
    required String password,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException('Internet connection required to sign in.');
    }

    final request = LoginRequest(email: email, password: password);
    final result = await remoteDataSource.login(request);

    if (result.isSuccess && result.authData != null) {
      final authData = result.authData!;
      await secureStorage.saveTokens(
        accessToken: authData.accessToken,
        refreshToken: authData.refreshToken,
      );

      final user = UserModel(
        id: authData.userId?.toString() ?? '',
        email: email,
        name: authData.name ?? email.split('@').first,
        authProvider: AuthProviderType.emailPassword,
      );
      await localDataSource.saveUser(user);
    }

    return result;
  }

  /// A5 — Forgot Password
  Future<MessageResponseData> forgotPassword(String email) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to request password reset.',
      );
    }

    final request = ForgotPasswordRequest(email: email);
    return await remoteDataSource.forgotPassword(request);
  }

  /// A6 — Reset Password
  Future<MessageResponseData> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String passwordConfirmation,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to reset password.',
      );
    }

    final request = ResetPasswordRequest(
      email: email,
      otp: otp,
      password: newPassword,
      passwordConfirmation: passwordConfirmation,
    );

    final res = await remoteDataSource.resetPassword(request);

    // Server revokes all existing access & refresh tokens on password reset
    await secureStorage.clearAuthToken();
    await localDataSource.clearUser();

    return res;
  }

  /// A7 — Refresh Access Token
  Future<AuthTokensResponseData> refreshToken() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const UnauthorizedException('No refresh token available.');
    }

    final request = RefreshTokenRequest(refreshToken: refreshToken);
    final authData = await remoteDataSource.refreshToken(request);

    await secureStorage.saveTokens(
      accessToken: authData.accessToken,
      refreshToken: authData.refreshToken,
    );

    return authData;
  }

  /// A8 — Google Sign In
  Future<UserModel> googleLogin(String firebaseIdToken) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required for Google sign in.',
      );
    }

    final request = SocialLoginRequest(firebaseIdToken: firebaseIdToken);
    final authData = await remoteDataSource.googleLogin(request);

    await secureStorage.saveTokens(
      accessToken: authData.accessToken,
      refreshToken: authData.refreshToken,
    );

    final user = UserModel(
      id: authData.userId?.toString() ?? '',
      email: authData.email ?? '',
      name: authData.name ?? 'Google User',
      authProvider: AuthProviderType.google,
    );
    await localDataSource.saveUser(user);

    return user;
  }

  /// A9 — Apple Sign In
  Future<UserModel> appleLogin(String firebaseIdToken) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required for Apple sign in.',
      );
    }

    final request = SocialLoginRequest(firebaseIdToken: firebaseIdToken);
    final authData = await remoteDataSource.appleLogin(request);

    await secureStorage.saveTokens(
      accessToken: authData.accessToken,
      refreshToken: authData.refreshToken,
    );

    final user = UserModel(
      id: authData.userId?.toString() ?? '',
      email: authData.email ?? '',
      name: authData.name ?? 'Apple User',
      authProvider: AuthProviderType.apple,
    );
    await localDataSource.saveUser(user);

    return user;
  }

  /// A10 — Sign Out / Logout
  Future<void> signOut() async {
    final isOnline = await connectivityService.checkConnectivity();
    final token = await secureStorage.getAuthToken();

    if (isOnline && token != null && token.isNotEmpty) {
      try {
        await remoteDataSource.logout();
      } catch (_) {
        // Safe swallow: local session must be cleared even if network or server fails
      }
    }

    await secureStorage.clearAuthToken();
    await localDataSource.clearUser();
  }

  /// B3 — Change Password
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to change password.',
      );
    }
    if (userRemoteDataSource == null) {
      throw StateError('UserRemoteDataSource not available');
    }

    return await userRemoteDataSource!.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      newPasswordConfirmation: newPasswordConfirmation,
    );
  }

  /// B4 (Step 1 / PDF B5) — Request Change Email
  Future<String> requestChangeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to request email change.',
      );
    }
    if (userRemoteDataSource == null) {
      throw StateError('UserRemoteDataSource not available');
    }

    return await userRemoteDataSource!.requestChangeEmail(
      currentPassword: currentPassword,
      newEmail: newEmail,
    );
  }

  /// B4 (Step 2 / PDF B6) — Confirm Change Email
  Future<Map<String, dynamic>> confirmChangeEmail({required String otp}) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to verify OTP.',
      );
    }
    if (userRemoteDataSource == null) {
      throw StateError('UserRemoteDataSource not available');
    }

    final res = await userRemoteDataSource!.confirmChangeEmail(otp: otp);
    if (res['user'] is Map) {
      final userMap = Map<String, dynamic>.from(res['user'] as Map);
      final currentUser = await localDataSource.getUser();
      if (currentUser != null && userMap['email'] != null) {
        await localDataSource.saveUser(
          currentUser.copyWith(email: userMap['email'].toString()),
        );
      }
    }
    return res;
  }

  /// B5 (PDF B4) — Delete Account
  Future<String> deleteAccount({required String currentPassword}) async {
    final isOnline = await connectivityService.checkConnectivity();
    if (!isOnline) {
      throw const NetworkException(
        'Internet connection required to delete account.',
      );
    }
    if (userRemoteDataSource == null) {
      throw StateError('UserRemoteDataSource not available');
    }

    final result = await userRemoteDataSource!.deleteAccount(
      currentPassword: currentPassword,
    );

    await secureStorage.clearAuthToken();
    await localDataSource.clearUser();

    return result;
  }
}
