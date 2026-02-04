import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

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
  ll.LatLng? _destination;

  final MapController _mainMapController = MapController();
  bool _followUserOnMainMap = true;
  double _mainMapZoom = 14;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
  }

  @override
  void dispose() {
    _monitor?.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  void _startMonitoring() async {
    final dest = _destination;
    if (dest == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a destination on the map first')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Destination'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MapPickerPage()),
                  );
                  if (result != null && result is ll.LatLng) {
                    setState(() => _destination = result);
                  }
                },
                icon: const Icon(Icons.map),
                label: Text(
                  _destination == null
                      ? 'Pick destination on map'
                      : 'Change destination',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _destination == null
                  ? 'No destination selected'
                  : 'Selected: ${_destination!.latitude.toStringAsFixed(6)}, ${_destination!.longitude.toStringAsFixed(6)}',
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
                    onPressed: _destination == null ? null : _startMonitoring,
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
                                  _destination ?? const ll.LatLng(0, 0),
                              initialZoom: _mainMapZoom,
                              onPositionChanged: (pos, hasGesture) {
                                // Track zoom so following keeps the user's chosen zoom.
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
                              if (_destination != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _destination!,
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
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
