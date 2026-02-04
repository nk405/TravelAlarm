import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/destination.dart';

class DestinationStore {
  DestinationStore._();

  static final DestinationStore instance = DestinationStore._();

  static const String _destinationsKey = 'destinations';
  static const String _activeIdKey = 'active_destination_id';

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

  Future<void> saveDestinations(List<Destination> destinations) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(destinations.map((d) => d.toJson()).toList());
    await prefs.setString(_destinationsKey, payload);
  }

  Future<void> saveActiveDestinationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeIdKey);
    } else {
      await prefs.setString(_activeIdKey, id);
    }
  }
}
