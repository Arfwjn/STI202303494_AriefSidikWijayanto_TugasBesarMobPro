import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Opening Hours Section Widget
/// Menampilkan opening dan closing time menggunakan TimePicker
class OpeningHoursSectionWidget extends StatelessWidget {
  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;
  final Function(TimeOfDay) onOpeningTimeSelected;
  final Function(TimeOfDay) onClosingTimeSelected;

  const OpeningHoursSectionWidget({
    super.key,
    required this.openingTime,
    required this.closingTime,
    required this.onOpeningTimeSelected,
    required this.onClosingTimeSelected,
  });

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay? currentTime,
    Function(TimeOfDay) onTimeSelected,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime ?? TimeOfDay.now(),
      builder: (context, child) {
        final theme = Theme.of(context);
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.colorScheme.surface,
              hourMinuteTextColor: theme.colorScheme.onSurface,
              dayPeriodTextColor: theme.colorScheme.onSurface,
              dialHandColor: theme.colorScheme.primary,
              dialBackgroundColor: theme.colorScheme.primaryContainer,
              hourMinuteColor: theme.colorScheme.primaryContainer,
              dayPeriodColor: theme.colorScheme.primaryContainer,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      onTimeSelected(picked);
    }
  }

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
        children: [
          _buildTimeSelector(
            context,
            theme,
            'Opening Time',
            openingTime,
            'access_time',
            () => _selectTime(context, openingTime, onOpeningTimeSelected),
          ),
          SizedBox(height: 2.h),
          _buildTimeSelector(
            context,
            theme,
            'Closing Time',
            closingTime,
            'schedule',
            () => _selectTime(context, closingTime, onClosingTimeSelected),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelector(
    BuildContext context,
    ThemeData theme,
    String label,
    TimeOfDay? time,
    String iconName,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                time != null ? theme.colorScheme.primary : theme.dividerColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: iconName,
              color: time != null
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label *',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    time != null ? time.format(context) : 'Select time',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: time != null
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight:
                          time != null ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            CustomIconWidget(
              iconName: 'arrow_forward_ios',
              color: theme.colorScheme.onSurfaceVariant,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
