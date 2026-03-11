import 'package:flutter_test/flutter_test.dart';

import 'package:travelalarm/main.dart';

void main() {
  testWidgets('App renders TravelAlarm home', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('TravelAlarm'), findsOneWidget);
    expect(find.text('Quick access'), findsOneWidget);
    expect(find.text('Destinations'), findsAtLeastNWidgets(1));
    expect(find.text('Alert'), findsOneWidget);
    expect(find.text('Monitor'), findsOneWidget);
  });
}
