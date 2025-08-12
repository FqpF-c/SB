import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';

/// Top performers card with avatar bars and timeframe dropdown
class TopPerformersCard extends StatefulWidget {
  final List<LeaderboardUser> topThree;
  final Timeframe selectedTimeframe;
  final Function(Timeframe) onTimeframeChanged;
  final bool isLoading;
  
  const TopPerformersCard({
    super.key,
    required this.topThree,
    required this.selectedTimeframe,
    required this.onTimeframeChanged,
    this.isLoading = false,
  });

  @override
  State<TopPerformersCard> createState() => _TopPerformersCardState();
}

class _TopPerformersCardState extends State<TopPerformersCard>
    with TickerProviderStateMixin {
  late AnimationController _barAnimationController;
  late List<Animation<double>> _barAnimations;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _barAnimationController = AnimationController(
      duration: SBConstants.animationDuration,
      vsync: this,
    );

    _barAnimations = List.generate(3, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _barAnimationController,
          curve: Interval(index * 0.2, 1.0, curve: Curves.easeOutBack),
        ),
      );
    });

    _barAnimationController.forward();
  }

  @override
  void didUpdateWidget(TopPerformersCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTimeframe != widget.selectedTimeframe ||
        oldWidget.topThree != widget.topThree) {
      _barAnimationController.reset();
      _barAnimationController.forward();
    }
  }

  @override
  void dispose() {
    _barAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: const Color(0xFFfbf0f6),
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.card,
      ),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(height: SBGap.lg),
          widget.isLoading ? _buildLoadingBars() : _buildPerformanceBars(),
          SizedBox(height: SBGap.lg),
          _buildFooterButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const SizedBox.shrink(),
        _buildTimeframeDropdown(),
      ],
    );
  }

  Widget _buildTimeframeDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: SBGap.md, vertical: 2.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(SBRadii.sm),
      ),
      child: DropdownButton<Timeframe>(
        value: widget.selectedTimeframe,
        onChanged: (timeframe) {
          if (timeframe != null) {
            widget.onTimeframeChanged(timeframe);
          }
        },
        underline: const SizedBox(),
        icon: Icon(Icons.keyboard_arrow_down, size: 16.sp, color: const Color(0xFFb8949f)),
        style: SBTypography.label.copyWith(
          color: const Color(0xFF3d1461),
          fontWeight: FontWeight.w600,
        ),
        items: Timeframe.values.map((timeframe) {
          return DropdownMenuItem(
            value: timeframe,
            child: Text(timeframe.displayName),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPerformanceBars() {
    if (widget.topThree.isEmpty) {
      return _buildEmptyState();
    }

    // Arrange users for left to right display [1st, 2nd, 3rd]
    final List<LeaderboardUser?> podiumUsers = [null, null, null];
    
    for (final user in widget.topThree) {
      switch (user.rank) {
        case 1:
          podiumUsers[0] = user; // Left
          break;
        case 2:
          podiumUsers[1] = user; // Center
          break;
        case 3:
          podiumUsers[2] = user; // Right
          break;
      }
    }

    return SizedBox(
      height: 180.h, // Reduced height to prevent overflow
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPerformanceBar(podiumUsers[0], 1, _barAnimations[0], 1.0),
          SizedBox(width: SBGap.sm),
          _buildPerformanceBar(podiumUsers[1], 2, _barAnimations[1], 0.7),
          SizedBox(width: SBGap.sm),
          _buildPerformanceBar(podiumUsers[2], 3, _barAnimations[2], 0.5),
        ],
      ),
    );
  }

  Widget _buildPerformanceBar(
    LeaderboardUser? user,
    int position,
    Animation<double> animation,
    double heightFactor,
  ) {
    if (user == null) {
      return Expanded(child: _buildEmptyBar(position, heightFactor));
    }

    final barColor = _getBarColor(position);
    final maxBarHeight = 100.h * heightFactor; // Reduced bar height to prevent overflow

    return Expanded(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Fixed height container to prevent layout shifts during animation
              SizedBox(
                height: maxBarHeight + (SBConstants.avatarSize / 2), // Bar height + half avatar
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Animated bar positioned at bottom
                    Positioned(
                      bottom: 0,
                      left: SBGap.xs,
                      right: SBGap.xs,
                      child: Container(
                        height: maxBarHeight * animation.value,
                        decoration: BoxDecoration(
                          color: barColor.withOpacity(_getBarOpacity(position)),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8.r),
                            topRight: Radius.circular(8.r),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              barColor.withOpacity(0.8),
                              barColor.withOpacity(_getBarOpacity(position)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Avatar positioned at fixed location relative to max bar height
                    Positioned(
                      bottom: maxBarHeight - (SBConstants.avatarSize / 2),
                      child: Container(
                        width: SBConstants.avatarSize,
                        height: SBConstants.avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: barColor, width: 2),
                          boxShadow: SBElevation.subtle,
                        ),
                        child: CircleAvatar(
                          radius: (SBConstants.avatarSize - 4) / 2,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(
                                  _getInitials(user.name),
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: SBColors.textPrimary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: SBGap.xs),
              
              // Name at bottom
              Text(
                user.name,
                style: SBTypography.label.copyWith(
                  fontSize: 10.sp, // Reduced font size
                  fontWeight: FontWeight.w700,
                  color: SBColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1, // Limit to 1 line to prevent overflow
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyBar(int position, double heightFactor) {
    final maxBarHeight = 100.h * heightFactor; // Reduced bar height to prevent overflow
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Fixed height container to prevent layout shifts
        SizedBox(
          height: maxBarHeight + (SBConstants.avatarSize / 2), // Bar height + half avatar
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // Bar positioned at bottom
              Positioned(
                bottom: 0,
                left: SBGap.xs,
                right: SBGap.xs,
                child: Container(
                  height: maxBarHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.r),
                      topRight: Radius.circular(8.r),
                    ),
                  ),
                ),
              ),
              
              // Avatar positioned at fixed location relative to max bar height
              Positioned(
                bottom: maxBarHeight - (SBConstants.avatarSize / 2),
                child: Container(
                  width: SBConstants.avatarSize,
                  height: SBConstants.avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: Colors.grey.shade400,
                    size: 20.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: SBGap.xs),
        Text(
          '-',
          style: SBTypography.label.copyWith(color: Colors.grey.shade400),
        ),
      ],
    );
  }

  Widget _buildLoadingBars() {
    return SizedBox(
      height: 180.h, // Reduced height to match performance bars
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: SBConstants.avatarSize,
                  height: SBConstants.avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                  ),
                ),
                SizedBox(height: SBGap.sm),
                Container(
                  width: 60.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                SizedBox(height: SBGap.xs),
                Container(
                  height: [0.7, 1.0, 0.5][index] * 100.h, // Reduced bar height
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: SBGap.xs),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8.r),
                      topRight: Radius.circular(8.r),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 150.h,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 48.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: SBGap.md),
            Text(
              'No rankings available',
              style: SBTypography.body.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterButton() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SBGap.md,
        vertical: SBGap.md,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(SBRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up,
            size: 14.sp,
            color: const Color(0xFFf5d5e2),
          ),
          SizedBox(width: SBGap.xs),
          Text(
            'Top Performance Category',
            style: SBTypography.label.copyWith(
              color: SBColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(int position) {
    switch (position) {
      case 1:
        return const Color(0xFFfd678b);
      case 2:
        return const Color(0xFFf5d5e2);
      case 3:
        return const Color(0xFFf7e2e9);
      default:
        return Colors.grey.shade300;
    }
  }

  double _getBarOpacity(int position) {
    switch (position) {
      case 1:
        return 1.0;
      case 2:
        return 0.7;
      case 3:
        return 0.5;
      default:
        return 0.3;
    }
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}