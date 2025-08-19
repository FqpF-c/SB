import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../theme/leaderboard_theme.dart';
import '../../models/leaderboard_models.dart';
import '../../providers/new_leaderboard_provider.dart';
// import '../../repositories/leaderboard_repository.dart';
// import '../../providers/lead_provider.dart'; // Legacy provider for adapter

import '../../widgets/leaderboard/leaderboard_header.dart';
import '../../widgets/leaderboard/welcome_hub_card.dart';
import '../../widgets/leaderboard/top_performers_card.dart';
import '../../widgets/leaderboard/your_rank_card.dart';
import '../../widgets/leaderboard/user_list_item.dart';
import '../../widgets/leaderboard/filter_controls.dart';
import '../../utils/dynamic_status_bar.dart';

/// New leaderboard screen with modern design and smooth animations
class NewLeaderboardScreen extends StatefulWidget {
  const NewLeaderboardScreen({super.key});

  @override
  State<NewLeaderboardScreen> createState() => _NewLeaderboardScreenState();
}

class _NewLeaderboardScreenState extends State<NewLeaderboardScreen>
    with TickerProviderStateMixin, DynamicStatusBarMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late List<Animation<double>> _staggerAnimations;

  @override
  void initState() {
    super.initState();
    _setupControllers();
    _setupAnimations();
  }

  void _setupControllers() {
    scrollController.addListener(_onScroll);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
  }

  void _setupAnimations() {
    _staggerAnimations = List.generate(4, (index) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.15,
            (index * 0.15) + 0.6,
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      _staggerController.forward();
    });
  }

  void _onScroll() {
    final provider =
        Provider.of<NewLeaderboardProvider>(context, listen: false);

    // Load more when near bottom
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      provider.loadMoreUsers();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicStatusBar.buildDynamicScaffold(
      body: Consumer<NewLeaderboardProvider>(
        builder: (context, provider, child) {
          if (provider.hasRetriableError) {
            return _buildErrorState(provider);
          }

          return Stack(
            children: [
              // Background gradient
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [SBColors.gradientStart, SBColors.gradientEnd],
                  ),
                ),
              ),

              // Main content
              RefreshIndicator(
                onRefresh: provider.refresh,
                color: SBColors.gradientStart,
                backgroundColor: Colors.white,
                displacement: 0.0, // Prevent visual pulling
                strokeWidth: 3.0,
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: FadeTransition(
                        opacity: _staggerAnimations[0],
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, -0.2),
                            end: Offset.zero,
                          ).animate(_staggerAnimations[0]),
                          child: LeaderboardHeader(
                            onBackPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),

                    // Welcome Hub Card (overlapping header)
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: Offset(0, -SBConstants.statsCardOverlap),
                        child: FadeTransition(
                          opacity: _staggerAnimations[1],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(_staggerAnimations[1]),
                            child: provider.isLoading
                                ? const WelcomeHubCardSkeleton()
                                : WelcomeHubCard(stats: provider.stats),
                          ),
                        ),
                      ),
                    ),

                    // Filter Controls
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset:
                            Offset(0, -SBConstants.statsCardOverlap + SBGap.lg),
                        child: FadeTransition(
                          opacity: _staggerAnimations[1],
                          child: FilterControls(
                            selectedTimeframe: provider.filters.timeframe,
                            onTimeframeChanged: provider.setTimeframe,
                            selectedGroup: provider.filters.group,
                            onGroupChanged: provider.setGroup,
                            selectedCategory: provider.filters.category,
                            onCategoryChanged: provider.setCategory,
                            filterOptions: provider.filterOptions,
                            showLegacyToggle: true,
                          ),
                        ),
                      ),
                    ),

                    // Top Performers Card
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: Offset(
                            0, -SBConstants.statsCardOverlap + (SBGap.lg * 2)),
                        child: FadeTransition(
                          opacity: _staggerAnimations[2],
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(_staggerAnimations[2]),
                            child: TopPerformersCard(
                              topThree: provider.topThree,
                              selectedTimeframe: provider.filters.timeframe,
                              onTimeframeChanged: provider.setTimeframe,
                              isLoading: provider.isLoading,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Your Rank Card (if not in top 3)
                    if (provider.currentUser != null &&
                        !provider.isCurrentUserInTopThree)
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0,
                              -SBConstants.statsCardOverlap + (SBGap.lg * 2)),
                          child: FadeTransition(
                            opacity: _staggerAnimations[2],
                            child: YourRankCard(
                              currentUser: provider.currentUser!,
                              isLoading: provider.isLoading,
                            ),
                          ),
                        ),
                      ),

                    // Section Header
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: Offset(
                            0, -SBConstants.statsCardOverlap + (SBGap.lg * 3)),
                        child: FadeTransition(
                          opacity: _staggerAnimations[3],
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: SBInsets.h,
                              vertical: SBGap.lg,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40.w,
                                  height: 2.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                SizedBox(width: SBGap.md),
                                Text(
                                  'Other Ranking',
                                  style: SBTypography.sectionHeader.copyWith(
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                  ),
                                ),
                                SizedBox(width: SBGap.md),
                                Container(
                                  width: 40.w,
                                  height: 2.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Users List
                    Transform.translate(
                      offset: Offset(
                          0, -SBConstants.statsCardOverlap + (SBGap.lg * 3)),
                      child: provider.isLoading && provider.allUsers.isEmpty
                          ? _buildLoadingList()
                          : _buildUsersList(provider),
                    ),

                    // Load More Button or Loading Indicator
                    if (provider.canLoadMore)
                      SliverToBoxAdapter(
                        child: Transform.translate(
                          offset: Offset(0,
                              -SBConstants.statsCardOverlap + (SBGap.lg * 3)),
                          child: _buildLoadMoreIndicator(provider),
                        ),
                      ),

                    // Bottom spacing
                    SliverToBoxAdapter(
                      child: SizedBox(height: 100.h),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsersList(NewLeaderboardProvider provider) {
    if (provider.allUsers.isEmpty && !provider.isLoading) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final user = provider.allUsers[index];

          return FadeTransition(
            opacity: _staggerAnimations[3],
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0.1, 0.1 * (index % 5)),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: _staggerAnimations[3],
                  curve: Interval(
                    (index % 10) * 0.05,
                    1.0,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
              child: UserListItem(
                user: user,
                displayIndex: index,
                onTap: () => _handleUserTap(user),
                showOnlineIndicator: true,
              ),
            ),
          );
        },
        childCount: provider.allUsers.length,
      ),
    );
  }

  Widget _buildLoadingList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return FadeTransition(
            opacity: _staggerAnimations[3],
            child: const UserListItemSkeleton(),
          );
        },
        childCount: 6,
      ),
    );
  }

  Widget _buildLoadMoreIndicator(NewLeaderboardProvider provider) {
    if (provider.isLoadingMore) {
      return Container(
        padding: EdgeInsets.all(SBInsets.h),
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.w,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: SBInsets.h, vertical: SBGap.lg),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: provider.loadMoreUsers,
          borderRadius: BorderRadius.circular(SBRadii.md),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: SBInsets.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(SBRadii.md),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: SBGap.sm),
                Text(
                  'Load More',
                  style: SBTypography.body.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: EdgeInsets.all(SBInsets.lg * 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_outlined,
            size: 64.sp,
            color: Colors.white.withOpacity(0.5),
          ),
          SizedBox(height: SBGap.lg),
          Text(
            'No rankings available',
            style: SBTypography.title.copyWith(
              fontSize: 20.sp,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: SBGap.md),
          Text(
            'Complete activities and earn points\nto appear on the leaderboard',
            style: SBTypography.body.copyWith(
              color: Colors.white.withOpacity(0.8),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: SBGap.xl),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final provider = Provider.of<NewLeaderboardProvider>(
                  context,
                  listen: false,
                );
                provider.refresh();
              },
              borderRadius: BorderRadius.circular(SBRadii.md),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: SBGap.xl,
                  vertical: SBGap.md,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white24, Colors.white12],
                  ),
                  borderRadius: BorderRadius.circular(SBRadii.md),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    SizedBox(width: SBGap.sm),
                    Text(
                      'Refresh',
                      style: SBTypography.body.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(NewLeaderboardProvider provider) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SBColors.gradientStart, SBColors.gradientEnd],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(SBInsets.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64.sp,
                  color: Colors.white.withOpacity(0.7),
                ),
                SizedBox(height: SBGap.lg),
                Text(
                  'Unable to load leaderboard',
                  style: SBTypography.title.copyWith(
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: SBGap.md),
                Text(
                  provider.error ?? 'An unexpected error occurred',
                  style: SBTypography.body.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: SBGap.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(SBRadii.md),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: SBGap.lg,
                            vertical: SBGap.md,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(SBRadii.md),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Go Back',
                            style: SBTypography.body.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: SBGap.md),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: provider.retry,
                        borderRadius: BorderRadius.circular(SBRadii.md),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: SBGap.lg,
                            vertical: SBGap.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white24, Colors.white12],
                            ),
                            borderRadius: BorderRadius.circular(SBRadii.md),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                              SizedBox(width: SBGap.xs),
                              Text(
                                'Retry',
                                style: SBTypography.body.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleUserTap(LeaderboardUser user) {
    HapticFeedback.lightImpact();

    // Show user profile or action sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildUserActionSheet(user),
    );
  }

  Widget _buildUserActionSheet(LeaderboardUser user) {
    return Container(
      padding: EdgeInsets.all(SBInsets.h),
      margin: EdgeInsets.all(SBInsets.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SBRadii.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          SizedBox(height: SBGap.lg),

          // User info
          Row(
            children: [
              Container(
                width: 50.w,
                height: 50.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SBColors.gradientStart, width: 2),
                ),
                child: CircleAvatar(
                  radius: 23.r,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: user.avatarUrl != null
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: user.avatarUrl == null
                      ? Text(
                          user.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: SBColors.textPrimary,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(width: SBGap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: SBTypography.body.copyWith(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.organization != null)
                      Text(
                        user.organization!,
                        style: SBTypography.label.copyWith(
                          color: SBColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '#${user.rank}',
                style: SBTypography.title.copyWith(
                  fontSize: 24.sp,
                  color: SBColors.gradientStart,
                ),
              ),
            ],
          ),

          SizedBox(height: SBGap.xl),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SBColors.textSecondary,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SBRadii.sm),
                    ),
                  ),
                  child: Text('Close'),
                ),
              ),
              SizedBox(width: SBGap.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to user profile
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SBColors.gradientStart,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SBRadii.sm),
                    ),
                  ),
                  child: Text(
                    'View Profile',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: SBGap.md),
        ],
      ),
    );
  }
}
