// lib/ui/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// Import StaggeredGrid yang lebih baru (package yang sama, class yang berbeda)
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/models/destination.dart';
import '../../../providers/destination_provider.dart';
import '../map/map_screen.dart';
import '../add_edit/add_edit_screen.dart';

// Helper untuk membangun tampilan setiap kartu destinasi
Widget _buildDestinationCard(BuildContext context, Destination destination) {
  final provider = context.read<DestinationProvider>();

  return Container(
    decoration: AppDecorations.gradientCard(),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                destination.name,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: AppTheme.textDark),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Kategori: ${destination.category}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                destination.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.textGrey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Dikunjungi: ${DateFormat('dd MMM yyyy').format(DateTime.parse(destination.dateAdded))}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  return Container(
    height: 250, // Tinggi Kartu Peta
    decoration: AppDecorations.gradientCard(),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).pushNamed(MapScreen.routeName);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Widget Google Map with error handling
              FutureBuilder(
                future: Future.delayed(Duration.zero),
                builder: (context, snapshot) {
                  try {
                    return GoogleMap(
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
                    );
                  } catch (e) {
                    // If map fails, show placeholder
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.map, size: 48, color: Colors.grey),
                      ),
                    );
                  }
                },
              ),
              // Overlay Interaktif
              Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.2),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite.withOpacity(0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.zoom_in_map,
                        size: 32,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Ketuk untuk Melihat Peta Detail',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DestinationProvider>(
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
              }),
            ],
          ),
        );
      },
    );
  }
}
