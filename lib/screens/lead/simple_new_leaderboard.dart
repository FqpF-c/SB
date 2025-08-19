import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../providers/lead_provider.dart';
import '../../utils/dynamic_status_bar.dart';

class SimpleNewLeaderboard extends StatefulWidget {
  const SimpleNewLeaderboard({super.key});

  @override
  State<SimpleNewLeaderboard> createState() => _SimpleNewLeaderboardState();
}

class _SimpleNewLeaderboardState extends State<SimpleNewLeaderboard>
    with TickerProviderStateMixin, DynamicStatusBarMixin {
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
    return DynamicStatusBar.buildDynamicScaffold(
      body: SafeArea(
        top: false,
        child: Consumer<LeadProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return _buildLoadingState();
            }

            return RefreshIndicator(
              color: const Color(0xFFdf678c),
              backgroundColor: Colors.white,
              strokeWidth: 3,
              displacement: 0.0, // Prevent visual pulling
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
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: ClampingScrollPhysics(),
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
                  if (provider.currentUserRank > 3)
                    _buildYourRankCard(provider),

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
            padding: EdgeInsets.fromLTRB(
                16.w, MediaQuery.of(context).padding.top + 16.h, 16.w, 140.w),
            decoration: BoxDecoration(
              color: const Color(0xFFdf678c),
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
                    Transform.translate(
                      offset: Offset(-16.w, 0),
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left,
                            color: Colors.white, size: 36),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                // Title positioned to start where arrow ends
                Padding(
                  padding: EdgeInsets.only(left: 24.w, bottom: 20.h),
                  child: const Text(
                    'Leaderboard',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Large half-circles at top-right corner rgb(218, 124, 162)
          Positioned(
            top: -100.h,
            right: -100.w,
            child: Container(
              width: 230.w,
              height: 230.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFFe26e92),
                  width: 2,
                ),
              ),
              child: Center(
                child: Container(
                  width: 120.w,
                  height: 120.w,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFe26e92),
                  ),
                ),
              ),
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
                color: const Color(0xFF3d1560), // Dark purple
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
                      color: const Color(0xFFffd6dd),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem('5', 'Total Users', Icons.person),
                      SizedBox(width: 12.w),
                      _buildStatItem('55', 'Active Users', Icons.location_on),
                      SizedBox(width: 12.w),
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
      child: Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: const Color(0xFF3d1560),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: const Color(0xFF6e2e6d),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            // Icon positioned at absolute top-left corner with bigger container
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF662a6c),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12.r),
                    topRight: Radius.circular(8.r),
                    bottomLeft: Radius.circular(8.r),
                    bottomRight: Radius.circular(12.r),
                  ),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFFdf678c),
                  size: 20.sp,
                ),
              ),
            ),
            // Number positioned at top-right (moved left)
            Positioned(
              top: 12.h,
              right: 20.w,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            // Text positioned at bottom center
            Positioned(
              bottom: 8.h,
              left: 8.w,
              right: 8.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: const Color(0xFF9e8ab0),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
          ],
        ),
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
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: DropdownButton<String>(
                    value: 'Monthly',
                    underline: const SizedBox(),
                    isDense: true,
                    icon: const Icon(Icons.keyboard_arrow_down,
                        size: 16, color: Color(0xFFdf678c)),
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
                    SizedBox(width: 12.w),
                    // 2nd place (center)
                    if (topThree.length >= 2)
                      _buildPerformanceBar(topThree[1], 2, 0.7),
                    SizedBox(width: 12.w),
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
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 20, color: Color(0xFFdf678c)),
                    SizedBox(width: 4),
                    Text('Top Performance Category',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
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
                    height: 95.h *
                        heightFactor *
                        _barAnimationController
                            .value, // Reduced from 110.h to 95.h
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
                      borderRadius: BorderRadius.circular(8.r),
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
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2d1050)),
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
              color: const Color(0xFFdf678c).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: const Color(0xFFdf678c).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.r),
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
            Transform.translate(
              offset: Offset(0, -6.h),
              child: Container(
                padding: EdgeInsets.only(
                    left: 2.w, right: 10.w, top: 1.h, bottom: 1.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFfefdff), // Points background
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: const Color(0xFFe9e3ee),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/xp_icon.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.emoji_events,
                          color: const Color(0xFF4B2C80),
                          size: 24,
                        );
                      },
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${user['points'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B2C80), // Points text
                      ),
                    ),
                  ],
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
                                fontSize: 12, fontWeight: FontWeight.w600),
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
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        if (user['college'] != null)
                          Row(
                            children: [
                              const Icon(Icons.school_outlined,
                                  size: 12, color: Color(0xFF6B6B6B)),
                              SizedBox(width: 12.w),
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
                  Transform.translate(
                    offset: Offset(0, -12.h),
                    child: Container(
                      padding: EdgeInsets.only(
                          left: 2.w, right: 10.w, top: 1.h, bottom: 1.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFfefdff),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: const Color(0xFFe9e3ee),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/xp_icon.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.emoji_events,
                                color: const Color(0xFF4B2C80),
                                size: 24,
                              );
                            },
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${user['points'] ?? 0}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B2C80),
                            ),
                          ),
                        ],
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
