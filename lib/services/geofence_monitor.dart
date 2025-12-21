import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/route_service.dart';
import '../utils/distance.dart';

class GeofenceMonitor {
  GeofenceMonitor({
    required this.destLat,
    required this.destLng,
    required this.radiusMeters,
  });

  double destLat;
  double destLng;
  double radiusMeters;

  StreamSubscription<Position>? _sub;
  bool _entered = false;

  bool _routing = false;
  DateTime? _lastRouteFetch;
  ll.LatLng? _lastRouteFrom;

  /// Remaining distance to destination.
  ///
  /// When possible this is the *driving route distance* (OSRM). If routing
  /// fails it falls back to straight-line (Haversine) distance.
  final ValueNotifier<double?> currentDistanceMeters = ValueNotifier<double?>(
    null,
  );

  /// Most recent polyline points for the driving route.
  final ValueNotifier<List<ll.LatLng>> routePoints =
      ValueNotifier<List<ll.LatLng>>(const []);

  /// Latest known user position.
  final ValueNotifier<ll.LatLng?> currentPosition = ValueNotifier<ll.LatLng?>(
    null,
  );

  final ValueNotifier<bool> monitoring = ValueNotifier<bool>(false);

  Future<LocationPermission> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // We can't enable it programmatically; caller should prompt user to enable GPS.
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  Future<bool> start() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Location services disabled; cannot start monitoring.');
      }
      return false;
    }

    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Location permission denied; cannot start monitoring.');
      }
      return false;
    }
    await NotificationService.instance.init();
    monitoring.value = true;
    _entered = false;
    routePoints.value = const [];
    currentDistanceMeters.value = null;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // meters between updates
    );
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final here = ll.LatLng(pos.latitude, pos.longitude);
        currentPosition.value = here;

        final dist = haversineDistanceMeters(
          pos.latitude,
          pos.longitude,
          destLat,
          destLng,
        );
        // Always set a fallback value; routing may update it later.
        currentDistanceMeters.value ??= dist;

        // Refresh route distance/geometry occasionally (avoid spamming OSRM).
        unawaited(_maybeUpdateRoute(here, fallbackCrowDistanceMeters: dist));

        final remaining = currentDistanceMeters.value ?? dist;
        final inside = remaining <= radiusMeters;
        if (inside && !_entered) {
          _entered = true;
          NotificationService.instance.showProximityAlert(
            title: 'Approaching destination',
            body:
                'You are ${(remaining).toStringAsFixed(0)} m from your destination.',
          );
          // Start audible alarm
          AlarmService.instance.startAlarm();
        }
        if (!inside && _entered) {
          // Reset flag if user exits the radius; allows re-notify on re-entry.
          _entered = false;
          AlarmService.instance.stopAlarm();
        }
      },
      onError: (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('Position stream error: $e');
        }
      },
      cancelOnError: false,
    );

    return true;
  }

  Future<void> _maybeUpdateRoute(
    ll.LatLng from, {
    required double fallbackCrowDistanceMeters,
  }) async {
    if (_routing) return;
    if (!monitoring.value) return;

    final now = DateTime.now();
    final last = _lastRouteFetch;
    if (last != null && now.difference(last).inSeconds < 15) return;

    final lastFrom = _lastRouteFrom;
    if (lastFrom != null) {
      final moved = haversineDistanceMeters(
        lastFrom.latitude,
        lastFrom.longitude,
        from.latitude,
        from.longitude,
      );
      if (moved < 30) return;
    }

    _routing = true;
    _lastRouteFetch = now;
    _lastRouteFrom = from;
    try {
      final result = await RouteService.fetchDrivingRoute(
        from: from,
        to: ll.LatLng(destLat, destLng),
      );
      routePoints.value = result.points;
      currentDistanceMeters.value =
          result.distanceMeters > 0
              ? result.distanceMeters
              : fallbackCrowDistanceMeters;
    } catch (_) {
      // Keep using fallback crow distance.
      currentDistanceMeters.value = fallbackCrowDistanceMeters;
      routePoints.value = const [];
    } finally {
      _routing = false;
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    monitoring.value = false;
    // Ensure alarm stops when monitoring stops
    await AlarmService.instance.stopAlarm();
  }

  void dispose() {
    _sub?.cancel();
    // Ensure we don't leave a looping alarm playing.
    unawaited(AlarmService.instance.stopAlarm());
    currentDistanceMeters.dispose();
    routePoints.dispose();
    currentPosition.dispose();
    monitoring.dispose();
  }
}
