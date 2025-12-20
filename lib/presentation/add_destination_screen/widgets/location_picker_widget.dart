import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart'; // Pastikan package ini ada di pubspec.yaml

// Import service yang sudah Anda buat sebelumnya
import '../../../services/place_search_service.dart';

/// Widget untuk memilih lokasi dari map
class LocationPickerWidget extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerWidget({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerWidget> createState() => _LocationPickerWidgetState();
}

class _LocationPickerWidgetState extends State<LocationPickerWidget> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  LatLng _currentCenter = const LatLng(-7.4297, 109.2401);
  bool _isLoading = true;
  final Set<Marker> _markers = {};

  // --- SEARCH VARIABLES ---
  final _searchController = TextEditingController();
  List<PlaceSuggestion> _placeSuggestions = [];
  final _placeService =
      PlaceSearchService('AIzaSyCkknVRZSvyOd9CIxu1PTXsJu5LNjqjNkY');
  final _uuid = const Uuid();
  String _sessionToken = '12345';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _searchController.addListener(_onSearchChanged); // Listener untuk search
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose(); // Dispose controller search
    super.dispose();
  }

  // --- SEARCH LOGIC ---
  void _onSearchChanged() {
    if (_sessionToken.isEmpty) {
      setState(() {
        _sessionToken = _uuid.v4();
      });
    }
    if (_searchController.text.length > 2) {
      _fetchSuggestions(_searchController.text);
    } else {
      setState(() {
        _placeSuggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _fetchSuggestions(String input) async {
    try {
      final suggestions =
          await _placeService.fetchSuggestions(input, _sessionToken);
      if (mounted) {
        setState(() {
          _placeSuggestions = suggestions;
          _isSearching = true;
        });
      }
    } catch (e) {
      print('Search Error: $e');
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

      // Pindahkan kamera map
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 17),
      );

      // Set marker dan state
      _onMapTap(location);

      setState(() {
        _searchController.clear();
        _placeSuggestions = [];
        _isSearching = false;
        _sessionToken = ''; // Reset token
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load place details: $e')),
        );
      }
    }
  }
  // -----------------------------

  Future<void> _initializeLocation() async {
    if (widget.initialLocation != null) {
      setState(() {
        _currentCenter = widget.initialLocation!;
        _selectedLocation = widget.initialLocation;
        _isLoading = false;
      });
      _updateMarker(_selectedLocation!);
    } else {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Location timeout'),
        );

        if (mounted) {
          setState(() {
            _currentCenter = LatLng(position.latitude, position.longitude);
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error getting location: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_selectedLocation != null) {
      _updateMarker(_selectedLocation!);
    }
  }

  void _onMapTap(LatLng location) {
    setState(() {
      _selectedLocation = location;
    });
    _updateMarker(location);
  }

  void _updateMarker(LatLng location) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Selected Location',
            snippet:
                '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
          ),
        ),
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoading = true);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final location = LatLng(position.latitude, position.longitude);

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );

      _onMapTap(location);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmLocation() {
    if (_selectedLocation != null) {
      Navigator.pop(context, _selectedLocation);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a location on the map'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Pick Location'),
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: Text(
              'CONFIRM',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Map (Existing)
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            )
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentCenter,
                zoom: 15,
              ),
              markers: _markers,
              onTap: _onMapTap,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: MapType.normal,
            ),

          // 2. SEARCH BAR & SUGGESTIONS
          // Kita letakkan di atas Map menggunakan Positioned
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search places...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _placeSuggestions = [];
                                  _isSearching = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Suggestions List
                if (_isSearching && _placeSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _placeSuggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final item = _placeSuggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on,
                              size: 20,
                              color: Color.fromARGB(255, 255, 102, 102)),
                          title: Text(
                            item.description,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onSuggestionSelected(item),
                          visualDensity: VisualDensity.compact,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. Selected location info card
          if (_selectedLocation != null && !_isLoading)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Selected Location',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. My location button
          Positioned(
            bottom: 26,
            right: 16,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              tooltip: 'My Location',
              child: Icon(
                Icons.my_location,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),

          // 5. Instructions (Existing)
          if (_selectedLocation == null && !_isLoading)
            Positioned(
              bottom: 24,
              left: 16,
              right: 80,
              child: Card(
                color: theme.colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap on the map to select a location',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
