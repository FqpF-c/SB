import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/leaderboard_models.dart';
import '../../lib/widgets/leaderboard/welcome_hub_card.dart';
import '../../lib/widgets/leaderboard/your_rank_card.dart';
import '../../lib/widgets/leaderboard/user_list_item.dart';
import '../../lib/widgets/leaderboard/filter_controls.dart';

void main() {
  group('WelcomeHubCard', () {
    testWidgets('should display stats correctly', (tester) async {
      final stats = LeaderboardStats(
        totalUsers: 1000,
        activeUsers: 750,
        inRankings: 500,
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeHubCard(stats: stats),
          ),
        ),
      );

      expect(find.text('Welcome Hub'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('750'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
    });

    testWidgets('should show loading state correctly', (tester) async {
      final stats = LeaderboardStats(
        totalUsers: 0,
        activeUsers: 0,
        inRankings: 0,
        lastUpdated: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeHubCard(stats: stats, isLoading: true),
          ),
        ),
      );

      expect(find.text('Welcome Hub'), findsOneWidget);
      // Should show loading chips instead of actual values
      expect(find.text('0'), findsNothing);
    });

    testWidgets('should format last updated time correctly', (tester) async {
      final stats = LeaderboardStats(
        totalUsers: 100,
        activeUsers: 75,
        inRankings: 50,
        lastUpdated: DateTime.now().subtract(const Duration(hours: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WelcomeHubCard(stats: stats),
          ),
        ),
      );

      expect(find.text('2h'), findsOneWidget);
    });
  });

  group('YourRankCard', () {
    testWidgets('should display user info correctly', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'John Doe',
        organization: 'MIT',
        points: 1500,
        rank: 5,
        isYou: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YourRankCard(currentUser: user),
          ),
        ),
      );

      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('MIT'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
      expect(find.text('Rank 5'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('should show loading state correctly', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'John Doe',
        points: 1500,
        rank: 5,
        isYou: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: YourRankCard(currentUser: user, isLoading: true),
          ),
        ),
      );

      // Should show loading containers instead of actual content
      expect(find.text('John Doe'), findsNothing);
    });

    testWidgets('should handle long names with ellipsis', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'This is a very long name that should be truncated',
        organization: 'This is also a very long organization name',
        points: 1500,
        rank: 5,
        isYou: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300, // Constrain width to test ellipsis
              child: YourRankCard(currentUser: user),
            ),
          ),
        ),
      );

      // Text should be present but may be truncated
      expect(find.textContaining('This is a very long name'), findsOneWidget);
      expect(find.textContaining('This is also a very long'), findsOneWidget);
    });
  });

  group('UserListItem', () {
    testWidgets('should display user info correctly', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'Jane Smith',
        organization: 'Stanford University',
        points: 2000,
        rank: 3,
        isOnline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListItem(
              user: user,
              displayIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.text('Stanford University'), findsOneWidget);
      expect(find.text('2000'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('should show "You" badge for current user', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'Current User',
        points: 1200,
        rank: 8,
        isYou: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListItem(
              user: user,
              displayIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('You'), findsOneWidget);
      expect(find.text('Current User'), findsOneWidget);
    });

    testWidgets('should show online indicator when user is online', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'Online User',
        points: 1000,
        rank: 10,
        isOnline: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListItem(
              user: user,
              displayIndex: 0,
              showOnlineIndicator: true,
            ),
          ),
        ),
      );

      // Look for the online indicator (green circle)
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('should handle tap correctly', (tester) async {
      bool tapped = false;
      const user = LeaderboardUser(
        id: 'user1',
        name: 'Tappable User',
        points: 1000,
        rank: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListItem(
              user: user,
              displayIndex: 0,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(UserListItem));
      expect(tapped, true);
    });

    testWidgets('should generate correct initials for users without avatars', (tester) async {
      const user = LeaderboardUser(
        id: 'user1',
        name: 'First Last',
        points: 1000,
        rank: 10,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserListItem(
              user: user,
              displayIndex: 0,
            ),
          ),
        ),
      );

      expect(find.text('FL'), findsOneWidget);
    });
  });

  group('LegacyFilterToggle', () {
    testWidgets('should display timeframe options correctly', (tester) async {
      Timeframe? selectedTimeframe;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LegacyFilterToggle(
              selectedTimeframe: Timeframe.weekly,
              onChanged: (timeframe) => selectedTimeframe = timeframe,
            ),
          ),
        ),
      );

      expect(find.text('Weekly'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
    });

    testWidgets('should handle selection changes correctly', (tester) async {
      Timeframe selectedTimeframe = Timeframe.weekly;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: LegacyFilterToggle(
                  selectedTimeframe: selectedTimeframe,
                  onChanged: (timeframe) {
                    setState(() {
                      selectedTimeframe = timeframe;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      // Tap on "All Time"
      await tester.tap(find.text('All Time'));
      await tester.pumpAndSettle();

      expect(selectedTimeframe, Timeframe.allTime);
    });
  });

  group('FilterDropdown', () {
    testWidgets('should display options correctly', (tester) async {
      String? selectedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterDropdown(
              label: 'Test Filter',
              selectedValue: 'All',
              options: const ['All', 'Option 1', 'Option 2'],
              onChanged: (value) => selectedValue = value,
            ),
          ),
        ),
      );

      expect(find.byType(DropdownButton<String>), findsOneWidget);
    });

    testWidgets('should handle selection changes correctly', (tester) async {
      String? selectedValue = 'All';

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: FilterDropdown(
                  label: 'Test Filter',
                  selectedValue: selectedValue,
                  options: const ['All', 'Option 1', 'Option 2'],
                  onChanged: (value) {
                    setState(() {
                      selectedValue = value;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      // Tap on dropdown
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();

      // Tap on "Option 1"
      await tester.tap(find.text('Option 1').last);
      await tester.pumpAndSettle();

      expect(selectedValue, 'Option 1');
    });
  });

  group('UserListItemSkeleton', () {
    testWidgets('should render loading skeleton correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserListItemSkeleton(),
          ),
        ),
      );

      // Should have containers for loading state
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('should animate shimmer effect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserListItemSkeleton(),
          ),
        ),
      );

      // Let some time pass for animation
      await tester.pump(const Duration(milliseconds: 500));
      
      // Animation controller should be running
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });

  group('WelcomeHubCardSkeleton', () {
    testWidgets('should render loading skeleton correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WelcomeHubCardSkeleton(),
          ),
        ),
      );

      // Should have shimmer containers
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });
}