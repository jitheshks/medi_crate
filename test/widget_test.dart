import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MediCrate initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('MediCrate'))),
      ),
    );

    expect(find.text('MediCrate'), findsOneWidget);
  });
}
