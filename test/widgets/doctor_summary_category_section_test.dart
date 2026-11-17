import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/features/doctor_summary/data/models/doctor_summary_model.dart';
import 'package:medi_crate/features/doctor_summary/presentation/providers/doctor_summary_providers.dart';
import 'package:medi_crate/features/doctor_summary/presentation/widgets/doctor_summary_category_section.dart';
import 'package:medi_crate/features/doctor_summary/presentation/widgets/doctor_summary_category_tile.dart';
import 'package:medi_crate/features/profile/data/models/profile_model.dart';

void main() {
  final testProfile = ProfileModel(
    profileId: 'prof-1',
    ownerUserId: 'user-1',
    fullName: 'Jane Doe',
    relationship: 'Self',
    dateOfBirth: '1995-05-15',
  );

  final testMedicines = [
    {
      'id': 'med-1',
      'name': 'Amoxicillin',
      'dosage': '500mg',
      'frequency': '3x daily',
      'doctor_name': 'Dr. House',
      'prescribed_date': '2026-01-10',
    },
    {
      'id': 'med-2',
      'name': 'Ibuprofen',
      'dosage': '400mg',
      'frequency': 'As needed',
      'doctor_name': 'Dr. Wilson',
      'prescribed_date': '2026-01-12',
    },
  ];

  final testConsultations = [
    {
      'id': 'cons-1',
      'doctor_name': 'Dr. Cuddy',
      'specialization': 'Endocrinologist',
      'consultation_date': '2026-01-05',
    },
  ];

  final testSummaryModel = DoctorSummaryModel(
    profile: testProfile,
    consultations: testConsultations,
    medicines: testMedicines,
    vitals: const [],
    reports: const [],
  );

  group('DoctorSummaryCategoryTile', () {
    testWidgets('renders category label, item count, and starts collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.medications,
              items: testMedicines,
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {},
              titleBuilder: (m) => m['name'] ?? '',
              subtitleBuilder: (m) => m['dosage'] ?? '',
              onToggleCategory: (_, _, _) {},
              onToggleItem: (_, _, _) {},
            ),
          ),
        ),
      );

      expect(find.text('Medications (2)'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('Amoxicillin'), findsNothing);
      expect(find.text('Ibuprofen'), findsNothing);
    });

    testWidgets('expands and collapses on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.medications,
              items: testMedicines,
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {},
              titleBuilder: (m) => m['name'] ?? '',
              subtitleBuilder: (m) => m['dosage'] ?? '',
              onToggleCategory: (_, _, _) {},
              onToggleItem: (_, _, _) {},
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.text('Medications (2)'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('Amoxicillin'), findsOneWidget);
      expect(find.text('Ibuprofen'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Medications (2)'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('Amoxicillin'), findsNothing);
    });

    testWidgets('calls onToggleCategory when category checkbox is tapped', (
      tester,
    ) async {
      DoctorSummaryCategory? toggledCategory;
      bool? toggledTristate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.medications,
              items: testMedicines,
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {},
              titleBuilder: (m) => m['name'] ?? '',
              subtitleBuilder: (m) => m['dosage'] ?? '',
              onToggleCategory: (cat, tristate, items) {
                toggledCategory = cat;
                toggledTristate = tristate;
              },
              onToggleItem: (_, _, _) {},
            ),
          ),
        ),
      );

      final checkboxFinder = find.byType(Checkbox);
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pump();

      expect(toggledCategory, equals(DoctorSummaryCategory.medications));
      expect(toggledTristate, isTrue);
    });

    testWidgets('shows tristate null dash when partially selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.medications,
              items: testMedicines,
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {'med-1'}, // 1 selected, 1 deselected
              titleBuilder: (m) => m['name'] ?? '',
              subtitleBuilder: (m) => m['dosage'] ?? '',
              onToggleCategory: (_, _, _) {},
              onToggleItem: (_, _, _) {},
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isNull); // Tristate dash for partial selection
    });

    testWidgets('calls onToggleItem when an item checkbox is tapped', (
      tester,
    ) async {
      String? toggledItemId;
      bool? toggledSelected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.medications,
              items: testMedicines,
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {},
              titleBuilder: (m) => m['name'] ?? '',
              subtitleBuilder: (m) => m['dosage'] ?? '',
              onToggleCategory: (_, _, _) {},
              onToggleItem: (id, isSelected, cat) {
                toggledItemId = id;
                toggledSelected = isSelected;
              },
            ),
          ),
        ),
      );

      // Expand first
      await tester.tap(find.text('Medications (2)'));
      await tester.pumpAndSettle();

      // Tap the first item's list tile
      await tester.tap(find.text('Amoxicillin'));
      await tester.pumpAndSettle();

      expect(toggledItemId, equals('med-1'));
      expect(
        toggledSelected,
        isFalse,
      ); // It was selected, so toggling deselects
    });

    testWidgets('shows empty state message when expanded with 0 items', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorSummaryCategoryTile(
              category: DoctorSummaryCategory.vitals,
              items: const [],
              isLast: false,
              isCategorySelected: true,
              deselectedIds: const {},
              titleBuilder: (m) => '',
              subtitleBuilder: (m) => '',
              onToggleCategory: (_, _, _) {},
              onToggleItem: (_, _, _) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Vitals (0)'));
      await tester.pumpAndSettle();

      expect(
        find.text('No vitals available for current filter.'),
        findsOneWidget,
      );
    });
  });

  group('DoctorSummaryCategorySection', () {
    testWidgets(
      'renders header, select all, clear all, and all category tiles',
      (tester) async {
        var selectAllCalled = false;
        var clearAllCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DoctorSummaryCategorySection(
                  combinedSummary: testSummaryModel,
                  selectedCategories: {
                    DoctorSummaryCategory.medications,
                    DoctorSummaryCategory.consultations,
                  },
                  deselectedIds: const {},
                  onSelectAll: () => selectAllCalled = true,
                  onClearAll: () => clearAllCalled = true,
                  onToggleCategory: (_, _, _) {},
                  onToggleItem: (_, _, _) {},
                ),
              ),
            ),
          ),
        );

        expect(find.text('CUSTOMIZE CONTENT'), findsOneWidget);
        expect(find.text('Select All'), findsOneWidget);
        expect(find.text('Clear All'), findsOneWidget);

        await tester.tap(find.text('Select All'));
        expect(selectAllCalled, isTrue);

        await tester.tap(find.text('Clear All'));
        expect(clearAllCalled, isTrue);

        // Verify categories rendered
        expect(find.text('Medications (2)'), findsOneWidget);
        expect(find.text('Consultations (1)'), findsOneWidget);
        expect(find.text('Vitals (0)'), findsOneWidget);
        expect(find.text('Reports (0)'), findsOneWidget);
      },
    );
  });
}
