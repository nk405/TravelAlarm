import 'package:flutter_test/flutter_test.dart';
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
}
