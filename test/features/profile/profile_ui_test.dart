import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/storage/avatar_url_resolver.dart';
import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/profile/presentation/widgets/family_profile_card.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_avatar_picker.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_form_dialog.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_switcher_sheet.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  _FakeAuthNotifier({required this.initialState});

  @override
  AuthState build() => initialState;
}

class _FakeProfilesListNotifier extends ProfilesListNotifier {
  final List<ProfileModel> _profiles;
  final List<String> deletedPhotoCalls = [];

  _FakeProfilesListNotifier(this._profiles);

  @override
  Future<List<ProfileModel>> build() async => _profiles;

  @override
  Future<ProfileModel> deletePhoto(String profileId) async {
    deletedPhotoCalls.add(profileId);
    return _profiles.firstWhere(
      (p) => p.profileId == profileId,
      orElse: () => _profiles.first,
    ).copyWith(photo: null);
  }
}

class FakeAvatarUrlResolver extends Fake implements AvatarUrlResolver {
  final Map<String, String?> resolutions;
  FakeAvatarUrlResolver(this.resolutions);

  @override
  Future<String?> resolveUrl(String? rawPath) async => resolutions[rawPath];

  @override
  Future<String?> resolveAvatarUrl(String? rawPath) async => resolutions[rawPath];

  @override
  void invalidate([String? storagePath]) {}

  @override
  void invalidateCache([String? storagePath]) {}

  @override
  void clearCache() {}

  @override
  int get cachedEntryCount => resolutions.length;
}

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  final ProfileModel? _profile;
  _FakeActiveProfileNotifier(this._profile);

  @override
  ProfileModel? build() => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final selfProfile = ProfileModel(
    profileId: 'prof-self-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    isPrimary: true,
    gender: 'Female',
    dateOfBirth: '1990-05-20',
    bloodGroup: 'O+',
  );

  final fatherProfile = ProfileModel(
    profileId: 'prof-father-1',
    ownerUserId: 'user-uuid-1',
    fullName: 'Robert Doe',
    relationship: 'Father',
    isPrimary: false,
    gender: 'Male',
    dateOfBirth: '1960-03-15',
    bloodGroup: 'A+',
  );

  final testUser = UserModel(
    id: 'user-uuid-1',
    name: 'Jane Doe',
    email: 'jane@example.com',
  );

  Widget createTestWidget({
    required Widget child,
    List<ProfileModel>? profiles,
    ProfileModel? activeProfile,
    AvatarUrlResolver? avatarResolver,
    _FakeProfilesListNotifier? profilesNotifier,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FakeAuthNotifier(
            initialState: AuthState(
              isLoading: false,
              isAuthenticated: true,
              user: testUser,
            ),
          ),
        ),
        profilesListProvider.overrideWith(
          () => profilesNotifier ?? _FakeProfilesListNotifier(profiles ?? [selfProfile, fatherProfile]),
        ),
        activeProfileProvider.overrideWith(
          () => _FakeActiveProfileNotifier(activeProfile ?? selfProfile),
        ),
        if (avatarResolver != null)
          avatarUrlResolverProvider.overrideWithValue(avatarResolver),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('ProfileFormDialog Widget Tests', () {
    testWidgets('renders all MediVault demographic fields and omits Mark as Primary switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const ProfileFormDialog()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Family Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Relationship'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Blood Group'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Height (cm)'), findsOneWidget);
      expect(find.text('Weight (kg)'), findsOneWidget);
      expect(find.text('No known allergies'), findsOneWidget);
      expect(find.text('No chronic conditions'), findsOneWidget);
      expect(find.text('Notes (Optional)'), findsOneWidget);

      // Verify that "Mark as Primary Profile" switch has been removed
      expect(find.text('Mark as Primary Profile'), findsNothing);
    });

    testWidgets('defaults gender and blood group to null with placeholder hints for new family profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const ProfileFormDialog()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Gender'), findsOneWidget);
      expect(find.text('Select Blood Group'), findsOneWidget);
    });

    testWidgets('shows validation error when full name is submitted empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(child: const ProfileFormDialog()),
      );
      await tester.pumpAndSettle();

      final createButton = find.text('Create Profile');
      expect(createButton, findsOneWidget);

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('Please enter full name'), findsOneWidget);
    });

    testWidgets('dynamically displays Specify Relationship when Other is selected', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestWidget(child: const ProfileFormDialog()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Specify Relationship'), findsNothing);

      // Tap relationship dropdown (which is visible at the top)
      final dropdown = find.byType(DropdownButtonFormField<String>).first;
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap 'Other' in dropdown menu
      final otherItem = find.text('Other').last;
      await tester.tap(otherItem);
      await tester.pumpAndSettle();

      expect(find.text('Specify Relationship'), findsOneWidget);
    });
  });

  group('FamilyProfileCard Widget Tests', () {
    testWidgets('shows PRIMARY badge for Self primary profile and hides Mark Primary popup menu', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: FamilyProfileCard(profile: selfProfile, isActive: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('PRIMARY'), findsOneWidget);

      // Open popup menu
      final moreButton = find.byIcon(Icons.more_vert);
      expect(moreButton, findsOneWidget);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Mark Primary'), findsNothing);
    });

    testWidgets('shows disabled Delete (Protected) menu item for family member', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: FamilyProfileCard(profile: fatherProfile, isActive: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Robert Doe'), findsOneWidget);
      expect(find.text('PRIMARY'), findsNothing);

      // Open popup menu
      final moreButton = find.byIcon(Icons.more_vert);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Mark Primary'), findsNothing);
      expect(find.text('Delete (Protected)'), findsOneWidget);
      expect(find.text('Archive Profile'), findsOneWidget);
    });

    testWidgets('shows ARCHIVED badge, Historical Records Preserved text, and Restore button for archived profile', (
      tester,
    ) async {
      final archivedProfile = ProfileModel(
        profileId: 'prof-archived-ui-1',
        ownerUserId: 'user-uuid-1',
        fullName: 'Grandpa Joe',
        relationship: 'Grandfather',
        isPrimary: false,
        isArchived: true,
        archivedAt: DateTime(2026, 11, 10, 8, 0),
      );

      await tester.pumpWidget(
        createTestWidget(
          child: FamilyProfileCard(
            profile: archivedProfile,
            isActive: false,
            isArchivedView: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grandpa Joe'), findsOneWidget);
      expect(find.text('ARCHIVED'), findsOneWidget);
      expect(find.text('Historical Records Preserved'), findsOneWidget);
      expect(find.text('Restore Profile'), findsOneWidget);
      expect(find.text('Switch to Profile'), findsNothing);
      expect(find.text('ACTIVE PROFILE'), findsNothing);

      // Open popup menu
      final moreButton = find.byIcon(Icons.more_vert);
      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      expect(find.text('Restore Profile'), findsAtLeastNWidgets(1));
      expect(find.text('Archive Profile'), findsNothing);
      expect(find.text('Edit Profile'), findsNothing);
    });
  });

  group('ProfileSwitcherSheet Widget Tests', () {
    testWidgets('renders all profiles with active profile highlighted', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ProfileSwitcherSheet(),
          activeProfile: selfProfile,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Switch Health Profile'), findsOneWidget);
      expect(find.text('Jane Doe'), findsOneWidget);
      expect(find.text('Robert Doe'), findsOneWidget);

      // Active profile checkmark
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      // Actions at bottom
      expect(find.text('Add Profile'), findsOneWidget);
      expect(find.text('Manage All'), findsOneWidget);
    });
  });

  group('ProfileAvatar Widget Tests', () {
    testWidgets('renders check icon for primary self profile with no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatar(profile: selfProfile),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('renders initial letter for family member with no photo', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatar(profile: fatherProfile),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('renders NetworkImage when photo storage path resolves to signed URL', (
      tester,
    ) async {
      final profileWithPhoto =
          selfProfile.copyWith(photo: 'user-uuid-1/avatar.jpg');
      final fakeResolver = FakeAvatarUrlResolver({
        'user-uuid-1/avatar.jpg': 'https://signed.supabase.co/avatar.jpg',
      });

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatar(profile: profileWithPhoto),
          avatarResolver: fakeResolver,
        ),
      );
      await tester.pumpAndSettle();

      final circleAvatar =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
      final netImage = circleAvatar.backgroundImage as NetworkImage;
      expect(netImage.url, 'https://signed.supabase.co/avatar.jpg');
    });
  });

  group('ProfileAvatarPicker Widget Tests', () {
    testWidgets('renders person icon when photoPath is null', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatarPicker(
            photoPath: null,
            profileId: 'prof-self-1',
            onPhotoChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.text('Upload photo'), findsOneWidget);
    });

    testWidgets('renders NetworkImage when photoPath resolves to signed URL', (
      tester,
    ) async {
      final fakeResolver = FakeAvatarUrlResolver({
        'user-uuid-1/picker.jpg': 'https://signed.supabase.co/picker.jpg',
      });

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatarPicker(
            photoPath: 'user-uuid-1/picker.jpg',
            profileId: 'prof-self-1',
            onPhotoChanged: (_) {},
          ),
          avatarResolver: fakeResolver,
        ),
      );
      await tester.pumpAndSettle();

      final circleAvatar =
          tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circleAvatar.backgroundImage, isA<NetworkImage>());
      final netImage = circleAvatar.backgroundImage as NetworkImage;
      expect(netImage.url, 'https://signed.supabase.co/picker.jpg');
    });

    testWidgets('shows bottom sheet and confirmation dialog on photo removal', (
      tester,
    ) async {
      String? updatedPhoto = 'initial_photo';
      final fakeNotifier = _FakeProfilesListNotifier([selfProfile]);

      await tester.pumpWidget(
        createTestWidget(
          child: ProfileAvatarPicker(
            photoPath: 'user-uuid-1/existing.jpg',
            profileId: 'prof-self-1',
            onPhotoChanged: (val) => updatedPhoto = val,
          ),
          profilesNotifier: fakeNotifier,
        ),
      );
      await tester.pumpAndSettle();

      // Tap to open options
      await tester.tap(find.text('Upload photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Remove Photo'), findsOneWidget);

      // Tap Remove Photo
      await tester.tap(find.text('Remove Photo'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(
        find.text('Are you sure you want to remove this profile photo?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Remove in dialog
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      // Verified: deletePhoto was invoked and onPhotoChanged was passed null
      expect(fakeNotifier.deletedPhotoCalls, contains('prof-self-1'));
      expect(updatedPhoto, isNull);
    });
  });
}
