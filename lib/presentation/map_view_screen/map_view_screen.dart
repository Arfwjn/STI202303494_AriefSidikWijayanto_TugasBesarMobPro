import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../services/place_search_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/destination_list_sheet_widget.dart';
import './widgets/map_controls_widget.dart';

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

  // -- SEARCH VARIABLES --
  final TextEditingController _searchController = TextEditingController();
  List<PlaceSuggestion> _placeSuggestions = [];
  final _placeService =
      PlaceSearchService('AIzaSyCkknVRZSvyOd9CIxu1PTXsJu5LNjqjNkY');
  final _uuid = const Uuid();
  String _sessionToken = '12345';
  bool _isSearching = false;
  // ----------------------

  LatLng? _selectedLocation;
  bool _mapCreated = false;
  List<Map<String, dynamic>> _destinations = [];
  String _errorMessage = '';
  Map<String, dynamic>? _focusDestination;

  LatLng? _tappedLocation;
  Marker? _temporaryMarker;

  bool _isDisposed = false;
  static const LatLng _defaultLocation = LatLng(-7.4297, 109.2401);
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args.containsKey('focusDestination')) {
      _focusDestination = args['focusDestination'] as Map<String, dynamic>?;
    }
    if (_destinations.isEmpty) {
      _initializeMap();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) {
      setState(fn);
    }
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged() {
    if (_sessionToken.isEmpty) {
      _sessionToken = _uuid.v4();
    }
    if (_searchController.text.length > 2) {
      _fetchPlaceSuggestions(_searchController.text);
    } else {
      _safeSetState(() {
        _placeSuggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    try {
      final suggestions =
          await _placeService.fetchSuggestions(input, _sessionToken);
      _safeSetState(() {
        _placeSuggestions = suggestions;
        _isSearching = true;
      });
    } catch (e) {
      debugPrint('Place API Error: $e');
    }
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    try {
      FocusScope.of(context).unfocus(); // Tutup keyboard

      final detail =
          await _placeService.getPlaceDetailFromId(suggestion.placeId);
      final lat = detail['lat'];
      final lng = detail['lng'];
      final location = LatLng(lat, lng);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );

      _onMapTapped(location); // Trigger logika marker sementara

      _safeSetState(() {
        _searchController.clear();
        _placeSuggestions = [];
        _isSearching = false;
        _sessionToken = '';
      });
    } catch (e) {
      debugPrint('Error selecting place: $e');
    }
  }
  // --------------------

  Future<void> _initializeMap() async {
    try {
      final hasConnection = await _checkConnectivity();
      if (!hasConnection) {
        _showError('No internet connection.');
        return;
      }
      await _loadDestinations();
      _getCurrentLocationAsync();
      await _createMarkers();
      _safeSetState(() {
        _isLoading = false;
      });
    } catch (e) {
      _showError('Failed to initialize map: ${e.toString()}');
    }
  }

  Future<bool> _checkConnectivity() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult.contains(ConnectivityResult.wifi) ||
          connectivityResult.contains(ConnectivityResult.mobile) ||
          connectivityResult.contains(ConnectivityResult.ethernet);
    } catch (e) {
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
      _safeSetState(() {
        _destinations = [];
      });
    }
  }

  Future<void> _getCurrentLocationAsync() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _safeSetState(() {
        _currentPosition = position;
      });

      // Jika belum ada marker yang difokuskan, pindah ke lokasi user
      if (_focusDestination == null && _mapCreated && _mapController != null) {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
              LatLng(position.latitude, position.longitude), 15),
        );
      }
    } catch (e) {
      debugPrint('Loc Error: $e');
    }
  }

  void _onMapTapped(LatLng position) {
    HapticFeedback.selectionClick();
    _safeSetState(() {
      _tappedLocation = position;
      _selectedLocation = null;
      _temporaryMarker = Marker(
        markerId: const MarkerId('temp_selection'),
        position: position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "New Location?"),
      );
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
    _clearTemporarySelection();
    final result = await Navigator.pushNamed(
      context,
      '/add-destination-screen',
      arguments: {'initial_lat': lat, 'initial_lng': lng},
    );
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
          position: LatLng(destination["latitude"], destination["longitude"]),
          infoWindow: InfoWindow(
            title: destination["name"],
            snippet: destination["description"],
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
    if (_temporaryMarker != null) newMarkers.add(_temporaryMarker!);
    _safeSetState(() {
      _markers.clear();
      _markers.addAll(newMarkers);
    });

    // Handle Focus Destination (dari Home)
    if (_focusDestination != null && _mapCreated && _mapController != null) {
      Future.delayed(const Duration(milliseconds: 300), () {
        final loc = LatLng(
            _focusDestination!['latitude'], _focusDestination!['longitude']);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 17));
        _mapController?.showMarkerInfoWindow(
            MarkerId(_focusDestination!['id'].toString()));
        _focusDestination = null;
      });
    }
  }

  void _onMarkerTapped(Map<String, dynamic> destination) {
    HapticFeedback.lightImpact();
    _safeSetState(() {
      _tappedLocation = null;
      _temporaryMarker = null;
      _createMarkers();
      _selectedLocation = LatLng(
        destination["latitude"],
        destination["longitude"],
      );
    });
    if (_mapController != null && !_isDisposed && _mapCreated) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );
    }
  }

  void _navigateToDetail(Map<String, dynamic> destination) {
    Navigator.pushNamed(context, '/destination-detail-screen',
        arguments: destination);
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!_controller.isCompleted) _controller.complete(controller);
    _safeSetState(() {
      _mapController = controller;
      _mapCreated = true;
      _errorMessage = '';
    });

    // Initial Fit
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_isDisposed && _mapCreated) {
        if (_focusDestination == null) {
          _fitAllMarkers();
        } else {
          // Logic focus sudah ditangani di _createMarkers
          _createMarkers();
        }
      }
    });
  }

  void _fitAllMarkers() {
    if (_mapController == null || !_mapCreated || _isDisposed) return;
    try {
      if (_markers.isEmpty) {
        final targetLocation = _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : _defaultLocation;
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(targetLocation, 12));
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
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    } catch (e) {
      debugPrint('Fit Error: $e');
    }
  }

  void _toggleMapType() {
    HapticFeedback.lightImpact();
    _safeSetState(() => _currentMapType =
        _currentMapType == MapType.normal ? MapType.satellite : MapType.normal);
  }

  void _centerOnUserLocation() {
    HapticFeedback.lightImpact();
    if (_currentPosition != null && _mapController != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            15),
      );
    } else {
      _getCurrentLocationAsync();
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

  void _showError(String message) {
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
      // Hapus CustomAppBar agar Search Bar bisa melayang (overlay) di atas Map
      body: Stack(
        children: <Widget>[
          // 1. GOOGLE MAP LAYER
          if (_errorMessage.isNotEmpty)
            Center(child: Text(_errorMessage))
          else
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
              onTap: _onMapTapped,
            ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // 2. SEARCH BAR OVERLAY (TOP)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // Search Field Container
                  Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 47, 45, 45),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(255, 246, 244, 244)
                              .withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          color: Color.fromARGB(225, 255, 255, 255)),
                      decoration: InputDecoration(
                        hintText: 'Search map...',
                        hintStyle: TextStyle(
                            color: const Color.fromARGB(255, 255, 255, 255)),
                        prefixIcon: const Icon(Icons.search,
                            color: Color.fromARGB(255, 255, 255, 255)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Color.fromARGB(255, 255, 255, 255)),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _placeSuggestions = [];
                                    _isSearching = false;
                                  });
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
                    ),
                  ),

                  // 3. SEARCH SUGGESTIONS LIST
                  if (_isSearching && _placeSuggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white, // FIX: Background List Putih
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _placeSuggestions.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (context, index) {
                          final item = _placeSuggestions[index];
                          return ListTile(
                            leading: const Icon(Icons.location_on_outlined,
                                color: Color.fromARGB(255, 255, 101, 101)),
                            title: Text(
                              item.description,
                              style: const TextStyle(
                                  color: Colors.black87, // FIX: Teks List Hitam
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                            ),
                            onTap: () => _onSuggestionSelected(item),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. MAP CONTROLS (Layer & List)
          Positioned(
            top: 650,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'layer_toggle',
                  backgroundColor: Colors.white,
                  onPressed: _toggleMapType,
                  child: Icon(Icons.layers, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'list_view',
                  backgroundColor: Colors.white,
                  onPressed: _showDestinationList,
                  child: Icon(Icons.format_list_bulleted,
                      color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),

          // 5. MY LOCATION BUTTON
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'my_loc_btn',
              onPressed: _centerOnUserLocation,
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),

          // 6. SELECTED LOCATION CARD (Bottom Sheet)
          if (_tappedLocation != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 80,
              child: _buildLocationSelectionCard(theme),
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

  Widget _buildLocationSelectionCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                child: const Icon(Icons.close,
                    size: 20, color: Color.fromARGB(255, 255, 255, 255)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_tappedLocation!.latitude.toStringAsFixed(5)}, ${_tappedLocation!.longitude.toStringAsFixed(5)}',
            style: const TextStyle(color: Colors.black87),
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
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
