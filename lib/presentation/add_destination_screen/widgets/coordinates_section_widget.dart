import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Coordinates Section Widget
/// Menunjukan input latitude/longitude dengan tombol Use Current Location dan Pick from Map
class CoordinatesSectionWidget extends StatelessWidget {
  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final bool isLoadingLocation;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback? onPickFromMap;

  const CoordinatesSectionWidget({
    super.key,
    required this.latitudeController,
    required this.longitudeController,
    required this.isLoadingLocation,
    required this.onUseCurrentLocation,
    this.onPickFromMap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: latitudeController,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Latitude *',
                    hintText: '0.000000',
                    prefixIcon: CustomIconWidget(
                      iconName: 'my_location',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final lat = double.tryParse(value);
                    if (lat == null || lat < -90 || lat > 90) {
                      return 'Invalid latitude';
                    }
                    return null;
                  },
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: TextFormField(
                  controller: longitudeController,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Longitude *',
                    hintText: '0.000000',
                    prefixIcon: CustomIconWidget(
                      iconName: 'location_on',
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  keyboardType: TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final lng = double.tryParse(value);
                    if (lng == null || lng < -180 || lng > 180) {
                      return 'Invalid longitude';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Pick from Map button
          if (onPickFromMap != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPickFromMap,
                icon: CustomIconWidget(
                  iconName: 'map',
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
                label: Text(
                  'Pick from Map',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                ),
              ),
            ),
            SizedBox(height: 1.h),
          ],

          // Use Current Location button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isLoadingLocation ? null : onUseCurrentLocation,
              icon: isLoadingLocation
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
                  : CustomIconWidget(
                      iconName: 'gps_fixed',
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
              label: Text(
                isLoadingLocation
                    ? 'Getting Location...'
                    : 'Use Current Location',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isLoadingLocation
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.primary,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
              ),
            ),
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              CustomIconWidget(
                iconName: 'info_outline',
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
              SizedBox(width: 1.w),
              Expanded(
                child: Text(
                  onPickFromMap != null
                      ? 'Pick location from map or use GPS coordinates'
                      : 'Tap to automatically fill coordinates using GPS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
