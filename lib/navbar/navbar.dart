import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/home/home_screen.dart';
import '../screens/academics/academics_screen.dart';
import '../screens/lead/simple_new_leaderboard.dart';
import '../screens/profile/profile_screen.dart';

class NavBar extends StatefulWidget {
  const NavBar({super.key});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const AcademicsScreen(),
    const SimpleNewLeaderboard(),
    const ProfileScreen(),
  ];

  final List<IconData> _icons = [
    Icons.home_outlined,
    Icons.school_outlined,
    Icons.leaderboard_outlined,
    Icons.person_outline,
  ];

  final List<String> _labels = [
    'Home',
    'Academics',
    'Lead',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      extendBody: true,
      bottomNavigationBar: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: const Color(0xFF3D1560),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_icons.length, (index) {
              final bool isSelected = _currentIndex == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16.w : 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFE471A0)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _icons[index],
                        color: Colors.white,
                        size: 24.sp,
                      ),
                      if (isSelected) ...[
                        SizedBox(width: 6.w),
                        Text(
                          _labels[index],
                          style: GoogleFonts.roboto(
                            color: Colors.white,
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ),
      ),
    );
  }
}
