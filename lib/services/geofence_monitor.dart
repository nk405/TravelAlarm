import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/notification_service.dart';
import '../services/alarm_service.dart';
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

  final ValueNotifier<double?> currentDistanceMeters = ValueNotifier<double?>(
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

  Future<void> start() async {
    final permission = await ensurePermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Location permission denied; cannot start monitoring.');
      }
      return;
    }
    await NotificationService.instance.init();
    monitoring.value = true;
    _entered = false;

    final settings = const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // meters between updates
    );
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        final dist = haversineDistanceMeters(
          pos.latitude,
          pos.longitude,
          destLat,
          destLng,
        );
        currentDistanceMeters.value = dist;
        final inside = dist <= radiusMeters;
        if (inside && !_entered) {
          _entered = true;
          NotificationService.instance.showProximityAlert(
            title: 'Approaching destination',
            body:
                'You are ${(dist).toStringAsFixed(0)} m from your destination.',
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
  }

  Future<void> stop() async {
    await _sub?.cancel();
    monitoring.value = false;
    // Ensure alarm stops when monitoring stops
    await AlarmService.instance.stopAlarm();
  }

  void dispose() {
    _sub?.cancel();
    currentDistanceMeters.dispose();
    monitoring.dispose();
  }
}
