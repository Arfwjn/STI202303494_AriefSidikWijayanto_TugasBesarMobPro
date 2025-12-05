import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Search overlay widget untuk menemukan lokasi
class SearchOverlayWidget extends StatefulWidget {
  final String searchQuery;
  final Function(String) onSearchQueryChanged;
  final Function(LatLng, String) onLocationSelected;
  final VoidCallback onClose;

  const SearchOverlayWidget({
    super.key,
    required this.searchQuery,
    required this.onSearchQueryChanged,
    required this.onLocationSelected,
    required this.onClose,
  });

  @override
  State<SearchOverlayWidget> createState() => _SearchOverlayWidgetState();
}

class _SearchOverlayWidgetState extends State<SearchOverlayWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  // Mock saran pencarian
  final List<Map<String, dynamic>> _mockSuggestions = [
    {
      "name": "Curug Jenggala",
      "address":
          "Jl. Pangeran Limboro, Dusun III Kalipagu, Ketenger, Kec. Baturaden, Kabupaten Banyumas, Jawa Tengah",
      "latitude": -7.308877709465497,
      "longitude": 109.20872405118497,
    },
    {
      "name": "Menara Pandang Teratai",
      "address":
          "Jl. Bung Karno, Kalibener, Kedungwuluh, Kec. Purwokerto Tim., Kabupaten Banyumas, Jawa Tengah",
      "latitude": -7.431312718223754,
      "longitude": 109.23249445118637,
    },
    {
      "name": "Alun-Alun Purwokerto",
      "address":
          "Komplek PJKA 386-388, JL. Jend. Sudirman, Purwokerto Lor, Purwokerto, Sokanegara, Kec. Purwokerto Tim., Kabupaten Banyumas, Jawa Tengah",
      "latitude": -7.423757694467924,
      "longitude": 109.23013411699363,
    },
    {
      "name": "Taman Andhang Pangrenan",
      "address":
          "Jalan Gerilya Purwokerto Selatan, Jl. Prof. M Yamin I, Windusara, Karangklesem, Kec. Banyumas, Kabupaten Banyumas, Jawa Tengah",
      "latitude": -7.439814441594049,
      "longitude": 109.24371685036475,
    },
    {
      "name": "STMIK Widya Utama Purwokerto",
      "address":
          "Jl. Sunan Kalijaga, Dusun III, Berkoh, Kec. Purwokerto Sel., Kabupaten Banyumas, Jawa Tengah",
      "latitude": -7.439159591700715,
      "longitude": 109.2662043242014,
    },
  ];

  List<Map<String, dynamic>> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _filteredSuggestions = _mockSuggestions;
    _searchFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterSuggestions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuggestions = _mockSuggestions;
      } else {
        _filteredSuggestions = _mockSuggestions.where((suggestion) {
          final name = (suggestion["name"] as String).toLowerCase();
          final address = (suggestion["address"] as String).toLowerCase();
          final searchLower = query.toLowerCase();
          return name.contains(searchLower) || address.contains(searchLower);
        }).toList();
      }
    });
    widget.onSearchQueryChanged(query);
  }

  void _selectLocation(Map<String, dynamic> suggestion) {
    HapticFeedback.lightImpact();
    final location = LatLng(
      suggestion["latitude"] as double,
      suggestion["longitude"] as double,
    );
    widget.onLocationSelected(location, suggestion["name"] as String);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.95),
      child: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(theme),
            Expanded(
              child: _buildSuggestionsList(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: CustomIconWidget(
              iconName: 'arrow_back',
              color: theme.colorScheme.onSurface,
              size: 24,
            ),
            onPressed: widget.onClose,
            tooltip: 'Close search',
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _filterSuggestions,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Search for places...',
                hintStyle: theme.inputDecorationTheme.hintStyle,
                prefixIcon: Padding(
                  padding: EdgeInsets.all(12),
                  child: CustomIconWidget(
                    iconName: 'search',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: CustomIconWidget(
                          iconName: 'clear',
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterSuggestions('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: theme.colorScheme.primaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(ThemeData theme) {
    if (_filteredSuggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CustomIconWidget(
              iconName: 'search_off',
              color: theme.colorScheme.onSurfaceVariant,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredSuggestions.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final suggestion = _filteredSuggestions[index];
        return _buildSuggestionItem(theme, suggestion);
      },
    );
  }

  Widget _buildSuggestionItem(
    ThemeData theme,
    Map<String, dynamic> suggestion,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectLocation(suggestion),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: CustomIconWidget(
                    iconName: 'place',
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion["name"] as String,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      suggestion["address"] as String,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              CustomIconWidget(
                iconName: 'north_west',
                color: theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
