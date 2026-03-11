import 'package:flutter_test/flutter_test.dart';

import 'package:travelalarm/main.dart';

void main() {
  testWidgets('App renders TravelAlarm home', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 200));

    // AppBar title
    expect(find.text('TravelAlarm'), findsOneWidget);
    expect(find.text('Alert distance'), findsOneWidget);
    expect(find.text('Start alert'), findsOneWidget);
    expect(find.text('Add destination'), findsOneWidget);
  });
}
