import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/destination.dart';
import '../models/alarm_sync_snapshot.dart';
import '../services/alarm_sync_service.dart';
import '../services/destination_store.dart';
import '../services/geofence_monitor.dart';
import '../services/notification_service.dart';
import '../services/weather_ai_service.dart';
import '../services/weather_service.dart';
import '../widgets/home_components.dart';
import 'settings_screen.dart';
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
  bool _loadingWeather = false;
  bool _syncBusy = false;
  String? _syncStatus;
  String? _lastCloudBackupLabel;
  int _selectedIndex = 0;
  DestinationWeather? _activeDestinationWeather;
  WeatherAiSuggestionResult? _activeAiSuggestions;
  String? _weatherError;
  bool? _locationServicesEnabled;
  LocationPermission? _locationPermission;

  final MapController _mainMapController = MapController();
  bool _followUserOnMainMap = true;
  double _mainMapZoom = 14;

  static const List<String> _pageTitles = <String>[
    'TravelAlarm',
    'Tracking Map',
    'Saved Places',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
    _loadDestinations();
    _refreshPreTripReadiness();
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
    DestinationStore.instance.saveRadiusMeters(clamped);
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
    final radiusMeters = await DestinationStore.instance.loadRadiusMeters();
    final adaptiveRadiusEnabled =
        await DestinationStore.instance.loadAdaptiveRadiusEnabled();
    if (!mounted) return;

    setState(() {
      _destinations
        ..clear()
        ..addAll(list);
      _radius = radiusMeters;
      _useAdaptiveRadius = adaptiveRadiusEnabled;
      _activeDestinationId =
          _destinations.any((destination) => destination.id == activeId)
              ? activeId
              : (_destinations.isNotEmpty ? _destinations.first.id : null);
      _loadingDestinations = false;
    });

    await DestinationStore.instance.saveActiveDestinationId(
      _activeDestinationId,
    );
    await _refreshCloudBackupMeta();
    await _refreshActiveDestinationWeather();
  }

  Future<void> _persistDestinations() async {
    await DestinationStore.instance.saveDestinations(_destinations);
    await DestinationStore.instance.saveActiveDestinationId(
      _activeDestinationId,
    );
  }

  Future<void> _setSyncBusy(bool value, {String? status}) async {
    if (!mounted) return;
    setState(() {
      _syncBusy = value;
      if (status != null) {
        _syncStatus = status;
      }
    });
  }

  Future<void> _signInWithGoogle() async {
    await _setSyncBusy(true, status: 'Signing in with Google...');
    try {
      await AlarmSyncService.instance.signInWithGoogle();
      await _refreshCloudBackupMeta();
      await _setSyncBusy(false, status: 'Signed in with Google.');
    } on SyncSignInCancelledException {
      await _setSyncBusy(false, status: 'Google sign-in canceled.');
    } on SyncNotConfiguredException {
      await _setSyncBusy(
        false,
        status: 'Cloud sync is not configured yet for this app build.',
      );
    } on FirebaseAuthException catch (e) {
      await _setSyncBusy(false, status: _mapAuthError(e));
    } catch (_) {
      await _setSyncBusy(
        false,
        status: 'Google sign-in failed. Please try again.',
      );
    }
  }

  Future<void> _signOutFromSync() async {
    await _setSyncBusy(true, status: 'Signing out...');
    try {
      await AlarmSyncService.instance.signOut();
      if (!mounted) return;
      setState(() {
        _syncBusy = false;
        _syncStatus = 'Signed out.';
        _lastCloudBackupLabel = null;
      });
    } catch (_) {
      await _setSyncBusy(false, status: 'Unable to sign out right now.');
    }
  }

  Future<void> _backupNow() async {
    await _setSyncBusy(true, status: 'Uploading backup...');
    try {
      final snapshot = await DestinationStore.instance.loadSnapshot();
      await AlarmSyncService.instance.backupNow(snapshot);
      await _refreshCloudBackupMeta();
      await _setSyncBusy(false, status: 'Backup completed.');
    } on SyncNotConfiguredException {
      await _setSyncBusy(
        false,
        status: 'Cloud sync is not configured yet for this app build.',
      );
    } on SyncUserNotSignedInException {
      await _setSyncBusy(false, status: 'Sign in first to back up data.');
    } catch (_) {
      await _setSyncBusy(
        false,
        status: 'Backup failed. Check network and try again.',
      );
    }
  }

  Future<void> _restoreNow() async {
    await _setSyncBusy(true, status: 'Checking cloud backup...');
    try {
      final remote = await AlarmSyncService.instance.fetchBackup();
      if (remote == null) {
        await _setSyncBusy(false, status: 'No cloud backup found.');
        return;
      }

      final local = await DestinationStore.instance.loadSnapshot();
      final shouldOverwrite = await _confirmRestoreIfNeeded(
        local: local,
        remote: remote,
      );
      if (shouldOverwrite != true) {
        await _setSyncBusy(false, status: 'Restore canceled.');
        return;
      }

      await DestinationStore.instance.saveSnapshot(
        remote.snapshot.copyWith(
          localUpdatedAtMillis: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      await _loadDestinations();
      await _setSyncBusy(false, status: 'Restore completed.');
    } on SyncNotConfiguredException {
      await _setSyncBusy(
        false,
        status: 'Cloud sync is not configured yet for this app build.',
      );
    } on SyncUserNotSignedInException {
      await _setSyncBusy(false, status: 'Sign in first to restore backup.');
    } catch (_) {
      await _setSyncBusy(false, status: 'Restore failed. Please try again.');
    }
  }

  Future<void> _refreshCloudBackupMeta() async {
    final user = AlarmSyncService.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _lastCloudBackupLabel = null;
      });
      return;
    }

    try {
      final remote = await AlarmSyncService.instance.fetchBackup();
      if (!mounted) return;
      setState(() {
        _lastCloudBackupLabel =
            remote == null
                ? null
                : _formatTimestamp(remote.cloudUpdatedAtMillis);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastCloudBackupLabel = null;
      });
    }
  }

  Future<bool?> _confirmRestoreIfNeeded({
    required AlarmSyncSnapshot local,
    required RemoteBackupState remote,
  }) async {
    final localTime = local.localUpdatedAtMillis;
    final cloudTime = remote.cloudUpdatedAtMillis;
    final localNewer = localTime > cloudTime;

    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore cloud backup'),
          content: Text(
            localNewer
                ? 'Local data looks newer than cloud backup. Overwrite this device with cloud data anyway?'
                : 'This will replace local saved alarms and settings with the cloud backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Invalid email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      case 'network-request-failed':
        return 'Network error. Check connection and try again.';
      case 'email-already-in-use':
        return 'Email already in use. Try signing in.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return 'Authentication failed. ${e.message ?? ''}'.trim();
    }
  }

  String _formatTimestamp(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd $hh:$min';
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    await _refreshPreTripReadiness();
  }

  Future<void> _refreshPreTripReadiness() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final permission = await Geolocator.checkPermission();
    if (!mounted) return;
    setState(() {
      _locationServicesEnabled = serviceEnabled;
      _locationPermission = permission;
    });
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
      _selectedIndex = 1;
    });
    await _refreshPreTripReadiness();
  }

  Future<void> _stopMonitoring() async {
    await _monitor?.stop();
    if (!mounted) return;
    setState(() {});
    await _refreshPreTripReadiness();
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
    await _refreshActiveDestinationWeather();
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
      _selectedIndex = 2;
    });
    await _persistDestinations();
    await _refreshActiveDestinationWeather();

    if (_monitor != null) {
      await _stopMonitoring();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Monitoring stopped')));
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
    await _refreshActiveDestinationWeather();
  }

  Future<void> _refreshActiveDestinationWeather() async {
    final destination = _activeDestination;
    if (destination == null) {
      if (!mounted) return;
      setState(() {
        _activeDestinationWeather = null;
        _activeAiSuggestions = null;
        _loadingWeather = false;
        _weatherError = null;
      });
      return;
    }

    final requestDestinationId = destination.id;
    final cached = await WeatherService.loadFreshCachedWeather(
      latitude: destination.latitude,
      longitude: destination.longitude,
    );

    if (!mounted || _activeDestinationId != requestDestinationId) return;
    setState(() {
      _activeDestinationWeather = cached;
      _activeAiSuggestions = null;
      _loadingWeather = true;
      _weatherError = null;
    });

    if (cached != null) {
      final cachedAi = await WeatherAiService.instance.predictSuggestions(
        cached,
      );
      if (!mounted || _activeDestinationId != requestDestinationId) return;
      setState(() {
        _activeAiSuggestions = cachedAi;
      });
    }

    try {
      final latest = await WeatherService.fetchCurrentWeather(
        latitude: destination.latitude,
        longitude: destination.longitude,
      );

      if (!mounted || _activeDestinationId != requestDestinationId) return;
      final aiResult = await WeatherAiService.instance.predictSuggestions(
        latest,
      );
      if (!mounted || _activeDestinationId != requestDestinationId) return;
      setState(() {
        _activeDestinationWeather = latest;
        _activeAiSuggestions = aiResult;
        _loadingWeather = false;
        _weatherError = null;
      });
    } catch (_) {
      if (!mounted || _activeDestinationId != requestDestinationId) return;
      setState(() {
        _loadingWeather = false;
        _weatherError =
            'Unable to refresh weather right now. Suggestions may be outdated.';
      });
    }
  }

  void _selectPage(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0 || index == 1) {
      _refreshPreTripReadiness();
    }
  }

  Future<void> _startMonitoringFromHome() async {
    await _startMonitoring();
  }

  Future<void> _activateDestinationFromHome(String destinationId) async {
    await _setActiveDestination(destinationId);
    if (!mounted) return;
    setState(() {
      _selectedIndex = 1;
    });
  }

  List<Destination> _buildQuickDestinationCandidates() {
    if (_destinations.isEmpty) return const <Destination>[];

    final lowerPriorityKeywords = <String>['home', 'work', 'office', 'airport'];
    final scored =
        _destinations.map((destination) {
            final name = destination.name.toLowerCase();
            var score = 0;
            for (final keyword in lowerPriorityKeywords) {
              if (name.contains(keyword)) {
                score += 2;
              }
            }
            if (destination.id == _activeDestinationId) {
              score += 1;
            }
            return (destination: destination, score: score);
          }).toList()
          ..sort((a, b) {
            final byScore = b.score.compareTo(a.score);
            if (byScore != 0) return byScore;
            return a.destination.name.compareTo(b.destination.name);
          });

    return scored.take(4).map((item) => item.destination).toList();
  }

  String _buildAlertReadinessLabel() {
    final monitor = _monitor;
    if (monitor == null) return 'Ready';

    final isRunning = monitor.monitoring.value;
    if (!isRunning) return 'Paused';

    if (monitor.currentPosition.value == null) {
      return 'Starting';
    }

    return 'Running';
  }

  List<Widget> _buildPages() {
    final activeDestination = _activeDestination;
    final activeLatLng =
        activeDestination == null
            ? null
            : ll.LatLng(
              activeDestination.latitude,
              activeDestination.longitude,
            );

    return [
      HomeOverviewScreen(
        activeDestination: activeDestination,
        destinationCount: _destinations.length,
        loadingDestinations: _loadingDestinations,
        weather: _activeDestinationWeather,
        aiSuggestionResult: _activeAiSuggestions,
        loadingWeather: _loadingWeather,
        weatherError: _weatherError,
        isMonitoring: _monitor != null,
        radiusLabel: _buildRadiusBadgeLabel(),
        adaptiveRadiusEnabled: _useAdaptiveRadius,
        quickDestinations: _buildQuickDestinationCandidates(),
        activeDestinationId: _activeDestinationId,
        preTripChecklistState: PreTripChecklistState(
          hasDestination: activeDestination != null,
          locationServicesEnabled: _locationServicesEnabled,
          locationPermission: _locationPermission,
          monitoringReady: _buildAlertReadinessLabel(),
        ),
        onRunPreTripChecklist: _refreshPreTripReadiness,
        onSelectQuickDestination: _activateDestinationFromHome,
        onStartMonitoring: _startMonitoringFromHome,
        onRefreshWeather: _refreshActiveDestinationWeather,
        onOpenDestinations: () => _selectPage(2),
        onOpenAlertSettings: () => _selectPage(3),
        onOpenMonitoring: () => _selectPage(1),
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
        formatSpeed: _formatSpeed,
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
      SettingsScreen(
        radius: _radius,
        useAdaptiveRadius: _useAdaptiveRadius,
        radiusBadgeLabel: _buildRadiusBadgeLabel(),
        monitor: _monitor,
        onSetRadius: _setRadius,
        onSetAdaptiveRadius: _setAdaptiveRadius,
        formatDistance: _formatDistance,
        formatSpeed: _formatSpeed,
        syncBusy: _syncBusy,
        syncUserEmail: AlarmSyncService.instance.currentUser?.email,
        syncStatus: _syncStatus,
        lastBackupLabel: _lastCloudBackupLabel,
        onSignInWithGoogle: _signInWithGoogle,
        onSignOut: _signOutFromSync,
        onBackupNow: _backupNow,
        onRestoreNow: _restoreNow,
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
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Trip Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.place_outlined),
            selectedIcon: Icon(Icons.place),
            label: 'Places',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton:
          _selectedIndex == 2
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
