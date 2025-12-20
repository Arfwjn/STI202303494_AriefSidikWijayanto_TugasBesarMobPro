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

// FITUR BARU: Variabel untuk 'Tap to Add'
  LatLng? _tappedLocation; // Lokasi yang diklik user
  Marker? _temporaryMarker; // Marker sementara (biasanya warna beda)

  // Flag to track if widget is still mounted
  bool _isDisposed = false;

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
    _isDisposed = true;
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  // Safe method to update state only if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
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
      _safeSetState(() {
        _isLoading = false;
      });
      debugPrint('MapViewScreen: Initialization complete');
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

      return connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
    } catch (e) {
      debugPrint('MapViewScreen: Connectivity check error: $e');
      return true;
    }
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await DatabaseHelper.instance.getAllDestinations();
      _safeSetState(() {
        _destinations = destinations;
      });
    } catch (e) {
      debugPrint('MapViewScreen: Error loading destinations: $e');
      _safeSetState(() {
        _destinations = [];
      });
    }
  }

  Future<void> _getCurrentLocationAsync() async {
    try {
      // 1. Cek Service GPS
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('MapViewScreen: Location services disabled');
        _showError('Location services are disabled. Please enable GPS.');
        return;
      }

      // 2. Cek Permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('MapViewScreen: Location permission denied');
          _showError('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('MapViewScreen: Location permission permanently denied');
        _showError(
            'Location permission is permanently denied. Please enable it in settings.');
        return;
      }

      final lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        _safeSetState(() {
          _currentPosition = lastPosition;
          if (_mapCreated && _mapController != null) {
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                  LatLng(lastPosition.latitude, lastPosition.longitude), 15),
            );
          }
        });
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('MapViewScreen: Location request timed out');
          if (_currentPosition != null) return _currentPosition!;
          throw TimeoutException('Gagal mendapatkan lokasi tepat waktu');
        },
      );

      _safeSetState(() {
        _currentPosition = position;
      });

      debugPrint(
          'MapViewScreen: Got location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');
    } catch (e) {
      debugPrint('MapViewScreen: Error getting location: $e');
      if (_currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Using default location (GPS signal weak)')),
          );
        }
      }
    }
  }

  void _onMapTapped(LatLng position) {
    HapticFeedback.selectionClick();
    debugPrint("Map Tapped at: $position");

    _safeSetState(() {
      // 1. Simpan lokasi yang diklik
      _tappedLocation = position;

      // 2. Reset selected location
      _selectedLocation = null;

      // 3. Buat Marker Sementara
      _temporaryMarker = Marker(
        markerId: const MarkerId('temp_selection'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "New Location?"),
      );

      // 4. Update kumpulan markers
      _createMarkers();
    });

    _mapController?.animateCamera(CameraUpdate.newLatLng(position));
  }

  void _clearTemporarySelection() {
    _safeSetState(() {
      _tappedLocation = null;
      _temporaryMarker = null;
      _createMarkers();
    });
  }

  void _navigateToAddFromMap() async {
    if (_tappedLocation == null) return;

    final lat = _tappedLocation!.latitude;
    final lng = _tappedLocation!.longitude;

    // Reset temporary selection sebelum navigasi
    final selectedPos = _tappedLocation;
    _clearTemporarySelection();

    // Navigasi
    final result = await Navigator.pushNamed(
      context,
      '/add-destination-screen',
      arguments: {
        'initial_lat': lat,
        'initial_lng': lng,
      },
    );

    // Jika berhasil nambah, reload map
    if (result == true) {
      _loadDestinations();
      _createMarkers();
    }
  }

  Future<void> _createMarkers() async {
    Set<Marker> newMarkers = {};

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
        newMarkers.add(marker);
      } catch (e) {
        debugPrint('Error creating marker: $e');
      }
    }

    if (_temporaryMarker != null) {
      newMarkers.add(_temporaryMarker!);
    }

    _safeSetState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });

    if (_focusDestination != null && _mapCreated && _mapController != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _focusOnDestination(_focusDestination!);
        _focusDestination = null;
      });
    }
  }

  void _onMarkerTapped(Map<String, dynamic> destination) {
    HapticFeedback.lightImpact();
    // Saat marker asli diklik, hilangkan temporary marker
    _safeSetState(() {
      _tappedLocation = null;
      _temporaryMarker = null;
      _createMarkers();

      _selectedLocation = LatLng(
        destination["latitude"] as double,
        destination["longitude"] as double,
      );
    });

    // Only animate if controller is available and not disposed
    if (_mapController != null && !_isDisposed && _mapCreated) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    }
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

    _safeSetState(() {
      _mapController = controller;
      _mapCreated = true;
      _errorMessage = '';
    });

    debugPrint('MapViewScreen: Map created successfully');

    // Fit markers after a short delay to ensure map is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed && _mapCreated) {
        if (_focusDestination != null) {
          _focusOnDestination(_focusDestination!);
        } else {
          _fitAllMarkers();
        }
      }
    });
  }

  void _focusOnDestination(Map<String, dynamic> destination) {
    if (_mapController == null || !_mapCreated || _isDisposed) return;
    try {
      final loc = LatLng(destination['latitude'], destination['longitude']);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
      _mapController
          ?.showMarkerInfoWindow(MarkerId(destination['id'].toString()));
    } catch (e) {
      debugPrint('$e');
    }
  }

  void _fitAllMarkers() {
    if (_mapController == null || !_mapCreated || _isDisposed) {
      debugPrint('MapViewScreen: Cannot fit markers - controller not ready');
      return;
    }

    try {
      if (_markers.isEmpty) {
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
    _safeSetState(() => _currentMapType =
        _currentMapType == MapType.normal ? MapType.satellite : MapType.normal);
  }

  void _centerOnUserLocation() async {
    HapticFeedback.lightImpact();

    if (_currentPosition != null &&
        !_isDisposed &&
        _mapCreated &&
        _mapController != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15,
        ),
      );
    } else {
      // Try to get location again
      _safeSetState(() => _isLoading = true);
      await _getCurrentLocationAsync();
      _safeSetState(() => _isLoading = false);

      if (_currentPosition != null &&
          !_isDisposed &&
          _mapCreated &&
          _mapController != null) {
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
    _safeSetState(() => _showSearchOverlay = !_showSearchOverlay);
  }

  void _onSearchQueryChanged(String query) {
    _safeSetState(() => _searchQuery = query);
  }

  void _onDestinationSelected(Map<String, dynamic> destination) {
    _onMarkerTapped(destination);
    _safeSetState(() {
      _showSearchOverlay = false;
    });
  }

  void _showError(String message) {
    debugPrint('MapViewScreen: Error: $message');
    _safeSetState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _retry() {
    _safeSetState(() {
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
    if (_isLoading) return _buildLoadingScreen(theme);
    if (_errorMessage.isNotEmpty) return _buildErrorScreen(theme);
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
          onTap: _onMapTapped,
        ),
        if (_showSearchOverlay)
          SearchOverlayWidget(
            searchQuery: _searchQuery,
            onSearchQueryChanged: _onSearchQueryChanged,
            onDestinationSelected: _onDestinationSelected,
            onClose: _toggleSearchOverlay,
          ),

        // Map Controls (Layer & Type)
        Positioned(
          top: 16,
          right: 16,
          child: MapControlsWidget(
            currentMapType: _currentMapType,
            onToggleMapType: _toggleMapType,
          ),
        ),

        // My Location Button
        Positioned(
          bottom: 24, // Sesuaikan agar tidak tertutup floating box
          right: 16,
          child: FloatingActionButton(
            heroTag: 'my_loc_btn',
            onPressed: _centerOnUserLocation,
            tooltip: 'My Location',
            child: CustomIconWidget(
              iconName: 'my_location',
              color: theme.colorScheme.onPrimary,
              size: 24,
            ),
          ),
        ),

        if (_tappedLocation != null)
          Positioned(
            bottom: 24,
            left: 16,
            right: 80,
            child: _buildLocationSelectionCard(theme),
          ),
      ],
    );
  }

  // Widget Floating Cards
  Widget _buildLocationSelectionCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selected Location',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              InkWell(
                onTap: _clearTemporarySelection,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.close,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on,
                  size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '${_tappedLocation!.latitude.toStringAsFixed(5)}, ${_tappedLocation!.longitude.toStringAsFixed(5)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToAddFromMap,
              icon: const Icon(Icons.add_location_alt, size: 18),
              label: const Text('Add Destination'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
