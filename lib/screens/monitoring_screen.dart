import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/destination.dart';
import '../services/geofence_monitor.dart';
import '../widgets/home_components.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({
    super.key,
    required this.activeDestination,
    required this.monitor,
    required this.activeLatLng,
    required this.mapController,
    required this.followUserOnMap,
    required this.mapZoom,
    required this.onMapZoomChanged,
    required this.onToggleFollowUser,
    required this.onStartMonitoring,
    required this.onStopMonitoring,
    required this.formatDistance,
    required this.formatSpeed,
  });

  final Destination? activeDestination;
  final GeofenceMonitor? monitor;
  final ll.LatLng? activeLatLng;
  final MapController mapController;
  final bool followUserOnMap;
  final double mapZoom;
  final ValueChanged<double> onMapZoomChanged;
  final VoidCallback onToggleFollowUser;
  final Future<void> Function() onStartMonitoring;
  final Future<void> Function() onStopMonitoring;
  final String Function(double meters) formatDistance;
  final String Function(double speedMetersPerSecond) formatSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardSection(
            gradient: LinearGradient(
              colors: [colors.tertiaryContainer, colors.surfaceContainerLow],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.near_me_outlined,
                    color: colors.onTertiaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeDestination?.name ?? 'No destination selected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeDestination == null
                            ? 'Select a destination before starting an alert.'
                            : 'Live trip monitoring for your active destination.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CardSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: colors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Alert status', style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                if (monitor == null)
                  StatusRow(label: 'Not running', color: colors.outline)
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: monitor!.monitoring,
                    builder: (context, running, _) {
                      return StatusRow(
                        label: running ? 'Running' : 'Paused',
                        color: running ? colors.primary : colors.outline,
                        pulse: running,
                      );
                    },
                  ),
                const SizedBox(height: 16),
                if (monitor == null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed:
                          activeDestination == null
                              ? null
                              : () => onStartMonitoring(),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start alert'),
                    ),
                  )
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: monitor!.monitoring,
                    builder: (context, running, _) {
                      return SizedBox(
                        width: double.infinity,
                        height: 48,
                        child:
                            running
                                ? OutlinedButton.icon(
                                  onPressed: () => onStopMonitoring(),
                                  icon: const Icon(Icons.stop_rounded),
                                  label: const Text('Stop alert'),
                                )
                                : FilledButton.icon(
                                  onPressed: () => onStartMonitoring(),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Start alert'),
                                ),
                      );
                    },
                  ),
              ],
            ),
          ),
          if (monitor != null) ...[
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: monitor!.monitoring,
              builder: (context, running, _) {
                return ValueListenableBuilder<double?>(
                  valueListenable: monitor!.currentDistanceMeters,
                  builder: (context, distance, __) {
                    return ValueListenableBuilder<double>(
                      valueListenable: monitor!.currentSpeedMetersPerSecond,
                      builder: (context, speed, ___) {
                        return ValueListenableBuilder<double?>(
                          valueListenable: monitor!.currentAccuracyMeters,
                          builder: (context, accuracy, ____) {
                            return ValueListenableBuilder<DateTime?>(
                              valueListenable: monitor!.lastPositionFixAt,
                              builder: (context, lastFix, _____) {
                                final routePoints = monitor!.routePoints.value;
                                final eta = _estimateEta(distance, speed);
                                final gpsQuality = _gpsQualityLabel(accuracy);
                                final confidence = _confidenceScore(
                                  running: running,
                                  distanceMeters: distance,
                                  speedMetersPerSecond: speed,
                                  gpsAccuracyMeters: accuracy,
                                  hasRoute: routePoints.length > 1,
                                );

                                final readiness =
                                    running && activeDestination != null
                                        ? 'Alert active'
                                        : activeDestination == null
                                        ? 'No destination'
                                        : 'Ready to start';

                                return CardSection(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.analytics_outlined,
                                            color: colors.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Trip status',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _StatusPill(
                                            title: 'ETA',
                                            value: eta,
                                            icon: Icons.schedule,
                                          ),
                                          _StatusPill(
                                            title: 'Speed',
                                            value: formatSpeed(speed),
                                            icon: Icons.speed,
                                          ),
                                          _StatusPill(
                                            title: 'GPS quality',
                                            value: gpsQuality,
                                            icon: Icons.gps_fixed,
                                          ),
                                          // _StatusPill(
                                          //   title: 'Confidence',
                                          //   value: '$confidence%',
                                          //   icon: Icons.shield_outlined,
                                          // ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Alarm readiness: $readiness',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                      if (lastFix != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Last GPS fix: ${_formatTime(lastFix)}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            CardSection(
              child: ValueListenableBuilder<double?>(
                valueListenable: monitor!.currentDistanceMeters,
                builder: (context, distance, _) {
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.straighten,
                          color: colors.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Distance remaining',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              distance == null
                                  ? 'Awaiting location...'
                                  : formatDistance(distance),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: monitor!.monitoring,
              builder: (context, running, _) {
                if (!running) {
                  return CardSection(
                    child: Text(
                      'Monitoring is paused. Start the alert to see the live map and route.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return CardSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            color: colors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('Live map', style: theme.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 320,
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: mapController,
                                options: MapOptions(
                                  initialCenter:
                                      activeLatLng ?? const ll.LatLng(0, 0),
                                  initialZoom: mapZoom,
                                  onPositionChanged: (position, hasGesture) {
                                    if (!hasGesture) return;
                                    final zoom = position.zoom;
                                    if (zoom != null) {
                                      onMapZoomChanged(zoom);
                                    }
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.travelalarm.travelalarm',
                                    subdomains: const [],
                                  ),
                                  ValueListenableBuilder<List<ll.LatLng>>(
                                    valueListenable: monitor!.routePoints,
                                    builder: (context, points, _) {
                                      if (points.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: points,
                                            strokeWidth: 5,
                                            color: colors.primary,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  if (activeLatLng != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: activeLatLng!,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.place,
                                            color: Colors.red,
                                            size: 36,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ValueListenableBuilder<ll.LatLng?>(
                                    valueListenable: monitor!.currentPosition,
                                    builder: (context, position, _) {
                                      if (position == null) {
                                        return const SizedBox.shrink();
                                      }

                                      if (followUserOnMap) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              mapController.move(
                                                position,
                                                mapZoom,
                                              );
                                            });
                                      }

                                      return MarkerLayer(
                                        markers: [
                                          Marker(
                                            point: position,
                                            width: 20,
                                            height: 20,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.primary,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 3,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: colors.surface,
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: IconButton(
                                    tooltip:
                                        followUserOnMap
                                            ? 'Following location'
                                            : 'Follow location',
                                    icon: Icon(
                                      followUserOnMap
                                          ? Icons.my_location
                                          : Icons.location_searching,
                                    ),
                                    onPressed: onToggleFollowUser,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

String _estimateEta(double? distanceMeters, double speedMetersPerSecond) {
  if (distanceMeters == null || distanceMeters <= 0) {
    return 'Calculating...';
  }

  final speed = speedMetersPerSecond < 0.8 ? 0.8 : speedMetersPerSecond;
  final etaSeconds = (distanceMeters / speed).round();
  final etaMinutes = (etaSeconds / 60).ceil();

  if (etaMinutes < 1) {
    return '<1 min';
  }

  if (etaMinutes < 60) {
    return '$etaMinutes min';
  }

  final hours = etaMinutes ~/ 60;
  final mins = etaMinutes % 60;
  return '${hours}h ${mins}m';
}

String _gpsQualityLabel(double? accuracyMeters) {
  if (accuracyMeters == null) return 'Waiting';
  if (accuracyMeters <= 12) return 'Excellent';
  if (accuracyMeters <= 25) return 'Good';
  if (accuracyMeters <= 50) return 'Fair';
  return 'Poor';
}

int _confidenceScore({
  required bool running,
  required double? distanceMeters,
  required double speedMetersPerSecond,
  required double? gpsAccuracyMeters,
  required bool hasRoute,
}) {
  if (!running || distanceMeters == null) return 0;

  var score = 35;

  if (hasRoute) {
    score += 20;
  }

  if (speedMetersPerSecond > 1) {
    score += 15;
  }

  final accuracy = gpsAccuracyMeters;
  if (accuracy == null) {
    score += 0;
  } else if (accuracy <= 12) {
    score += 30;
  } else if (accuracy <= 25) {
    score += 22;
  } else if (accuracy <= 50) {
    score += 12;
  } else {
    score += 5;
  }

  if (distanceMeters < 120) {
    score -= 10;
  }

  return score.clamp(0, 99);
}

String _formatTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hours = local.hour.toString().padLeft(2, '0');
  final mins = local.minute.toString().padLeft(2, '0');
  return '$hours:$mins';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text('$title: ', style: theme.textTheme.labelMedium),
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
