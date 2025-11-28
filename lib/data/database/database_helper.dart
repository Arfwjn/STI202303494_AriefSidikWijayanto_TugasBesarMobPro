// lib/data/database/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // 1. Singleton Pattern: Memastikan hanya ada satu instance DB Helper
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  // 2. Getter untuk mendapatkan instance database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 3. Inisialisasi Database
  Future<Database> _initDatabase() async {
    // Mendapatkan path lengkap untuk database
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'travel_db.db'); // Nama file DB kita

    return await openDatabase(
      path,
      version: 1, // Versi 1
      onCreate: _onCreate,
    );
  }

  // 4. Proses Pembuatan Tabel (SQL DDL)
  Future<void> _onCreate(Database db, int version) async {
    // Query DDL (Data Definition Language) untuk membuat tabel destinations
    const String createTableQuery = '''
      CREATE TABLE destinations(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        date_added TEXT NOT NULL,
        category TEXT
      )
    ''';
    await db.execute(createTableQuery);
  }
}
