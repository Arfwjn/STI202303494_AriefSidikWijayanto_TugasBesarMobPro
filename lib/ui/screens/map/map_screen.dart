// lib/ui/screens/map/map_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../data/models/destination.dart';
import '../../../providers/destination_provider.dart';

class MapScreen extends StatefulWidget {
  static const routeName = '/map';
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controller Opsional jika diperlukan interaksi lanjutan
  GoogleMapController? mapController;
  BitmapDescriptor customIcon = BitmapDescriptor.defaultMarker;

  // Fungsi untuk menghitung titik tengah peta (center)
  LatLngBounds _calculateBounds(List<Destination> destinations) {
    if (destinations.isEmpty) {
      // Default bounds jika tidak ada data (sekitar Indonesia)
      return LatLngBounds(
        southwest: const LatLng(-11.0, 95.0),
        northeast: const LatLng(6.0, 141.0),
      );
    }

    double minLat = destinations.first.latitude;
    double maxLat = destinations.first.latitude;
    double minLon = destinations.first.longitude;
    double maxLon = destinations.first.longitude;

    for (var dest in destinations) {
      minLat = minLat < dest.latitude ? minLat : dest.latitude;
      maxLat = maxLat > dest.latitude ? maxLat : dest.latitude;
      minLon = minLon < dest.longitude ? minLon : dest.longitude;
      maxLon = maxLon > dest.longitude ? maxLon : dest.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  // Fungsi untuk menggerakkan kamera ke batas semua marker
  void _setCameraToFitMarkers(List<Destination> destinations) {
    if (destinations.isEmpty) return;

    // Memberikan delay agar controller benar-benar siap
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(destinations),
            50.0, // Padding
          ),
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  // Metode untuk memuat gambar kustom sebagai Marker Icon
  void _loadCustomMarker() async {
    try {
      // Ukuran yang sesuai
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/custom_pin.png', // Ganti dengan path aset Anda
      );
      if (mounted) {
        setState(() {
          customIcon = icon;
        });
      }
    } catch (e) {
      // If loading fails, use default marker and log error
      debugPrint('Error loading custom marker: $e');
      if (mounted) {
        setState(() {
          customIcon = BitmapDescriptor.defaultMarker;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DestinationProvider>(
      builder: (context, provider, child) {
        final destinationList = provider.destinations;

        // 1. Siapkan Markers Wajib
        final Set<Marker> markers = destinationList.map((dest) {
          return Marker(
            markerId: MarkerId(dest.id.toString()),
            position: LatLng(dest.latitude, dest.longitude),
            infoWindow: InfoWindow(title: dest.name, snippet: dest.category),
            // Gunakan icon kustom yang sudah dimuat
            icon: customIcon,
          );
        }).toSet();

        // Lokasi awal (Jika kosong, gunakan Jakarta, jika ada, gunakan yang pertama)
        final initialPosition = destinationList.isNotEmpty
            ? LatLng(
                destinationList.first.latitude,
                destinationList.first.longitude,
              )
            : const LatLng(-6.2088, 106.8456);

        // 2. Tampilkan Google Map with error handling
        return FutureBuilder(
          future: Future.delayed(Duration.zero), // Allow map to load
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              try {
                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: destinationList.isEmpty
                        ? 8.0
                        : 12.0, // Zoom lebih dekat jika ada data
                  ),
                  markers: markers,
                  // --- Interaktivitas Penuh Wajib ---
                  zoomControlsEnabled: true,
                  scrollGesturesEnabled: true,
                  rotateGesturesEnabled: true,

                  // Dijalankan saat peta pertama kali dibuat
                  onMapCreated: (controller) {
                    mapController = controller;
                    // Panggil fungsi untuk menyesuaikan tampilan ke batas semua marker
                    _setCameraToFitMarkers(destinationList);
                  },
                );
              } catch (e) {
                // If map fails to load, show error message
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load map. Please check your internet connection and API key.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // Try to reload the map
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}
