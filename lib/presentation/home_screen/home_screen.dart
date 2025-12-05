import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_export.dart';
import '../../services/database_helper.dart';
import '../../widgets/custom_bottom_bar.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/destination_card_widget.dart';
import './widgets/empty_state_widget.dart';
import './widgets/search_bar_widget.dart';

/// Layar utama untuk destinasi
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  bool _isRefreshing = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _destinations = [];

  @override
  void initState() {
    super.initState();
    _loadDestinations();
  }

  /// Load destinations from database
  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);

    try {
      final destinations = await DatabaseHelper.instance.getAllDestinations();
      setState(() {
        _destinations = destinations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading destinations: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredDestinations {
    if (_searchQuery.isEmpty) {
      return _destinations;
    }
    return _destinations.where((destination) {
      final name = (destination['name'] as String).toLowerCase();
      final description = (destination['description'] as String).toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Travvel',
          style: theme.appBarTheme.titleTextStyle,
        ),
        actions: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'filter_list',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: _showFilterOptions,
            tooltip: 'Filter',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SearchBarWidget(
              onSearch: (query) {
                setState(() {
                  _searchQuery = query;
                });
              },
              initialQuery: _searchQuery,
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
                      ),
                    )
                  : _filteredDestinations.isEmpty
                      ? _searchQuery.isEmpty
                          ? EmptyStateWidget(
                              onAddDestination: _navigateToAddDestination,
                            )
                          : _buildNoResultsWidget(theme)
                      : RefreshIndicator(
                          onRefresh: _handleRefresh,
                          color: theme.colorScheme.primary,
                          child: ListView.builder(
                            itemCount: _filteredDestinations.length,
                            padding: const EdgeInsets.only(bottom: 80),
                            itemBuilder: (context, index) {
                              final destination = _filteredDestinations[index];
                              return DestinationCardWidget(
                                destination: destination,
                                onTap: () =>
                                    _navigateToDestinationDetail(destination),
                                onEdit: () =>
                                    _navigateToEditDestination(destination),
                                onDelete: () =>
                                    _showDeleteConfirmation(destination),
                                onViewOnMap: () =>
                                    _navigateToMapView(destination),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddDestination,
        icon: CustomIconWidget(
          iconName: 'add',
          color: theme.colorScheme.onPrimary,
          size: 24,
        ),
        label: const Text('Add Destination'),
      ),
      bottomNavigationBar: CustomBottomBar(
        currentIndex: 0,
        onTap: (index) {
          if (index != 0) {
            CustomBottomBarNavigation.navigateToIndex(context, index);
          }
        },
      ),
    );
  }

  /// Widget untuk menampilkan pesan tidak ada hasil pencarian
  Widget _buildNoResultsWidget(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'search_off',
              color: theme.colorScheme.onSurfaceVariant,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No Results Found',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Menangani refresh data destinasi
  Future<void> _handleRefresh() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isRefreshing = true;
    });

    await _loadDestinations();

    setState(() {
      _isRefreshing = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Destinations refreshed'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// Menampilkan opsi filter dalam modal bottom sheet
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Filter Options',
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'sort_by_alpha',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'Sort by Name',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sortByName();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'access_time',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'Sort by Date Added',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _sortByDate();
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'location_on',
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'View on Map',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/map-view-screen');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _sortByName() {
    setState(() {
      _destinations
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sorted by name'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _sortByDate() {
    setState(() {
      _destinations.sort((a, b) {
        final aDate = DateTime.parse(a['created_at'] as String);
        final bDate = DateTime.parse(b['created_at'] as String);
        return bDate.compareTo(aDate); // Newest first
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sorted by date added'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Navigasi ke layar tambah destinasi
  Future<void> _navigateToAddDestination() async {
    final result =
        await Navigator.pushNamed(context, '/add-destination-screen');

    if (result == true && mounted) {
      // Reload destinations after adding new one
      await _loadDestinations();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destination added successfully'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _navigateToDestinationDetail(
      Map<String, dynamic> destination) async {
    final result = await Navigator.pushNamed(
      context,
      '/destination-detail-screen',
      arguments: destination,
    );

    if (result == true && mounted) {
      // Reload destinations jika destination dihapus di layar detail
      await _loadDestinations();
    }
  }

  Future<void> _navigateToEditDestination(
      Map<String, dynamic> destination) async {
    final result = await Navigator.pushNamed(
      context,
      '/edit-destination-screen',
      arguments: destination,
    );

    if (result == true && mounted) {
      // Reload destinations setelah editing
      await _loadDestinations();
    }
  }

  void _navigateToMapView(Map<String, dynamic> destination) {
    Navigator.pushNamed(
      context,
      '/map-view-screen',
      arguments: destination,
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> destination) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Delete Destination',
            style: theme.textTheme.titleLarge,
          ),
          content: Text(
            'Are you sure you want to delete "${destination['name']}"? This action cannot be undone.',
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteDestination(destination);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDestination(Map<String, dynamic> destination) async {
    HapticFeedback.mediumImpact();

    try {
      await DatabaseHelper.instance.deleteDestination(destination['id'] as int);

      // Reload destinations
      await _loadDestinations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${destination['name']} deleted'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete destination'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
