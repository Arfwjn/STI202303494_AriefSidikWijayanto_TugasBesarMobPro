# Travvel - Aplikasi Pengelola Destinasi Perjalanan

Aplikasi mobile berbasis Flutter untuk mengelola destinasi perjalanan dengan fitur navigasi rute real-time dan pencarian lokasi menggunakan Google Maps APIs.

---

## 📱 Fitur Utama

### Pengelolaan Destinasi

- Tambah, edit, dan hapus destinasi perjalanan
- Menyimpan detail destinasi (nama, deskripsi, koordinat, foto, jam operasional)
- Tampilan list dan map view untuk semua destinasi
- Filter dan pencarian destinasi
- Share destinasi ke aplikasi lain
- Random pick untuk rekomendasi destinasi

### Peta Interaktif

- Tampilkan semua destinasi di Google Maps
- Navigasi rute real-time ke Google Maps
- Kalkulasi jarak pengguna dengan lokasi destinasi
- Pelacakan lokasi live
- Pilih lokasi dari peta dengan fitur search
- Mini map preview di detail destinasi

### Pencarian Cerdas

- Pencarian destinasi dari database lokal
- Integrasi Google Places API untuk menemukan lokasi baru
- Autocomplete suggestions saat mengetik

### Manajemen Foto

- Tambah foto dari kamera atau galeri
- Penyimpanan lokal untuk akses offline
- Preview foto di detail destinasi

### Layanan Lokasi

- Pilih lokasi dari peta dengan pencarian
- Gunakan lokasi GPS saat ini
- Input koordinat manual
- Location picker dengan autocomplete

### Fitur Tambahan

- Statistik destinasi (total, dengan foto, terbaru, terlama)
- Sort berdasarkan nama atau tanggal ditambahkan
- Export data destinasi ke text file
- Date picker untuk tanggal kunjungan
- Speed dial FAB untuk quick actions

---

## Arsitektur Aplikasi

### Tech Stack

- **Framework**: Flutter 3.29.2
- **Bahasa**: Dart 3.7.2
- **State Management**: Stateful Widgets
- **Database**: SQLite (sqflite)
- **Maps**: Google Maps Flutter
- **HTTP Client**: Dio & HTTP
- **UI Framework**: Sizer (Responsive Design)

### Struktur Proyek

```
travvel/
├── android/                    # Platform Android
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   └── kotlin/
│   │   └── build.gradle.kts
│   └── local.properties       # Google Maps API Key (gitignored)
│
├── lib/
│   ├── core/                  # Core utilities
│   │   └── app_export.dart
│   │
│   ├── presentation/          # UI Screens
│   │   ├── splash_screen/
│   │   ├── home_screen/
│   │   ├── add_destination_screen/
│   │   ├── edit_destination_screen/
│   │   ├── destination_detail_screen/
│   │   └── map_view_screen/
│   │
│   ├── services/              # Business Logic
│   │   ├── database_helper.dart
│   │   ├── directions_service.dart
│   │   └── place_search_service.dart
│   │
│   ├── routes/                # Navigation
│   │   └── app_routes.dart
│   │
│   ├── theme/                 # Styling
│   │   └── app_theme.dart
│   │
│   ├── widgets/               # Reusable Components
│   │   ├── custom_app_bar.dart
│   │   ├── custom_bottom_bar.dart
│   │   ├── custom_icon_widget.dart
│   │   └── custom_image_widget.dart
│   │
│   └── main.dart              # Entry point
│
├── assets/
│   └── images/                # App assets
│
├── pubspec.yaml               # Dependencies
└── README.md                  # Dokumentasi ini
```

---

## Persyaratan Sistem

### Persyaratan Hardware

- **OS**: Windows 10+, macOS 10.14+, atau Linux
- **RAM**: Minimum 4GB (8GB+ direkomendasikan)
- **Storage**: 500MB ruang kosong
- **Internet**: Diperlukan untuk API calls

### Persyaratan Software

- Flutter SDK 3.29.2
- Dart SDK 3.7.2
- Android Studio / VS Code dengan Flutter extensions
- Android SDK (untuk development Android)
- Xcode (untuk development iOS, hanya macOS)

### Persyaratan API

Google Maps API Key dengan API berikut diaktifkan:

- Maps SDK for Android
- Directions API
- Places API

**Catatan Penting**: Google Cloud Billing Account aktif diperlukan untuk menggunakan API

---

## Instalasi dan Setup

### 1. Clone Repository

```bash
git clone https://github.com/Arfwjn/STI202303494_AriefSidikWijayanto_TugasBesarMobPro
cd travvel
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Konfigurasi Google Maps API Key

#### Untuk Android:

1. Buat file `android/local.properties` (jika belum ada)
2. Tambahkan Google Maps API Key:

```properties
flutter.sdk=/path/to/flutter/sdk
googleMapsApiKey=YOUR_API_KEY_HERE
```

3. API Key akan otomatis diinjeksi ke `AndroidManifest.xml` melalui `build.gradle.kts`

#### Alternatif (Hardcode):

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

### 4. Jalankan Aplikasi

```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

---

## Dependencies Utama

```yaml
dependencies:
  # UI & Design
  sizer: ^3.1.3 # Responsive design
  google_fonts: ^6.1.0 # Custom fonts
  flutter_svg: ^2.0.9 # SVG support
  cached_network_image: ^3.3.1 # Image caching
  fl_chart: ^1.1.0 # Charts

  # Maps & Location
  google_maps_flutter: ^2.5.3 # Google Maps
  geolocator: ^14.0.2 # GPS location
  permission_handler: ^12.0.1 # Permissions

  # Database & Storage
  sqflite: ^2.3.0 # SQLite database
  shared_preferences: ^2.2.2 # Local storage
  path_provider: ^2.1.2 # File paths

  # Network
  dio: ^5.4.0 # HTTP client
  http: ^1.2.0 # HTTP requests
  connectivity_plus: ^7.0.0 # Network status

  # Features
  image_picker: ^1.0.4 # Camera & gallery
  url_launcher: ^6.2.2 # External URLs
  share_plus: ^10.0.0 # Share content
  intl: ^0.19.0 # Internationalization
  uuid: ^4.3.3 # UUID generator
  flutter_slidable: ^4.0.3 # Swipe actions
  fluttertoast: ^9.0.0 # Toast messages
```

---

## Tema dan Desain

### Color Palette - Deep Space Electric

- **Primary Surface**: `#1A1A2E` (Dark Navy)
- **Secondary Surface**: `#252547` (Deeper Navy)
- **Electric Accent**: `#00D4FF` (Cyan Blue)
- **Success State**: `#00FF88` (Neon Green)
- **Error State**: `#FF4757` (Coral Red)

### Typography

(Opsional)

- **Headings**: Poppins (600-700 weight)
- **Body Text**: Inter (300-500 weight)
- **Labels**: Poppins (400-500 weight)

---

## Permissions

Aplikasi memerlukan permission berikut:

### Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

---

## Fitur Per Screen

### 1. Home Screen

- List semua destinasi dengan foto
- Search bar untuk filter
- Sort berdasarkan nama/tanggal
- Swipe actions (edit, delete)
- Speed dial FAB dengan:
  - Add Destination
  - Statistics
  - Random Pick
  - Share All
- Long press untuk context menu

### 2. Add/Edit Destination Screen

- Form input lengkap
- Photo picker (camera/gallery)
- Date picker untuk tanggal kunjungan
- Time picker untuk jam operasional
- Location picker dengan:
  - Use current location (GPS)
  - Pick from map dengan search
  - Manual coordinate input
- Mini map preview
- Real-time validation

### 3. Destination Detail Screen

- Hero image dengan gradient overlay
- Informasi lengkap destinasi
- Mini map preview (interactive)
- Action buttons:
  - View on Map
  - Show Route & Navigate
- Edit/Delete via menu
- Copy coordinates dengan long press

### 4. Map View Screen

- Tampilan semua destinasi di map
- Search bar dengan Places API autocomplete
- Tap marker untuk fokus destinasi
- Tap peta untuk add destinasi baru
- Bottom sheet list destinasi
- Toggle map type (normal/satellite)
- Center to user location
- Distance calculation

### 5. Route Viewer

- Straight-line distance calculation
- Direct navigation ke Google Maps
- Real-time location tracking
- Refresh location button

---

## Fitur Pencarian

### Database Search

- Pencarian berdasarkan nama destinasi
- Case-insensitive search
- Instant results

### Places API Search

- Autocomplete suggestions
- Search sesion management
- Place details dengan koordinat
- Support untuk POI (Points of Interest)

---

## Database Schema

### Table: `destinations`

```sql
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
```

### CRUD Operations

- `insertDestination()` - Tambah destinasi baru
- `getAllDestinations()` - Ambil semua destinasi
- `getDestination(id)` - Ambil destinasi by ID
- `updateDestination(id, data)` - Update destinasi
- `deleteDestination(id)` - Hapus destinasi
- `searchDestinations(query)` - Cari destinasi

---

## Google Maps Integration

### Maps SDK for Android

- Menampilkan peta interaktif
- Custom markers untuk destinasi
- Camera controls dan animations
- Map type switching (normal/satellite)

### Directions API

(masih dalam proses pengembangan)

- Real-time route
- Distance matrix
- Polyline decoding untuk rute
- Duration estimation

### Places API

- Autocomplete predictions
- Place details
- Location coordinates
- POI information

---

## Known Issues & Limitations

### Current Limitations

1. **Offline Mode**: Fitur peta dan navigasi memerlukan koneksi internet
2. **Photo Storage**: Foto disimpan lokal, tidak ada cloud backup
3. **Multi-Language**: Saat ini hanya mendukung Bahasa Indonesia dan Inggris
4. **Platform**: Optimized untuk Android, iOS belum ditest sepenuhnya

### Planned Features

- [ ] Cloud sync untuk backup data
- [ ] Offline maps dengan cache
- [ ] Multi-language support lengkap
- [ ] Dark/Light theme toggle
- [ ] Export to PDF
- [ ] Trip planner dengan multiple destinations
- [ ] Weather integration
- [ ] Photo gallery dengan multiple images
- [ ] Categories untuk destinasi

---

## Troubleshooting

### Google Maps tidak muncul

1. Periksa API Key di `AndroidManifest.xml`
2. Pastikan Maps SDK for Android sudah diaktifkan
3. Periksa billing account Google Cloud aktif
4. Cek log Android Studio untuk error details

### Location permission ditolak

1. Buka Settings → Apps → Travvel → Permissions
2. Enable Location permission
3. Restart aplikasi

### Build gagal

```bash
# Clean build
flutter clean
flutter pub get
flutter run
```

### Database error

```bash
# Uninstall app untuk reset database
flutter clean
flutter run
```

---

## License

Proyek ini dibuat untuk keperluan educational dan portfolio.

---

## Developer

**Nama Developer**

- Email: ariefsidik2016@gmail.com
- GitHub: @Arfwjn

---

## Acknowledgments

- Google Maps Platform untuk Maps, Directions, dan Places APIs
- Flutter team untuk framework yang luar biasa
- Material Design untuk design guidelines
- Open source community untuk packages yang digunakan

---

## Support

Jika menemukan bug atau ingin request fitur baru:

1. Buka issue di GitHub repository
2. Kirim email ke developer
3. Fork repository dan buat pull request

---
