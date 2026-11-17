import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/exceptions/app_exception.dart';
import 'package:medi_crate/features/profile/data/datasources/remote/supabase_profile_remote_data_source.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

class _MockProfileRemoteDataSource extends SupabaseProfileRemoteDataSource {
  ProfileModel? profileToReturn;
  Map<String, dynamic>? executedUpdatePayload;

  @override
  Future<ProfileModel?> getProfileById({
    required String profileId,
    required String ownerUserId,
  }) async {
    if (profileToReturn != null &&
        profileToReturn!.profileId == profileId &&
        profileToReturn!.ownerUserId == ownerUserId) {
      return profileToReturn;
    }
    return null;
  }
}

void main() {
  group('SupabaseProfileRemoteDataSource Archival & Restoration Unit Tests', () {
    late _MockProfileRemoteDataSource dataSource;

    setUp(() {
      dataSource = _MockProfileRemoteDataSource();
    });

    final primaryProfile = ProfileModel(
      profileId: 'prof-primary-1',
      ownerUserId: 'user-1',
      fullName: 'Primary Owner',
      relationship: 'Self',
      isPrimary: true,
      isArchived: false,
    );

    final activeFamilyProfile = ProfileModel(
      profileId: 'prof-family-1',
      ownerUserId: 'user-1',
      fullName: 'Family Daughter',
      relationship: 'Daughter',
      isPrimary: false,
      isArchived: false,
    );

    final archivedFamilyProfile = ProfileModel(
      profileId: 'prof-family-archived-1',
      ownerUserId: 'user-1',
      fullName: 'Archived Uncle',
      relationship: 'Uncle',
      isPrimary: false,
      isArchived: true,
      archivedAt: DateTime(2026, 11, 10, 8, 0),
    );

    test('archiveProfile throws UnauthorizedException if ownerUserId is empty', () async {
      await expectLater(
        dataSource.archiveProfile(profileId: 'prof-1', ownerUserId: '   '),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('archiveProfile throws ValidationException if profileId is empty', () async {
      await expectLater(
        dataSource.archiveProfile(profileId: '', ownerUserId: 'user-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('archiveProfile throws NotFoundException if profile does not exist', () async {
      dataSource.profileToReturn = null;
      await expectLater(
        dataSource.archiveProfile(profileId: 'missing-id', ownerUserId: 'user-1'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('archiveProfile throws ValidationException if profile is primary', () async {
      dataSource.profileToReturn = primaryProfile;
      await expectLater(
        dataSource.archiveProfile(
          profileId: primaryProfile.profileId,
          ownerUserId: primaryProfile.ownerUserId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Primary profile cannot be archived'),
          ),
        ),
      );
    });

    test('archiveProfile returns existing profile idempotently if already archived', () async {
      dataSource.profileToReturn = archivedFamilyProfile;
      final result = await dataSource.archiveProfile(
        profileId: archivedFamilyProfile.profileId,
        ownerUserId: archivedFamilyProfile.ownerUserId,
      );
      expect(result.profileId, archivedFamilyProfile.profileId);
      expect(result.isArchived, isTrue);
    });

    test('restoreProfile throws UnauthorizedException if ownerUserId is empty', () async {
      await expectLater(
        dataSource.restoreProfile(profileId: 'prof-1', ownerUserId: ''),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('restoreProfile throws ValidationException if profileId is empty', () async {
      await expectLater(
        dataSource.restoreProfile(profileId: '   ', ownerUserId: 'user-1'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('restoreProfile throws NotFoundException if profile does not exist', () async {
      dataSource.profileToReturn = null;
      await expectLater(
        dataSource.restoreProfile(profileId: 'missing-id', ownerUserId: 'user-1'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('restoreProfile throws ValidationException if profile is primary', () async {
      dataSource.profileToReturn = primaryProfile;
      await expectLater(
        dataSource.restoreProfile(
          profileId: primaryProfile.profileId,
          ownerUserId: primaryProfile.ownerUserId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.message,
            'message',
            contains('Primary profile cannot be restored'),
          ),
        ),
      );
    });

    test('restoreProfile returns existing profile idempotently if not archived', () async {
      dataSource.profileToReturn = activeFamilyProfile;
      final result = await dataSource.restoreProfile(
        profileId: activeFamilyProfile.profileId,
        ownerUserId: activeFamilyProfile.ownerUserId,
      );
      expect(result.profileId, activeFamilyProfile.profileId);
      expect(result.isArchived, isFalse);
    });
  });
}
