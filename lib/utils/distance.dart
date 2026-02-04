import 'dart:math' as math;

double haversineDistanceMeters(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadius = 6371000.0; // meters
  final dLat = _deg2rad(endLat - startLat);
  final dLon = _deg2rad(endLng - startLng);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(startLat)) *
          math.cos(_deg2rad(endLat)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadius * c;
}

double _deg2rad(double deg) => deg * (math.pi / 180.0);
