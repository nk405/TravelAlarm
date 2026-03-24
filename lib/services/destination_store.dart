import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm_sync_snapshot.dart';
import '../models/destination.dart';

class DestinationStore {
  DestinationStore._();

  static final DestinationStore instance = DestinationStore._();

  static const String _destinationsKey = 'destinations';
  static const String _activeIdKey = 'active_destination_id';
  static const String _adaptiveRadiusEnabledKey = 'adaptive_radius_enabled';
  static const String _radiusMetersKey = 'radius_meters';
  static const String _updatedAtMillisKey = 'alarms_local_updated_at_millis';

  Future<List<Destination>> loadDestinations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_destinationsKey);
      if (raw == null || raw.isEmpty) return <Destination>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Destination>[];
      return decoded
          .whereType<Map>()
          .map((e) => Destination.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <Destination>[];
    }
  }

  Future<String?> loadActiveDestinationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeIdKey);
  }

  Future<bool> loadAdaptiveRadiusEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_adaptiveRadiusEnabledKey) ?? true;
  }

  Future<double> loadRadiusMeters() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getDouble(_radiusMetersKey);
    return (value ?? 300).clamp(50, 2000).toDouble();
  }

  Future<int> loadLastUpdatedAtMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_updatedAtMillisKey) ?? 0;
  }

  Future<void> saveDestinations(List<Destination> destinations) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(destinations.map((d) => d.toJson()).toList());
    await prefs.setString(_destinationsKey, payload);
    await _touchUpdatedAt(prefs);
  }

  Future<void> saveActiveDestinationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeIdKey);
    } else {
      await prefs.setString(_activeIdKey, id);
    }
    await _touchUpdatedAt(prefs);
  }

  Future<void> saveAdaptiveRadiusEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adaptiveRadiusEnabledKey, enabled);
    await _touchUpdatedAt(prefs);
  }

  Future<void> saveRadiusMeters(double value) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = value.clamp(50, 2000).toDouble();
    await prefs.setDouble(_radiusMetersKey, clamped);
    await _touchUpdatedAt(prefs);
  }

  Future<AlarmSyncSnapshot> loadSnapshot() async {
    final destinations = await loadDestinations();
    final activeDestinationId = await loadActiveDestinationId();
    final adaptiveRadiusEnabled = await loadAdaptiveRadiusEnabled();
    final radiusMeters = await loadRadiusMeters();
    final lastUpdatedAt = await loadLastUpdatedAtMillis();

    return AlarmSyncSnapshot(
      destinations: destinations,
      activeDestinationId:
          destinations.any((d) => d.id == activeDestinationId)
              ? activeDestinationId
              : null,
      adaptiveRadiusEnabled: adaptiveRadiusEnabled,
      radiusMeters: radiusMeters,
      localUpdatedAtMillis:
          lastUpdatedAt > 0
              ? lastUpdatedAt
              : DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> saveSnapshot(AlarmSyncSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      snapshot.destinations.map((d) => d.toJson()).toList(),
    );
    await prefs.setString(_destinationsKey, payload);
    await prefs.setBool(
      _adaptiveRadiusEnabledKey,
      snapshot.adaptiveRadiusEnabled,
    );
    await prefs.setDouble(
      _radiusMetersKey,
      snapshot.radiusMeters.clamp(50, 2000).toDouble(),
    );

    final validActiveId =
        snapshot.destinations.any((d) => d.id == snapshot.activeDestinationId)
            ? snapshot.activeDestinationId
            : (snapshot.destinations.isNotEmpty
                ? snapshot.destinations.first.id
                : null);

    if (validActiveId == null) {
      await prefs.remove(_activeIdKey);
    } else {
      await prefs.setString(_activeIdKey, validActiveId);
    }

    await prefs.setInt(_updatedAtMillisKey, snapshot.localUpdatedAtMillis);
  }

  Future<void> _touchUpdatedAt(SharedPreferences prefs) async {
    await prefs.setInt(
      _updatedAtMillisKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
