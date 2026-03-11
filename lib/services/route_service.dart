import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';

enum RouteDataSource { network, cache }

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    this.dataSource = RouteDataSource.network,
  });

  final List<ll.LatLng> points;
  final double distanceMeters;
  final RouteDataSource dataSource;
}

class RouteService {
  RouteService._();

  static const String _routeCacheKey = 'cached_routes_v1';
  static const int _maxCachedRoutes = 30;

  static Future<RouteResult> fetchDrivingRoute({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    try {
      final result = await _fetchDrivingRouteFromNetwork(from: from, to: to);
      await _saveCachedRoute(from: from, to: to, result: result);
      return result;
    } catch (_) {
      final cached = await _loadCachedRoute(from: from, to: to);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  static Future<RouteResult> _fetchDrivingRouteFromNetwork({
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

  static Future<void> _saveCachedRoute({
    required ll.LatLng from,
    required ll.LatLng to,
    required RouteResult result,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _readCacheEntries(prefs);
    final key = _buildCacheKey(from: from, to: to);

    cache.removeWhere((entry) => entry['key'] == key);
    cache.insert(0, {
      'key': key,
      'createdAt': DateTime.now().toIso8601String(),
      'distanceMeters': result.distanceMeters,
      'points':
          result.points
              .map((point) => <double>[point.latitude, point.longitude])
              .toList(),
    });

    if (cache.length > _maxCachedRoutes) {
      cache.removeRange(_maxCachedRoutes, cache.length);
    }

    await prefs.setString(_routeCacheKey, jsonEncode(cache));
  }

  static Future<RouteResult?> _loadCachedRoute({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = await _readCacheEntries(prefs);
    final key = _buildCacheKey(from: from, to: to);

    for (final entry in cache) {
      if (entry['key'] != key) continue;

      final distance = (entry['distanceMeters'] as num?)?.toDouble() ?? 0;
      final rawPoints = entry['points'];
      final points = <ll.LatLng>[];
      if (rawPoints is List) {
        for (final rawPoint in rawPoints) {
          if (rawPoint is! List || rawPoint.length < 2) continue;
          final lat = (rawPoint[0] as num?)?.toDouble();
          final lon = (rawPoint[1] as num?)?.toDouble();
          if (lat == null || lon == null) continue;
          points.add(ll.LatLng(lat, lon));
        }
      }

      return RouteResult(
        points: points,
        distanceMeters: distance,
        dataSource: RouteDataSource.cache,
      );
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> _readCacheEntries(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_routeCacheKey);
    if (raw == null || raw.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return decoded
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static String _buildCacheKey({
    required ll.LatLng from,
    required ll.LatLng to,
  }) {
    return '${_roundCoord(from.latitude)},${_roundCoord(from.longitude)}>'
        '${_roundCoord(to.latitude)},${_roundCoord(to.longitude)}';
  }

  static double _roundCoord(double value) {
    return (value * 1000).roundToDouble() / 1000;
  }
}
