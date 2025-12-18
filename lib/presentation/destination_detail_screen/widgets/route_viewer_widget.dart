import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';

/// Widget untuk menampilkan rute dan jarak ke destinasi
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
  final Set<Polyline> _polylines = {};
  double _distance = 0;
  String _estimatedTime = '';

  @override
  void initState() {
    super.initState();
    _initializeRoute();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeRoute() async {
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

      // Calculate distance
      _distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.destinationLat,
        widget.destinationLng,
      );

      // Calculate estimated time (assuming average speed 40 km/h)
      final hours = _distance / 40;
      if (hours < 1) {
        final minutes = (hours * 60).round();
        _estimatedTime = '$minutes min';
      } else {
        final wholeHours = hours.floor();
        final minutes = ((hours - wholeHours) * 60).round();
        _estimatedTime = '${wholeHours}h ${minutes}min';
      }

      // Create markers
      _createMarkers();

      // Create polyline (straight line for simplicity)
      _createPolyline();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load route: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Haversine formula
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
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

  void _createPolyline() {
    if (_currentPosition == null) return;

    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          LatLng(widget.destinationLat, widget.destinationLng),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _fitBounds() {
    if (_currentPosition == null || _mapController == null) return;

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
  }

  Future<void> _refreshLocation() async {
    setState(() => _isLoading = true);
    await _initializeRoute();
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
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
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
                      polylines: _polylines,
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildInfoItem(
                                    theme,
                                    Icons.straighten,
                                    'Distance',
                                    '${_distance.toStringAsFixed(2)} km',
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: theme.dividerColor,
                                  ),
                                  _buildInfoItem(
                                    theme,
                                    Icons.access_time,
                                    'Est. Time',
                                    _estimatedTime,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Start Navigation button
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          // In real app, this would open Google Maps navigation
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Opening navigation...'),
                              action: SnackBarAction(
                                label: 'OK',
                                onPressed: () {},
                              ),
                            ),
                          );
                        },
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

  Widget _buildInfoItem(
      ThemeData theme, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
              'Unable to Load Route',
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
