import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/core/theme/app_theme.dart';
import 'package:medi_crate/features/auth/data/models/user_model.dart';
import 'package:medi_crate/features/auth/presentation/providers/auth_providers.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';
import 'package:medi_crate/features/profile/presentation/providers/profile_providers.dart';
import 'package:medi_crate/features/profile/presentation/screens/profile_screen.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_allergies_section.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_chronic_conditions_section.dart';
import 'package:medi_crate/features/profile/presentation/widgets/profile_form_dialog.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  _FakeAuthNotifier({required this.initialState});

  @override
  AuthState build() => initialState;
}

class _FakeActiveProfileNotifier extends ActiveProfileNotifier {
  final ProfileModel? _profile;
  _FakeActiveProfileNotifier(this._profile);

  @override
  ProfileModel? build() => _profile;
}

class _FakeProfilesListNotifier extends ProfilesListNotifier {
  final List<ProfileModel> _profiles;
  ProfileModel? lastCreatedProfile;
  ProfileModel? lastUpdatedProfile;

  _FakeProfilesListNotifier(this._profiles);

  @override
  Future<List<ProfileModel>> build() async => _profiles;

  @override
  Future<ProfileModel> createProfile({
    required String fullName,
    required String relationship,
    String? relationshipOther,
    String? gender,
    String? dateOfBirth,
    String? bloodGroup,
    String? photo,
    double? height,
    double? weight,
    bool isPrimary = false,
    String? notes,
    List<String> allergies = const [],
    bool allergiesConfirmedNone = false,
    List<String> chronicConditions = const [],
    bool chronicConditionsConfirmedNone = false,
  }) async {
    final p = ProfileModel(
      profileId: 'new-prof-${DateTime.now().millisecondsSinceEpoch}',
      ownerUserId: 'user-1',
      fullName: fullName,
      relationship: relationship,
      isPrimary: isPrimary,
      photo: photo,
      allergies: allergies,
      allergiesConfirmedNone: allergiesConfirmedNone,
      chronicConditions: chronicConditions,
      chronicConditionsConfirmedNone: chronicConditionsConfirmedNone,
    );
    lastCreatedProfile = p;
    return p;
  }

  @override
  Future<ProfileModel> updateProfile(ProfileModel updated) async {
    lastUpdatedProfile = updated;
    return updated;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  group('1. ProfileAllergiesSection State Consistency Tests', () {
    testWidgets('1. Empty allergy list, unchecked checkbox: checkbox enabled, input enabled', (tester) async {
      final controller = TextEditingController();
      bool? confirmedNoneValue;

      await tester.pumpWidget(wrapWidget(
        ProfileAllergiesSection(
          allergyInputController: controller,
          allergies: const [],
          allergiesConfirmedNone: false,
          onAddAllergy: () {},
          onRemoveAllergy: (_) {},
          onAllergiesConfirmedNoneChanged: (val) => confirmedNoneValue = val,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNotNull);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNotNull);

      // Tap checkbox to confirm toggling works
      await tester.tap(find.text('No known allergies'));
      await tester.pumpAndSettle();
      expect(confirmedNoneValue, isTrue);
    });

    testWidgets('2. Empty allergy list, checked checkbox: checkbox enabled, input disabled', (tester) async {
      final controller = TextEditingController();
      bool? confirmedNoneValue;

      await tester.pumpWidget(wrapWidget(
        ProfileAllergiesSection(
          allergyInputController: controller,
          allergies: const [],
          allergiesConfirmedNone: true,
          onAddAllergy: () {},
          onRemoveAllergy: (_) {},
          onAllergiesConfirmedNoneChanged: (val) => confirmedNoneValue = val,
        ),
      ));

      // Input and Add button must be disabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNull);

      // Checkbox must remain enabled for unchecking
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
      expect(checkbox.onChanged, isNotNull);

      // Tap to uncheck
      await tester.tap(find.text('No known allergies'));
      await tester.pumpAndSettle();
      expect(confirmedNoneValue, isFalse);
    });

    testWidgets('3. Existing allergies: checkbox disabled, input enabled', (tester) async {
      final controller = TextEditingController();
      var changedCalled = false;

      await tester.pumpWidget(wrapWidget(
        ProfileAllergiesSection(
          allergyInputController: controller,
          allergies: const ['Penicillin', 'Peanuts'],
          allergiesConfirmedNone: false,
          onAddAllergy: () {},
          onRemoveAllergy: (_) {},
          onAllergiesConfirmedNoneChanged: (_) => changedCalled = true,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNotNull);

      // Checkbox must be disabled
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNull);

      // Tapping container does not trigger callback
      await tester.tap(find.text('No known allergies'));
      await tester.pumpAndSettle();
      expect(changedCalled, isFalse);
    });
  });

  group('2. ProfileChronicConditionsSection State Consistency Tests', () {
    testWidgets('4. Empty condition list, unchecked checkbox: checkbox enabled, input enabled', (tester) async {
      final controller = TextEditingController();
      bool? confirmedNoneValue;

      await tester.pumpWidget(wrapWidget(
        ProfileChronicConditionsSection(
          conditionInputController: controller,
          chronicConditions: const [],
          chronicConditionsConfirmedNone: false,
          onAddCondition: () {},
          onRemoveCondition: (_) {},
          onChronicConditionsConfirmedNoneChanged: (val) => confirmedNoneValue = val,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNotNull);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNotNull);

      await tester.tap(find.text('No chronic conditions'));
      await tester.pumpAndSettle();
      expect(confirmedNoneValue, isTrue);
    });

    testWidgets('5. Empty condition list, checked checkbox: unchecking is enabled, input is disabled', (tester) async {
      final controller = TextEditingController();
      bool? confirmedNoneValue;

      await tester.pumpWidget(wrapWidget(
        ProfileChronicConditionsSection(
          conditionInputController: controller,
          chronicConditions: const [],
          chronicConditionsConfirmedNone: true,
          onAddCondition: () {},
          onRemoveCondition: (_) {},
          onChronicConditionsConfirmedNoneChanged: (val) => confirmedNoneValue = val,
        ),
      ));

      // Input and Add button must be disabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isFalse);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNull);

      // Checkbox must be enabled so user can uncheck! (Fixed inverted bug)
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
      expect(checkbox.onChanged, isNotNull);

      await tester.tap(find.text('No chronic conditions'));
      await tester.pumpAndSettle();
      expect(confirmedNoneValue, isFalse);
    });

    testWidgets('6. Existing chronic conditions: checkbox disabled, input enabled', (tester) async {
      final controller = TextEditingController();
      var changedCalled = false;

      await tester.pumpWidget(wrapWidget(
        ProfileChronicConditionsSection(
          conditionInputController: controller,
          chronicConditions: const ['Hypertension', 'Asthma'],
          chronicConditionsConfirmedNone: false,
          onAddCondition: () {},
          onRemoveCondition: (_) {},
          onChronicConditionsConfirmedNoneChanged: (_) => changedCalled = true,
        ),
      ));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, isTrue);

      final addButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(addButton.onPressed, isNotNull);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNull);

      await tester.tap(find.text('No chronic conditions'));
      await tester.pumpAndSettle();
      expect(changedCalled, isFalse);
    });
  });

  group('3. ProfileScreen Medical History Flow Tests', () {
    testWidgets('7. Adding an allergy clears confirmed-none flag and disables checkbox', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = ProfileModel(
        profileId: 'p-1',
        ownerUserId: 'u-1',
        fullName: 'Test User',
        relationship: 'Self',
        isPrimary: true,
        allergies: const [],
        allergiesConfirmedNone: true, // Initially confirmed none
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(
                initialState: AuthState(
                  user: const UserModel(id: 'u-1', name: 'Test User', email: 't@example.com'),
                  isAuthenticated: true,
                ),
              ),
            ),
            activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(profile)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkbox is checked, input disabled
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Penicillin')).enabled, isFalse);

      // Uncheck "No known allergies"
      await tester.tap(find.text('No known allergies'));
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isFalse);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Penicillin')).enabled, isTrue);

      // Enter an allergy and click ADD
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Penicillin'), 'Aspirin');
      await tester.tap(find.widgetWithText(ElevatedButton, 'ADD').first);
      await tester.pumpAndSettle();

      // Allergy chip exists
      expect(find.text('Aspirin'), findsOneWidget);
      // Checkbox must now be disabled because allergies is non-empty
      final checkboxAfterAdd = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkboxAfterAdd.value, isFalse);
      expect(checkboxAfterAdd.onChanged, isNull);
    });

    testWidgets('8. Removing last entry does not automatically mark as confirmed-none', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = ProfileModel(
        profileId: 'p-1',
        ownerUserId: 'u-1',
        fullName: 'Test User',
        relationship: 'Self',
        isPrimary: true,
        allergies: const ['Pollen'],
        allergiesConfirmedNone: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(
                initialState: AuthState(
                  user: const UserModel(id: 'u-1', name: 'Test User', email: 't@example.com'),
                  isAuthenticated: true,
                ),
              ),
            ),
            activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(profile)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pollen'), findsOneWidget);
      // Remove allergy chip
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      expect(find.text('Pollen'), findsNothing);
      expect(find.text('None added yet.'), findsWidgets);

      // Checkbox must be enabled, but UNCHECKED (never automatically confirmed)
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(checkbox.value, isFalse);
      expect(checkbox.onChanged, isNotNull);
    });

    testWidgets('9. Existing contradictory data on load is normalized without deleting entries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Contradictory profile: has allergies, but allergiesConfirmedNone is erroneously true
      final contradictoryProfile = ProfileModel(
        profileId: 'p-1',
        ownerUserId: 'u-1',
        fullName: 'Contradictory User',
        relationship: 'Self',
        isPrimary: true,
        allergies: const ['Peanuts'],
        allergiesConfirmedNone: true, // Contradictory flag!
        chronicConditions: const ['Diabetes'],
        chronicConditionsConfirmedNone: true, // Contradictory flag!
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _FakeAuthNotifier(
                initialState: AuthState(
                  user: const UserModel(id: 'u-1', name: 'Test User', email: 't@example.com'),
                  isAuthenticated: true,
                ),
              ),
            ),
            activeProfileProvider.overrideWith(() => _FakeActiveProfileNotifier(contradictoryProfile)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Entries are fully preserved!
      expect(find.text('Peanuts'), findsOneWidget);
      expect(find.text('Diabetes'), findsOneWidget);

      // Confirmed-none flags must be normalized to FALSE, and checkboxes disabled
      for (final checkboxFinder in [find.byType(Checkbox).first, find.byType(Checkbox).last]) {
        final cb = tester.widget<Checkbox>(checkboxFinder);
        expect(cb.value, isFalse);
        expect(cb.onChanged, isNull);
      }
    });
  });

  group('4. ProfileFormDialog Medical History Tests', () {
    testWidgets('10. Creating profile allows confirming neither, either, or both categories', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeListNotifier = _FakeProfilesListNotifier([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profilesListProvider.overrideWith(() => fakeListNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: ProfileFormDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both checkboxes start unchecked and enabled
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isFalse);
      expect(checkboxes[0].onChanged, isNotNull);
      expect(checkboxes[1].value, isFalse);
      expect(checkboxes[1].onChanged, isNotNull);

      // Check both
      await tester.tap(find.text('No known allergies'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No chronic conditions'));
      await tester.pumpAndSettle();

      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);

      // Enter name and submit
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Eleanor Vance'), 'Alice Smith');
      await tester.ensureVisible(find.text('Create Profile'));
      await tester.tap(find.text('Create Profile'));
      await tester.pumpAndSettle();

      expect(fakeListNotifier.lastCreatedProfile, isNotNull);
      expect(fakeListNotifier.lastCreatedProfile!.allergiesConfirmedNone, isTrue);
      expect(fakeListNotifier.lastCreatedProfile!.chronicConditionsConfirmedNone, isTrue);
      expect(fakeListNotifier.lastCreatedProfile!.allergies, isEmpty);
      expect(fakeListNotifier.lastCreatedProfile!.chronicConditions, isEmpty);
    });

    testWidgets('11. Editing profile with existing history prevents confirming none and preserves entries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final existingProfile = ProfileModel(
        profileId: 'p-edit',
        ownerUserId: 'u-1',
        fullName: 'Existing Member',
        relationship: 'Mother',
        isPrimary: false,
        allergies: const ['Latex'],
        allergiesConfirmedNone: false,
        chronicConditions: const ['Arthritis'],
        chronicConditionsConfirmedNone: false,
      );

      final fakeListNotifier = _FakeProfilesListNotifier([existingProfile]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profilesListProvider.overrideWith(() => fakeListNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: ProfileFormDialog(profileToEdit: existingProfile)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Checkboxes must be disabled because existing lists are non-empty
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isFalse);
      expect(checkboxes[0].onChanged, isNull);
      expect(checkboxes[1].value, isFalse);
      expect(checkboxes[1].onChanged, isNull);

      // Save changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fakeListNotifier.lastUpdatedProfile, isNotNull);
      expect(fakeListNotifier.lastUpdatedProfile!.allergies, ['Latex']);
      expect(fakeListNotifier.lastUpdatedProfile!.chronicConditions, ['Arthritis']);
      expect(fakeListNotifier.lastUpdatedProfile!.allergiesConfirmedNone, isFalse);
      expect(fakeListNotifier.lastUpdatedProfile!.chronicConditionsConfirmedNone, isFalse);
    });

    testWidgets('12. Editing profile with contradictory data normalizes flag while preserving entries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final contradictoryProfile = ProfileModel(
        profileId: 'p-contradictory',
        ownerUserId: 'u-1',
        fullName: 'Contradictory Member',
        relationship: 'Brother',
        isPrimary: false,
        allergies: const ['Dust'],
        allergiesConfirmedNone: true, // Contradictory!
        chronicConditions: const ['Migraine'],
        chronicConditionsConfirmedNone: true, // Contradictory!
      );

      final fakeListNotifier = _FakeProfilesListNotifier([contradictoryProfile]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profilesListProvider.overrideWith(() => fakeListNotifier),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(body: ProfileFormDialog(profileToEdit: contradictoryProfile)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both checkboxes must be initialized to FALSE and disabled
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox)).toList();
      expect(checkboxes[0].value, isFalse);
      expect(checkboxes[0].onChanged, isNull);
      expect(checkboxes[1].value, isFalse);
      expect(checkboxes[1].onChanged, isNull);

      // Save changes
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fakeListNotifier.lastUpdatedProfile, isNotNull);
      // Entries strictly preserved
      expect(fakeListNotifier.lastUpdatedProfile!.allergies, ['Dust']);
      expect(fakeListNotifier.lastUpdatedProfile!.chronicConditions, ['Migraine']);
      // Flags normalized to false
      expect(fakeListNotifier.lastUpdatedProfile!.allergiesConfirmedNone, isFalse);
      expect(fakeListNotifier.lastUpdatedProfile!.chronicConditionsConfirmedNone, isFalse);
    });
  });
}
