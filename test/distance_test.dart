import 'package:flutter_test/flutter_test.dart';
import 'package:travelalarm/utils/adaptive_alert_distance.dart';
import 'package:travelalarm/utils/distance.dart';

void main() {
  test('Zero distance when coordinates are identical', () {
    final d = haversineDistanceMeters(0, 0, 0, 0);
    expect(d, closeTo(0, 1e-6));
  });

  test('Rough known distance between two points', () {
    final d = haversineDistanceMeters(0, 0, 0, 0.01);
    expect(d, closeTo(1112, 20));
  });

  test('Adaptive alert radius grows with speed', () {
    final walking = computeAdaptiveAlertRadius(
      baseRadiusMeters: 100,
      speedMetersPerSecond: 1.4,
    );
    final driving = computeAdaptiveAlertRadius(
      baseRadiusMeters: 100,
      speedMetersPerSecond: 20,
    );

    expect(walking, greaterThan(100));
    expect(driving, greaterThan(walking));
  });

  test('Adaptive alert radius respects max clamp', () {
    final radius = computeAdaptiveAlertRadius(
      baseRadiusMeters: 1200,
      speedMetersPerSecond: 50,
      maxRadiusMeters: 1300,
    );

    expect(radius, 1300);
  });
}
