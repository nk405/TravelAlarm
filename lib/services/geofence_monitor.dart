import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../services/notification_service.dart';
import '../services/alarm_service.dart';
import '../services/route_service.dart';
import '../utils/adaptive_alert_distance.dart';
import '../utils/distance.dart';

class GeofenceMonitor {
  GeofenceMonitor({
    required this.destLat,
    required this.destLng,
    required this.destName,
    required this.radiusMeters,
    this.adaptiveRadiusEnabled = false,
  });

  double destLat;
  double destLng;
  String destName;
  double radiusMeters;
  bool adaptiveRadiusEnabled;

  StreamSubscription<Position>? _sub;
  bool _entered = false;

  bool _routing = false;
  DateTime? _lastRouteFetch;
  ll.LatLng? _lastRouteFrom;

  DateTime? _lastStatusNotificationAt;
  double? _lastStatusMeters;
  double _smoothedSpeedMetersPerSecond = 0;

  final ValueNotifier<double?> currentDistanceMeters = ValueNotifier<double?>(
    null,
  );

  final ValueNotifier<double> currentSpeedMetersPerSecond =
      ValueNotifier<double>(0);

  final ValueNotifier<double> effectiveRadiusMeters = ValueNotifier<double>(0);

  final ValueNotifier<List<ll.LatLng>> routePoints =
      ValueNotifier<List<ll.LatLng>>(const []);

  final ValueNotifier<ll.LatLng?> currentPosition = ValueNotifier<ll.LatLng?>(
    null,
  );

  final ValueNotifier<double?> currentAccuracyMeters = ValueNotifier<double?>(
    null,
  );

  final ValueNotifier<DateTime?> lastPositionFixAt = ValueNotifier<DateTime?>(
    null,
  );

  final ValueNotifier<bool> monitoring = ValueNotifier<bool>(false);

  void setBaseRadius(double value) {
    radiusMeters = value.clamp(50, 2000).toDouble();
    _updateEffectiveRadius();
  }

  void setAdaptiveRadiusEnabled(bool value) {
    adaptiveRadiusEnabled = value;
    _updateEffectiveRadius();
  }

  Future<LocationPermission> ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {}
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
        print('Location services disabled; cannot start monitoring.');
      }
      return false;
    }

    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        print('Location permission denied; cannot start monitoring.');
      }
      return false;
    }
    await NotificationService.instance.init();
    monitoring.value = true;
    _entered = false;
    routePoints.value = const [];
    currentDistanceMeters.value = null;
    currentSpeedMetersPerSecond.value = 0;
    currentAccuracyMeters.value = null;
    lastPositionFixAt.value = null;
    _smoothedSpeedMetersPerSecond = 0;
    _lastStatusNotificationAt = null;
    _lastStatusMeters = null;
    _updateEffectiveRadius();

    unawaited(
      NotificationService.instance.showMonitoringStatus(
        destinationName: destName,
        remainingText: 'Awaiting location...',
      ),
    );

    final settings = _buildLocationSettings();
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final here = ll.LatLng(pos.latitude, pos.longitude);
        currentPosition.value = here;
        currentAccuracyMeters.value =
            pos.accuracy.isFinite
                ? pos.accuracy.clamp(0, 200).toDouble()
                : null;
        lastPositionFixAt.value = pos.timestamp;
        _updateSpeed(pos.speed);

        final dist = haversineDistanceMeters(
          pos.latitude,
          pos.longitude,
          destLat,
          destLng,
        );
        currentDistanceMeters.value ??= dist;

        unawaited(_maybeUpdateRoute(here, fallbackCrowDistanceMeters: dist));

        final remaining = currentDistanceMeters.value ?? dist;
        unawaited(_maybeUpdateMonitoringStatus(remaining));
        final inside = remaining <= effectiveRadiusMeters.value;
        if (inside && !_entered) {
          _entered = true;
          NotificationService.instance.showProximityAlert(
            title: 'Approaching destination',
            body:
                'You are ${_formatDistance(remaining)} from your destination.',
          );
          AlarmService.instance.startAlarm();
        }
        if (!inside && _entered) {
          _entered = false;
          AlarmService.instance.stopAlarm();
        }
      },
      onError: (e) {
        if (kDebugMode) {
          print('Position stream error: $e');
        }
      },
      cancelOnError: false,
    );

    return true;
  }

  void _updateSpeed(double speedMetersPerSecond) {
    final rawSpeed =
        speedMetersPerSecond.isFinite
            ? speedMetersPerSecond.clamp(0, 60).toDouble()
            : 0.0;
    _smoothedSpeedMetersPerSecond =
        (_smoothedSpeedMetersPerSecond * 0.7) + (rawSpeed * 0.3);
    currentSpeedMetersPerSecond.value = _smoothedSpeedMetersPerSecond;
    _updateEffectiveRadius();
  }

  void _updateEffectiveRadius() {
    effectiveRadiusMeters.value =
        adaptiveRadiusEnabled
            ? computeAdaptiveAlertRadius(
              baseRadiusMeters: radiusMeters,
              speedMetersPerSecond: _smoothedSpeedMetersPerSecond,
            )
            : radiusMeters;
  }

  Future<void> _maybeUpdateMonitoringStatus(double remainingMeters) async {
    if (!monitoring.value) return;

    final now = DateTime.now();
    final lastAt = _lastStatusNotificationAt;
    final lastMeters = _lastStatusMeters;

    if (lastAt != null && now.difference(lastAt).inSeconds < 20) {
      if (lastMeters != null && (lastMeters - remainingMeters).abs() < 50) {
        return;
      }
    }

    _lastStatusNotificationAt = now;
    _lastStatusMeters = remainingMeters;

    await NotificationService.instance.showMonitoringStatus(
      destinationName: destName,
      remainingText: 'Remaining distance: ${_formatDistance(remainingMeters)}',
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  Future<void> _maybeUpdateRoute(
    ll.LatLng from, {
    required double fallbackCrowDistanceMeters,
  }) async {
    if (_routing) return;
    if (!monitoring.value) return;

    final now = DateTime.now();
    final last = _lastRouteFetch;
    if (last != null && now.difference(last).inSeconds < 30) return;

    final lastFrom = _lastRouteFrom;
    if (lastFrom != null) {
      final moved = haversineDistanceMeters(
        lastFrom.latitude,
        lastFrom.longitude,
        from.latitude,
        from.longitude,
      );
      if (moved < 50) return;
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
      final updated = currentDistanceMeters.value;
      if (updated != null) {
        unawaited(_maybeUpdateMonitoringStatus(updated));
      }
    } catch (_) {
      currentDistanceMeters.value = fallbackCrowDistanceMeters;
      routePoints.value = const [];
      final updated = currentDistanceMeters.value;
      if (updated != null) {
        unawaited(_maybeUpdateMonitoringStatus(updated));
      }
    } finally {
      _routing = false;
    }
  }

  LocationSettings _buildLocationSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TravelAlarm running',
          notificationText: 'Monitoring destination in background',
          enableWakeLock: true,
          enableWifiLock: false,
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
        ),
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    monitoring.value = false;
    currentSpeedMetersPerSecond.value = 0;
    currentAccuracyMeters.value = null;
    lastPositionFixAt.value = null;
    _smoothedSpeedMetersPerSecond = 0;
    _updateEffectiveRadius();
    await AlarmService.instance.stopAlarm();
    await NotificationService.instance.cancelMonitoringStatus();
  }

  void dispose() {
    _sub?.cancel();
    unawaited(AlarmService.instance.stopAlarm());
    unawaited(NotificationService.instance.cancelMonitoringStatus());
    currentDistanceMeters.dispose();
    currentSpeedMetersPerSecond.dispose();
    effectiveRadiusMeters.dispose();
    routePoints.dispose();
    currentPosition.dispose();
    currentAccuracyMeters.dispose();
    lastPositionFixAt.dispose();
    monitoring.dispose();
  }
}
