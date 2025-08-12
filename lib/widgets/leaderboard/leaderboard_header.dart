import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/leaderboard_theme.dart';

/// Pink gradient header with curved bottom overlap
class LeaderboardHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  
  const LeaderboardHeader({
    super.key,
    required this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SBConstants.headerHeight,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SBColors.gradientStart, SBColors.gradientEnd],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: SBInsets.h),
          child: Column(
            children: [
              SizedBox(height: SBGap.md),
              Row(
                children: [
                  // Back button
                  Container(
                    width: SBConstants.minTouchTarget,
                    height: SBConstants.minTouchTarget,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(SBRadii.sm),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onBackPressed,
                        borderRadius: BorderRadius.circular(SBRadii.sm),
                        child: Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 24.sp,
                        ),
                      ),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Title
                  Text(
                    'Leaderboard',
                    style: SBTypography.title.copyWith(fontSize: 22.sp),
                  ),
                  
                  const Spacer(),
                  
                  // Trophy icon
                  Container(
                    width: 56.w,
                    height: 56.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(SBRadii.sm),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 28.sp,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              
              // Curved bottom section
              Container(
                height: 40.h,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(SBRadii.lg),
                    topRight: Radius.circular(SBRadii.lg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom clipper for curved header bottom
class HeaderCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(HeaderCurveClipper oldClipper) => false;
}

/// Alternative stacked header approach
class StackedLeaderboardHeader extends StatelessWidget {
  final VoidCallback onBackPressed;
  final Widget child;
  
  const StackedLeaderboardHeader({
    super.key,
    required this.onBackPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          height: SBConstants.headerHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [SBColors.gradientStart, SBColors.gradientEnd],
            ),
          ),
        ),
        
        // Header content
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(
              left: SBInsets.h,
              right: SBInsets.h,
              top: SBGap.md,
            ),
            child: Row(
              children: [
                // Back button
                Container(
                  width: SBConstants.minTouchTarget,
                  height: SBConstants.minTouchTarget,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(SBRadii.sm),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onBackPressed,
                      borderRadius: BorderRadius.circular(SBRadii.sm),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Title
                Text(
                  'Leaderboard',
                  style: SBTypography.title.copyWith(fontSize: 22.sp),
                ),
                
                const Spacer(),
                
                // Trophy icon
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(SBRadii.sm),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.emoji_events,
                    color: Colors.amber,
                    size: 28.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Body content with overlap
        Padding(
          padding: EdgeInsets.only(top: (SBConstants.headerHeight - SBConstants.statsCardOverlap).h),
          child: child,
        ),
      ],
    );
  }
}