import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/destination_actions_widget.dart';
import './widgets/destination_header_widget.dart';
import './widgets/destination_info_widget.dart';

/// Destination Detail Screen menampilkan informasi komprehensif destination
class DestinationDetailScreen extends StatefulWidget {
  const DestinationDetailScreen({super.key});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  Map<String, dynamic>? _destinationData;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _destinationData == null) {
      _destinationData = args;
      _loadDestinationData();
    }
  }

  Future<void> _loadDestinationData() async {
    if (_destinationData == null) return;

    setState(() => _isLoading = true);

    try {
      final id = _destinationData!['id'] as int;
      final freshData = await DatabaseHelper.instance.getDestination(id);

      if (freshData != null && mounted) {
        setState(() {
          _destinationData = freshData;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading destination: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation() {
    if (_destinationData == null) return;

    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'warning',
              color: theme.colorScheme.error,
              size: 24,
            ),
            SizedBox(width: 2.w),
            Text(
              'Delete Destination',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${_destinationData!["name"]}"? This action cannot be undone.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              _deleteDestination();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(
              'Delete',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDestination() async {
    if (_destinationData == null) return;

    final theme = Theme.of(context);

    try {
      await DatabaseHelper.instance
          .deleteDestination(_destinationData!['id'] as int);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CustomIconWidget(
                  iconName: 'check_circle',
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Destination deleted successfully',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.tertiary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigasi kembali ke home screen setelah deletion
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(
                context, true); // Return true untuk mengindikasi deletion
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete destination: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _navigateToEdit() async {
    if (_destinationData == null) return;

    HapticFeedback.lightImpact();
    final result = await Navigator.pushNamed(
      context,
      '/edit-destination-screen',
      arguments: _destinationData,
    );

    if (result == true && mounted) {
      // Reload destination data setelah edit
      await _loadDestinationData();
    }
  }

  void _navigateToMap() {
    if (_destinationData == null) return;

    HapticFeedback.lightImpact();
    Navigator.pushNamed(
      context,
      '/map-view-screen',
      arguments: {
        'latitude': _destinationData!['latitude'],
        'longitude': _destinationData!['longitude'],
        'name': _destinationData!['name'],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    if (_destinationData == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomIconWidget(
                iconName: 'error_outline',
                color: theme.colorScheme.error,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Destination not found',
                style: theme.textTheme.titleLarge,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Hero header dengan image dan actions
          SliverToBoxAdapter(
            child: DestinationHeaderWidget(
              imageUrl: _destinationData!['photo_path'] as String? ?? '',
              semanticLabel: 'Photo of ${_destinationData!['name']}',
              onBack: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              onEdit: _navigateToEdit,
              onDelete: _showDeleteConfirmation,
            ),
          ),

          // Informasi destination
          SliverToBoxAdapter(
            child: DestinationInfoWidget(
              name: _destinationData!['name'] as String,
              description: _destinationData!['description'] as String,
              openingHours:
                  _destinationData!['opening_hours'] as String? ?? 'N/A',
              latitude: _destinationData!['latitude'] as double,
              longitude: _destinationData!['longitude'] as double,
            ),
          ),

          // Action buttons
          SliverToBoxAdapter(
            child: DestinationActionsWidget(
              latitude: _destinationData!['latitude'] as double,
              longitude: _destinationData!['longitude'] as double,
              onViewOnMap: _navigateToMap,
            ),
          ),

          // Bottom spacing
          SliverToBoxAdapter(
            child: SizedBox(height: 4.h),
          ),
        ],
      ),
    );
  }
}
