// lib/ui/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Import StaggeredGrid yang lebih baru (package yang sama, class yang berbeda)
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../data/models/destination.dart';
import '../../../providers/destination_provider.dart';
import '../map/map_screen.dart';
import '../add_edit/add_edit_screen.dart';

// Helper untuk membangun tampilan setiap kartu destinasi
Widget _buildDestinationCard(BuildContext context, Destination destination) {
  final provider = context.read<DestinationProvider>();

  return Card(
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: InkWell(
      onTap: () {
        // Panggil AddEditScreen dan kirim objek Destinasi yang akan diedit
        Navigator.of(context).pushNamed(
          AddEditScreen.routeName,
          arguments: destination, // Kirim data destinasi
        );
      },
      onLongPress: () {
        // --- CRUD DELETE (Wajib) ---
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Destinasi?'),
            content: Text('Anda yakin ingin menghapus ${destination.name}?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Panggil fungsi DELETE dari Provider
                  provider.deleteDestination(destination.id!);
                  Navigator.of(ctx).pop(true);
                  // SnackBar Feedback Wajib
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${destination.name} berhasil dihapus!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              destination.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Kategori: ${destination.category}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.teal,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              destination.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Dikunjungi: ${DateFormat('dd MMM yyyy').format(DateTime.parse(destination.dateAdded))}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    ),
  );
}

// Helper untuk membangun Peta Kartu Interaktif (index 0 di grid)
Widget _buildMapCard(BuildContext context) {
  final destinations = context.watch<DestinationProvider>().destinations;

  // Tentukan posisi kamera awal (Jakarta sebagai default jika kosong)
  LatLng initialPosition = const LatLng(-6.2088, 106.8456);
  if (destinations.isNotEmpty) {
    // Ambil lokasi destinasi pertama sebagai pusat
    initialPosition = LatLng(
      destinations.first.latitude,
      destinations.first.longitude,
    );
  }

  // Siapkan Markers
  final Set<Marker> markers = destinations.map((dest) {
    return Marker(
      markerId: MarkerId(dest.id.toString()),
      position: LatLng(dest.latitude, dest.longitude),
      infoWindow: InfoWindow(title: dest.name, snippet: dest.category),
    );
  }).toSet();

  return Card(
    elevation: 10,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    clipBehavior:
        Clip.antiAlias, // Memastikan Map terpotong rapi sesuai border radius
    child: SizedBox(
      height: 250, // Tinggi Kartu Peta
      child: Stack(
        children: [
          // Widget Google Map Wajib
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 8,
            ),
            markers: markers,
            // Batasi interaksi di Kartu Home Screen
            zoomControlsEnabled: false,
            scrollGesturesEnabled: false,
            // Navigasi ke MapScreen penuh
            onTap: (_) {
              Navigator.of(context).pushNamed(MapScreen.routeName);
            },
          ),
          // Overlay Interaktif
          Container(
            alignment: Alignment.center,
            color: Colors.black.withOpacity(0.3), // Layer transparan
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.zoom_in_map, size: 50, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  'Ketuk untuk Melihat Peta Detail',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Hapus Scaffold, gunakan Column untuk menampung AppBar dan Konten
    return Column(
      children: [
        AppBar(
          title: const Text('Destinasi Wisata Lokal'),
          backgroundColor: Colors.teal,
          automaticallyImplyLeading: false, // Penting karena ini root screen
        ),

        // Expanded memastikan GridView mengambil sisa ruang yang tersedia
        Expanded(
          child: Consumer<DestinationProvider>(
            builder: (context, provider, child) {
              final destinationList = provider.destinations;

              if (destinationList.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text(
                      'Aplikasi siap digunakan! Tambahkan destinasi pertama Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: StaggeredGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8.0,
                  crossAxisSpacing: 8.0,
                  children: [
                    // Map Card
                    StaggeredGridTile.count(
                      crossAxisCellCount: 2,
                      mainAxisCellCount: 1.5,
                      child: _buildMapCard(context),
                    ),
                    // Destinasi Cards
                    ...destinationList.map((destination) {
                      return StaggeredGridTile.fit(
                        crossAxisCellCount: 1,
                        child: _buildDestinationCard(context, destination),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
