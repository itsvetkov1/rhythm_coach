// Basic widget test for AI Rhythm Coach
//
// Note: Full testing requires physical device for audio testing.
// These are basic smoke tests to verify the app initializes correctly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ai_rhythm_coach/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App initializes and shows practice screen', (WidgetTester tester) async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame
    await tester.pumpWidget(MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Verify that the practice screen is shown
    expect(find.text('AI Rhythm Coach'), findsOneWidget);
    expect(find.text('Ready to Practice'), findsOneWidget);
    expect(find.text('Start Practice'), findsOneWidget);
  });

  testWidgets('BPM controls work correctly', (WidgetTester tester) async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app
    await tester.pumpWidget(MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Verify default BPM is 120
    expect(find.text('120'), findsOneWidget);

    // Tap the increase button
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pumpAndSettle();

    // Verify BPM increased to 125
    expect(find.text('125'), findsOneWidget);

    // Tap the decrease button
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();

    // Verify BPM decreased back to 120
    expect(find.text('120'), findsOneWidget);
  });
}
