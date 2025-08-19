import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';

/// Individual user row in the leaderboard list
class UserListItem extends StatelessWidget {
  final LeaderboardUser user;
  final int displayIndex;
  final VoidCallback? onTap;
  final bool showOnlineIndicator;
  
  const UserListItem({
    super.key,
    required this.user,
    required this.displayIndex,
    this.onTap,
    this.showOnlineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: SBInsets.h,
        vertical: 5.h,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SBRadii.md),
          child: Container(
            padding: EdgeInsets.all(SBInsets.h),
            decoration: BoxDecoration(
              color: user.isYou
                  ? SBColors.gradientStart.withOpacity(0.05)
                  : SBColors.card,
              borderRadius: BorderRadius.circular(SBRadii.md),
              border: user.isYou
                  ? Border.all(
                      color: SBColors.gradientStart.withOpacity(0.3),
                      width: 1,
                    )
                  : null,
              boxShadow: SBElevation.subtle,
            ),
            child: Row(
              children: [
                // Avatar with rank
                Stack(
                  children: [
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: user.isYou
                              ? SBColors.gradientStart
                              : Colors.grey.shade300,
                          width: user.isYou ? 2 : 1,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: user.isYou ? 18.r : 19.r,
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
                    
                    // Online indicator
                    if (showOnlineIndicator && user.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12.w,
                          height: 12.w,
                          decoration: BoxDecoration(
                            color: SBColors.online,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    
                    // Rank badge
                    Positioned(
                      top: -2.h,
                      left: -2.w,
                      child: Container(
                        width: 18.w,
                        height: 18.w,
                        decoration: BoxDecoration(
                          color: user.isYou
                              ? SBColors.gradientStart
                              : SBColors.textSecondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: Center(
                          child: Text(
                            '${user.rank}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(width: SBGap.md),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // XP icon next to name
                          Image.asset(
                            'assets/icons/xp_icon.png',
                            width: 16.w,
                            height: 16.w,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.emoji_events,
                                color: Colors.amber,
                                size: 16.w,
                              );
                            },
                          ),
                          SizedBox(width: 6.w),
                          Flexible(
                            child: Text(
                              user.name,
                              style: SBTypography.body.copyWith(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: user.isYou
                                    ? SBColors.gradientStart
                                    : SBColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          if (user.isYou) ...[
                            SizedBox(width: SBGap.xs),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SBGap.xs,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: SBColors.gradientStart.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: SBColors.gradientStart,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      
                      if (user.organization != null) ...[
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 12.sp,
                              color: SBColors.textSecondary,
                            ),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                user.organization!,
                                style: SBTypography.label.copyWith(
                                  fontSize: 12.sp,
                                  color: SBColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                SizedBox(width: SBGap.md),
                
                // Points and actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: SBGap.md,
                        vertical: SBGap.xs,
                      ),
                      decoration: BoxDecoration(
                        color: SBColors.pointsBg,
                        borderRadius: BorderRadius.circular(SBRadii.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${user.points}',
                            style: SBTypography.label.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: SBColors.pointsText,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Text(
                            'pts',
                            style: SBTypography.label.copyWith(
                              fontSize: 10.sp,
                              color: SBColors.pointsText.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (onTap != null) ...[
                      SizedBox(height: 4.h),
                      Icon(
                        Icons.more_vert,
                        size: 16.sp,
                        color: SBColors.textSecondary.withOpacity(0.5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final words = name.trim().split(' ');
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words[0][0].toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}

/// Skeleton loading version of UserListItem
class UserListItemSkeleton extends StatefulWidget {
  const UserListItemSkeleton({super.key});

  @override
  State<UserListItemSkeleton> createState() => _UserListItemSkeletonState();
}

class _UserListItemSkeletonState extends State<UserListItemSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: SBInsets.h,
        vertical: 5.h,
      ),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: SBColors.card,
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.subtle,
      ),
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
          ),
          
          SizedBox(width: SBGap.md),
          
          // Info skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildShimmerItem(120.w, 16.h),
                SizedBox(height: 4.h),
                _buildShimmerItem(80.w, 12.h),
              ],
            ),
          ),
          
          // Points skeleton
          _buildShimmerItem(60.w, 28.h),
        ],
      ),
    );
  }

  Widget _buildShimmerItem(double width, double height) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: [
                0.0,
                _shimmerAnimation.value.clamp(0.0, 1.0),
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}