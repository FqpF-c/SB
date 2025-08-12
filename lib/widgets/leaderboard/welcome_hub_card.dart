import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';

/// Dark purple stats card with pill chips - "Welcome Hub"
class WelcomeHubCard extends StatelessWidget {
  final LeaderboardStats stats;
  final bool isLoading;
  
  const WelcomeHubCard({
    super.key,
    required this.stats,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: SBColors.deepPurple,
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Hub',
            style: SBTypography.welcomeTitle.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          SizedBox(height: SBGap.md),
          
          isLoading
              ? _buildLoadingChips()
              : _buildStatChips(),
        ],
      ),
    );
  }

  Widget _buildStatChips() {
    return Wrap(
      spacing: SBGap.sm,
      runSpacing: SBGap.sm,
      children: [
        _buildStatChip(
          'Total Users',
          stats.totalUsers.toString(),
          Icons.people_rounded,
        ),
        _buildStatChip(
          'Active Users',
          stats.activeUsers.toString(),
          Icons.trending_up_rounded,
        ),
        _buildStatChip(
          'In Rankings',
          stats.inRankings.toString(),
          Icons.leaderboard_rounded,
        ),
        _buildStatChip(
          'Updated',
          _formatLastUpdated(),
          Icons.refresh_rounded,
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SBGap.md,
        vertical: SBGap.xs,
      ),
      decoration: BoxDecoration(
        color: SBColors.pillPurple,
        borderRadius: BorderRadius.circular(SBRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.8),
            size: 14.sp,
          ),
          SizedBox(width: SBGap.xs),
          Text(
            value,
            style: SBTypography.chip.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            label,
            style: SBTypography.chip.copyWith(
              color: Colors.white.withOpacity(0.8),
              fontSize: 10.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingChips() {
    return Wrap(
      spacing: SBGap.sm,
      runSpacing: SBGap.sm,
      children: List.generate(4, (index) => _buildLoadingChip()),
    );
  }

  Widget _buildLoadingChip() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: SBGap.md,
        vertical: SBGap.sm,
      ),
      decoration: BoxDecoration(
        color: SBColors.pillPurple,
        borderRadius: BorderRadius.circular(SBRadii.sm),
      ),
      child: Container(
        width: 60.w,
        height: 12.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  String _formatLastUpdated() {
    final now = DateTime.now();
    final diff = now.difference(stats.lastUpdated);
    
    if (diff.inMinutes < 1) {
      return 'Now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }
}

/// Shimmer loading version of the welcome hub card
class WelcomeHubCardSkeleton extends StatefulWidget {
  const WelcomeHubCardSkeleton({super.key});

  @override
  State<WelcomeHubCardSkeleton> createState() => _WelcomeHubCardSkeletonState();
}

class _WelcomeHubCardSkeletonState extends State<WelcomeHubCardSkeleton>
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
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h),
      padding: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: SBColors.deepPurple,
        borderRadius: BorderRadius.circular(SBRadii.md),
        boxShadow: SBElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerItem(100.w, 16.h),
          SizedBox(height: SBGap.md),
          Wrap(
            spacing: SBGap.sm,
            runSpacing: SBGap.sm,
            children: List.generate(4, (index) => _buildShimmerChip()),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerChip() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: SBGap.md,
            vertical: SBGap.sm,
          ),
          decoration: BoxDecoration(
            color: SBColors.pillPurple,
            borderRadius: BorderRadius.circular(SBRadii.sm),
          ),
          child: _buildShimmerItem(80.w, 12.h),
        );
      },
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
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.1),
              ],
              stops: [
                0.0,
                _shimmerAnimation.value,
                1.0,
              ],
            ),
          ),
        );
      },
    );
  }
}