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
                    Icon(Icons.shield_outlined, color: colors.primary, size: 20),
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
                      onPressed: activeDestination == null
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
                        child: running
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
                          Icon(Icons.map_outlined, color: colors.primary, size: 20),
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
                                  initialCenter: activeLatLng ?? const ll.LatLng(0, 0),
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
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          mapController.move(position, mapZoom);
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
                                    tooltip: followUserOnMap
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