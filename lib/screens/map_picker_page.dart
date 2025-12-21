import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;

class _PlaceResult {
  const _PlaceResult({required this.title, required this.point});

  final String title;
  final ll.LatLng point;
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  final MapController _mapController = MapController();
  ll.LatLng? _selected;
  ll.LatLng _center = const ll.LatLng(0, 0);
  double _zoom = 3;

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String? _searchError;
  List<_PlaceResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse) {
      try {
        final pos = await Geolocator.getCurrentPosition();
        setState(() {
          _center = ll.LatLng(pos.latitude, pos.longitude);
          _zoom = 15;
        });
      } catch (_) {
        // Keep default center
      }
    }
  }

  void _onTap(ll.LatLng latLng) {
    setState(() => _selected = latLng);
  }

  void _confirm() {
    if (_selected != null) {
      Navigator.of(context).pop(_selected);
    } else {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> _searchPlace(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'json',
        'limit': '5',
      });

      final resp = await http.get(
        uri,
        headers: const {
          // Nominatim requires a valid User-Agent.
          'User-Agent': 'TravelAlarm/1.0 (Flutter; contact: local)',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw Exception('Unexpected response');
      }

      final items = <_PlaceResult>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final display = raw['display_name']?.toString();
        final latStr = raw['lat']?.toString();
        final lonStr = raw['lon']?.toString();
        if (display == null || latStr == null || lonStr == null) continue;
        final lat = double.tryParse(latStr);
        final lon = double.tryParse(lonStr);
        if (lat == null || lon == null) continue;
        items.add(_PlaceResult(title: display, point: ll.LatLng(lat, lon)));
      }

      if (!mounted) return;
      setState(() {
        _results = items;
        _searchError = items.isEmpty ? 'No results found' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchError = 'Search failed. Check internet connection.';
        _results = const [];
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _selectResult(_PlaceResult r) {
    setState(() {
      _selected = r.point;
      _center = r.point;
      _zoom = 15;
      _results = const [];
      _searchError = null;
    });
    _mapController.move(r.point, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick destination'),
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              onTap: (tapPos, latLng) => _onTap(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.travelalarm.travelalarm',
                subdomains: const [],
              ),
              if (_selected != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selected!,
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
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: _searchPlace,
                      decoration: InputDecoration(
                        hintText: 'Search a place',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        prefixIcon:
                            _searching
                                ? const Padding(
                                  padding: EdgeInsets.all(14.0),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                                : IconButton(
                                  onPressed:
                                      () =>
                                          _searchPlace(_searchController.text),
                                  icon: const Icon(Icons.search),
                                ),
                        suffixIcon:
                            _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _results = const [];
                                      _searchError = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                ),
                      ),
                    ),
                  ),
                  if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_searchError!),
                    ),
                  ],
                  if (_results.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _results[i];
                            return ListTile(
                              title: Text(
                                r.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectResult(r),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selected == null
                    ? 'Tap on the map to select a destination'
                    : 'Selected: ${_selected!.latitude.toStringAsFixed(6)}, ${_selected!.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selected == null ? null : _confirm,
                  child: const Text('Confirm location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
