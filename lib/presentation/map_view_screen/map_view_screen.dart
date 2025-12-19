import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/destination_list_sheet_widget.dart';
import './widgets/map_controls_widget.dart';
import './widgets/search_overlay_widget.dart';

/// Map View Screen - Interactive Google Maps with destination markers
/// Improved error handling and initialization
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
  bool _mapCreated = false;
  List<Map<String, dynamic>> _destinations = [];
  String _errorMessage = '';
  Map<String, dynamic>? _focusDestination;

  // Default location (Purwokerto, Indonesia)
  static const LatLng _defaultLocation = LatLng(-7.4297, 109.2401);

  // Completer for map creation
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    debugPrint('MapViewScreen: Initializing...');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get arguments if available
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('focusDestination')) {
      _focusDestination = args['focusDestination'] as Map<String, dynamic>?;
    }

    // Initialize map only once
    if (_destinations.isEmpty && !_isLoading && _errorMessage.isEmpty) {
      return;
    }

    if (_destinations.isEmpty) {
      _initializeMap();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    debugPrint('MapViewScreen: Starting initialization');

    try {
      // Step 1: Check connectivity
      debugPrint('MapViewScreen: Checking connectivity...');
      final hasConnection = await _checkConnectivity();

      if (!hasConnection) {
        _showError(
            'No internet connection. Please enable WiFi or mobile data.');
        return;
      }

      debugPrint('MapViewScreen: Connectivity OK');

      // Step 2: Load destinations from database
      debugPrint('MapViewScreen: Loading destinations...');
      await _loadDestinations();
      debugPrint('MapViewScreen: Loaded ${_destinations.length} destinations');

      // Step 3: Get current location (non-blocking)
      debugPrint('MapViewScreen: Getting location...');
      _getCurrentLocationAsync();

      // Step 4: Create markers
      debugPrint('MapViewScreen: Creating markers...');
      await _createMarkers();

      // Mark as ready
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('MapViewScreen: Initialization complete');
      }
    } catch (e, stackTrace) {
      debugPrint('MapViewScreen: Initialization error: $e');
      debugPrint('MapViewScreen: Stack trace: $stackTrace');
      _showError('Failed to initialize map: ${e.toString()}');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      debugPrint('MapViewScreen: Connectivity result: $connectivityResult');

      // Check if connected to WiFi or mobile data
      return connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
    } catch (e) {
      debugPrint('MapViewScreen: Connectivity check error: $e');
      // Assume connected if check fails
      return true;
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await DatabaseHelper.instance.getAllDestinations();
      if (mounted) {
        setState(() {
          _destinations = destinations;
        });
      }
    } catch (e) {
      debugPrint('MapViewScreen: Error loading destinations: $e');
      // Don't fail the whole map initialization if destinations fail
      if (mounted) {
        setState(() {
          _destinations = [];
        });
      }
    }
  }

  Future<void> _getCurrentLocationAsync() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('MapViewScreen: Location services disabled');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('MapViewScreen: Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('MapViewScreen: Location permission permanently denied');
        return;
      }

      // Get current position with timeout
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('MapViewScreen: Location timeout, using default');
          throw TimeoutException('Location timeout');
        },
      );

      debugPrint(
          'MapViewScreen: Got location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      debugPrint('MapViewScreen: Error getting location: $e');
      // Continue without current location
    }
  }

  Future<void> _createMarkers() async {
    _markers.clear();

    for (var destination in _destinations) {
      try {
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
      } catch (e) {
        debugPrint(
            'MapViewScreen: Error creating marker for ${destination["id"]}: $e');
      }
    }

    if (mounted) {
      setState(() {});
    }

    debugPrint('MapViewScreen: Created ${_markers.length} markers');
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
    debugPrint('MapViewScreen: onMapCreated called');

    if (!_controller.isCompleted) {
      _controller.complete(controller);
    }

    setState(() {
      _mapController = controller;
      _mapCreated = true;
      _errorMessage = '';
    });

    debugPrint('MapViewScreen: Map created successfully');

    // Fit markers after a short delay to ensure map is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _mapCreated) {
        if (_focusDestination != null) {
          // Focus on specific destination
          _focusOnDestination(_focusDestination!);
        } else {
          // Fit all markers
          _fitAllMarkers();
        }
      }
    });
  }

  void _focusOnDestination(Map<String, dynamic> destination) {
    if (_mapController == null || !_mapCreated) {
      debugPrint(
          'MapViewScreen: Cannot focus on destination - controller not ready');
      return;
    }

    try {
      final location = LatLng(
        destination['latitude'] as double,
        destination['longitude'] as double,
      );

      debugPrint(
          'MapViewScreen: Focusing on destination: ${destination['name']}');

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );

      setState(() {
        _selectedLocation = location;
      });
    } catch (e) {
      debugPrint('MapViewScreen: Error focusing on destination: $e');
    }
  }

  void _fitAllMarkers() {
    if (_mapController == null || !_mapCreated) {
      debugPrint('MapViewScreen: Cannot fit markers - controller not ready');
      return;
    }

    try {
      if (_markers.isEmpty) {
        // No markers, center on current position or default
        final targetLocation = _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation;

        debugPrint('MapViewScreen: No markers, centering on $targetLocation');

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(targetLocation, 12),
        );
        return;
      }

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

      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      debugPrint('MapViewScreen: Fitting bounds: $bounds');

      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50),
      );
    } catch (e) {
      debugPrint('MapViewScreen: Error fitting markers: $e');
    }
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
      // Try to get location again
      setState(() => _isLoading = true);
      await _getCurrentLocationAsync();
      setState(() => _isLoading = false);

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
              content: Text(
                  'Unable to get current location. Please enable location services.'),
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

  void _showError(String message) {
    debugPrint('MapViewScreen: Error: $message');
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _mapCreated = false;
    });
    _initializeMap();
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
            onPressed: _mapCreated ? _toggleSearchOverlay : () {},
            tooltip: 'Search locations',
          ),
          CustomAppBarAction(
            icon: Icons.list,
            onPressed: _showDestinationList,
            tooltip: 'View destination list',
          ),
        ],
      ),
      body: _buildBody(theme),
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

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingScreen(theme);
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorScreen(theme);
    }

    return _buildMapView(theme);
  }

  Widget _buildLoadingScreen(ThemeData theme) {
    return Center(
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
          SizedBox(height: 8),
          Text(
            'Please wait',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Unable to Load Map',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(ThemeData theme) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentPosition != null
                ? LatLng(
                    _currentPosition!.latitude, _currentPosition!.longitude)
                : _defaultLocation,
            zoom: 12,
          ),
          markers: _markers,
          mapType: _currentMapType,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          minMaxZoomPreference: MinMaxZoomPreference(2, 20),
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
    );
  }
}
