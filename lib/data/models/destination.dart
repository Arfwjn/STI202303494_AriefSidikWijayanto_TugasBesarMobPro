// lib/data/models/destination.dart

class Destination {
  // Semua properti harus sesuai dengan skema DB (Langkah 3)
  final int? id; // Nullable, karena ID dibuat otomatis oleh DB saat insert
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final String dateAdded; // Disimpan sebagai String ISO8601
  final String category;

  // Konstruktor utama
  Destination({
    this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.dateAdded,
    required this.category,
  });

  // Metode untuk mengkonversi Model menjadi Map (untuk disimpan ke DB)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'date_added': dateAdded,
      'category': category,
    };
  }

  // Metode static untuk membuat Model dari Map (saat diambil dari DB)
  factory Destination.fromMap(Map<String, dynamic> map) {
    return Destination(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      // Pastikan konversi ke double/String yang benar
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      dateAdded: map['date_added'] as String,
      category: map['category'] as String,
    );
  }
}
