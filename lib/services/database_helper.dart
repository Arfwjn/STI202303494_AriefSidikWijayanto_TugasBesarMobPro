import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Database Helper untuk operasi SQLite lokal
/// Implementasi CRUD
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('travvel.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE destinations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        opening_hours TEXT NOT NULL,
        photo_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertDestination(Map<String, dynamic> destination) async {
    final db = await database;
    return await db.insert('destinations', destination);
  }

  Future<List<Map<String, dynamic>>> getAllDestinations() async {
    final db = await database;
    return await db.query(
      'destinations',
      orderBy: 'created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getDestination(int id) async {
    final db = await database;
    final results = await db.query(
      'destinations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateDestination(
      int id, Map<String, dynamic> destination) async {
    final db = await database;
    return await db.update(
      'destinations',
      destination,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDestination(int id) async {
    final db = await database;
    return await db.delete(
      'destinations',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search destinations by name only (not description)
  Future<List<Map<String, dynamic>>> searchDestinations(String query) async {
    final db = await database;
    return await db.query(
      'destinations',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
