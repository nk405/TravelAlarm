import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'weather_service.dart';

class WeatherAiSuggestionResult {
  const WeatherAiSuggestionResult({
    required this.predictedLabel,
    required this.confidence,
    required this.suggestions,
  });

  final String predictedLabel;
  final double confidence;
  final List<String> suggestions;
}

class WeatherAiService {
  WeatherAiService._();

  static final WeatherAiService instance = WeatherAiService._();

  static const String _configAssetPath = 'model/weather_model_config.json';

  Interpreter? _interpreter;
  bool _initAttempted = false;

  late List<String> _labels;
  late List<double> _means;
  late List<double> _stds;
  late double _threshold;

  Map<String, List<String>> _suggestionsByLabel = const {};

  bool get isReady => _interpreter != null;

  Future<void> _initIfNeeded() async {
    if (_initAttempted) return;
    _initAttempted = true;

    try {
      final configRaw = await rootBundle.loadString(_configAssetPath);
      final config = jsonDecode(configRaw);
      if (config is! Map) return;

      final configMap = Map<String, dynamic>.from(config);
      final labels = configMap['labels'];
      final means = configMap['featureMeans'];
      final stds = configMap['featureStds'];

      if (labels is! List || means is! List || stds is! List) return;
      if (labels.length != 4 || means.length != 4 || stds.length != 4) return;

      _labels = labels.map((item) => item.toString()).toList();
      _means = means.map((item) => (item as num).toDouble()).toList();
      _stds =
          stds.map((item) {
            final value = (item as num).toDouble();
            return value == 0 ? 1.0 : value;
          }).toList();

      _threshold =
          (configMap['confidenceThreshold'] as num?)?.toDouble() ?? 0.45;

      final rawSuggestions = configMap['labelSuggestions'];
      if (rawSuggestions is Map) {
        _suggestionsByLabel = rawSuggestions.map(
          (key, value) => MapEntry(
            key.toString(),
            (value is List)
                ? value.map((item) => item.toString()).toList()
                : const <String>[],
          ),
        );
      }

      final modelPath =
          configMap['modelAssetPath']?.toString() ??
          'model/weather_model.tflite';
      _interpreter = await Interpreter.fromAsset(modelPath);
    } catch (_) {
      _interpreter = null;
    }
  }

  Future<WeatherAiSuggestionResult?> predictSuggestions(
    DestinationWeather weather,
  ) async {
    await _initIfNeeded();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    final precipitationPercentProxy =
        (weather.precipitationMm * 10).clamp(0, 100).toDouble();

    final rawFeatures = <double>[
      weather.temperatureC,
      weather.humidityPercent,
      weather.windSpeedKmh,
      precipitationPercentProxy,
    ];

    final scaledFeatures = <double>[];
    for (var i = 0; i < rawFeatures.length; i++) {
      final standardized = (rawFeatures[i] - _means[i]) / _stds[i];
      scaledFeatures.add(standardized);
    }

    final input = [scaledFeatures];
    final output = [List<double>.filled(_labels.length, 0)];
    interpreter.run(input, output);

    final probabilities = output.first;
    if (probabilities.isEmpty) return null;

    var bestIndex = 0;
    var bestProbability = probabilities.first;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > bestProbability) {
        bestProbability = probabilities[i];
        bestIndex = i;
      }
    }

    if (bestIndex >= _labels.length || bestProbability < _threshold) {
      return null;
    }

    final predictedLabel = _labels[bestIndex];
    final configuredSuggestions =
        _suggestionsByLabel[predictedLabel] ??
        _defaultSuggestionsForLabel(predictedLabel);

    if (configuredSuggestions.isEmpty) {
      return null;
    }

    return WeatherAiSuggestionResult(
      predictedLabel: predictedLabel,
      confidence: bestProbability,
      suggestions: configuredSuggestions,
    );
  }

  List<String> _defaultSuggestionsForLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('rain')) {
      return const [
        'Carry an umbrella and protect electronics from moisture.',
        'Leave earlier in case of wet-road traffic delays.',
      ];
    }

    if (normalized.contains('snow')) {
      return const [
        'Wear warm layers and non-slip footwear.',
        'Plan extra travel time due to reduced visibility and slower traffic.',
      ];
    }

    if (normalized.contains('sun') || normalized.contains('clear')) {
      return const [
        'Carry water to stay hydrated while traveling.',
        'Use sunglasses or sunscreen for longer outdoor exposure.',
      ];
    }

    if (normalized.contains('cloud')) {
      return const [
        'Conditions look mild; regular travel preparation should be enough.',
      ];
    }

    return const [];
  }
}
