import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/destination.dart';
import '../services/destination_store.dart';
import '../services/geofence_monitor.dart';
import '../services/notification_service.dart';
import '../widgets/home_components.dart';
import 'alert_settings_screen.dart';
import 'destinations_screen.dart';
import 'home_overview_screen.dart';
import 'map_picker_page.dart';
import 'monitoring_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  double _radius = 300;
  bool _useAdaptiveRadius = true;
  GeofenceMonitor? _monitor;
  final List<Destination> _destinations = [];
  String? _activeDestinationId;
  bool _loadingDestinations = true;
  int _selectedIndex = 0;

  final MapController _mainMapController = MapController();
  bool _followUserOnMainMap = true;
  double _mainMapZoom = 14;

  static const List<String> _pageTitles = <String>[
    'TravelAlarm',
    'Destinations',
    'Alert settings',
    'Monitoring',
  ];

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
    for (final destination in _destinations) {
      if (destination.id == id) {
        return destination;
      }
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
          _destinations.any((destination) => destination.id == activeId)
              ? activeId
              : (_destinations.isNotEmpty ? _destinations.first.id : null);
      _loadingDestinations = false;
    });

    await DestinationStore.instance.saveActiveDestinationId(_activeDestinationId);
  }

  Future<void> _persistDestinations() async {
    await DestinationStore.instance.saveDestinations(_destinations);
    await DestinationStore.instance.saveActiveDestinationId(_activeDestinationId);
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _startMonitoring() async {
    final destination = _activeDestination;
    if (destination == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a destination first')),
      );
      return;
    }

    await _requestLocationPermission();
    _monitor?.dispose();
    _monitor = GeofenceMonitor(
      destLat: destination.latitude,
      destLng: destination.longitude,
      destName: destination.name,
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
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedIndex = 3;
    });
  }

  Future<void> _stopMonitoring() async {
    await _monitor?.stop();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _setActiveDestination(String? id) async {
    if (id == _activeDestinationId) return;

    if (_monitor != null) {
      await _stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monitoring stopped')),
        );
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
    if (result == null || result is! ll.LatLng || !mounted) return;

    final name = await _promptDestinationName();
    if (name == null) return;

    final finalName =
        name.isEmpty ? 'Destination ${_destinations.length + 1}' : name;

    final destination = Destination(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: finalName,
      latitude: result.latitude,
      longitude: result.longitude,
    );

    setState(() {
      _destinations.add(destination);
      _activeDestinationId = destination.id;
      _selectedIndex = 1;
    });
    await _persistDestinations();

    if (_monitor != null) {
      await _stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monitoring stopped')),
        );
      }
    }
  }

  void _showDestinationDetails(Destination destination) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final isActive = destination.id == _activeDestinationId;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(destination.name, style: theme.textTheme.titleLarge),
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
                      '${destination.latitude.toStringAsFixed(6)}, ${destination.longitude.toStringAsFixed(6)}',
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

  Future<void> _deleteDestination(Destination destination) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove destination'),
          content: Text('Delete "${destination.name}"?'),
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

    if (_monitor != null && _activeDestinationId == destination.id) {
      await _stopMonitoring();
    }

    setState(() {
      _destinations.removeWhere((item) => item.id == destination.id);
      if (_activeDestinationId == destination.id) {
        _activeDestinationId =
            _destinations.isNotEmpty ? _destinations.first.id : null;
      }
    });
    await _persistDestinations();
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
  }

  List<Widget> _buildPages() {
    final activeDestination = _activeDestination;
    final activeLatLng = activeDestination == null
        ? null
        : ll.LatLng(activeDestination.latitude, activeDestination.longitude);

    return [
      HomeOverviewScreen(
        activeDestination: activeDestination,
        destinationCount: _destinations.length,
        loadingDestinations: _loadingDestinations,
        isMonitoring: _monitor != null,
        radiusLabel: _buildRadiusBadgeLabel(),
        adaptiveRadiusEnabled: _useAdaptiveRadius,
        onOpenDestinations: () => _selectPage(1),
        onOpenAlertSettings: () => _selectPage(2),
        onOpenMonitoring: () => _selectPage(3),
      ),
      DestinationsScreen(
        loadingDestinations: _loadingDestinations,
        destinations: _destinations,
        activeDestinationId: _activeDestinationId,
        onSelectDestination: _setActiveDestination,
        onDeleteDestination: _deleteDestination,
        onShowDetails: _showDestinationDetails,
        onAddDestination: _addDestination,
      ),
      AlertSettingsScreen(
        radius: _radius,
        useAdaptiveRadius: _useAdaptiveRadius,
        radiusBadgeLabel: _buildRadiusBadgeLabel(),
        monitor: _monitor,
        onSetRadius: _setRadius,
        onSetAdaptiveRadius: _setAdaptiveRadius,
        formatDistance: _formatDistance,
        formatSpeed: _formatSpeed,
      ),
      MonitoringScreen(
        activeDestination: activeDestination,
        monitor: _monitor,
        activeLatLng: activeLatLng,
        mapController: _mainMapController,
        followUserOnMap: _followUserOnMainMap,
        mapZoom: _mainMapZoom,
        onMapZoomChanged: (zoom) => _mainMapZoom = zoom,
        onToggleFollowUser: () {
          setState(() {
            _followUserOnMainMap = !_followUserOnMainMap;
          });

          final position = _monitor?.currentPosition.value;
          if (_followUserOnMainMap && position != null) {
            _mainMapController.move(position, _mainMapZoom);
          }
        },
        onStartMonitoring: _startMonitoring,
        onStopMonitoring: _stopMonitoring,
        formatDistance: _formatDistance,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pages = _buildPages();

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
            Text(_pageTitles[_selectedIndex]),
          ],
        ),
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectPage,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Destinations',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Alert',
          ),
          NavigationDestination(
            icon: Icon(Icons.radar_outlined),
            selectedIcon: Icon(Icons.radar),
            label: 'Monitor',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _addDestination,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Add destination'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : null,
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final kilometers = meters / 1000;
      return '${kilometers.toStringAsFixed(1)} km';
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
