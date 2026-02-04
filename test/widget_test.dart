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
