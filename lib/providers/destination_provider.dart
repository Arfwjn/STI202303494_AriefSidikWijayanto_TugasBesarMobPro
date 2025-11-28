// lib/providers/destination_provider.dart

import 'package:flutter/material.dart';
import '../data/models/destination.dart';
import '../data/repositories/destination_repo.dart';

class DestinationProvider extends ChangeNotifier {
  // 1. State (Data yang akan diakses oleh UI)
  List<Destination> _destinations = [];
  List<Destination> get destinations => _destinations;

  // Instance Repository
  final DestinationRepository _repository = DestinationRepository();

  // 2. Fungsi Inisialisasi/Ambil Data Awal
  // Dipanggil saat aplikasi dimuat pertama kali
  Future<void> loadDestinations() async {
    _destinations = await _repository.getDestinations();
    notifyListeners(); // Memberi tahu UI untuk di-rebuild
  }

  // 3. Fungsi Tambah Data
  Future<void> addDestination(Destination destination) async {
    // Insert ke DB
    final newId = await _repository.insertDestination(destination);

    // Buat objek baru dengan ID dari DB
    final newDestinationWithId = Destination(
      id: newId,
      name: destination.name,
      description: destination.description,
      latitude: destination.latitude,
      longitude: destination.longitude,
      dateAdded: destination.dateAdded,
      category: destination.category,
    );

    // Update state
    _destinations.add(newDestinationWithId);
    notifyListeners(); // Memberi tahu UI
  }

  // 4. Fungsi Hapus Data
  Future<void> deleteDestination(int id) async {
    // Hapus dari DB
    await _repository.deleteDestination(id);

    // Hapus dari state
    _destinations.removeWhere((item) => item.id == id);
    notifyListeners(); // Memberi tahu UI
  }

  // 5. Fungsi Update Data (disederhanakan)
  Future<void> updateDestination(Destination destination) async {
    await _repository.updateDestination(destination);

    // Muat ulang (atau update secara spesifik di state)
    // Untuk menyederhanakan, kita muat ulang penuh:
    await loadDestinations();
  }
}
