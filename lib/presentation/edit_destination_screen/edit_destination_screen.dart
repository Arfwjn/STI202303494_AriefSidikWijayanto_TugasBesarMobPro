import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../services/database_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../add_destination_screen/widgets/location_picker_widget.dart';
import './widgets/coordinates_section_widget.dart';
import './widgets/form_fields_widget.dart';
import './widgets/photo_section_widget.dart';

class EditDestinationScreen extends StatefulWidget {
  final Map<String, dynamic> destination;

  const EditDestinationScreen({
    super.key,
    required this.destination,
  });

  @override
  State<EditDestinationScreen> createState() => _EditDestinationScreenState();
}

class _EditDestinationScreenState extends State<EditDestinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  String? _currentImagePath;
  String? _newImagePath;
  bool _hasChanges = false;
  bool _isUpdating = false;
  bool _photoRemoved = false;

  // Mini map variables
  GoogleMapController? _miniMapController;
  final Set<Marker> _miniMapMarkers = {};
  bool _hasValidLocation = false;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    _nameController.text = widget.destination['name'] ?? '';
    _descriptionController.text = widget.destination['description'] ?? '';
    _latitudeController.text = widget.destination['latitude']?.toString() ?? '';
    _longitudeController.text =
        widget.destination['longitude']?.toString() ?? '';
    _currentImagePath = widget.destination['photo_path'];

    // Check if we have valid coordinates
    if (_latitudeController.text.isNotEmpty &&
        _longitudeController.text.isNotEmpty) {
      final lat = double.tryParse(_latitudeController.text);
      final lng = double.tryParse(_longitudeController.text);
      if (lat != null &&
          lng != null &&
          lat >= -90 &&
          lat <= 90 &&
          lng >= -180 &&
          lng <= 180) {
        _hasValidLocation = true;
        _updateMiniMapMarker();
      }
    }

    // Parse opening hours from database format
    final openingHours = widget.destination['opening_hours'] as String?;
    if (openingHours != null && openingHours.isNotEmpty) {
      final parts = openingHours.split(' - ');
      if (parts.length == 2) {
        _openingTime = _parseTimeOfDay(parts[0]);
        _closingTime = _parseTimeOfDay(parts[1]);
      }
    }

    _nameController.addListener(_onFormChanged);
    _descriptionController.addListener(_onFormChanged);
    _latitudeController.addListener(_onLocationChanged);
    _longitudeController.addListener(_onLocationChanged);
  }

  void _onLocationChanged() {
    final lat = double.tryParse(_latitudeController.text);
    final lng = double.tryParse(_longitudeController.text);

    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      setState(() {
        _hasValidLocation = true;
        _hasChanges = true;
      });
      _updateMiniMapMarker();
    } else {
      setState(() {
        _hasValidLocation = false;
      });
    }
  }

  void _updateMiniMapMarker() {
    if (!_hasValidLocation) return;

    final lat = double.parse(_latitudeController.text);
    final lng = double.parse(_longitudeController.text);
    final location = LatLng(lat, lng);

    setState(() {
      _miniMapMarkers.clear();
      _miniMapMarkers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });

    // Animate camera to new location
    _miniMapController?.animateCamera(
      CameraUpdate.newLatLngZoom(location, 15),
    );
  }

  TimeOfDay? _parseTimeOfDay(String timeString) {
    try {
      // Parse format like "08:00 AM" or "8:00 PM"
      timeString = timeString.trim();
      final parts = timeString.split(' ');
      if (parts.length != 2) return null;

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return null;

      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return null;
    }
  }

  void _onFormChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isOpening) async {
    final theme = Theme.of(context);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isOpening
          ? (_openingTime ?? TimeOfDay.now())
          : (_closingTime ?? TimeOfDay.now()),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.colorScheme.primaryContainer,
              hourMinuteTextColor: theme.colorScheme.onPrimaryContainer,
              dialHandColor: theme.colorScheme.primary,
              dialBackgroundColor: theme.colorScheme.surface,
              hourMinuteColor: theme.colorScheme.surface,
              dayPeriodTextColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isOpening) {
          _openingTime = picked;
        } else {
          _closingTime = picked;
        }
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final shouldReplace = await _showReplacePhotoDialog();
        if (shouldReplace == true) {
          setState(() {
            _newImagePath = image.path;
            _photoRemoved = false;
            _hasChanges = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to pick image: ${e.toString()}');
      }
    }
  }

  Future<bool?> _showReplacePhotoDialog() async {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.primaryContainer,
        title: Text(
          'Replace Photo',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'Do you want to replace the existing photo?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
  }

  void _removePhoto() {
    setState(() {
      _photoRemoved = true;
      _newImagePath = null;
      _hasChanges = true;
    });
  }

  Future<void> _updateLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          _showErrorSnackBar('Location permission denied');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _hasChanges = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location updated successfully',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to get location: ${e.toString()}');
    }
  }

  Future<void> _handlePickFromMap() async {
    try {
      LatLng? initialLocation;

      if (_latitudeController.text.isNotEmpty &&
          _longitudeController.text.isNotEmpty) {
        final lat = double.tryParse(_latitudeController.text);
        final lng = double.tryParse(_longitudeController.text);
        if (lat != null && lng != null) {
          initialLocation = LatLng(lat, lng);
        }
      }

      final LatLng? result = await Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          builder: (context) => LocationPickerWidget(
            initialLocation: initialLocation,
          ),
        ),
      );

      if (result != null) {
        setState(() {
          _latitudeController.text = result.latitude.toStringAsFixed(6);
          _longitudeController.text = result.longitude.toStringAsFixed(6);
          _hasChanges = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location selected from map'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick location: ${e.toString()}');
    }
  }

  Future<void> _updateDestination() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isUpdating = true);

    try {
      // Format opening hours
      String? openingHoursFormatted;
      if (_openingTime != null && _closingTime != null) {
        openingHoursFormatted =
            '${_openingTime!.format(context)} - ${_closingTime!.format(context)}';
      }

      // Determine photo path
      String? finalPhotoPath;
      if (_photoRemoved) {
        finalPhotoPath = '';
      } else if (_newImagePath != null) {
        finalPhotoPath = _newImagePath;
      } else {
        finalPhotoPath = _currentImagePath ?? '';
      }

      final updatedDestination = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text) ?? 0.0,
        'longitude': double.tryParse(_longitudeController.text) ?? 0.0,
        'opening_hours': openingHoursFormatted ?? '',
        'photo_path': finalPhotoPath,
        // Keep the original created_at date
        'created_at': widget.destination['created_at'],
      };

      // Update in database
      final result = await DatabaseHelper.instance.updateDestination(
        widget.destination['id'] as int,
        updatedDestination,
      );

      if (mounted) {
        if (result > 0) {
          Navigator.pop(context, true); // Return true to indicate success

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Destination updated successfully',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception('Update failed');
        }
      }
    } catch (e) {
      setState(() => _isUpdating = false);
      _showErrorSnackBar('Failed to update destination: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;

    final theme = Theme.of(context);
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.primaryContainer,
        title: Text(
          'Discard Changes?',
          style: theme.textTheme.titleLarge,
        ),
        content: Text(
          'You have unsaved changes. Do you want to discard them?',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep Editing',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return shouldPop ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _miniMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: CustomAppBar(
          title: 'Edit Destination',
          variant: CustomAppBarVariant.withBack,
          actions: [
            TextButton(
              onPressed:
                  _hasChanges && !_isUpdating ? _updateDestination : null,
              child: _isUpdating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                      ),
                    )
                  : Text(
                      'Update',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _hasChanges
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PhotoSectionWidget(
                      currentImagePath: _currentImagePath,
                      newImagePath: _newImagePath,
                      photoRemoved: _photoRemoved,
                      onPickImage: _pickImage,
                      onRemovePhoto: _removePhoto,
                    ),
                    SizedBox(height: 3.h),
                    FormFieldsWidget(
                      nameController: _nameController,
                      descriptionController: _descriptionController,
                      openingTime: _openingTime,
                      closingTime: _closingTime,
                      onSelectTime: _selectTime,
                    ),
                    SizedBox(height: 3.h),
                    CoordinatesSectionWidget(
                      latitudeController: _latitudeController,
                      longitudeController: _longitudeController,
                      onUpdateLocation: _updateLocation,
                      onPickFromMap: _handlePickFromMap,
                    ),

                    // Mini Map Preview
                    if (_hasValidLocation) ...[
                      SizedBox(height: 3.h),
                      _buildSectionTitle(theme, 'Location Preview'),
                      SizedBox(height: 2.h),
                      _buildMiniMap(theme),
                    ],

                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildMiniMap(ThemeData theme) {
    final lat = double.parse(_latitudeController.text);
    final lng = double.parse(_longitudeController.text);

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          onMapCreated: (controller) {
            _miniMapController = controller;
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(lat, lng),
            zoom: 15,
          ),
          markers: _miniMapMarkers,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: false,
          zoomGesturesEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          mapType: MapType.normal,
        ),
      ),
    );
  }
}
