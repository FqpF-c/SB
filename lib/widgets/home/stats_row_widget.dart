import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/progress_provider.dart';
import '../../providers/lead_provider.dart';
import '../../secure_storage.dart';
import 'dart:async';

class FirebaseStatsRowWidget extends StatefulWidget {
  const FirebaseStatsRowWidget({Key? key}) : super(key: key);

  @override
  State<FirebaseStatsRowWidget> createState() => _FirebaseStatsRowWidgetState();
}

class _FirebaseStatsRowWidgetState extends State<FirebaseStatsRowWidget> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Add this to track async operations
  final List<Completer<void>> _activeOperations = [];

  int _completed = 0;
  int _rankPosition = 0;
  int _studyHours = 0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadStatsData();
  }

  @override
  void dispose() {
    // Cancel all pending operations
    for (final completer in _activeOperations) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _activeOperations.clear();
    super.dispose();
  }

  // Helper method to safely call setState
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // Helper method to track async operations
  Future<T> _trackOperation<T>(Future<T> operation) async {
    final completer = Completer<void>();
    _activeOperations.add(completer);

    try {
      final result = await operation;
      if (!completer.isCompleted) {
        completer.complete();
      }
      return result;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete();
      }
      rethrow;
    } finally {
      _activeOperations.remove(completer);
    }
  }

  Future<void> _loadStatsData() async {
    if (!mounted) return;

    _safeSetState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Load data in parallel with tracking
      await _trackOperation(Future.wait([
        _loadCompletedTopics(),
        _loadRankPosition(),
        _loadStudyHours(),
      ]));
    } catch (e) {
      print('Error loading stats: $e');
      _safeSetState(() {
        _hasError = true;
      });
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompletedTopics() async {
    if (!mounted) return;

    try {
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);
      await _trackOperation(progressProvider.refresh());

      if (!mounted) return;

      final allProgress = progressProvider.allProgress;

      // Count topics with progress >= 80% as "completed"
      int completedCount = 0;
      allProgress.forEach((topicId, progressData) {
        final progress = progressData['progress'] ?? 0.0;
        if (progress == 100.0) {
          completedCount++;
        }
      });

      _safeSetState(() {
        _completed = completedCount;
      });

      print('Completed topics calculated: $completedCount');
    } catch (e) {
      print('Error loading completed topics: $e');
      if (mounted) {
        _safeSetState(() {
          _completed = 0;
        });
      }
    }
  }

  Future<void> _loadRankPosition() async {
    if (!mounted) return;

    try {
      final user = _auth.currentUser;
      if (user == null || !mounted) return;

      // Get current user's total XP from quiz sessions
      final userXP = await _trackOperation(_calculateTotalXP(user.uid));

      if (!mounted) return;

      // Get all users' XP to calculate rank
      final leaderboardSnapshot = await _trackOperation(
          _database.ref().child('skillbench/quiz_sessions').get());

      if (!mounted) return;

      if (!leaderboardSnapshot.exists) {
        _safeSetState(() {
          _rankPosition = 1;
        });
        return;
      }

      // Calculate XP for all users
      Map<String, int> userXPMap = {};
      final allSessions = leaderboardSnapshot.value as Map<dynamic, dynamic>;

      allSessions.forEach((userId, sessions) {
        int totalXP = 0;
        if (sessions is Map) {
          sessions.forEach((sessionId, sessionData) {
            if (sessionData is Map && sessionData['totalXP'] != null) {
              totalXP += (sessionData['totalXP'] as num).toInt();
            }
          });
        }
        userXPMap[userId] = totalXP;
      });

      // Sort users by XP (descending) and find current user's rank
      final sortedUsers = userXPMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      int rank = 1;
      for (int i = 0; i < sortedUsers.length; i++) {
        if (sortedUsers[i].key == user.uid) {
          rank = i + 1;
          break;
        }
      }

      _safeSetState(() {
        _rankPosition = rank;
      });

      print(
          'Rank position calculated: $rank out of ${sortedUsers.length} users');
    } catch (e) {
      print('Error loading rank position: $e');
      _safeSetState(() {
        _rankPosition = 1;
      });
    }
  }

  Future<int> _calculateTotalXP(String userId) async {
    if (!mounted) return 0;

    try {
      final userSessionsSnapshot = await _trackOperation(
          _database.ref().child('skillbench/quiz_sessions/$userId').get());

      if (!userSessionsSnapshot.exists || !mounted) return 0;

      int totalXP = 0;
      final sessions = userSessionsSnapshot.value as Map<dynamic, dynamic>;

      sessions.forEach((sessionId, sessionData) {
        if (sessionData is Map && sessionData['totalXP'] != null) {
          totalXP += (sessionData['totalXP'] as num).toInt();
        }
      });

      return totalXP;
    } catch (e) {
      print('Error calculating total XP: $e');
      return 0;
    }
  }

  Future<void> _loadStudyHours() async {
    if (!mounted) return;

    try {
      final user = _auth.currentUser;
      if (user == null || !mounted) return;

      final userSessionsSnapshot = await _trackOperation(
          _database.ref().child('skillbench/quiz_sessions/${user.uid}').get());

      if (!mounted) return;

      if (!userSessionsSnapshot.exists) {
        _safeSetState(() {
          _studyHours = 0;
        });
        return;
      }

      int totalTimeInSeconds = 0;
      final sessions = userSessionsSnapshot.value as Map<dynamic, dynamic>;

      sessions.forEach((sessionId, sessionData) {
        if (sessionData is Map && sessionData['timeSpent'] != null) {
          totalTimeInSeconds += (sessionData['timeSpent'] as num).toInt();
        }
      });

      // Convert seconds to hours (rounded)
      final hours = (totalTimeInSeconds / 3600).round();

      _safeSetState(() {
        _studyHours = hours;
      });

      print(
          'Study hours calculated: $hours hours from $totalTimeInSeconds seconds');
    } catch (e) {
      print('Error loading study hours: $e');
      _safeSetState(() {
        _studyHours = 0;
      });
    }
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;
    await _loadStatsData();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -65),
      child: GestureDetector(
        onTap: _hasError ? _refreshStats : null,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20.w, 65.h, 20.w, 15.h),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE17DA8), Color(0xFFE15E89)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(48.r),
              bottomRight: Radius.circular(48.r),
            ),
          ),
          child: Column(
            children: [
              SizedBox(height: 15.h),
              if (_isLoading)
                _buildLoadingState()
              else if (_hasError)
                _buildErrorState()
              else
                _buildStatsRow(),
            ],
          ),
        ),
      ),
    ).animate(
      effects: [
        ScaleEffect(duration: 300.ms, curve: Curves.easeOut),
        FadeEffect(duration: 300.ms),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItemSkeleton(),
        Container(
            height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
        _buildStatItemSkeleton(),
        Container(
            height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
        _buildStatItemSkeleton(),
      ],
    );
  }

  Widget _buildStatItemSkeleton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22.sp,
          height: 22.sp,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          width: 60.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(height: 4.h),
        Container(
          width: 40.w,
          height: 24.h,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      children: [
        Icon(
          Icons.refresh,
          color: Colors.white.withOpacity(0.8),
          size: 24.sp,
        ),
        SizedBox(height: 8.h),
        Text(
          'Tap to refresh stats',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(
          icon: Icons.check_circle_outline,
          label: "Completed",
          value: _completed.toString(),
        ).animate(effects: [
          SlideEffect(
              begin: const Offset(-0.3, 0), duration: 400.ms, delay: 100.ms),
          FadeEffect(duration: 400.ms, delay: 100.ms),
        ]),
        Container(
            height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
        _buildStatItem(
          icon: Icons.leaderboard,
          label: "Rank Position",
          value: _rankPosition.toString(),
        ).animate(effects: [
          SlideEffect(
              begin: const Offset(0, -0.3), duration: 400.ms, delay: 200.ms),
          FadeEffect(duration: 400.ms, delay: 200.ms),
        ]),
        Container(
            height: 40.h, width: 1.w, color: Colors.white.withOpacity(0.3)),
        _buildStatItem(
          icon: Icons.access_time,
          label: "Study Hours",
          value: _studyHours.toString(),
        ).animate(effects: [
          SlideEffect(
              begin: const Offset(0.3, 0), duration: 400.ms, delay: 300.ms),
          FadeEffect(duration: 400.ms, delay: 300.ms),
        ]),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 22.sp,
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.sp,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
