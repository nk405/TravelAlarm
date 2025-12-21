import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'services/geofence_monitor.dart';
import 'services/notification_service.dart';
import 'screens/map_picker_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  double _radius = 300; // meters
  GeofenceMonitor? _monitor;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
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
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid latitude and longitude')),
      );
      return;
    }
    await _requestLocationPermission();
    _monitor?.dispose();
    _monitor = GeofenceMonitor(
      destLat: lat,
      destLng: lng,
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
            const Text('Destination (lat, lng)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MapPickerPage()),
                  );
                  if (result != null) {
                    // Result is a LatLng from flutter_map (latlong2)
                    final lat = result.latitude as double? ?? result.latitude;
                    final lng = result.longitude as double? ?? result.longitude;
                    _latController.text = lat.toStringAsFixed(6);
                    _lngController.text = lng.toStringAsFixed(6);
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text('Pick on map'),
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
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _startMonitoring,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _stopMonitoring,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_monitor != null)
              ValueListenableBuilder<double?>(
                valueListenable: _monitor!.currentDistanceMeters,
                builder: (context, dist, _) {
                  final text =
                      dist == null
                          ? 'Awaiting location...'
                          : 'Current distance: ${dist.toStringAsFixed(1)} m';
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
            const Spacer(),
            const Text(
              'Note: Background alerts require extra setup. This demo alerts while the app is open.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
