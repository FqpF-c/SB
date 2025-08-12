import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/leaderboard_models.dart';

void main() {
  group('LeaderboardUser', () {
    test('should create user from JSON correctly', () {
      final json = {
        'id': 'user123',
        'name': 'John Doe',
        'avatarUrl': 'https://example.com/avatar.jpg',
        'organization': 'MIT',
        'points': 1500,
        'rank': 5,
        'is_online': true,
        'metadata': {'department': 'CS', 'batch': '2024'},
      };

      final user = LeaderboardUser.fromJson(json);

      expect(user.id, 'user123');
      expect(user.name, 'John Doe');
      expect(user.avatarUrl, 'https://example.com/avatar.jpg');
      expect(user.organization, 'MIT');
      expect(user.points, 1500);
      expect(user.rank, 5);
      expect(user.isOnline, true);
      expect(user.isYou, false);
      expect(user.metadata['department'], 'CS');
    });

    test('should handle missing fields gracefully', () {
      final json = {
        'name': 'Jane Doe',
        'points': 1000,
      };

      final user = LeaderboardUser.fromJson(json);

      expect(user.id, '');
      expect(user.name, 'Jane Doe');
      expect(user.avatarUrl, null);
      expect(user.organization, null);
      expect(user.points, 1000);
      expect(user.rank, 0);
      expect(user.isOnline, false);
      expect(user.isYou, false);
    });

    test('should mark user as "you" when specified', () {
      final json = {'name': 'Current User', 'points': 500};
      final user = LeaderboardUser.fromJson(json, isYou: true);

      expect(user.isYou, true);
    });

    test('should convert back to JSON correctly', () {
      const user = LeaderboardUser(
        id: 'user456',
        name: 'Bob Smith',
        points: 2000,
        rank: 1,
        isYou: true,
        isOnline: false,
      );

      final json = user.toJson();

      expect(json['id'], 'user456');
      expect(json['name'], 'Bob Smith');
      expect(json['points'], 2000);
      expect(json['rank'], 1);
      expect(json['isYou'], true);
      expect(json['isOnline'], false);
    });

    test('should handle equality correctly', () {
      const user1 = LeaderboardUser(id: 'same_id', name: 'User 1', points: 100, rank: 1);
      const user2 = LeaderboardUser(id: 'same_id', name: 'User 2', points: 200, rank: 2);
      const user3 = LeaderboardUser(id: 'different_id', name: 'User 3', points: 100, rank: 1);

      expect(user1, equals(user2)); // Same ID
      expect(user1, isNot(equals(user3))); // Different ID
    });

    test('should copy with updated values', () {
      const original = LeaderboardUser(
        id: 'user123',
        name: 'Original Name',
        points: 100,
        rank: 5,
      );

      final updated = original.copyWith(
        points: 200,
        rank: 3,
      );

      expect(updated.id, 'user123');
      expect(updated.name, 'Original Name');
      expect(updated.points, 200);
      expect(updated.rank, 3);
    });
  });

  group('LeaderboardStats', () {
    test('should create stats from JSON correctly', () {
      final json = {
        'totalUsers': 1000,
        'activeUsers': 750,
        'inRankings': 500,
        'lastUpdated': '2024-01-15T10:30:00Z',
      };

      final stats = LeaderboardStats.fromJson(json);

      expect(stats.totalUsers, 1000);
      expect(stats.activeUsers, 750);
      expect(stats.inRankings, 500);
      expect(stats.lastUpdated.year, 2024);
      expect(stats.lastUpdated.month, 1);
      expect(stats.lastUpdated.day, 15);
    });

    test('should handle missing fields with defaults', () {
      final stats = LeaderboardStats.fromJson({});

      expect(stats.totalUsers, 0);
      expect(stats.activeUsers, 0);
      expect(stats.inRankings, 0);
      expect(stats.lastUpdated, isA<DateTime>());
    });

    test('should convert back to JSON correctly', () {
      final stats = LeaderboardStats(
        totalUsers: 500,
        activeUsers: 300,
        inRankings: 200,
        lastUpdated: DateTime(2024, 1, 15, 10, 30),
      );

      final json = stats.toJson();

      expect(json['totalUsers'], 500);
      expect(json['activeUsers'], 300);
      expect(json['inRankings'], 200);
      expect(json['lastUpdated'], '2024-01-15T10:30:00.000');
    });
  });

  group('Timeframe', () {
    test('should convert from string correctly', () {
      expect(Timeframe.fromString('Daily'), Timeframe.daily);
      expect(Timeframe.fromString('Weekly'), Timeframe.weekly);
      expect(Timeframe.fromString('Monthly'), Timeframe.monthly);
      expect(Timeframe.fromString('All Time'), Timeframe.allTime);
      expect(Timeframe.fromString('Invalid'), Timeframe.weekly); // default
    });

    test('should have correct display names', () {
      expect(Timeframe.daily.displayName, 'Daily');
      expect(Timeframe.weekly.displayName, 'Weekly');
      expect(Timeframe.monthly.displayName, 'Monthly');
      expect(Timeframe.allTime.displayName, 'All Time');
    });
  });

  group('LeaderboardSnapshot', () {
    test('should create empty snapshot correctly', () {
      final snapshot = LeaderboardSnapshot.empty();

      expect(snapshot.stats.totalUsers, 0);
      expect(snapshot.topThree, isEmpty);
      expect(snapshot.currentUser, isNull);
      expect(snapshot.users, isEmpty);
      expect(snapshot.totalPages, 0);
      expect(snapshot.currentPage, 0);
      expect(snapshot.hasMorePages, false);
    });

    test('should copy with updated values', () {
      final original = LeaderboardSnapshot.empty();
      const newUser = LeaderboardUser(id: '1', name: 'Test', points: 100, rank: 1);
      
      final updated = original.copyWith(
        currentUser: newUser,
        currentPage: 1,
        hasMorePages: true,
      );

      expect(updated.currentUser, newUser);
      expect(updated.currentPage, 1);
      expect(updated.hasMorePages, true);
      expect(updated.stats, original.stats); // unchanged
    });
  });

  group('LeaderboardFilters', () {
    test('should create filters correctly', () {
      const filters = LeaderboardFilters(
        timeframe: Timeframe.monthly,
        group: 'Engineering',
        category: 'Programming',
      );

      expect(filters.timeframe, Timeframe.monthly);
      expect(filters.group, 'Engineering');
      expect(filters.category, 'Programming');
    });

    test('should handle equality correctly', () {
      const filters1 = LeaderboardFilters(
        timeframe: Timeframe.weekly,
        group: 'MIT',
        category: 'CS',
      );
      const filters2 = LeaderboardFilters(
        timeframe: Timeframe.weekly,
        group: 'MIT',
        category: 'CS',
      );
      const filters3 = LeaderboardFilters(
        timeframe: Timeframe.daily,
        group: 'MIT',
        category: 'CS',
      );

      expect(filters1, equals(filters2));
      expect(filters1, isNot(equals(filters3)));
    });

    test('should copy with updated values', () {
      const original = LeaderboardFilters(
        timeframe: Timeframe.weekly,
        group: 'MIT',
      );

      final updated = original.copyWith(
        timeframe: Timeframe.monthly,
        category: 'Programming',
      );

      expect(updated.timeframe, Timeframe.monthly);
      expect(updated.group, 'MIT'); // unchanged
      expect(updated.category, 'Programming'); // new
    });
  });
}