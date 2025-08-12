import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import '../../lib/models/leaderboard_models.dart';
import '../../lib/providers/new_leaderboard_provider.dart';
import '../../lib/repositories/leaderboard_repository.dart';

@GenerateMocks([LeaderboardRepository])
void main() {
  group('NewLeaderboardProvider', () {
    late MockLeaderboardRepository mockRepository;
    late NewLeaderboardProvider provider;
    late LeaderboardSnapshot mockSnapshot;

    setUp(() {
      mockRepository = MockLeaderboardRepository();
      provider = NewLeaderboardProvider(mockRepository);

      // Create mock data
      mockSnapshot = LeaderboardSnapshot(
        stats: LeaderboardStats(
          totalUsers: 100,
          activeUsers: 75,
          inRankings: 50,
          lastUpdated: DateTime.now(),
        ),
        topThree: const [
          LeaderboardUser(id: '1', name: 'User 1', points: 1000, rank: 1),
          LeaderboardUser(id: '2', name: 'User 2', points: 900, rank: 2),
          LeaderboardUser(id: '3', name: 'User 3', points: 800, rank: 3),
        ],
        currentUser: const LeaderboardUser(
          id: 'current', 
          name: 'Current User', 
          points: 500, 
          rank: 10,
          isYou: true,
        ),
        users: const [
          LeaderboardUser(id: '4', name: 'User 4', points: 700, rank: 4),
          LeaderboardUser(id: '5', name: 'User 5', points: 600, rank: 5),
        ],
        totalPages: 5,
        currentPage: 0,
        hasMorePages: true,
        timestamp: DateTime.now(),
      );
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
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {
                'groups': ['All', 'MIT', 'Stanford'],
                'categories': ['All', 'CS', 'Engineering'],
              });

      await provider.loadData();

      expect(provider.isLoading, false);
      expect(provider.error, isNull);
      expect(provider.topThree.length, 3);
      expect(provider.currentUser?.name, 'Current User');
      expect(provider.allUsers.length, 2);
      expect(provider.stats.totalUsers, 100);
    });

    test('should handle loading error correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenThrow(Exception('Network error'));

      await provider.loadData();

      expect(provider.isLoading, false);
      expect(provider.error, contains('Failed to load data'));
      expect(provider.hasRetriableError, true);
    });

    test('should refresh data correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

      await provider.refresh();

      expect(provider.isRefreshing, false);
      expect(provider.error, isNull);
      verify(mockRepository.clearCache()).called(1);
    });

    test('should load more users correctly', () async {
      // Setup initial data
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: 0,
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

      await provider.loadData();

      // Setup next page data
      final nextPageSnapshot = mockSnapshot.copyWith(
        users: const [
          LeaderboardUser(id: '6', name: 'User 6', points: 500, rank: 6),
          LeaderboardUser(id: '7', name: 'User 7', points: 400, rank: 7),
        ],
        currentPage: 1,
        hasMorePages: false,
      );

      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: 1,
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => nextPageSnapshot);

      await provider.loadMoreUsers();

      expect(provider.isLoadingMore, false);
      expect(provider.allUsers.length, 4); // 2 initial + 2 from next page
      expect(provider.hasMorePages, false);
    });

    test('should update timeframe filter correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      await provider.setTimeframe(Timeframe.monthly);

      expect(provider.filters.timeframe, Timeframe.monthly);
      expect(provider.timeframeDisplayName, 'Monthly');
    });

    test('should update group filter correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      await provider.setGroup('MIT');

      expect(provider.filters.group, 'MIT');
    });

    test('should update category filter correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      await provider.setCategory('Programming');

      expect(provider.filters.category, 'Programming');
    });

    test('should get user by rank correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

      await provider.loadData();

      final user1 = provider.getUserByRank(1);
      final user4 = provider.getUserByRank(4);
      final invalidUser = provider.getUserByRank(100);

      expect(user1?.name, 'User 1');
      expect(user4?.name, 'User 4');
      expect(invalidUser, isNull);
    });

    test('should identify current user in top three correctly', () async {
      final topThreeCurrentUser = mockSnapshot.copyWith(
        currentUser: const LeaderboardUser(
          id: 'current',
          name: 'Current User',
          points: 1000,
          rank: 2,
          isYou: true,
        ),
      );

      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => topThreeCurrentUser);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

      await provider.loadData();

      expect(provider.isCurrentUserInTopThree, true);
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

    test('should retry after error correctly', () async {
      // First call fails
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenThrow(Exception('Network error'));

      await provider.loadData();
      expect(provider.hasRetriableError, true);

      // Second call succeeds
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      await provider.retry();

      expect(provider.hasRetriableError, false);
      expect(provider.error, isNull);
      expect(provider.topThree.length, 3);
    });

    test('should reset correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot);

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

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
      verify(mockRepository.clearCache()).called(1);
    });

    test('should not load more when cannot load more', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenAnswer((_) async => mockSnapshot.copyWith(hasMorePages: false));

      when(mockRepository.getFilterOptions())
          .thenAnswer((_) async => {'groups': ['All'], 'categories': ['All']});

      await provider.loadData();
      expect(provider.canLoadMore, false);

      // This should not make any repository calls
      await provider.loadMoreUsers();
      
      // Verify no additional calls were made
      verifyNever(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: 1,
        pageSize: anyNamed('pageSize'),
      ));
    });

    test('should clear error correctly', () async {
      when(mockRepository.fetchLeaderboard(
        timeframe: anyNamed('timeframe'),
        group: anyNamed('group'),
        category: anyNamed('category'),
        page: anyNamed('page'),
        pageSize: anyNamed('pageSize'),
      )).thenThrow(Exception('Network error'));

      await provider.loadData();
      expect(provider.error, isNotNull);

      provider.clearError();
      expect(provider.error, isNull);
    });
  });
}