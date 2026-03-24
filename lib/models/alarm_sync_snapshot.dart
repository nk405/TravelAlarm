import 'destination.dart';

class AlarmSyncSnapshot {
  AlarmSyncSnapshot({
    required this.destinations,
    required this.activeDestinationId,
    required this.adaptiveRadiusEnabled,
    required this.radiusMeters,
    required this.localUpdatedAtMillis,
  });

  final List<Destination> destinations;
  final String? activeDestinationId;
  final bool adaptiveRadiusEnabled;
  final double radiusMeters;
  final int localUpdatedAtMillis;

  Map<String, dynamic> toCloudJson() {
    return {
      'version': 1,
      'payload': {
        'destinations': destinations.map((d) => d.toJson()).toList(),
        'activeDestinationId': activeDestinationId,
        'adaptiveRadiusEnabled': adaptiveRadiusEnabled,
        'radiusMeters': radiusMeters,
      },
      'localUpdatedAtMillis': localUpdatedAtMillis,
    };
  }

  static AlarmSyncSnapshot fromCloudJson(Map<String, dynamic> json) {
    final payload = Map<String, dynamic>.from(
      (json['payload'] as Map?) ?? const <String, dynamic>{},
    );

    final rawDestinations = (payload['destinations'] as List?) ?? const [];
    final destinations =
        rawDestinations
            .whereType<Map>()
            .map((e) => Destination.fromJson(Map<String, dynamic>.from(e)))
            .toList();

    final radius = (payload['radiusMeters'] as num?)?.toDouble() ?? 300;
    final localUpdatedAtMillis =
        (json['localUpdatedAtMillis'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    return AlarmSyncSnapshot(
      destinations: destinations,
      activeDestinationId: payload['activeDestinationId']?.toString(),
      adaptiveRadiusEnabled: payload['adaptiveRadiusEnabled'] as bool? ?? true,
      radiusMeters: radius.clamp(50, 2000).toDouble(),
      localUpdatedAtMillis: localUpdatedAtMillis,
    );
  }

  AlarmSyncSnapshot copyWith({
    List<Destination>? destinations,
    String? activeDestinationId,
    bool clearActiveDestinationId = false,
    bool? adaptiveRadiusEnabled,
    double? radiusMeters,
    int? localUpdatedAtMillis,
  }) {
    return AlarmSyncSnapshot(
      destinations: destinations ?? this.destinations,
      activeDestinationId:
          clearActiveDestinationId
              ? null
              : (activeDestinationId ?? this.activeDestinationId),
      adaptiveRadiusEnabled:
          adaptiveRadiusEnabled ?? this.adaptiveRadiusEnabled,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      localUpdatedAtMillis: localUpdatedAtMillis ?? this.localUpdatedAtMillis,
    );
  }
}
