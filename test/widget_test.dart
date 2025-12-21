// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:travelalarm/main.dart';

void main() {
  testWidgets('App renders TravelAlarm home', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // AppBar title
    expect(find.text('TravelAlarm'), findsOneWidget);
    // Destination map picker
    expect(find.text('Pick destination on map'), findsOneWidget);
    // Start button
    expect(find.text('Start'), findsOneWidget);
  });
}
