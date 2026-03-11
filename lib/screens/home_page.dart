import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/destination.dart';
import '../services/destination_store.dart';
import '../services/geofence_monitor.dart';
import '../services/notification_service.dart';
import 'map_picker_page.dart';
import '../widgets/home_components.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _radius = 300; // meters
  bool _useAdaptiveRadius = true;
  GeofenceMonitor? _monitor;
  final List<Destination> _destinations = [];
  String? _activeDestinationId;
  bool _loadingDestinations = true;

  final MapController _mainMapController = MapController();
  bool _followUserOnMainMap = true;
  double _mainMapZoom = 14;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _loadDestinations();
  }

  @override
  void dispose() {
    _monitor?.dispose();
    super.dispose();
  }

  void _setRadius(double value) {
    final clamped = value.clamp(50, 2000).toDouble();
    setState(() => _radius = clamped);
    _monitor?.setBaseRadius(clamped);
  }

  Future<void> _setAdaptiveRadius(bool value) async {
    setState(() => _useAdaptiveRadius = value);
    _monitor?.setAdaptiveRadiusEnabled(value);
    await DestinationStore.instance.saveAdaptiveRadiusEnabled(value);
  }

  Destination? get _activeDestination {
    final id = _activeDestinationId;
    if (id == null) return null;
    for (final d in _destinations) {
      if (d.id == id) return d;
    }
    return null;
  }

  Future<void> _loadDestinations() async {
    final list = await DestinationStore.instance.loadDestinations();
    final activeId = await DestinationStore.instance.loadActiveDestinationId();
    final adaptiveRadiusEnabled =
        await DestinationStore.instance.loadAdaptiveRadiusEnabled();
    if (!mounted) return;
    setState(() {
      _destinations
        ..clear()
        ..addAll(list);
      _useAdaptiveRadius = adaptiveRadiusEnabled;
      _activeDestinationId =
          _destinations.any((d) => d.id == activeId)
              ? activeId
              : (_destinations.isNotEmpty ? _destinations.first.id : null);
      _loadingDestinations = false;
    });
    await DestinationStore.instance.saveActiveDestinationId(
      _activeDestinationId,
    );
  }

  Future<void> _persistDestinations() async {
    await DestinationStore.instance.saveDestinations(_destinations);
    await DestinationStore.instance.saveActiveDestinationId(
      _activeDestinationId,
    );
  }

  Future<void> _requestLocationPermission() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _startMonitoring() async {
    final dest = _activeDestination;
    if (dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a destination first')),
      );
      return;
    }
    await _requestLocationPermission();
    _monitor?.dispose();
    _monitor = GeofenceMonitor(
      destLat: dest.latitude,
      destLng: dest.longitude,
      destName: dest.name,
      radiusMeters: _radius,
      adaptiveRadiusEnabled: _useAdaptiveRadius,
    );
    final started = await _monitor!.start();
    if (!started) {
      _monitor?.dispose();
      _monitor = null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to start monitoring. Enable Location services and allow location permission.',
          ),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _stopMonitoring() async {
    await _monitor?.stop();
    setState(() {});
  }

  Future<void> _setActiveDestination(String? id) async {
    if (id == _activeDestinationId) return;
    if (_monitor != null) {
      await _stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Monitoring stopped')));
      }
    }
    setState(() => _activeDestinationId = id);
    await _persistDestinations();
  }

  Future<String?> _promptDestinationName() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const DestinationNameDialog(),
    );
  }

  Future<void> _addDestination() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MapPickerPage()));
    if (result == null || result is! ll.LatLng) return;
    if (!mounted) return;

    final name = await _promptDestinationName();
    if (name == null) return;
    final finalName =
        name.isEmpty ? 'Destination ${_destinations.length + 1}' : name;

    final dest = Destination(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: finalName,
      latitude: result.latitude,
      longitude: result.longitude,
    );

    setState(() {
      _destinations.add(dest);
      _activeDestinationId = dest.id;
    });
    await _persistDestinations();

    if (_monitor != null) {
      await _stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Monitoring stopped')));
      }
    }
  }

  void _showDestinationDetails(Destination dest) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isActive = dest.id == _activeDestinationId;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dest.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                isActive ? 'Active destination' : 'Saved destination',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.pin_drop_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${dest.latitude.toStringAsFixed(6)}, ${dest.longitude.toStringAsFixed(6)}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tap a destination to set it active.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteDestination(Destination dest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove destination'),
          content: Text('Delete "${dest.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    if (_monitor != null && _activeDestinationId == dest.id) {
      await _stopMonitoring();
    }

    setState(() {
      _destinations.removeWhere((d) => d.id == dest.id);
      if (_activeDestinationId == dest.id) {
        _activeDestinationId =
            _destinations.isNotEmpty ? _destinations.first.id : null;
      }
    });
    await _persistDestinations();
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeDestination;
    final activeLatLng =
        active == null ? null : ll.LatLng(active.latitude, active.longitude);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: colors.surface,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_active, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            const Text('TravelAlarm'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Hero status card ---
              CardSection(
                gradient: LinearGradient(
                  colors: [colors.primaryContainer, colors.surfaceContainerLow],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.travel_explore,
                        color: colors.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active == null ? 'No destination' : active.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active == null
                                ? 'Add a destination to get started'
                                : 'Active destination',
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

              // --- Alert distance card ---
              CardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.radar, color: colors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Alert distance',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.secondaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _buildRadiusBadgeLabel(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _useAdaptiveRadius,
                      onChanged: _setAdaptiveRadius,
                      title: const Text('Auto-adjust by speed'),
                      subtitle: Text(
                        _useAdaptiveRadius
                            ? 'Uses live speed to increase the alert radius before arrival.'
                            : 'Uses only the fixed distance you set below.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        activeTrackColor: colors.primary,
                        inactiveTrackColor: colors.outlineVariant,
                        thumbColor: colors.primary,
                      ),
                      child: Slider(
                        min: 50,
                        max: 2000,
                        divisions: 39,
                        value: _radius,
                        label:
                            _useAdaptiveRadius
                                ? 'Base ${_radius.toStringAsFixed(0)} m'
                                : '${_radius.toStringAsFixed(0)} m',
                        onChanged: _setRadius,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _useAdaptiveRadius
                          ? 'Base distance used by the predictor. The live alert radius grows with speed.'
                          : 'Fixed alert distance before the alarm triggers.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        RadiusChip(
                          label: '200 m',
                          value: 200,
                          selected: _radius == 200,
                          onTap: _setRadius,
                        ),
                        RadiusChip(
                          label: '500 m',
                          value: 500,
                          selected: _radius == 500,
                          onTap: _setRadius,
                        ),
                        RadiusChip(
                          label: '1 km',
                          value: 1000,
                          selected: _radius == 1000,
                          onTap: _setRadius,
                        ),
                      ],
                    ),
                    if (_monitor != null && _useAdaptiveRadius) ...[
                      const SizedBox(height: 12),
                      ValueListenableBuilder<double>(
                        valueListenable: _monitor!.effectiveRadiusMeters,
                        builder: (context, effectiveRadius, _) {
                          return ValueListenableBuilder<double>(
                            valueListenable:
                                _monitor!.currentSpeedMetersPerSecond,
                            builder: (context, speed, __) {
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 18,
                                      color: colors.primary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Live radius ${_formatDistance(effectiveRadius)} at ${_formatSpeed(speed)}',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- Alert status card ---
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
                    if (_monitor == null)
                      StatusRow(label: 'Not running', color: colors.outline)
                    else
                      ValueListenableBuilder<bool>(
                        valueListenable: _monitor!.monitoring,
                        builder: (context, running, _) {
                          return StatusRow(
                            label: running ? 'Running' : 'Paused',
                            color: running ? colors.primary : colors.outline,
                            pulse: running,
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    if (_monitor == null)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: active == null ? null : _startMonitoring,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start alert'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      )
                    else
                      ValueListenableBuilder<bool>(
                        valueListenable: _monitor!.monitoring,
                        builder: (context, running, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 48,
                            child:
                                running
                                    ? OutlinedButton.icon(
                                      onPressed: _stopMonitoring,
                                      icon: const Icon(Icons.stop_rounded),
                                      label: const Text('Stop alert'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        side: BorderSide(color: colors.outline),
                                      ),
                                    )
                                    : FilledButton.icon(
                                      onPressed: _startMonitoring,
                                      icon: const Icon(
                                        Icons.play_arrow_rounded,
                                      ),
                                      label: const Text('Start alert'),
                                      style: FilledButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                    ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // --- Distance remaining ---
              if (_monitor != null)
                CardSection(
                  gradient: LinearGradient(
                    colors: [
                      colors.tertiaryContainer,
                      colors.surfaceContainerLow,
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  child: ValueListenableBuilder<double?>(
                    valueListenable: _monitor!.currentDistanceMeters,
                    builder: (context, dist, _) {
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.straighten,
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
                                  'Distance remaining',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dist == null
                                      ? 'Awaiting location...'
                                      : _formatDistance(dist),
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
              if (_monitor != null)
                ValueListenableBuilder<bool>(
                  valueListenable: _monitor!.monitoring,
                  builder: (context, running, _) {
                    if (!running) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: CardSection(
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(top: 8),
                          leading: Icon(
                            Icons.map_outlined,
                            color: colors.primary,
                            size: 20,
                          ),
                          title: Text(
                            'Live map',
                            style: theme.textTheme.titleSmall,
                          ),
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                height: 260,
                                child: Stack(
                                  children: [
                                    FlutterMap(
                                      mapController: _mainMapController,
                                      options: MapOptions(
                                        initialCenter:
                                            activeLatLng ??
                                            const ll.LatLng(0, 0),
                                        initialZoom: _mainMapZoom,
                                        onPositionChanged: (pos, hasGesture) {
                                          if (!hasGesture) return;
                                          final zoom = pos.zoom;
                                          if (zoom == null) return;
                                          _mainMapZoom = zoom;
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
                                          valueListenable:
                                              _monitor!.routePoints,
                                          builder: (context, pts, _) {
                                            if (pts.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return PolylineLayer(
                                              polylines: [
                                                Polyline(
                                                  points: pts,
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
                                                point: activeLatLng,
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
                                          valueListenable:
                                              _monitor!.currentPosition,
                                          builder: (context, pos, _) {
                                            if (pos == null) {
                                              return const SizedBox.shrink();
                                            }

                                            if (_followUserOnMainMap) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                    if (!mounted) return;
                                                    _mainMapController.move(
                                                      pos,
                                                      _mainMapZoom,
                                                    );
                                                  });
                                            }

                                            return MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: pos,
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
                                              _followUserOnMainMap
                                                  ? 'Following location'
                                                  : 'Follow location',
                                          icon: Icon(
                                            _followUserOnMainMap
                                                ? Icons.my_location
                                                : Icons.location_searching,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _followUserOnMainMap =
                                                  !_followUserOnMainMap;
                                            });

                                            if (_followUserOnMainMap) {
                                              final pos =
                                                  _monitor!
                                                      .currentPosition
                                                      .value;
                                              if (pos != null) {
                                                _mainMapController.move(
                                                  pos,
                                                  _mainMapZoom,
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // --- Destinations card ---
              CardSection(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              color: colors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Destinations',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                        if (_destinations.isNotEmpty)
                          Text(
                            '${_destinations.length}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_loadingDestinations)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_destinations.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Column(
                            children: [
                              Icon(
                                Icons.add_location_alt_outlined,
                                size: 48,
                                color: colors.outlineVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No destinations yet',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the button below to add one',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _destinations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final dest = _destinations[i];
                          final isActive = dest.id == _activeDestinationId;
                          return Dismissible(
                            key: ValueKey(dest.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (_) async {
                              return showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Remove destination'),
                                      content: Text('Delete "${dest.name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed:
                                              () => Navigator.of(
                                                context,
                                              ).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                            onDismissed: (_) => _deleteDestination(dest),
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: colors.errorContainer,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: colors.onErrorContainer,
                              ),
                            ),
                            child: Material(
                              color:
                                  isActive
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _setActiveDestination(dest.id),
                                onLongPress:
                                    () => _showDestinationDetails(dest),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color:
                                              isActive
                                                  ? colors.primaryContainer
                                                  : colors
                                                      .surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          isActive
                                              ? Icons.check_circle_rounded
                                              : Icons.place_outlined,
                                          color:
                                              isActive
                                                  ? colors.onPrimaryContainer
                                                  : colors.onSurfaceVariant,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dest.name,
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    fontWeight:
                                                        isActive
                                                            ? FontWeight.w600
                                                            : FontWeight.normal,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              isActive
                                                  ? 'Active'
                                                  : 'Long-press for details',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        isActive
                                                            ? colors.primary
                                                            : colors
                                                                .onSurfaceVariant,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        Icon(
                                          Icons.check,
                                          color: colors.primary,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDestination,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add destination'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatSpeed(double speedMetersPerSecond) {
    final speedKmh = speedMetersPerSecond * 3.6;
    return '${speedKmh.toStringAsFixed(0)} km/h';
  }

  String _buildRadiusBadgeLabel() {
    final monitor = _monitor;
    if (!_useAdaptiveRadius || monitor == null) {
      return '${_radius.toStringAsFixed(0)} m';
    }

    final effectiveRadius = monitor.effectiveRadiusMeters.value;
    if (effectiveRadius <= 0) {
      return 'Base ${_radius.toStringAsFixed(0)} m';
    }

    return 'Auto ${effectiveRadius.toStringAsFixed(0)} m';
  }
}
