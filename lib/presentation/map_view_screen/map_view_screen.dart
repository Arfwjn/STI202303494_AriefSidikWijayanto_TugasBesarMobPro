import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/destination_list_sheet_widget.dart';
import './widgets/map_controls_widget.dart';
import './widgets/search_overlay_widget.dart';

/// Map View Screen - Interactive Google Maps with destination markers
/// Implements dark theme styling with custom markers and clustering
class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  MapType _currentMapType = MapType.normal;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _showSearchOverlay = false;
  String _searchQuery = '';
  LatLng? _selectedLocation;
  bool _mapLoaded = false;
  List<Map<String, dynamic>> _destinations = [];

  static const String _darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#242f3e"
      }
    ]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#263c3f"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#6b9a76"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#38414e"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#212a37"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#9ca5b3"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#746855"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#1f2835"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#f3d19c"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2f3948"
      }
    ]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d59563"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#515c6d"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "color": "#17263c"
      }
    ]
  }
]
''';

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      await _getCurrentLocation();
      await _loadDestinations();
      await _createMarkers();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Unable to load map. Please check location permissions.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await DatabaseHelper.instance.getAllDestinations();
      setState(() {
        _destinations = destinations;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading destinations: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {}
  }

  Future<void> _createMarkers() async {
    _markers.clear();

    for (var destination in _destinations) {
      final marker = Marker(
        markerId: MarkerId(destination["id"].toString()),
        position: LatLng(
          destination["latitude"] as double,
          destination["longitude"] as double,
        ),
        infoWindow: InfoWindow(
          title: destination["name"] as String,
          snippet: destination["description"] as String,
          onTap: () => _navigateToDetail(destination),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        onTap: () => _onMarkerTapped(destination),
      );
      _markers.add(marker);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onMarkerTapped(Map<String, dynamic> destination) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedLocation = LatLng(
        destination["latitude"] as double,
        destination["longitude"] as double,
      );
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
    );
  }

  void _navigateToDetail(Map<String, dynamic> destination) {
    Navigator.pushNamed(
      context,
      '/destination-detail-screen',
      arguments: destination,
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapController?.setMapStyle(_darkMapStyle);
    setState(() {
      _mapLoaded = true;
      _isLoading = false;
    });
    _fitAllMarkers();
  }

  void _fitAllMarkers() {
    if (_markers.isEmpty) {
      // If no markers, center on current position or default location
      if (_currentPosition != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            12,
          ),
        );
      }
      return;
    }

    LatLngBounds bounds;
    List<LatLng> positions = _markers.map((m) => m.position).toList();

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (var pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _toggleMapType() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _centerOnUserLocation() async {
    HapticFeedback.lightImpact();

    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15,
        ),
      );
    } else {
      await _getCurrentLocation();
      if (_currentPosition != null && mounted) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to get current location'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  void _showDestinationList() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DestinationListSheetWidget(
        destinations: _destinations,
        onDestinationSelected: (destination) {
          Navigator.pop(context);
          _onMarkerTapped(destination);
        },
      ),
    );
  }

  void _toggleSearchOverlay() {
    HapticFeedback.lightImpact();
    setState(() => _showSearchOverlay = !_showSearchOverlay);
  }

  void _onSearchQueryChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onDestinationSelected(Map<String, dynamic> destination) {
    _onMarkerTapped(destination);
    setState(() {
      _showSearchOverlay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: 'Map View',
        variant: CustomAppBarVariant.standard,
        actions: [
          CustomAppBarAction(
            icon: Icons.search,
            onPressed: _toggleSearchOverlay,
            tooltip: 'Search locations',
          ),
          CustomAppBarAction(
            icon: Icons.list,
            onPressed: _showDestinationList,
            tooltip: 'View destination list',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading map...',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : !_mapLoaded
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: theme.colorScheme.error,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Unable to load map. Please check your internet connection and API key.',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _mapLoaded = false;
                          });
                          _initializeMap();
                        },
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    GoogleMap(
                      key: ValueKey(_isLoading),
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _currentPosition != null
                            ? LatLng(_currentPosition!.latitude,
                                _currentPosition!.longitude)
                            : LatLng(-7.4297, 109.2401), // Default: Purwokerto
                        zoom: 12,
                      ),
                      markers: _markers,
                      mapType: _currentMapType,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                      onLongPress: (LatLng location) async {
                        HapticFeedback.mediumImpact();
                        final result = await Navigator.pushNamed(
                          context,
                          '/add-destination-screen',
                          arguments: {
                            'latitude': location.latitude,
                            'longitude': location.longitude,
                          },
                        );
                        if (result == true && mounted) {
                          setState(() => _isLoading = true);
                          await _loadDestinations();
                          await _createMarkers();
                          setState(() => _isLoading = false);
                        }
                      },
                    ),
                    if (_showSearchOverlay)
                      SearchOverlayWidget(
                        searchQuery: _searchQuery,
                        onSearchQueryChanged: _onSearchQueryChanged,
                        onDestinationSelected: _onDestinationSelected,
                        onClose: _toggleSearchOverlay,
                      ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: MapControlsWidget(
                        currentMapType: _currentMapType,
                        onToggleMapType: _toggleMapType,
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _centerOnUserLocation,
                        tooltip: 'My Location',
                        child: CustomIconWidget(
                          iconName: 'my_location',
                          color: theme.colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 2,
        onTap: (index) {
          if (index != 2) {
            CustomBottomBarNavigation.navigateToIndex(context, index);
          }
        },
      ),
    );
  }
}
