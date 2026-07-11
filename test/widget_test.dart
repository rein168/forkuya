// Smoke test: the app boots to the profile selection screen.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:typer/globals.dart';
import 'package:typer/main.dart';

void main() {
  testWidgets('App boots to the profile selection screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await initGlobals();

    await tester.pumpWidget(const TyperApp());
    await tester.pumpAndSettle();

    expect(find.text('Select Profile'), findsOneWidget);
    expect(find.text('Create Profile'), findsOneWidget);
  });
}
