import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// Hero header widget menampilkan gambar destination dengan gradient overlay
class DestinationHeaderWidget extends StatelessWidget {
  final String imageUrl;
  final String semanticLabel;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DestinationHeaderWidget({
    super.key,
    required this.imageUrl,
    required this.semanticLabel,
    required this.onBack,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 40.h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Hero image
          Hero(
            tag: 'destination_image_$imageUrl',
            child: _buildImage(theme),
          ),

          // Gradient overlay untuk text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.3, 1.0],
              ),
            ),
          ),

          // Top action buttons
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: CustomIconWidget(
                        iconName: 'arrow_back',
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onBack();
                      },
                      tooltip: 'Back',
                    ),
                  ),

                  // Actions menu
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      icon: CustomIconWidget(
                        iconName: 'more_vert',
                        color: Colors.white,
                        size: 24,
                      ),
                      color: theme.colorScheme.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        HapticFeedback.lightImpact();
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'edit',
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Edit',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              CustomIconWidget(
                                iconName: 'delete',
                                color: theme.colorScheme.error,
                                size: 20,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'Delete',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(ThemeData theme) {
    // Check imageUrl adalah local file path atau network URL
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      // Local file
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: double.infinity,
          height: 40.h,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(theme);
          },
        );
      }
    } else if (imageUrl.startsWith('http')) {
      // Network image
      return CustomImageWidget(
        imageUrl: imageUrl,
        width: double.infinity,
        height: 40.h,
        fit: BoxFit.cover,
        semanticLabel: semanticLabel,
        errorWidget: _buildPlaceholder(theme),
      );
    }

    // tidak ada gambar atau gagal dimuat
    return _buildPlaceholder(theme);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 40.h,
      color: theme.colorScheme.primaryContainer,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomIconWidget(
            iconName: 'image',
            color: theme.colorScheme.onSurfaceVariant,
            size: 64,
          ),
          SizedBox(height: 2.h),
          Text(
            'No Image Available',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
