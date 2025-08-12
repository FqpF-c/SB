import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/leaderboard_models.dart';
import '../../lib/repositories/leaderboard_repository.dart';

void main() {
  group('MockLeaderboardRepository', () {
    late MockLeaderboardRepository repository;

    setUp(() {
      repository = MockLeaderboardRepository();
    });

    tearDown(() {
      repository.clearCache();
    });

    test('should fetch leaderboard data successfully', () async {
      final snapshot = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );

      expect(snapshot.stats.totalUsers, greaterThan(0));
      expect(snapshot.topThree.length, lessThanOrEqualTo(3));
      expect(snapshot.users.length, lessThanOrEqualTo(10));
      expect(snapshot.currentPage, 0);
      expect(snapshot.timestamp, isA<DateTime>());
    });

    test('should return paginated results correctly', () async {
      // First page
      final page0 = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 5,
      );

      // Second page
      final page1 = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 1,
        pageSize: 5,
      );

      expect(page0.currentPage, 0);
      expect(page1.currentPage, 1);
      expect(page0.users.length, lessThanOrEqualTo(5));
      expect(page1.users.length, lessThanOrEqualTo(5));

      // Users should be different (assuming enough mock data)
      if (page0.users.isNotEmpty && page1.users.isNotEmpty) {
        expect(page0.users.first.id, isNot(equals(page1.users.first.id)));
      }
    });

    test('should handle different timeframes correctly', () async {
      final weekly = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 5,
      );

      final allTime = await repository.fetchLeaderboard(
        timeframe: Timeframe.allTime,
        page: 0,
        pageSize: 5,
      );

      // Points should be different for different timeframes
      if (weekly.users.isNotEmpty && allTime.users.isNotEmpty) {
        expect(
          weekly.users.first.points,
          isNot(equals(allTime.users.first.points)),
        );
      }
    });

    test('should apply group filters correctly', () async {
      final unfiltered = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );

      final filtered = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        group: 'MIT',
        page: 0,
        pageSize: 10,
      );

      // Filtered results should have fewer or equal users
      expect(filtered.stats.inRankings, lessThanOrEqualTo(unfiltered.stats.inRankings));
    });

    test('should include current user correctly', () async {
      final snapshot = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );

      expect(snapshot.currentUser, isNotNull);
      expect(snapshot.currentUser!.isYou, true);
      expect(snapshot.currentUser!.rank, greaterThan(0));
    });

    test('should cache results correctly', () async {
      final stopwatch = Stopwatch()..start();
      
      // First call - should fetch from "network"
      await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );
      
      final firstCallTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      // Second call with same parameters - should be cached
      await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );
      
      final secondCallTime = stopwatch.elapsedMilliseconds;

      // Cached call should be significantly faster
      expect(secondCallTime, lessThan(firstCallTime));
      expect(secondCallTime, lessThan(100)); // Should be very fast
    });

    test('should clear cache correctly', () async {
      // Populate cache
      await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );

      // Clear cache
      repository.clearCache();

      final stopwatch = Stopwatch()..start();
      
      // This call should take longer since cache was cleared
      await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );
      
      final callTime = stopwatch.elapsedMilliseconds;

      // Should take network time again
      expect(callTime, greaterThan(400)); // Network delay
    });

    test('should get filter options correctly', () async {
      final options = await repository.getFilterOptions();

      expect(options, isA<Map<String, List<String>>>());
      expect(options['groups'], isNotNull);
      expect(options['categories'], isNotNull);
      expect(options['groups']!.contains('All'), true);
      expect(options['categories']!.contains('All'), true);
    });

    test('should handle edge cases correctly', () async {
      // Very large page size
      final largePage = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 1000,
      );

      expect(largePage.users.length, lessThanOrEqualTo(100)); // Mock data limit

      // High page number
      final highPage = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 100,
        pageSize: 10,
      );

      expect(highPage.users, isEmpty); // Should be empty for out-of-range pages
    });

    test('should maintain consistent ranking order', () async {
      final snapshot = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 20,
      );

      // Check that users are sorted by points (descending)
      for (int i = 0; i < snapshot.users.length - 1; i++) {
        expect(
          snapshot.users[i].points,
          greaterThanOrEqualTo(snapshot.users[i + 1].points),
          reason: 'Users should be sorted by points in descending order',
        );
      }

      // Check that ranks are sequential and correct
      for (int i = 0; i < snapshot.users.length; i++) {
        expect(
          snapshot.users[i].rank,
          equals(i + 4), // +4 because top 3 are separate
          reason: 'User ranks should be sequential',
        );
      }
    });

    test('should generate valid mock data', () async {
      final snapshot = await repository.fetchLeaderboard(
        timeframe: Timeframe.weekly,
        page: 0,
        pageSize: 10,
      );

      // Validate all users have required fields
      for (final user in [...snapshot.topThree, ...snapshot.users]) {
        expect(user.id, isNotEmpty);
        expect(user.name, isNotEmpty);
        expect(user.points, greaterThanOrEqualTo(0));
        expect(user.rank, greaterThan(0));
      }

      // Validate stats
      expect(snapshot.stats.totalUsers, greaterThan(snapshot.stats.activeUsers));
      expect(snapshot.stats.activeUsers, greaterThanOrEqualTo(0));
      expect(snapshot.stats.inRankings, greaterThanOrEqualTo(0));
    });
  });
}