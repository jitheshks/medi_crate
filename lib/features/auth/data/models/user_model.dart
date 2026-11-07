import 'package:firebase_auth/firebase_auth.dart';

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

  /// Safely resolves the active Firebase provider when not present in storage.
  /// Handles linked accounts by giving priority to email/password if credentials exist.
  static AuthProviderType resolveFirebaseProvider() {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return AuthProviderType.emailPassword;
      final providers = currentUser.providerData
          .map((p) => p.providerId)
          .toSet();
      if (providers.contains('password')) {
        return AuthProviderType.emailPassword;
      }
      if (providers.contains('apple.com')) {
        return AuthProviderType.apple;
      }
      if (providers.contains('google.com')) {
        return AuthProviderType.google;
      }
      return AuthProviderType.emailPassword;
    } catch (_) {
      return AuthProviderType.emailPassword;
    }
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
      dateOfBirth: map['dateOfBirth']?.toString() ?? map['dob']?.toString(),
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
