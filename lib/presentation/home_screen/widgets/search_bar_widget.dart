import 'package:flutter/material.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Search bar widget untuk filtering destinations
class SearchBarWidget extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final String? initialQuery;

  const SearchBarWidget({
    super.key,
    required this.onSearch,
    this.initialQuery,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isSearching ? theme.colorScheme.primary : theme.dividerColor,
          width: 1,
        ),
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          widget.onSearch(value);
        },
        onTap: () {
          setState(() {
            _isSearching = true;
          });
        },
        onSubmitted: (_) {
          setState(() {
            _isSearching = false;
          });
        },
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Search destinations...',
          hintStyle: theme.inputDecorationTheme.hintStyle,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: CustomIconWidget(
              iconName: 'search',
              color: _isSearching
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: CustomIconWidget(
                    iconName: 'clear',
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearch('');
                    setState(() {
                      _isSearching = false;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
