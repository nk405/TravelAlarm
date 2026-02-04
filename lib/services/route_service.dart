import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

class RouteResult {
  const RouteResult({required this.points, required this.distanceMeters});

  final List<ll.LatLng> points;
  final double distanceMeters;
}

class RouteService {
  RouteService._();

  static Future<RouteResult> fetchDrivingRoute({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    final path =
        '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.https('router.project-osrm.org', path, {
      'overview': 'full',
      'geometries': 'geojson',
    });

    final resp = await http.get(
      uri,
      headers: const {
        'User-Agent': 'TravelAlarm/1.0 (Flutter; contact: local)',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw Exception('Unexpected response');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      return const RouteResult(points: <ll.LatLng>[], distanceMeters: 0);
    }

    final first = routes.first;
    if (first is! Map) {
      throw Exception('Unexpected route format');
    }

    final distance = (first['distance'] as num?)?.toDouble() ?? 0;

    final geometry = first['geometry'];
    if (geometry is! Map) {
      return RouteResult(points: const <ll.LatLng>[], distanceMeters: distance);
    }
    final coords = geometry['coordinates'];
    if (coords is! List) {
      return RouteResult(points: const <ll.LatLng>[], distanceMeters: distance);
    }

    final points = <ll.LatLng>[];
    for (final c in coords) {
      if (c is! List || c.length < 2) continue;
      final lon = (c[0] as num?)?.toDouble();
      final lat = (c[1] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      points.add(ll.LatLng(lat, lon));
    }

    return RouteResult(points: points, distanceMeters: distance);
  }
}
