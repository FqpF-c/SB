import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/leaderboard_models.dart';
import '../../lib/providers/new_leaderboard_provider.dart';
import '../../lib/repositories/leaderboard_repository.dart';

/// Simple mock repository for testing without mockito dependency
class TestLeaderboardRepository implements LeaderboardRepository {
  final Map<String, LeaderboardSnapshot> _mockData = {};
  bool shouldFail = false;
  
  @override
  Future<LeaderboardSnapshot> fetchLeaderboard({
    required Timeframe timeframe,
    String? group,
    String? category,
    int page = 0,
    int pageSize = 10,
  }) async {
    if (shouldFail) {
      throw Exception('Test error');
    }
    
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network
    
    final key = '${timeframe.displayName}_${group}_${category}_${page}_$pageSize';
    
    if (!_mockData.containsKey(key)) {
      _mockData[key] = _createMockSnapshot(page, pageSize);
    }
    
    return _mockData[key]!;
  }
  
  @override
  Future<Map<String, List<String>>> getFilterOptions() async {
    return {
      'groups': ['All', 'MIT', 'Stanford', 'Harvard'],
      'categories': ['All', 'Computer Science', 'Engineering'],
    };
  }
  
  @override
  void clearCache() {
    _mockData.clear();
  }
  
  LeaderboardSnapshot _createMockSnapshot(int page, int pageSize) {
    final users = List.generate(pageSize, (index) {
      final globalIndex = (page * pageSize) + index;
      return LeaderboardUser(
        id: 'user_$globalIndex',
        name: 'User $globalIndex',
        points: 1000 - (globalIndex * 10),
        rank: globalIndex + 4, // +4 because top 3 are separate
        organization: 'Test University',
      );
    });
    
    return LeaderboardSnapshot(
      stats: LeaderboardStats(
        totalUsers: 100,
        activeUsers: 75,
        inRankings: 50,
        lastUpdated: DateTime.now(),
      ),
      topThree: const [
        LeaderboardUser(id: '1', name: 'Top 1', points: 1000, rank: 1),
        LeaderboardUser(id: '2', name: 'Top 2', points: 950, rank: 2),
        LeaderboardUser(id: '3', name: 'Top 3', points: 900, rank: 3),
      ],
      currentUser: const LeaderboardUser(
        id: 'current',
        name: 'Current User',
        points: 500,
        rank: 15,
        isYou: true,
      ),
      users: users,
      totalPages: 5,
      currentPage: page,
      hasMorePages: page < 4,
      timestamp: DateTime.now(),
    );
  }
}

void main() {
  group('NewLeaderboardProvider', () {
    late TestLeaderboardRepository mockRepository;
    late NewLeaderboardProvider provider;

    setUp(() {
      mockRepository = TestLeaderboardRepository();
      provider = NewLeaderboardProvider(mockRepository);
    });

    tearDown(() {
      provider.dispose();
    });

    test('should initialize with correct default values', () {
      expect(provider.isLoading, false);
      expect(provider.isLoadingMore, false);
      expect(provider.isRefreshing, false);
      expect(provider.error, isNull);
      expect(provider.filters.timeframe, Timeframe.weekly);
      expect(provider.topThree, isEmpty);
      expect(provider.currentUser, isNull);
      expect(provider.allUsers, isEmpty);
    });

    test('should load data successfully', () async {
      await provider.loadData();

      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.topThree.length, 3);
      expect(provider.currentUser?.name, 'Current User');
      expect(provider.allUsers.length, 10); // Default page size
      expect(provider.stats.totalUsers, 100);
    });

    test('should handle loading error correctly', () async {
      mockRepository.shouldFail = true;

      await provider.loadData();

      expect(provider.isLoading, false);
      expect(provider.error, isNotNull);
      expect(provider.hasRetriableError, true);
    });

    test('should refresh data correctly', () async {
      await provider.refresh();

      expect(provider.isRefreshing, false);
      expect(provider.error, isNull);
      expect(provider.topThree.length, 3);
    });

    test('should update timeframe filter correctly', () async {
      await provider.setTimeframe(Timeframe.monthly);

      expect(provider.filters.timeframe, Timeframe.monthly);
      expect(provider.timeframeDisplayName, 'Monthly');
    });

    test('should update group filter correctly', () async {
      await provider.setGroup('MIT');

      expect(provider.filters.group, 'MIT');
    });

    test('should update category filter correctly', () async {
      await provider.setCategory('Programming');

      expect(provider.filters.category, 'Programming');
    });

    test('should generate correct period info', () {
      expect(provider.periodInfo, contains('Week of'));

      provider.filters = provider.filters.copyWith(timeframe: Timeframe.daily);
      expect(provider.periodInfo, contains('Today'));

      provider.filters = provider.filters.copyWith(timeframe: Timeframe.monthly);
      expect(provider.periodInfo, contains('Month of'));

      provider.filters = provider.filters.copyWith(timeframe: Timeframe.allTime);
      expect(provider.periodInfo, 'All Time Rankings');
    });

    test('should reset correctly', () async {
      // Load some data first
      await provider.loadData();
      expect(provider.topThree.isNotEmpty, true);

      // Reset
      provider.reset();

      expect(provider.topThree, isEmpty);
      expect(provider.currentUser, isNull);
      expect(provider.allUsers, isEmpty);
      expect(provider.error, isNull);
      expect(provider.filters.timeframe, Timeframe.weekly);
    });

    test('should clear error correctly', () async {
      mockRepository.shouldFail = true;
      await provider.loadData();
      expect(provider.error, isNotNull);

      provider.clearError();
      expect(provider.error, isNull);
    });
  });
}