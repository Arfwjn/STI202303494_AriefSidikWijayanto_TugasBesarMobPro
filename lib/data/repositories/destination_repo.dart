// CRUD operations for Destination entity

// lib/data/repositories/destination_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../data/models/destination.dart';
import '../../data/database/database_helper.dart';

class DestinationRepository {
  // Mengambil instance Database Helper
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final String _tableName = 'destinations'; // Nama tabel kita

  // 1. CREATE (Tambah Destinasi Baru)
  Future<int> insertDestination(Destination destination) async {
    final db = await _dbHelper.database;
    // Menggunakan insert(), id akan dikembalikan
    return await db.insert(
      _tableName,
      destination.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Jika data sama, timpa
    );
  }

  // 2. READ (Ambil Semua Destinasi)
  Future<List<Destination>> getDestinations() async {
    final db = await _dbHelper.database;
    // Query untuk mengambil semua baris
    final List<Map<String, dynamic>> maps = await db.query(_tableName);

    // Mengkonversi List<Map> menjadi List<Destination>
    return List.generate(maps.length, (i) {
      return Destination.fromMap(maps[i]);
    });
  }

  // 3. UPDATE (Ubah Data Destinasi)
  Future<int> updateDestination(Destination destination) async {
    final db = await _dbHelper.database;
    return await db.update(
      _tableName,
      destination.toMap(),
      where: 'id = ?',
      whereArgs: [destination.id], // ID destinasi yang diupdate
    );
  }

  // 4. DELETE (Hapus Destinasi)
  Future<int> deleteDestination(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }
}
