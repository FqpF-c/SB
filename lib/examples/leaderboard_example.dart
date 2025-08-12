import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/leaderboard/new_leaderboard_screen.dart';
import '../providers/new_leaderboard_provider.dart';
import '../repositories/leaderboard_repository.dart';

/// Example integration showing how to set up the new leaderboard screen
class LeaderboardExample extends StatelessWidget {
  const LeaderboardExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'New Leaderboard Example',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        useMaterial3: true,
      ),
      home: const ExampleHomeScreen(),
      routes: {
        '/new_leaderboard': (context) => ChangeNotifierProvider(
          create: (_) => NewLeaderboardProvider(MockLeaderboardRepository()),
          child: const NewLeaderboardScreen(),
        ),
      },
    );
  }
}

class ExampleHomeScreen extends StatelessWidget {
  const ExampleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard Example'),
        backgroundColor: const Color(0xFFFF6B8B),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.emoji_events,
              size: 100,
              color: Color(0xFFFF6B8B),
            ),
            const SizedBox(height: 32),
            const Text(
              'New Leaderboard Implementation',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tap the button below to see the new leaderboard screen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/new_leaderboard');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B8B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.leaderboard),
                  SizedBox(width: 8),
                  Text(
                    'View Leaderboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                _showInfoDialog(context);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF6B8B),
                side: const BorderSide(color: Color(0xFFFF6B8B)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('About This Implementation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Leaderboard Features'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('✨ Modern pink gradient design'),
            Text('🏆 Animated top performers bars'),
            Text('📊 Real-time statistics'),
            Text('👤 Your rank highlighting'),
            Text('📱 Smooth infinite scroll'),
            Text('⚡ Fast caching system'),
            Text('🎯 Advanced filtering'),
            Text('♿ Full accessibility support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

/// Example of how to integrate with existing app
/// 
/// ```dart
/// // In your main app:
/// MultiProvider(
///   providers: [
///     // Your existing providers...
///     ChangeNotifierProvider(
///       create: (_) => NewLeaderboardProvider(MockLeaderboardRepository()),
///     ),
///   ],
///   child: MyApp(),
/// )
/// 
/// // In your routes:
/// '/leaderboard': (context) => const NewLeaderboardScreen(),
/// 
/// // To use with existing LeadProvider:
/// '/leaderboard': (context) => ChangeNotifierProvider(
///   create: (ctx) {
///     final leadProvider = Provider.of<LeadProvider>(ctx, listen: false);
///     final repository = LeaderboardRepositoryAdapter(leadProvider);
///     return NewLeaderboardProvider(repository);
///   },
///   child: const NewLeaderboardScreen(),
/// ),
/// ```