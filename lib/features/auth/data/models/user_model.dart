import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Supported authentication providers in MediCrate.
enum AuthProviderType { emailPassword, google, apple }

extension AuthProviderTypeX on AuthProviderType {
  bool get isOAuth =>
      this == AuthProviderType.google || this == AuthProviderType.apple;
  bool get isEmailPassword => this == AuthProviderType.emailPassword;

  String get displayName {
    switch (this) {
      case AuthProviderType.google:
        return 'Google';
      case AuthProviderType.apple:
        return 'Apple';
      case AuthProviderType.emailPassword:
        return 'Email/Password';
    }
  }
}

/// UserModel represents the authenticated user profile in MediCrate.
class UserModel {
  final String id;
  final String email;
  final String name;
  final String? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final AuthProviderType authProvider;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.authProvider = AuthProviderType.emailPassword,
  });

  /// Deprecated legacy fallback; always defaults to emailPassword without Firebase Auth.
  @Deprecated('Firebase is no longer used. Providers are managed by Supabase.')
  static AuthProviderType resolveFirebaseProvider() =>
      AuthProviderType.emailPassword;

  /// Creates a [UserModel] from a Supabase [sb.User] instance.
  factory UserModel.fromSupabaseUser(
    sb.User user, {
    AuthProviderType? provider,
  }) {
    final meta = user.userMetadata ?? <String, dynamic>{};
    final appMeta = user.appMetadata;

    // Resolve user display name
    final name =
        (meta['full_name'] ??
                meta['name'] ??
                user.email?.split('@').first ??
                'User')
            .toString();

    // Resolve authentication provider
    AuthProviderType resolvedProvider;
    if (provider != null) {
      resolvedProvider = provider;
    } else {
      final pStr = (appMeta['provider'] ?? meta['provider'])
          ?.toString()
          .toLowerCase();
      if (pStr == 'google') {
        resolvedProvider = AuthProviderType.google;
      } else if (pStr == 'apple') {
        resolvedProvider = AuthProviderType.apple;
      } else {
        resolvedProvider = AuthProviderType.emailPassword;
      }
    }

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: name,
      dateOfBirth: meta['dob']?.toString() ??
          meta['dateOfBirth']?.toString() ??
          meta['date_of_birth']?.toString(),
      gender: meta['gender']?.toString(),
      bloodGroup:
          meta['blood_group']?.toString() ?? meta['bloodGroup']?.toString(),
      authProvider: resolvedProvider,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      'authProvider': authProvider.name,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    AuthProviderType resolvedProvider = AuthProviderType.emailPassword;
    final providerStr =
        map['authProvider']?.toString() ?? map['auth_provider']?.toString();
    if (providerStr != null) {
      if (providerStr == AuthProviderType.google.name ||
          providerStr == 'google') {
        resolvedProvider = AuthProviderType.google;
      } else if (providerStr == AuthProviderType.apple.name ||
          providerStr == 'apple') {
        resolvedProvider = AuthProviderType.apple;
      } else {
        resolvedProvider = AuthProviderType.emailPassword;
      }
    } else {
      resolvedProvider = resolveFirebaseProvider();
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      dateOfBirth: map['dateOfBirth']?.toString() ??
          map['dob']?.toString() ??
          map['date_of_birth']?.toString(),
      gender: map['gender']?.toString(),
      bloodGroup:
          map['bloodGroup']?.toString() ?? map['blood_group']?.toString(),
      authProvider: resolvedProvider,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? dateOfBirth,
    String? gender,
    String? bloodGroup,
    AuthProviderType? authProvider,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      authProvider: authProvider ?? this.authProvider,
    );
  }
}
