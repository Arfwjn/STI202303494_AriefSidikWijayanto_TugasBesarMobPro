import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/coordinates_section_widget.dart';
import './widgets/opening_hours_section_widget.dart';
import './widgets/photo_section_widget.dart';

/// Add Destination Screen
/// Memungkinkan pengisian data destinations secara lengkap melalui scrollable form layout
class AddDestinationScreen extends StatefulWidget {
  const AddDestinationScreen({super.key});

  @override
  State<AddDestinationScreen> createState() => _AddDestinationScreenState();
}

class _AddDestinationScreenState extends State<AddDestinationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  XFile? _selectedImage;
  bool _isSaving = false;
  bool _isLoadingLocation = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  bool get _isFormValid {
    return _nameController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty &&
        _latitudeController.text.trim().isNotEmpty &&
        _longitudeController.text.trim().isNotEmpty &&
        _openingTime != null &&
        _closingTime != null;
  }

  Future<void> _handleSave() async {
    if (!_isFormValid) {
      _showSnackBar('Please fill all required fields', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final destination = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'latitude': double.parse(_latitudeController.text.trim()),
        'longitude': double.parse(_longitudeController.text.trim()),
        'opening_hours':
            '${_openingTime!.format(context)} - ${_closingTime!.format(context)}',
        'photo_path': _selectedImage?.path ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      await DatabaseHelper.instance.insertDestination(destination);

      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.pop(context, true);
        _showSnackBar('Destination saved successfully');
      }
    } catch (e) {
      _showSnackBar('Failed to save destination', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleCancel() {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
  }

  Future<void> _handlePhotoSelection(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() => _selectedImage = image);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showSnackBar('Failed to select photo', isError: true);
    }
  }

  Future<void> _handleUseCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Permission.location.request();

      if (!permission.isGranted) {
        _showSnackBar('Location permission denied', isError: true);
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
        _isLoadingLocation = false;
      });

      HapticFeedback.lightImpact();
      _showSnackBar('Location updated successfully');
    } catch (e) {
      _showSnackBar('Failed to get current location', isError: true);
      setState(() => _isLoadingLocation = false);
    }
  }

  void _handleOpeningTimeSelection(TimeOfDay time) {
    setState(() => _openingTime = time);
    HapticFeedback.lightImpact();
  }

  void _handleClosingTimeSelection(TimeOfDay time) {
    setState(() => _closingTime = time);
    HapticFeedback.lightImpact();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        variant: CustomAppBarVariant.standard,
        title: 'Add Destination',
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: CustomIconWidget(
            iconName: 'close',
            color: theme.colorScheme.onSurface,
            size: 24,
          ),
          onPressed: _handleCancel,
          tooltip: 'Cancel',
        ),
        actions: [
          CustomAppBarAction(
            icon: Icons.check,
            onPressed: _isSaving ? () {} : _handleSave,
            tooltip: 'Save',
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(theme, 'Destination Details'),
                SizedBox(height: 2.h),
                _buildNameField(theme),
                SizedBox(height: 2.h),
                _buildDescriptionField(theme),
                SizedBox(height: 3.h),
                _buildSectionTitle(theme, 'Opening Hours'),
                SizedBox(height: 2.h),
                OpeningHoursSectionWidget(
                  openingTime: _openingTime,
                  closingTime: _closingTime,
                  onOpeningTimeSelected: _handleOpeningTimeSelection,
                  onClosingTimeSelected: _handleClosingTimeSelection,
                ),
                SizedBox(height: 3.h),
                _buildSectionTitle(theme, 'Photo'),
                SizedBox(height: 2.h),
                PhotoSectionWidget(
                  selectedImage: _selectedImage,
                  onPhotoSelected: _handlePhotoSelection,
                ),
                SizedBox(height: 3.h),
                _buildSectionTitle(theme, 'Location Coordinates'),
                SizedBox(height: 2.h),
                CoordinatesSectionWidget(
                  latitudeController: _latitudeController,
                  longitudeController: _longitudeController,
                  isLoadingLocation: _isLoadingLocation,
                  onUseCurrentLocation: _handleUseCurrentLocation,
                ),
                SizedBox(height: 4.h),
              ],
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

  Widget _buildNameField(ThemeData theme) {
    return TextFormField(
      controller: _nameController,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: 'Destination Name *',
        hintText: 'Enter destination name',
        prefixIcon: CustomIconWidget(
          iconName: 'place',
          color: theme.colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter destination name';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      controller: _descriptionController,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: 'Description *',
        hintText: 'Enter destination description',
        prefixIcon: Padding(
          padding: const EdgeInsets.only(bottom: 60),
          child: CustomIconWidget(
            iconName: 'description',
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter description';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }
}
