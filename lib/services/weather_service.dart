import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum WeatherDataSource { network, cache }

class DestinationWeather {
  const DestinationWeather({
    required this.temperatureC,
    required this.humidityPercent,
    required this.weatherCode,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.isDay,
    required this.fetchedAt,
    required this.dataSource,
  });

  final double temperatureC;
  final double humidityPercent;
  final int weatherCode;
  final double windSpeedKmh;
  final double precipitationMm;
  final bool isDay;
  final DateTime fetchedAt;
  final WeatherDataSource dataSource;

  String get conditionLabel {
    if (_clearCodes.contains(weatherCode)) return 'Clear';
    if (_cloudyCodes.contains(weatherCode)) return 'Cloudy';
    if (_fogCodes.contains(weatherCode)) return 'Foggy';
    if (_rainCodes.contains(weatherCode)) return 'Rainy';
    if (_snowCodes.contains(weatherCode)) return 'Snowy';
    if (_thunderCodes.contains(weatherCode)) return 'Thunderstorm';
    return 'Mixed conditions';
  }

  String get summary {
    final roundedTemp = temperatureC.toStringAsFixed(1);
    final roundedWind = windSpeedKmh.toStringAsFixed(0);
    return '$conditionLabel, $roundedTemp C, wind $roundedWind km/h';
  }

  List<String> buildSuggestions() {
    final suggestions = <String>[];

    if (_rainCodes.contains(weatherCode) || precipitationMm >= 0.5) {
      suggestions.add('Carry an umbrella or light rain jacket.');
    }

    if (_snowCodes.contains(weatherCode)) {
      suggestions.add(
        'Wear insulated footwear and prepare for slippery roads.',
      );
    }

    if (_thunderCodes.contains(weatherCode)) {
      suggestions.add('Avoid exposed outdoor areas until the storm passes.');
    }

    if (temperatureC >= 32) {
      suggestions.add(
        'Pack water and plan indoor breaks to avoid heat stress.',
      );
    } else if (temperatureC <= 10) {
      suggestions.add('Bring a warm layer for chilly conditions.');
    }

    if (windSpeedKmh >= 30) {
      suggestions.add('Expect strong wind and secure loose items.');
    }

    if (suggestions.isEmpty) {
      suggestions.add('Weather looks comfortable for regular travel plans.');
    }

    return suggestions;
  }

  static const Set<int> _clearCodes = <int>{0, 1};
  static const Set<int> _cloudyCodes = <int>{2, 3};
  static const Set<int> _fogCodes = <int>{45, 48};
  static const Set<int> _rainCodes = <int>{
    51,
    53,
    55,
    56,
    57,
    61,
    63,
    65,
    66,
    67,
    80,
    81,
    82,
  };
  static const Set<int> _snowCodes = <int>{71, 73, 75, 77, 85, 86};
  static const Set<int> _thunderCodes = <int>{95, 96, 99};
}

class WeatherService {
  WeatherService._();

  static const String _cacheKey = 'destination_weather_cache_v1';
  static const int _maxCacheEntries = 50;
  static const Duration _freshCacheDuration = Duration(minutes: 30);

  static Future<DestinationWeather> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final weather = await _fetchFromNetwork(
        latitude: latitude,
        longitude: longitude,
      );
      await _saveToCache(
        latitude: latitude,
        longitude: longitude,
        weather: weather,
      );
      return weather;
    } catch (_) {
      final cached = await _loadFromCache(
        latitude: latitude,
        longitude: longitude,
        maxAge: const Duration(hours: 6),
      );
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<DestinationWeather?> loadFreshCachedWeather({
    required double latitude,
    required double longitude,
  }) {
    return _loadFromCache(
      latitude: latitude,
      longitude: longitude,
      maxAge: _freshCacheDuration,
    );
  }

  static Future<DestinationWeather> _fetchFromNetwork({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'current':
          'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,precipitation,is_day',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    final response = await http.get(
      uri,
      headers: const {
        'User-Agent': 'TravelAlarm/1.0 (Flutter; weather lookup)',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Unexpected weather response');
    }

    final current = decoded['current'];
    if (current is! Map) {
      throw Exception('Missing current weather data');
    }

    return DestinationWeather(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      humidityPercent:
          (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? -1,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      precipitationMm: (current['precipitation'] as num?)?.toDouble() ?? 0,
      isDay: ((current['is_day'] as num?)?.toInt() ?? 1) == 1,
      fetchedAt: DateTime.now().toUtc(),
      dataSource: WeatherDataSource.network,
    );
  }

  static Future<void> _saveToCache({
    required double latitude,
    required double longitude,
    required DestinationWeather weather,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readCacheEntries(prefs);
    final key = _buildCacheKey(latitude: latitude, longitude: longitude);

    entries.removeWhere((entry) => entry['key'] == key);
    entries.insert(0, {
      'key': key,
      'createdAt': weather.fetchedAt.toIso8601String(),
      'temperatureC': weather.temperatureC,
      'humidityPercent': weather.humidityPercent,
      'weatherCode': weather.weatherCode,
      'windSpeedKmh': weather.windSpeedKmh,
      'precipitationMm': weather.precipitationMm,
      'isDay': weather.isDay,
    });

    if (entries.length > _maxCacheEntries) {
      entries.removeRange(_maxCacheEntries, entries.length);
    }

    await prefs.setString(_cacheKey, jsonEncode(entries));
  }

  static Future<DestinationWeather?> _loadFromCache({
    required double latitude,
    required double longitude,
    required Duration maxAge,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _readCacheEntries(prefs);
    final key = _buildCacheKey(latitude: latitude, longitude: longitude);

    for (final entry in entries) {
      if (entry['key'] != key) continue;

      final rawCreatedAt = entry['createdAt']?.toString();
      final createdAt = DateTime.tryParse(rawCreatedAt ?? '');
      if (createdAt == null) continue;

      final age = DateTime.now().toUtc().difference(createdAt.toUtc());
      if (age > maxAge) continue;

      return DestinationWeather(
        temperatureC: (entry['temperatureC'] as num?)?.toDouble() ?? 0,
        humidityPercent: (entry['humidityPercent'] as num?)?.toDouble() ?? 0,
        weatherCode: (entry['weatherCode'] as num?)?.toInt() ?? -1,
        windSpeedKmh: (entry['windSpeedKmh'] as num?)?.toDouble() ?? 0,
        precipitationMm: (entry['precipitationMm'] as num?)?.toDouble() ?? 0,
        isDay: entry['isDay'] == true,
        fetchedAt: createdAt.toUtc(),
        dataSource: WeatherDataSource.cache,
      );
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> _readCacheEntries(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_cacheKey);
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
    required double latitude,
    required double longitude,
  }) {
    return '${_roundCoord(latitude)},${_roundCoord(longitude)}';
  }

  static double _roundCoord(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
