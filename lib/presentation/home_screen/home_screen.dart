import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' show Random;

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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _searchQuery = '';
  bool _isRefreshing = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _destinations = [];

  // Speed Dial FAB variables
  bool _isFabExpanded = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabRotateAnimation;
  late Animation<double> _fabScaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _initializeFabAnimations();
  }

  void _initializeFabAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabRotateAnimation = Tween<double>(
      begin: 0.0,
      end: 0.875, // 315 degrees (7/8 of a full rotation)
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    _fabScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
    HapticFeedback.mediumImpact();

    // Debug print
    print('🔥 FAB Expanded: $_isFabExpanded');
    print('🔥 Animation Status: ${_fabAnimationController.status}');
  }

  void _closeFab() {
    if (_isFabExpanded) {
      setState(() {
        _isFabExpanded = false;
        _fabAnimationController.reverse();
      });
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  /// Load destinations from database
  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);

    try {
      final destinations = await DatabaseHelper.instance.getAllDestinations();

      if (mounted) {
        setState(() {
          _destinations = destinations
              .map((dest) => Map<String, dynamic>.from(dest))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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

    return GestureDetector(
      onTap: _closeFab,
      child: Scaffold(
        appBar: AppBar(
          title: _buildAppBarTitle(theme),
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
        body: Stack(
          children: [
            // Main content
            SafeArea(
              child: Column(
                children: [
                  SearchBarWidget(
                    onSearch: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                      _closeFab();
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
                                    final destination =
                                        _filteredDestinations[index];
                                    return DestinationCardWidget(
                                      destination: destination,
                                      onTap: () => _navigateToDestinationDetail(
                                          destination),
                                      onEdit: () => _navigateToEditDestination(
                                          destination),
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

            // Backdrop overlay when FAB is expanded
            if (_isFabExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeFab,
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: _buildSpeedDialFab(theme),
        bottomNavigationBar: CustomBottomBar(
          currentIndex: 0,
          onTap: (index) {
            _closeFab();
            if (index != 0) {
              CustomBottomBarNavigation.navigateToIndex(context, index);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSpeedDialFab(ThemeData theme) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // Main FAB
        IgnorePointer(
          ignoring: _isFabExpanded,
          child: AnimatedBuilder(
            animation: _fabAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _fabScaleAnimation.value,
                child: FloatingActionButton(
                  onPressed: _isFabExpanded ? null : _toggleFab,
                  tooltip: _isFabExpanded ? 'Close' : 'Quick Actions',
                  backgroundColor: _isFabExpanded
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      _isFabExpanded ? Icons.close : Icons.apps,
                      key: ValueKey(_isFabExpanded),
                      color: theme.colorScheme.onPrimary,
                      size: 28,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Speed dial buttons - harus di atas main FAB
        if (_isFabExpanded) ...[
          _buildSpeedDialButton(
            theme: theme,
            icon: 'add_location',
            label: 'Add Destination',
            backgroundColor: theme.colorScheme.primary,
            onTap: () async {
              print('🎯 Add Destination clicked!');
              _closeFab();
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                _navigateToAddDestination();
              }
            },
            offset: 80,
          ),
          _buildSpeedDialButton(
            theme: theme,
            icon: 'insights',
            label: 'Statistics',
            backgroundColor: Colors.deepPurple,
            onTap: () async {
              print('🎯 Statistics clicked!');
              _closeFab();
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                _showStatistics();
              }
            },
            offset: 150,
          ),
          _buildSpeedDialButton(
            theme: theme,
            icon: 'explore',
            label: 'Random Pick',
            backgroundColor: Colors.orange,
            onTap: () async {
              print('🎯 Random Pick clicked!');
              _closeFab();
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                _pickRandomDestination();
              }
            },
            offset: 220,
          ),
          _buildSpeedDialButton(
            theme: theme,
            icon: 'share',
            label: 'Share All',
            backgroundColor: Colors.teal,
            onTap: () async {
              print('🎯 Share All clicked!');
              _closeFab();
              await Future.delayed(const Duration(milliseconds: 100));
              if (mounted) {
                _shareAllDestinations();
              }
            },
            offset: 290,
          ),
        ],
      ],
    );
  }

  Widget _buildSpeedDialButton({
    required ThemeData theme,
    required String icon,
    required String label,
    required Color backgroundColor,
    required VoidCallback onTap,
    required double offset,
  }) {
    return Positioned(
      bottom: offset,
      right: 0,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: _isFabExpanded ? 1.0 : 0.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          // Clamp value to prevent negative opacity
          final clampedValue = value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: clampedValue,
            child: Opacity(
              opacity: clampedValue,
              child: child,
            ),
          );
        },
        child: IgnorePointer(
          ignoring: !_isFabExpanded,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              GestureDetector(
                onTap: () {
                  print('🔥 Label tapped: $label');
                  HapticFeedback.lightImpact();
                  onTap();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Button
              FloatingActionButton(
                mini: true,
                onPressed: () {
                  print('🔥 FAB tapped: $label');
                  HapticFeedback.mediumImpact();
                  onTap();
                },
                backgroundColor: backgroundColor,
                heroTag: 'fab_$label',
                child: CustomIconWidget(
                  iconName: icon,
                  color: theme.colorScheme.onPrimary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build app bar title with styled text
  Widget _buildAppBarTitle(ThemeData theme) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Tra',
            style: theme.appBarTheme.titleTextStyle,
          ),
          TextSpan(
            text: 'vv',
            style: theme.appBarTheme.titleTextStyle?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          TextSpan(
            text: 'el',
            style: theme.appBarTheme.titleTextStyle,
          ),
        ],
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

    if (mounted) {
      setState(() {
        _isRefreshing = false;
      });

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
    _closeFab();
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
                  'View All on Map',
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAllDestinationsOnMap();
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
        return bDate.compareTo(aDate);
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sorted by date added'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show statistics dialog
  void _showStatistics() {
    print('📊 _showStatistics called');
    final theme = Theme.of(context);
    final total = _destinations.length;

    print('📊 Total destinations: $total');

    if (total == 0) {
      print('📊 No destinations, showing snackbar');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No destinations yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('📊 Calculating statistics...');

    // Calculate statistics
    final oldest = _destinations.reduce((a, b) {
      final aDate = DateTime.parse(a['created_at'] as String);
      final bDate = DateTime.parse(b['created_at'] as String);
      return aDate.isBefore(bDate) ? a : b;
    });

    final newest = _destinations.reduce((a, b) {
      final aDate = DateTime.parse(a['created_at'] as String);
      final bDate = DateTime.parse(b['created_at'] as String);
      return aDate.isAfter(bDate) ? a : b;
    });

    final withPhotos = _destinations
        .where((d) => (d['photo_path'] as String?)?.isNotEmpty ?? false)
        .length;

    print(
        '📊 Stats calculated - Photos: $withPhotos, Oldest: ${oldest['name']}, Newest: ${newest['name']}');
    print('📊 Showing dialog...');

    showDialog(
      context: context,
      builder: (context) {
        print('📊 Building dialog widget');
        return AlertDialog(
          backgroundColor: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CustomIconWidget(
                iconName: 'insights',
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Travel Statistics',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatItem(
                theme,
                'Total Destinations',
                total.toString(),
                Icons.place,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                theme,
                'With Photos',
                withPhotos.toString(),
                Icons.photo_camera,
              ),
              const SizedBox(height: 12),
              _buildStatItem(
                theme,
                'Without Photos',
                (total - withPhotos).toString(),
                Icons.hide_image,
              ),
              const Divider(height: 24),
              Text(
                'Oldest: ${oldest['name']}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Newest: ${newest['name']}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(
      ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Pick random destination
  void _pickRandomDestination() {
    print('🎲 _pickRandomDestination called');

    if (_destinations.isEmpty) {
      print('🎲 No destinations available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No destinations yet'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print('🎲 Picking random from ${_destinations.length} destinations');
    final random = (_destinations.toList()..shuffle()).first;
    print('🎲 Selected: ${random['name']}');

    showDialog(
      context: context,
      builder: (context) {
        print('🎲 Building dialog widget');
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              CustomIconWidget(
                iconName: 'explore',
                color: theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('Random Pick'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How about visiting...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'place',
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            random['name'] as String,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      random['description'] as String,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CustomIconWidget(
                          iconName: 'access_time',
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          random['opening_hours'] as String? ?? 'N/A',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _navigateToDestinationDetail(random);
              },
              child: const Text('View Details'),
            ),
          ],
        );
      },
    );
  }

  /// Share all destinations as text
  void _shareAllDestinations() {
    print('📤 _shareAllDestinations called');

    if (_destinations.isEmpty) {
      print('📤 No destinations to share');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No destinations to share'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    print(
        '📤 Creating shareable text for ${_destinations.length} destinations');
    final theme = Theme.of(context);

    // Create shareable text
    final buffer = StringBuffer();
    buffer.writeln('🗺️ My Travel Destinations\n');

    for (int i = 0; i < _destinations.length; i++) {
      final dest = _destinations[i];
      buffer.writeln('${i + 1}. ${dest['name']}');
      buffer.writeln('   📍 ${dest['latitude']}, ${dest['longitude']}');
      buffer.writeln('   ⏰ ${dest['opening_hours']}');
      buffer.writeln('   📝 ${dest['description']}\n');
    }

    buffer.writeln('Generated by Travvel App');

    print('📤 Showing share dialog');

    showDialog(
        context: context,
        builder: (context) {
          print('📤 Building dialog widget');
          return AlertDialog(
            backgroundColor: theme.colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                CustomIconWidget(
                  iconName: 'share',
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text('Share Destinations'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share ${_destinations.length} destinations',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CustomIconWidget(
                          iconName: 'content_copy',
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Copy to Clipboard'),
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: buffer.toString()));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: theme.dividerColor),
                      ListTile(
                        leading: CustomIconWidget(
                          iconName: 'file_download',
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        title: const Text('Export as Text'),
                        onTap: () {
                          // Future: Implement file export
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Export feature coming soon!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        });
  }

  /// Show all destinations on map
  void _showAllDestinationsOnMap() {
    Navigator.pushNamed(context, '/map-view-screen');
  }

  /// Navigasi ke layar tambah destinasi
  Future<void> _navigateToAddDestination() async {
    final result =
        await Navigator.pushNamed(context, '/add-destination-screen');

    if (result == true && mounted) {
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
    _closeFab();
    final result = await Navigator.pushNamed(
      context,
      '/destination-detail-screen',
      arguments: destination,
    );

    if (result == true && mounted) {
      await _loadDestinations();
    }
  }

  Future<void> _navigateToEditDestination(
      Map<String, dynamic> destination) async {
    _closeFab();
    final result = await Navigator.pushNamed(
      context,
      '/edit-destination-screen',
      arguments: destination,
    );

    if (result == true && mounted) {
      await _loadDestinations();
    }
  }

  void _navigateToMapView(Map<String, dynamic> destination) {
    _closeFab();
    Navigator.pushNamed(
      context,
      '/map-view-screen',
      arguments: {
        'focusDestination': destination,
      },
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> destination) {
    _closeFab();
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
            content: const Text('Failed to delete destination'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
