import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
import 'dart:math';
import '../../providers/lead_provider.dart';
import '../../theme/default_theme.dart';

class LeadScreen extends StatefulWidget {
  const LeadScreen({Key? key}) : super(key: key);

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _podiumController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _podiumAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _podiumController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _podiumAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _podiumController,
      curve: Curves.elasticOut,
    ));
    
    Future.microtask(() {
      Provider.of<LeadProvider>(context, listen: false).fetchLeaderboardData();
      _animationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _podiumController.forward();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _podiumController.dispose();
    super.dispose();
  }

  double _safeOpacity(double value) {
    return value.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFdf678c),
        elevation: 0,
        toolbarHeight: 0, // Hide the toolbar but keep the status bar styling
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFdf678c), // Set status bar color to #df678c
          statusBarIconBrightness: Brightness.light, // White icons on colored background
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.secondaryColor,
              AppTheme.secondaryColor.withOpacity(0.8),
              AppTheme.secondaryColor.withOpacity(0.6),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<LeadProvider>(
            builder: (context, leaderboardProvider, child) {
              if (leaderboardProvider.isLoading) {
                return _buildLoadingState();
              }
              
              final topThree = leaderboardProvider.getTopThreeUsers();
              final remainingUsers = leaderboardProvider.getRemainingUsers();
              
              return RefreshIndicator(
                onRefresh: () => leaderboardProvider.refreshData(),
                color: AppTheme.secondaryColor,
                backgroundColor: Colors.white,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildEnhancedAppBar(),
                    _buildStatsCard(leaderboardProvider),
                    _buildAnimatedFilterToggle(leaderboardProvider),
                    _buildEnhancedFilters(leaderboardProvider),
                    SliverToBoxAdapter(
                      child: topThree.isEmpty 
                        ? _buildEnhancedEmptyState() 
                        : _buildEnhancedPodium(topThree),
                    ),
                    _buildEnhancedUsersList(remainingUsers, leaderboardProvider),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 4.w,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Loading Leaderboard...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Fetching rankings and stats',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedAppBar() {
    return SliverAppBar(
      expandedHeight: 100.h,
      floating: true,
      pinned: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: EdgeInsets.all(8.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _safeOpacity(_fadeAnimation.value),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.emoji_events,
                      color: Colors.amber,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Leaderboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.sp,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatsCard(LeadProvider provider) {
    final stats = provider.getUserStats();
    
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _safeOpacity(_fadeAnimation.value),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildStatItem(
                      'Total Users',
                      stats['total_users'].toString(),
                      Icons.people_rounded,
                      Colors.blue,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      'Active Users',
                      stats['active_users'].toString(),
                      Icons.trending_up_rounded,
                      Colors.green,
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      'In Rankings',
                      stats['filtered_users'].toString(),
                      Icons.leaderboard_rounded,
                      Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 20.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40.h,
      width: 1.w,
      margin: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedFilterToggle(LeadProvider provider) {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 0.5),
            child: Opacity(
              opacity: _safeOpacity(_fadeAnimation.value),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: Container(
                  height: 50.h,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildEnhancedFilterButton(
                        'Weekly', 
                        provider.timeFilter == 'Weekly',
                        Icons.calendar_view_week,
                        () => provider.setTimeFilter('Weekly'),
                      ),
                      _buildEnhancedFilterButton(
                        'All Time', 
                        provider.timeFilter == 'All Time',
                        Icons.history,
                        () => provider.setTimeFilter('All Time'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedFilterButton(
    String text, 
    bool isSelected, 
    IconData icon,
    VoidCallback onTap
  ) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(
            colors: [
              AppTheme.secondaryColor,
              AppTheme.secondaryColor.withOpacity(0.8),
            ],
          ) : null,
          borderRadius: BorderRadius.circular(21.r),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.secondaryColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(21.r),
            child: Container(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: Colors.white,
                    size: 16.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedFilters(LeadProvider provider) {
    return SliverToBoxAdapter(
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 0.3),
            child: Opacity(
              opacity: _safeOpacity(_fadeAnimation.value),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildEnhancedDropdownFilter(
                        'College',
                        provider.collegeFilter,
                        provider.availableColleges,
                        Icons.school,
                        (value) => provider.setCollegeFilter(value ?? 'All'),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildEnhancedDropdownFilter(
                        'Department',
                        provider.departmentFilter,
                        provider.availableDepartments,
                        Icons.business,
                        (value) => provider.setDepartmentFilter(value ?? 'All'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedDropdownFilter(
    String label,
    String value,
    List<String> items,
    IconData icon,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: DropdownButton<String>(
        value: value,
        icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20.sp),
        elevation: 16,
        style: TextStyle(color: Colors.white, fontSize: 14.sp),
        underline: const SizedBox(),
        dropdownColor: AppTheme.primaryColor,
        isExpanded: true,
        hint: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 12.sp),
            ),
          ],
        ),
        onChanged: onChanged,
        items: items.map<DropdownMenuItem<String>>((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Row(
              children: [
                if (item != 'All') ...[
                  Icon(icon, color: Colors.white70, size: 14.sp),
                  SizedBox(width: 8.w),
                ],
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
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

  Widget _buildEnhancedPodium(List<Map<String, dynamic>> topThree) {
    return AnimatedBuilder(
      animation: _podiumAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _safeOpacity(_podiumAnimation.value),
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
            height: 320.h,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: EnhancedNetworkPainter(_safeOpacity(_podiumAnimation.value)),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    topThree.length >= 2 ? _buildEnhancedPodiumItem(
                      topThree[1], 
                      2, 
                      80.h, 
                      const Color(0xFFC0C0C0),
                      0.3,
                    ) : const SizedBox(),
                    topThree.isNotEmpty ? _buildEnhancedPodiumItem(
                      topThree[0], 
                      1, 
                      110.h, 
                      const Color(0xFFFFD700),
                      0.0,
                    ) : const SizedBox(),
                    topThree.length >= 3 ? _buildEnhancedPodiumItem(
                      topThree[2], 
                      3, 
                      60.h, 
                      const Color(0xFFCD7F32),
                      0.6,
                    ) : const SizedBox(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedPodiumItem(
    Map<String, dynamic> user, 
    int position, 
    double height, 
    Color medalColor,
    double animationDelay,
  ) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _podiumController,
        builder: (context, child) {
          final delayedAnimation = Tween<double>(
            begin: 0.0,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: _podiumController,
            curve: Interval(animationDelay, 1.0, curve: Curves.elasticOut),
          ));
          
          return Transform.scale(
            scale: _safeOpacity(delayedAnimation.value),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (position == 1) ...[
                  SizedBox(
                    height: 35.h,
                    child: TweenAnimationBuilder<double>(
                      duration: const Duration(seconds: 2),
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, sin(value * 2 * pi) * 2),
                          child: Container(
                            padding: EdgeInsets.all(4.w),
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.amber.withOpacity(0.3),
                                  Colors.transparent,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.emoji_events,
                              color: medalColor,
                              size: 24.sp,
                              shadows: [
                                Shadow(
                                  color: medalColor.withOpacity(0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else 
                  SizedBox(height: 35.h),
                
                SizedBox(height: 8.h),
                
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: (position == 1 ? 65 : 50).w,
                      height: (position == 1 ? 65 : 50).w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            medalColor.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: (position == 1 ? 54 : 42).w,
                      height: (position == 1 ? 54 : 42).w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: medalColor,
                          width: 2.w,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: medalColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: (position == 1 ? 25 : 19).r,
                        backgroundColor: Colors.white,
                        backgroundImage: user['profile_image'] != null && 
                                        user['profile_image'].toString().isNotEmpty
                            ? NetworkImage(user['profile_image'])
                            : null,
                        child: user['profile_image'] == null || 
                              user['profile_image'].toString().isEmpty
                            ? Icon(
                                Icons.person,
                                size: (position == 1 ? 26 : 20).sp,
                                color: AppTheme.primaryColor,
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          color: medalColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            position.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 8.h),
                
                Flexible(
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          (user['username'] ?? 'User').toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: (position == 1 ? 12 : 10).sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 3.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: medalColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            '${user['points'] ?? 0} GP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 6.h),
                
                Container(
                  height: height,
                  margin: EdgeInsets.symmetric(horizontal: 8.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        medalColor.withOpacity(0.8),
                        medalColor.withOpacity(0.6),
                        medalColor.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12.r),
                      topRight: Radius.circular(12.r),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: medalColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 6.h,
                        left: 8.w,
                        right: 8.w,
                        child: Container(
                          height: 12.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          position.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: (position == 1 ? 26 : 20).sp,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 1),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedUsersList(List<Map<String, dynamic>> remainingUsers, LeadProvider provider) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30.r),
            topRight: Radius.circular(30.r),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 20.h, bottom: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Other Rankings',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ],
              ),
            ),
            
            if (!provider.isUserInTopThree() && provider.currentUserRank > 0)
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: _buildEnhancedUserRankItem(
                  provider.currentUserData ?? {},
                  provider.currentUserRank,
                  true,
                  0,
                ),
              ),
            
            ...remainingUsers.asMap().entries.map((entry) {
              final index = entry.key;
              final user = entry.value;
              final rank = index + 4;
              return AnimatedContainer(
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutBack,
                margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                child: _buildEnhancedUserRankItem(
                  user, 
                  rank,
                  false,
                  index * 0.1,
                ),
              );
            }).toList(),
            
            SizedBox(height: 80.h),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedUserRankItem(
    Map<String, dynamic> user, 
    int rank,
    bool isCurrentUser,
    double animationDelay,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 600 + (animationDelay * 1000).round()),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutBack,
      builder: (context, animation, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - animation), 0),
          child: Opacity(
            opacity: _safeOpacity(animation),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCurrentUser ? [
                    AppTheme.secondaryColor.withOpacity(0.2),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ] : [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isCurrentUser 
                      ? AppTheme.secondaryColor.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
                boxShadow: [
                  if (isCurrentUser) BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20.r),
                  onTap: () {
                    HapticFeedback.lightImpact();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isCurrentUser ? [
                                AppTheme.secondaryColor,
                                AppTheme.secondaryColor.withOpacity(0.7),
                              ] : [
                                Colors.white.withOpacity(0.2),
                                Colors.white.withOpacity(0.1),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              rank.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16.sp,
                              ),
                            ),
                          ),
                        ),
                        
                        SizedBox(width: 16.w),
                        
                        Stack(
                          children: [
                            Container(
                              width: 50.w,
                              height: 50.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 50.w,
                              height: 50.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isCurrentUser 
                                      ? AppTheme.secondaryColor.withOpacity(0.5)
                                      : Colors.white.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 23.r,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                backgroundImage: user['profile_image'] != null && 
                                                user['profile_image'].toString().isNotEmpty
                                    ? NetworkImage(user['profile_image'])
                                    : null,
                                child: user['profile_image'] == null || 
                                      user['profile_image'].toString().isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 24.sp,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                            ),
                            
                            if (user['is_online'] == true)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  width: 14.w,
                                  height: 14.w,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        
                        SizedBox(width: 16.w),
                        
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      (user['username'] ?? 'User').toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  
                                  if (isCurrentUser)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w, 
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: Text(
                                        'You',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              
                              SizedBox(height: 4.h),
                              
                              Row(
                                children: [
                                  if (user['college'] != null) ...[
                                    Icon(
                                      Icons.school,
                                      size: 12.sp,
                                      color: Colors.white60,
                                    ),
                                    SizedBox(width: 4.w),
                                    Expanded(
                                      child: Text(
                                        user['college'].toString(),
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 12.sp,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w, 
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.withOpacity(0.2),
                                    Colors.orange.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: Colors.amber.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    color: Colors.amber,
                                    size: 16.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${user['points'] ?? 0}',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'points',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32.w),
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(seconds: 2),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.8 + (sin(value * 2 * pi) * 0.1),
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.amber,
                      size: 80.sp,
                    ),
                  ),
                );
              },
            ),
            SizedBox(height: 24.h),
            Text(
              'No Rankings Available',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              'Complete activities and earn points\nto appear on the leaderboard',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondaryColor,
                    AppTheme.secondaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.secondaryColor.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16.r),
                  onTap: () {
                    Provider.of<LeadProvider>(context, listen: false).refreshData();
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'Refresh Data',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EnhancedNetworkPainter extends CustomPainter {
  final double animationValue;
  
  EnhancedNetworkPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    
    final center1X = size.width / 2;
    final center2X = size.width / 4;
    final center3X = size.width * 3 / 4;
    final centerY = size.height * 0.3;
    
    final colors = [
      Colors.white.withOpacity((0.1 * animationValue).clamp(0.0, 1.0)),
      Colors.amber.withOpacity((0.05 * animationValue).clamp(0.0, 1.0)),
      Colors.purple.withOpacity((0.08 * animationValue).clamp(0.0, 1.0)),
    ];
    
    for (int colorIndex = 0; colorIndex < colors.length; colorIndex++) {
      paint.color = colors[colorIndex];
      
      path.reset();
      path.moveTo(center1X, centerY);
      path.quadraticBezierTo(
        (center1X + center2X) / 2, 
        centerY - (20 * animationValue * sin(colorIndex * pi / 3)), 
        center2X, 
        centerY
      );
      
      path.moveTo(center1X, centerY);
      path.quadraticBezierTo(
        (center1X + center3X) / 2, 
        centerY - (20 * animationValue * cos(colorIndex * pi / 3)), 
        center3X, 
        centerY
      );
      
      for (int i = 0; i < 6; i++) {
        final angle = (i * (pi / 3)) + (animationValue * pi / 6);
        final length = (size.width / 5) * animationValue;
        
        path.moveTo(center1X, centerY);
        path.lineTo(
          center1X + cos(angle) * length,
          centerY + sin(angle) * length * 0.5,
        );
      }
      
      canvas.drawPath(path, paint);
    }
    
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final x = (size.width / 8) * i;
      final y = size.height * 0.1 + sin((animationValue * 2 * pi) + (i * pi / 4)) * 10;
      paint.color = Colors.white.withOpacity((0.1 * animationValue).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), 2 * animationValue, paint);
    }
  }
  
  @override
  bool shouldRepaint(EnhancedNetworkPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}