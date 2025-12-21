import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Widget untuk menampilkan lokasi destinasi dan navigasi langsung ke Google Maps
class RouteViewerWidget extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String destinationName;

  const RouteViewerWidget({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
  });

  @override
  State<RouteViewerWidget> createState() => _RouteViewerWidgetState();
}

class _RouteViewerWidgetState extends State<RouteViewerWidget> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _errorMessage = '';
  final Set<Marker> _markers = {};
  double _distance = 0;
  String _distanceText = '';

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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied';
            _isLoading = false;
          });
          return;
        }
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // Create markers
      _createMarkers();

      // Calculate straight-line distance
      if (_currentPosition != null) {
        _distance = _calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          widget.destinationLat,
          widget.destinationLng,
        );
        _distanceText = '${_distance.toStringAsFixed(2)} km';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing map: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to get current location';
          _isLoading = false;
        });
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  void _createMarkers() {
    _markers.clear();

    // Current location marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('current_location'),
          position:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'You are here',
          ),
        ),
      );
    }

    // Destination marker
    _markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destinationLat, widget.destinationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.destinationName,
          snippet: 'Destination',
        ),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_currentPosition == null || _mapController == null) return;

    try {
      final bounds = LatLngBounds(
        southwest: LatLng(
          _currentPosition!.latitude < widget.destinationLat
              ? _currentPosition!.latitude
              : widget.destinationLat,
          _currentPosition!.longitude < widget.destinationLng
              ? _currentPosition!.longitude
              : widget.destinationLng,
        ),
        northeast: LatLng(
          _currentPosition!.latitude > widget.destinationLat
              ? _currentPosition!.latitude
              : widget.destinationLat,
          _currentPosition!.longitude > widget.destinationLng
              ? _currentPosition!.longitude
              : widget.destinationLng,
        ),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      debugPrint('Error fitting bounds: $e');
    }
  }

  Future<void> _refreshLocation() async {
    await _initializeMap();
  }

  Future<void> _centerOnDestination() async {
    if (_mapController == null) return;

    HapticFeedback.lightImpact();
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(widget.destinationLat, widget.destinationLng),
        15,
      ),
    );
  }

  Future<void> _openGoogleMaps() async {
    HapticFeedback.lightImpact();

    try {
      final String origin = _currentPosition != null
          ? '${_currentPosition!.latitude},${_currentPosition!.longitude}'
          : '';
      final String destination =
          '${widget.destinationLat},${widget.destinationLng}';

      // Google Maps URL with directions
      final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving',
      );

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: Open destination location only
        final Uri fallbackUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$destination',
        );
        if (await canLaunchUrl(fallbackUrl)) {
          await launchUrl(
            fallbackUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          throw 'Could not launch Google Maps';
        }
      }
    } catch (e) {
      debugPrint('Error opening Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to open Google Maps'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Route to Destination'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocation,
            tooltip: 'Refresh',
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
                  const SizedBox(height: 16),
                  const Text('Loading map...'),
                ],
              ),
            )
          : _errorMessage.isNotEmpty
              ? _buildErrorWidget(theme)
              : Stack(
                  children: [
                    GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                            widget.destinationLat, widget.destinationLng),
                        zoom: 12,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapType: MapType.normal,
                    ),

                    // Distance info card
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: theme.colorScheme.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.destinationName,
                                      style: theme.textTheme.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.straighten,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Direct Distance: $_distanceText',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Center on destination button
                    Positioned(
                      bottom: 24,
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: _centerOnDestination,
                        tooltip: 'Center on Destination',
                        heroTag: 'center_btn',
                        child: Icon(
                          Icons.center_focus_strong,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),

                    // Start Navigation button
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 88,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.navigation),
                        label: const Text('Start Navigation'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget(ThemeData theme) {
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
            const SizedBox(height: 16),
            Text(
              'Unable to Load Map',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
