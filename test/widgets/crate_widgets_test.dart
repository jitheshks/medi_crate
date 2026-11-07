import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medi_crate/shared/widgets/feedback/pulsing_vault_logo.dart';
import 'package:medi_crate/shared/widgets/feedback/vault_badge.dart';

void main() {
  group('MediCrate Brand Widgets', () {
    testWidgets('CrateBadge displays label with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CrateBadge(label: 'Protected'),
            ),
          ),
        ),
      );

      expect(find.text('Protected'), findsOneWidget);
      expect(find.byType(CrateBadge), findsOneWidget);
    });

    testWidgets('VaultBadge alias works identically for backwards compatibility', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: VaultBadge(label: 'Encrypted'),
            ),
          ),
        ),
      );

      expect(find.text('Encrypted'), findsOneWidget);
    });

    testWidgets('PulsingCrateLogo renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PulsingCrateLogo(),
            ),
          ),
        ),
      );

      expect(find.byType(PulsingCrateLogo), findsOneWidget);
    });
  });
}
