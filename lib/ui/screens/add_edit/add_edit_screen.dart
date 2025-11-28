// lib/ui/screens/add_edit/add_edit_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart'; // Wajib untuk GPS
import 'package:intl/intl.dart'; // Wajib untuk format tanggal/waktu
import '../../../core/theme.dart';
import '../../../data/models/destination.dart';
import '../../../providers/destination_provider.dart';

class AddEditScreen extends StatefulWidget {
  static const routeName = '/add_edit';
  // Tambahkan argumen untuk menerima data yang akan diedit (opsional)
  final Destination? destinationToEdit;

  const AddEditScreen({super.key, this.destinationToEdit});

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers untuk TextField Wajib
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _categoryController = TextEditingController();

  // State untuk Data
  double? _latitude;
  double? _longitude;
  DateTime? _selectedDateTime; // Kombinasi DatePicker & TimePicker

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Jika ada data yang dikirim (mode EDIT)
    if (widget.destinationToEdit != null) {
      final dest = widget.destinationToEdit!;
      _nameController.text = dest.name;
      _descController.text = dest.description;
      _categoryController.text = dest.category;
      _latitude = dest.latitude;
      _longitude = dest.longitude;
      _selectedDateTime = DateTime.parse(dest.dateAdded);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // Metode A: Menggunakan DatePicker dan TimePicker Wajib
  Future<void> _pickDateAndTime() async {
    // 1. DatePicker Wajib
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null) return;

    // 2. TimePicker Wajib
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // Metode B: Mengambil Lokasi GPS Wajib
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Cek Permission dan Service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Tampilkan Dialog/SnackBar jika Service tidak aktif
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS tidak aktif. Mohon aktifkan layanan lokasi.'),
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Tampilkan feedback jika ditolak permanen
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak.')));
        setState(() => _isLoading = false);
        return;
      }
    }

    // 2. Ambil Lokasi
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isLoading = false;
      });
    } catch (e) {
      // Error handling
      print('Error mengambil lokasi: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveDestination() async {
    if (!_formKey.currentState!.validate() ||
        _latitude == null ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Semua field wajib diisi, termasuk lokasi dan tanggal!',
          ),
        ),
      );
      return;
    }

    // Tentukan apakah ini mode UPDATE atau CREATE
    final bool isUpdating = widget.destinationToEdit != null;

    // Buat objek Destinasi
    final destination = Destination(
      // Jika mode update, gunakan ID yang sudah ada
      id: isUpdating ? widget.destinationToEdit!.id : null,
      name: _nameController.text,
      description: _descController.text,
      latitude: _latitude!,
      longitude: _longitude!,
      dateAdded: _selectedDateTime!.toIso8601String(),
      category: _categoryController.text.isEmpty
          ? 'Umum'
          : _categoryController.text,
    );

    if (isUpdating) {
      // Panggil fungsi UPDATE di Provider
      await context.read<DestinationProvider>().updateDestination(destination);
    } else {
      // Panggil fungsi CREATE di Provider
      await context.read<DestinationProvider>().addDestination(destination);
    }

    // SnackBar Wajib (Feedback setelah simpan)
    final feedbackMessage = isUpdating
        ? 'Destinasi berhasil diubah!'
        : 'Destinasi berhasil disimpan!';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(feedbackMessage)));

    // Kembali ke Home Screen
    Navigator.of(context).pop();
  }

  // (Lanjutan dari _AddEditScreenState)

  @override
  Widget build(BuildContext context) {
    final selectedDateDisplay = _selectedDateTime == null
        ? 'Pilih Tanggal & Waktu'
        : DateFormat('dd/MM/yyyy HH:mm').format(_selectedDateTime!);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.destinationToEdit == null
              ? 'Tambah Destinasi'
              : 'Edit Destinasi',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
      ),
      body: Container(
        color: AppTheme.backgroundLight,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Form Fields Section
                Container(
                  decoration: AppDecorations.gradientCard(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Text Field Wajib: Nama Destinasi
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Destinasi',
                          prefixIcon: Icon(
                            Icons.place,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        validator: (value) =>
                            value!.isEmpty ? 'Nama wajib diisi.' : null,
                      ),
                      const SizedBox(height: 16),
                      // Text Field Wajib: Deskripsi
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi / Catatan',
                          prefixIcon: Icon(
                            Icons.description,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      // Text Field Wajib: Kategori
                      TextFormField(
                        controller: _categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Kategori (misal: Pantai, Gunung)',
                          prefixIcon: Icon(
                            Icons.category,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Date Picker Section
                Container(
                  decoration: AppDecorations.gradientCard(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal Kunjungan:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickDateAndTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.textGrey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedDateDisplay,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              Icon(Icons.edit, color: AppTheme.textGrey),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Location Section
                Container(
                  decoration: AppDecorations.gradientCard(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lokasi GPS:',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                      ),
                      const SizedBox(height: 12),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardWhite,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.textGrey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppTheme.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lat: ${_latitude?.toStringAsFixed(6) ?? 'N/A'}, Lon: ${_longitude?.toStringAsFixed(6) ?? 'N/A'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      // Tombol Ambil Lokasi
                      GestureDetector(
                        onTap: _getCurrentLocation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryBlue.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Ambil Lokasi Saat Ini (GPS)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Tombol Simpan
                ElevatedButton.icon(
                  onPressed: _saveDestination,
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Destinasi'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
