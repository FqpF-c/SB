import 'package:flutter/foundation.dart';
import '../models/leaderboard_models.dart';

/// Abstract repository interface for leaderboard data
abstract class LeaderboardRepository {
  /// Fetch leaderboard data with pagination and filters
  Future<LeaderboardSnapshot> fetchLeaderboard({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  });

  /// Get available filter options
  Future<Map<String, List<String>>> getFilterOptions();

  /// Clear any cached data
  void clearCache();
}

/// In-memory cache key for leaderboard data
@immutable
class _CacheKey {
  final Timeframe timeframe;
  final String? group;
  final String? category;
  final int page;
  final int pageSize;

  const _CacheKey({
    required this.timeframe,
    this.group,
    this.category,
    required this.page,
    required this.pageSize,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CacheKey &&
        other.timeframe == timeframe &&
        other.group == group &&
        other.category == category &&
        other.page == page &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode {
    return Object.hash(timeframe, group, category, page, pageSize);
  }
}

/// Cached entry with timestamp
class _CacheEntry {
  final LeaderboardSnapshot snapshot;
  final DateTime timestamp;

  _CacheEntry(this.snapshot, this.timestamp);

  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 5);
  }
}

/// Base implementation with caching support
abstract class CachedLeaderboardRepository implements LeaderboardRepository {
  final Map<_CacheKey, _CacheEntry> _cache = {};
  static const Duration cacheExpiry = Duration(minutes: 5);

  @override
  Future<LeaderboardSnapshot> fetchLeaderboard({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  }) async {
    final key = _CacheKey(
      timeframe: timeframe,
      group: group,
      category: category,
      page: page,
      pageSize: pageSize,
    );

    // Check cache first
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.snapshot;
    }

    // Fetch fresh data
    final snapshot = await fetchLeaderboardData(
      timeframe: timeframe,
      group: group,
      category: category,
      page: page,
      pageSize: pageSize,
    );

    // Cache the result
    _cache[key] = _CacheEntry(snapshot, DateTime.now());

    return snapshot;
  }

  /// Abstract method for subclasses to implement actual data fetching
  @protected
  Future<LeaderboardSnapshot> fetchLeaderboardData({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  });

  @override
  void clearCache() {
    _cache.clear();
  }
}

/// Mock implementation for development and testing
class MockLeaderboardRepository extends CachedLeaderboardRepository {
  static const bool _useMockData = true; // Feature flag

  @override
  Future<LeaderboardSnapshot> fetchLeaderboardData({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  }) async {
    if (!_useMockData) {
      throw UnimplementedError('Real backend not implemented');
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return _generateMockData(
      timeframe: timeframe,
      group: group,
      category: category,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<Map<String, List<String>>> getFilterOptions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    return {
      'groups': ['All', 'Engineering', 'Business', 'Design', 'Science'],
      'categories': ['All', 'Programming', 'Mathematics', 'Literature', 'Physics'],
    };
  }

  LeaderboardSnapshot _generateMockData({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  }) {
    // Generate mock users
    final allUsers = List.generate(100, (index) {
      final isCurrentUser = index == 15; // Mock current user at rank 16
      return LeaderboardUser(
        id: 'user_$index',
        name: _mockNames[index % _mockNames.length],
        avatarUrl: index % 3 == 0 ? 'https://i.pravatar.cc/150?img=$index' : null,
        organization: _mockOrganizations[index % _mockOrganizations.length],
        points: 1000 - (index * 8) + (index % 5) * 2, // Varied but descending
        rank: index + 1,
        isYou: isCurrentUser,
        isOnline: index % 4 == 0,
        lastSeen: DateTime.now().subtract(Duration(hours: index % 24)),
        metadata: {
          'college': _mockOrganizations[index % _mockOrganizations.length],
          'department': group ?? 'Computer Science',
          'batch': '2024',
        },
      );
    });

    // Apply filters
    var filteredUsers = allUsers.where((user) {
      if (group != null && group != 'All' && !user.organization!.contains(group)) {
        return false;
      }
      return true;
    }).toList();

    // Adjust points based on timeframe
    filteredUsers = filteredUsers.map((user) {
      int adjustedPoints = user.points;
      switch (timeframe) {
        case Timeframe.daily:
          adjustedPoints = (user.points * 0.1).round();
          break;
        case Timeframe.weekly:
          adjustedPoints = (user.points * 0.3).round();
          break;
        case Timeframe.monthly:
          adjustedPoints = (user.points * 0.7).round();
          break;
        case Timeframe.allTime:
          // Keep original points
          break;
      }
      return user.copyWith(points: adjustedPoints);
    }).toList();

    // Sort by points and update ranks
    filteredUsers.sort((a, b) => b.points.compareTo(a.points));
    for (int i = 0; i < filteredUsers.length; i++) {
      filteredUsers[i] = filteredUsers[i].copyWith(rank: i + 1);
    }

    // Get top 3
    final topThree = filteredUsers.take(3).toList();

    // Get current user
    final currentUser = filteredUsers.firstWhere(
      (user) => user.isYou,
      orElse: () => filteredUsers.isNotEmpty ? filteredUsers[15] : topThree.first,
    );

    // Pagination
    final startIndex = page * pageSize;
    final paginatedUsers = startIndex < filteredUsers.length 
        ? filteredUsers.skip(startIndex).take(pageSize).toList()
        : <LeaderboardUser>[];

    final totalPages = (filteredUsers.length / pageSize).ceil();
    final hasMorePages = page < totalPages - 1;

    return LeaderboardSnapshot(
      stats: LeaderboardStats(
        totalUsers: allUsers.length,
        activeUsers: allUsers.where((u) => u.isOnline).length,
        inRankings: filteredUsers.length,
        lastUpdated: DateTime.now(),
      ),
      topThree: topThree,
      currentUser: currentUser.copyWith(isYou: true),
      users: paginatedUsers,
      totalPages: totalPages,
      currentPage: page,
      hasMorePages: hasMorePages,
      timestamp: DateTime.now(),
    );
  }

  static const List<String> _mockNames = [
    'Alex Johnson', 'Sarah Chen', 'Michael Brown', 'Emily Davis', 'David Wilson',
    'Jessica Garcia', 'Ryan Martinez', 'Ashley Rodriguez', 'Justin Taylor',
    'Amanda Anderson', 'Brandon Thomas', 'Samantha Jackson', 'Kevin White',
    'Nicole Harris', 'Tyler Martin', 'Megan Thompson', 'Andrew Garcia',
    'Lauren Martinez', 'Jordan Rodriguez', 'Taylor Lewis', 'Cameron Lee',
    'Morgan Walker', 'Casey Hall', 'Riley Young', 'Avery Allen',
    'Quinn King', 'Parker Wright', 'Sage Scott', 'River Green', 'Phoenix Adams'
  ];

  static const List<String> _mockOrganizations = [
    'MIT', 'Stanford University', 'Harvard University', 'UC Berkeley',
    'Carnegie Mellon', 'Cornell University', 'Princeton University',
    'Yale University', 'Columbia University', 'University of Chicago',
    'Northwestern University', 'Duke University', 'Vanderbilt University',
    'Rice University', 'Emory University', 'Georgetown University',
    'NYU', 'Boston University', 'USC', 'UCLA'
  ];
}

/// Adapter to convert existing LeadProvider data to new interface
class LeaderboardRepositoryAdapter extends CachedLeaderboardRepository {
  final dynamic _leadProvider; // LeadProvider from existing code

  LeaderboardRepositoryAdapter(this._leadProvider);

  @override
  Future<LeaderboardSnapshot> fetchLeaderboardData({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  }) async {
    // Set filters on existing provider
    await _leadProvider.setTimeFilter(timeframe.displayName);
    if (group != null) await _leadProvider.setCollegeFilter(group);
    if (category != null) await _leadProvider.setDepartmentFilter(category);

    // Fetch data
    await _leadProvider.fetchLeaderboardData();

    // Convert to new format
    final topThree = (_leadProvider.getTopThreeUsers() as List<Map<String, dynamic>>)
        .asMap()
        .entries
        .map((entry) => LeaderboardUser.fromJson({
              ...entry.value,
              'rank': entry.key + 1,
            }))
        .toList();

    final remainingUsers = (_leadProvider.getRemainingUsers() as List<Map<String, dynamic>>)
        .asMap()
        .entries
        .map((entry) => LeaderboardUser.fromJson({
              ...entry.value,
              'rank': entry.key + 4,
            }))
        .toList();

    // Apply pagination
    final startIndex = page * pageSize;
    final paginatedUsers = startIndex < remainingUsers.length
        ? remainingUsers.skip(startIndex).take(pageSize).toList()
        : <LeaderboardUser>[];

    final totalPages = (remainingUsers.length / pageSize).ceil();

    // Convert current user
    final currentUserData = _leadProvider.currentUserData;
    final currentUser = currentUserData != null
        ? LeaderboardUser.fromJson({
            ...currentUserData,
            'rank': _leadProvider.currentUserRank,
          }, isYou: true)
        : null;

    // Convert stats
    final userStats = _leadProvider.getUserStats() as Map<String, int>;
    final stats = LeaderboardStats(
      totalUsers: userStats['total_users'] ?? 0,
      activeUsers: userStats['active_users'] ?? 0,
      inRankings: userStats['filtered_users'] ?? 0,
      lastUpdated: DateTime.now(),
    );

    return LeaderboardSnapshot(
      stats: stats,
      topThree: topThree,
      currentUser: currentUser,
      users: paginatedUsers,
      totalPages: totalPages,
      currentPage: page,
      hasMorePages: page < totalPages - 1,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<Map<String, List<String>>> getFilterOptions() async {
    return {
      'groups': _leadProvider.availableColleges as List<String>,
      'categories': _leadProvider.availableDepartments as List<String>,
    };
  }
}