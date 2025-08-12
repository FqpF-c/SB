import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';

/// Compact "Your Rank" card displaying current user's position
class YourRankCard extends StatelessWidget {
  final LeaderboardUser currentUser;
  final bool isLoading;
  
  const YourRankCard({
    super.key,
    required this.currentUser,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: SBColors.card,
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.card,
        border: Border.all(
          color: SBColors.gradientStart.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SBColors.gradientStart,
                width: 2,
              ),
              boxShadow: SBElevation.subtle,
            ),
            child: CircleAvatar(
              radius: 23.r,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: currentUser.avatarUrl != null
                  ? NetworkImage(currentUser.avatarUrl!)
                  : null,
              child: currentUser.avatarUrl == null
                  ? Text(
                      _getInitials(currentUser.name),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: SBColors.textPrimary,
                      ),
                    )
                  : null,
            ),
          ),
          
          SizedBox(width: SBGap.md),
          
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        currentUser.name,
                        style: SBTypography.body.copyWith(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: SBGap.sm),
                    _buildYouBadge(),
                  ],
                ),
                
                if (currentUser.organization != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    currentUser.organization!,
                    style: SBTypography.label.copyWith(
                      color: SBColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          
          SizedBox(width: SBGap.md),
          
          // Points and rank
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildPointsCapsule(),
              SizedBox(height: 2.h),
              Text(
                'Rank ${currentUser.rank}',
                style: SBTypography.label.copyWith(
                  fontSize: 10.sp,
                  color: SBColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYouBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SBGap.xs,
        vertical: 2.h,
      ),
      decoration: BoxDecoration(
        color: SBColors.gradientStart.withOpacity(0.2),
        borderRadius: BorderRadius.circular(SBRadii.xs),
      ),
      child: Text(
        'You',
        style: SBTypography.chip.copyWith(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: SBColors.gradientStart,
        ),
      ),
    );
  }

  Widget _buildPointsCapsule() {
    return Container(
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
            '${currentUser.points}',
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
    );
  }

  Widget _buildLoadingState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.sm),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: SBColors.card,
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.card,
      ),
      child: Row(
        children: [
          // Loading avatar
          Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade200,
            ),
          ),
          
          SizedBox(width: SBGap.md),
          
          // Loading info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  width: 80.w,
                  height: 12.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
          
          // Loading points
          Container(
            width: 60.w,
            height: 28.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(SBRadii.sm),
            ),
          ),
        ],
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

/// Alternative minimal version for when user is not in top rankings
class YourRankMiniCard extends StatelessWidget {
  final LeaderboardUser currentUser;
  
  const YourRankMiniCard({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h),
      padding: EdgeInsets.symmetric(
        horizontal: SBInsets.h,
        vertical: SBGap.md,
      ),
      decoration: BoxDecoration(
        color: SBColors.gradientStart.withOpacity(0.1),
        borderRadius: BorderRadius.circular(SBRadii.md),
        border: Border.all(
          color: SBColors.gradientStart.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32.w,
            height: 32.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SBColors.gradientStart,
                width: 1.5,
              ),
            ),
            child: CircleAvatar(
              radius: 14.r,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: currentUser.avatarUrl != null
                  ? NetworkImage(currentUser.avatarUrl!)
                  : null,
              child: currentUser.avatarUrl == null
                  ? Text(
                      _getInitials(currentUser.name),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: SBColors.textPrimary,
                      ),
                    )
                  : null,
            ),
          ),
          
          SizedBox(width: SBGap.md),
          
          Expanded(
            child: Row(
              children: [
                Text(
                  currentUser.name,
                  style: SBTypography.body.copyWith(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
                      fontSize: 8.sp,
                      fontWeight: FontWeight.w600,
                      color: SBColors.gradientStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Row(
            children: [
              Text(
                '#${currentUser.rank}',
                style: SBTypography.label.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: SBColors.gradientStart,
                ),
              ),
              SizedBox(width: SBGap.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SBGap.sm,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: SBColors.pointsBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${currentUser.points}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: SBColors.pointsText,
                  ),
                ),
              ),
            ],
          ),
        ],
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