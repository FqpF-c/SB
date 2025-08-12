import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/lead_provider.dart';

class SimpleNewLeaderboard extends StatefulWidget {
  const SimpleNewLeaderboard({super.key});

  @override
  State<SimpleNewLeaderboard> createState() => _SimpleNewLeaderboardState();
}

class _SimpleNewLeaderboardState extends State<SimpleNewLeaderboard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _barAnimationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _barAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Load data and start animations
    Future.microtask(() {
      Provider.of<LeadProvider>(context, listen: false).fetchLeaderboardData();
      _animationController.forward();
      Future.delayed(const Duration(milliseconds: 300), () {
        _barAnimationController.forward();
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _barAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      appBar: AppBar(
        backgroundColor: const Color(0xFFdf678c),
        elevation: 0,
        toolbarHeight: 0, // Hide the toolbar but keep the status bar styling
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFFdf678c), // Set status bar color to #df678c
          statusBarIconBrightness: Brightness.light, // White icons on colored background
        ),
      ),
      body: SafeArea(
        child: Consumer<LeadProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildLoadingState();
            }

            return RefreshIndicator(
              color: const Color(0xFFdf678c),
              backgroundColor: Colors.white,
              strokeWidth: 3,
              onRefresh: () async {
                await provider.fetchLeaderboardData();
                _animationController.reset();
                _barAnimationController.reset();
                _animationController.forward();
                Future.delayed(const Duration(milliseconds: 300), () {
                  _barAnimationController.forward();
                });
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Combined Pink Header Box with Purple Box in front
                  _buildStackedHeaderCard(provider),

                  // Spacing to account for purple box extending outside
                  SliverToBoxAdapter(
                    child: SizedBox(
                        height:
                            60.h), // Space for purple box that extends outside
                  ),

                  // Top Performers Card
                  _buildTopPerformersCard(provider),

                  // Your Rank Card (if not in top 3)
                  if (provider.currentUserRank > 3) _buildYourRankCard(provider),

                  // Other Ranking Section
                  _buildOtherRankingSection(provider),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    );
  }

  Widget _buildStackedHeaderCard(LeadProvider provider) {
    return SliverToBoxAdapter(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pink header box (background layer)
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 140.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFdf678c), Color(0xFFdf678c)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(48.r),
                bottomRight: Radius.circular(48.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section with back button and title
                Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                    const Spacer(),
                  ],
                ),
                // Title positioned to the left and below back arrow
                Padding(
                  padding: EdgeInsets.only(left: 8.w, bottom: 40.h),
                  child: const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Purple Welcome Hub box (foreground layer - in front)
          Positioned(
            bottom: -50.h, // Position so 50% is outside the pink box
            left: 32.w,
            right: 32.w,
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: const Color(0xFF3A226A), // Dark purple
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(0.2), // Stronger shadow since it's on top
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome Hub',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('5', 'Total Users', Icons.person),
                      _buildStatItem('55', 'Active Users', Icons.location_on),
                      _buildStatItem('5', 'In Rankings', Icons.bar_chart),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: const Color(0xFF4B2C80), // Rounded background for icon
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformersCard(LeadProvider provider) {
    final topThree = provider.getTopThreeUsers();

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.fromLTRB(32.w, 16.w, 32.w, 16.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: const Color(0xFFf9ecf0), // Light version of df678c
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                // Dropdown for Monthly/Daily
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: DropdownButton<String>(
                    value: 'Monthly',
                    underline: const SizedBox(),
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFFdf678c)),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3d1560)),
                    items: const [
                      DropdownMenuItem(
                          value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                    ],
                    onChanged: (value) {
                      // Handle dropdown change
                    },
                  ),
                ),
              ],
            ),
            if (topThree.isNotEmpty)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // 1st place (left - tallest)
                    if (topThree.isNotEmpty)
                      _buildPerformanceBar(topThree[0], 1, 1.0),
                    SizedBox(width: 8.w),
                    // 2nd place (center)
                    if (topThree.length >= 2)
                      _buildPerformanceBar(topThree[1], 2, 0.7),
                    SizedBox(width: 8.w),
                    // 3rd place (right)
                    if (topThree.length >= 3)
                      _buildPerformanceBar(topThree[2], 3, 0.5),
                  ],
                ),
              ),
            SizedBox(height: 16.h),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 20, color: Color(0xFFdf678c)),
                    SizedBox(width: 4),
                    Text('Top Performance Category',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceBar(
      Map<String, dynamic> user, int position, double heightFactor) {
    final barColor = position == 1
        ? const Color(0xFFdf678c)
        : position == 2
            ? const Color(0xFFe8a9c1)
            : const Color(0xFFf0c4d6);

    return SizedBox(
      width: 60.w, // Fixed width for slimmer bars
      child: AnimatedBuilder(
        animation: _barAnimationController,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stack for bar and overlapping avatar
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Animated bar
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 95.h * heightFactor * _barAnimationController.value, // Reduced from 110.h to 95.h
                    width: 40.w, // Slimmer bar width
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          barColor.withOpacity(0.8),
                          barColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const SizedBox(),
                  ),
                  
                  // Avatar positioned to overlap bar (half inside, half outside)
                  Positioned(
                    top: -14.w, // Half of 28.w
                    child: Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: barColor, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 12.r,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          (user['username'] ?? 'U')
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 4.h),
              
              // Username at bottom
              Text(
                (user['username'] ?? 'User').toString(),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2d1050)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h), // Reduced from 8.h to 4.h
            ],
          );
        },
      ),
    );
  }

  Widget _buildYourRankCard(LeadProvider provider) {
    final user = provider.currentUserData;
    if (user == null) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 32.w, vertical: 8.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFdf678c).withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50.w,
              height: 50.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFdf678c), width: 2),
              ),
              child: CircleAvatar(
                radius: 23.r,
                child: Text(
                  (user['username'] ?? 'Y')
                      .toString()
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['username'] ?? 'You',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFdf678c).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFdf678c))),
                      ),
                    ],
                  ),
                  if (user['college'] != null)
                    Text(
                      user['college'].toString(),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B6B6B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Points capsule
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: const Color(0xFFEFE6FF), // Points background
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                '${user['points'] ?? 0}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B2C80), // Points text
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherRankingSection(LeadProvider provider) {
    final remainingUsers = provider.getRemainingUsers();

    return SliverToBoxAdapter(
      child: Column(
      children: [
        // Section header
        Container(
          margin: EdgeInsets.symmetric(horizontal: 32.w, vertical: 16.h),
          child: const Row(
            children: [
              Expanded(child: Divider(color: Colors.grey)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Other Ranking',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3d1560),
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey)),
            ],
          ),
        ),
        // User list
        ...remainingUsers.asMap().entries.map((entry) {
          final userIndex = entry.key;
          final user = entry.value;
          final rank = userIndex + 4;

          return Container(
            margin: EdgeInsets.symmetric(horizontal: 32.w, vertical: 5.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
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
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: CircleAvatar(
                        radius: 19.r,
                        child: Text(
                          (user['username'] ?? 'U')
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -2,
                      left: -2,
                      child: Container(
                        width: 18.w,
                        height: 18.w,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B6B6B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                        child: Center(
                          child: Text(
                            rank.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['username'] ?? 'User',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      if (user['college'] != null)
                        Row(
                          children: [
                            const Icon(Icons.school_outlined,
                                size: 12, color: Color(0xFF6B6B6B)),
                            SizedBox(width: 4.w),
                            Expanded(
                              child: Text(
                                user['college'].toString(),
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF6B6B6B)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Points capsule
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE6FF),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    '${user['points'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B2C80),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
      ),
    );
  }
}
