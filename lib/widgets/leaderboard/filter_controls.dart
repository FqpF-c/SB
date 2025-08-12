import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';

/// Legacy segmented control for Weekly/All Time with sync to dropdown
class LegacyFilterToggle extends StatelessWidget {
  final Timeframe selectedTimeframe;
  final Function(Timeframe) onChanged;
  
  const LegacyFilterToggle({
    super.key,
    required this.selectedTimeframe,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
      height: 44.h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildSegmentButton(
            'Weekly',
            selectedTimeframe == Timeframe.weekly,
            () => onChanged(Timeframe.weekly),
          ),
          _buildSegmentButton(
            'All Time',
            selectedTimeframe == Timeframe.allTime,
            () => onChanged(Timeframe.allTime),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    SBColors.gradientStart,
                    SBColors.gradientEnd,
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: isSelected ? SBElevation.subtle : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18.r),
            child: Container(
              alignment: Alignment.center,
              child: Text(
                text,
                style: SBTypography.body.copyWith(
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern timeframe dropdown that syncs with legacy toggle
class TimeframeDropdown extends StatelessWidget {
  final Timeframe selectedTimeframe;
  final Function(Timeframe) onChanged;
  final bool showAllOptions;
  
  const TimeframeDropdown({
    super.key,
    required this.selectedTimeframe,
    required this.onChanged,
    this.showAllOptions = true,
  });

  @override
  Widget build(BuildContext context) {
    final options = showAllOptions 
        ? Timeframe.values
        : [Timeframe.weekly, Timeframe.allTime];
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SBGap.md, vertical: SBGap.xs),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(SBRadii.sm),
        boxShadow: SBElevation.subtle,
      ),
      child: DropdownButton<Timeframe>(
        value: selectedTimeframe,
        onChanged: (timeframe) {
          if (timeframe != null) {
            onChanged(timeframe);
          }
        },
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          size: 16.sp,
          color: SBColors.textSecondary,
        ),
        style: SBTypography.label.copyWith(
          color: SBColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        dropdownColor: Colors.white,
        items: options.map((timeframe) {
          return DropdownMenuItem(
            value: timeframe,
            child: Text(timeframe.displayName),
          );
        }).toList(),
      ),
    );
  }
}

/// Filter dropdown for groups and categories
class FilterDropdown extends StatelessWidget {
  final String label;
  final String? selectedValue;
  final List<String> options;
  final Function(String?) onChanged;
  final IconData icon;
  
  const FilterDropdown({
    super.key,
    required this.label,
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    this.icon = Icons.filter_list,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SBGap.md, vertical: SBGap.xs),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(SBRadii.sm),
        boxShadow: SBElevation.subtle,
      ),
      child: DropdownButton<String>(
        value: selectedValue,
        onChanged: onChanged,
        underline: const SizedBox(),
        icon: Icon(
          Icons.keyboard_arrow_down,
          size: 16.sp,
          color: SBColors.textSecondary,
        ),
        style: SBTypography.label.copyWith(
          color: SBColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Colors.white,
        hint: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.sp,
              color: SBColors.textSecondary,
            ),
            SizedBox(width: SBGap.xs),
            Text(
              label,
              style: SBTypography.label.copyWith(
                color: SBColors.textSecondary,
              ),
            ),
          ],
        ),
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option != 'All') ...[
                  Icon(
                    icon,
                    size: 14.sp,
                    color: SBColors.textSecondary,
                  ),
                  SizedBox(width: SBGap.xs),
                ],
                Flexible(
                  child: Text(
                    option,
                    style: SBTypography.label.copyWith(
                      color: SBColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Combined filter controls widget
class FilterControls extends StatelessWidget {
  final Timeframe selectedTimeframe;
  final Function(Timeframe) onTimeframeChanged;
  final String? selectedGroup;
  final Function(String?) onGroupChanged;
  final String? selectedCategory;
  final Function(String?) onCategoryChanged;
  final Map<String, List<String>> filterOptions;
  final bool showLegacyToggle;
  
  const FilterControls({
    super.key,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
    required this.selectedGroup,
    required this.onGroupChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.filterOptions,
    this.showLegacyToggle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Legacy toggle (maintain existing behavior)
        if (showLegacyToggle)
          LegacyFilterToggle(
            selectedTimeframe: selectedTimeframe,
            onChanged: onTimeframeChanged,
          ),
        
        // Modern filter dropdowns
        Padding(
          padding: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
          child: Row(
            children: [
              // Group filter
              Expanded(
                child: FilterDropdown(
                  label: 'All Groups',
                  selectedValue: selectedGroup,
                  options: filterOptions['groups'] ?? ['All'],
                  onChanged: onGroupChanged,
                  icon: Icons.school,
                ),
              ),
              
              SizedBox(width: SBGap.md),
              
              // Category filter
              Expanded(
                child: FilterDropdown(
                  label: 'All Categories',
                  selectedValue: selectedCategory,
                  options: filterOptions['categories'] ?? ['All'],
                  onChanged: onCategoryChanged,
                  icon: Icons.category,
                ),
              ),
              
              SizedBox(width: SBGap.md),
              
              // Timeframe dropdown (sync with legacy toggle)
              TimeframeDropdown(
                selectedTimeframe: selectedTimeframe,
                onChanged: onTimeframeChanged,
                showAllOptions: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Compact filter bar for smaller screens
class CompactFilterControls extends StatelessWidget {
  final Timeframe selectedTimeframe;
  final Function(Timeframe) onTimeframeChanged;
  final String? selectedGroup;
  final Function(String?) onGroupChanged;
  final String? selectedCategory;
  final Function(String?) onCategoryChanged;
  final Map<String, List<String>> filterOptions;
  
  const CompactFilterControls({
    super.key,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
    required this.selectedGroup,
    required this.onGroupChanged,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.filterOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(SBInsets.h),
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(SBRadii.md),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilterDropdown(
                  label: 'Group',
                  selectedValue: selectedGroup,
                  options: filterOptions['groups'] ?? ['All'],
                  onChanged: onGroupChanged,
                  icon: Icons.school,
                ),
              ),
              SizedBox(width: SBGap.md),
              Expanded(
                child: FilterDropdown(
                  label: 'Category',
                  selectedValue: selectedCategory,
                  options: filterOptions['categories'] ?? ['All'],
                  onChanged: onCategoryChanged,
                  icon: Icons.category,
                ),
              ),
            ],
          ),
          SizedBox(height: SBGap.md),
          LegacyFilterToggle(
            selectedTimeframe: selectedTimeframe,
            onChanged: onTimeframeChanged,
          ),
        ],
      ),
    );
  }
}