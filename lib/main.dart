import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'models/destination.dart';
import 'services/destination_store.dart';
import 'services/geofence_monitor.dart';
import 'services/notification_service.dart';
import 'screens/map_picker_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelAlarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'TravelAlarm'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _radius = 300; // meters
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
    if (!mounted) return;
    setState(() {
      _destinations
        ..clear()
        ..addAll(list);
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
      radiusMeters: _radius,
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
      builder: (context) => const _DestinationNameDialog(),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _addDestination,
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add destination'),
              ),
            ),
            const SizedBox(height: 16),
            Text('Radius: ${_radius.toStringAsFixed(0)} m'),
            Slider(
              value: _radius,
              min: 50,
              max: 2000,
              divisions: 39,
              label: '${_radius.toStringAsFixed(0)} m',
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: 8),
            if (_monitor == null)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: active == null ? null : _startMonitoring,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ],
              )
            else
              ValueListenableBuilder<bool>(
                valueListenable: _monitor!.monitoring,
                builder: (context, running, _) {
                  return Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: running ? null : _startMonitoring,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: running ? _stopMonitoring : null,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            if (_monitor != null)
              ValueListenableBuilder<double?>(
                valueListenable: _monitor!.currentDistanceMeters,
                builder: (context, dist, _) {
                  final text =
                      dist == null
                          ? 'Awaiting location...'
                          : 'Remaining distance (driving): ${dist.toStringAsFixed(0)} m';
                  return Text(
                    text,
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                },
              ),
            if (_monitor != null)
              ValueListenableBuilder<bool>(
                valueListenable: _monitor!.monitoring,
                builder:
                    (context, running, _) => Text(
                      running ? 'Monitoring active' : 'Monitoring stopped',
                      style: TextStyle(
                        color: running ? Colors.green : Colors.red,
                      ),
                    ),
              ),
            if (_monitor != null)
              ValueListenableBuilder<bool>(
                valueListenable: _monitor!.monitoring,
                builder: (context, running, _) {
                  if (!running) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      height: 260,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mainMapController,
                            options: MapOptions(
                              initialCenter:
                                  activeLatLng ?? const ll.LatLng(0, 0),
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
                                valueListenable: _monitor!.routePoints,
                                builder: (context, pts, _) {
                                  if (pts.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return PolylineLayer(
                                    polylines: [
                                      Polyline(
                                        points: pts,
                                        strokeWidth: 5,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
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
                                valueListenable: _monitor!.currentPosition,
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
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
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
                              color: Theme.of(context).colorScheme.surface,
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
                                    final pos = _monitor!.currentPosition.value;
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
                  );
                },
              ),
            const SizedBox(height: 16),
            const Text('Saved destinations'),
            const SizedBox(height: 8),
            if (active != null) ...[
              Text(
                'Active: ${active.name} (${active.latitude.toStringAsFixed(6)}, ${active.longitude.toStringAsFixed(6)})',
              ),
              const SizedBox(height: 8),
            ],
            if (_loadingDestinations)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_destinations.isEmpty)
              const Text('No destinations saved')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _destinations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final dest = _destinations[i];
                  return ListTile(
                    leading: Radio<String>(
                      value: dest.id,
                      groupValue: _activeDestinationId,
                      onChanged: _setActiveDestination,
                    ),
                    title: Text(dest.name),
                    subtitle: Text(
                      '${dest.latitude.toStringAsFixed(6)}, ${dest.longitude.toStringAsFixed(6)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteDestination(dest),
                    ),
                    onTap: () => _setActiveDestination(dest.id),
                  );
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DestinationNameDialog extends StatefulWidget {
  const _DestinationNameDialog();

  @override
  State<_DestinationNameDialog> createState() => _DestinationNameDialogState();
}

class _DestinationNameDialogState extends State<_DestinationNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Destination name'),
      content: TextField(
        controller: _controller,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'e.g. Office'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
