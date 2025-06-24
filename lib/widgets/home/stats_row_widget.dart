import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StatsRowWidget extends StatelessWidget {
  final int completed;
  final int rankPosition;
  final int studyHours;

  const StatsRowWidget({
    Key? key,
    required this.completed,
    required this.rankPosition,
    required this.studyHours,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -65), // Keep the same upward overlap from prep.dart
      child: Container(
        width: double.infinity,
        // Decreased bottom padding from 25 to 15
        padding: EdgeInsets.fromLTRB(20.w, 65.h, 20.w, 15.h),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE17DA8), Color(0xFFE15E89)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(48.r),
            bottomRight: Radius.circular(48.r),
          ),
        ),
        child: Column(
          children: [
            // Decreased top padding from 15 to 10
            SizedBox(height: 15.h),
            
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  icon: Icons.check_circle_outline,
                  label: "Completed",
                  value: completed.toString(),
                ),
                Container(height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
                _buildStatItem(
                  icon: Icons.leaderboard,
                  label: "Rank Position",
                  value: rankPosition.toString(),
                ),
                Container(height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
                _buildStatItem(
                  icon: Icons.access_time,
                  label: "Study Hours",
                  value: studyHours.toString(),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate(
      effects: [
        ScaleEffect(duration: 300.ms, curve: Curves.easeOut),
        FadeEffect(duration: 300.ms),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 22.sp,
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}