import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaderboardService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> updateUserPoints({
    required int pointsEarned,
    required String activity,
    String? category,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final userDoc = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) throw Exception('User data not found');
      
      final userData = userDoc.data()!;
      final phoneNumber = userData['phone_number'];
      
      final userStatsSnapshot = await _database
          .ref('skillbench/users/${user.uid}')
          .get();
      
      int currentPoints = 0;
      if (userStatsSnapshot.exists) {
        final statsData = userStatsSnapshot.value as Map<dynamic, dynamic>;
        currentPoints = statsData['points'] ?? 0;
      }
      
      final int newPoints = currentPoints + pointsEarned;
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      await _database
          .ref('skillbench/users/${user.uid}')
          .update({
        'points': newPoints,
        'last_updated': ServerValue.timestamp,
      });
      
      final activityRef = _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(user.uid)
          .collection('activities')
          .doc();
          
      await activityRef.set({
        'activity': activity,
        'category': category,
        'points': pointsEarned,
        'timestamp': Timestamp.now(),
        'date': today,
      });
      
      await _database.ref()
          .child('skillbench/leaderboard/all_time/${user.uid}')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['selectedProfileImage'] ?? 1,
            'college': userData['college'] ?? '',
            'department': userData['department'] ?? '',
            'batch': userData['batch'],
            'phone_number': phoneNumber,
            'firebase_uid': user.uid,
            'last_updated': ServerValue.timestamp,
          });
      
      await _database.ref()
          .child('skillbench/leaderboard/weekly/$weekStartStr/${user.uid}')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['selectedProfileImage'] ?? 1,
            'college': userData['college'] ?? '',
            'department': userData['department'] ?? '',
            'batch': userData['batch'],
            'phone_number': phoneNumber,
            'firebase_uid': user.uid,
            'last_updated': ServerValue.timestamp,
          });
    } catch (e) {
      print('Error updating user points: $e');
      throw e;
    }
  }

  Future<void> updateDepartmentLeaderboard(String userId, int newPoints) async {
    try {
      final userDoc = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final college = userData['college'];
      final department = userData['department'];
      final batch = userData['batch'];
      final phoneNumber = userData['phone_number'];
      
      if (college == null || department == null || batch == null) return;
      
      await _database.ref()
          .child('skillbench/leaderboard/departments/$college/$department/$userId')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['selectedProfileImage'] ?? 1,
            'college': college,
            'department': department,
            'batch': batch,
            'phone_number': phoneNumber,
            'firebase_uid': userId,
            'last_updated': ServerValue.timestamp,
          });
    } catch (e) {
      print('Error updating department leaderboard: $e');
    }
  }

  Future<void> resetWeeklyLeaderboards() async {
    try {
      final now = DateTime.now();
      final previousWeekStart = now.subtract(Duration(days: now.weekday + 6));
      final previousWeekStartStr = DateFormat('yyyy-MM-dd').format(previousWeekStart);
      
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      final previousWeekRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$previousWeekStartStr');
          
      final snapshot = await previousWeekRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        await _database.ref()
            .child('skillbench/leaderboard/weekly_archive/$previousWeekStartStr')
            .set(data);
        await previousWeekRef.remove();
      }
      
      final newWeekRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$weekStartStr');
          
      final newWeekSnapshot = await newWeekRef.get();
      
      if (!newWeekSnapshot.exists) {
        await newWeekRef.child('info').set({
          'week_start': weekStartStr,
          'created_at': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error resetting weekly leaderboards: $e');
      throw e;
    }
  }

  Future<int> getUserRanking(String filter) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;
      
      DatabaseReference leaderboardRef;
      
      switch (filter) {
        case 'weekly':
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
          leaderboardRef = _database.ref()
              .child('skillbench/leaderboard/weekly/$weekStartStr');
          break;
        case 'all_time':
        default:
          leaderboardRef = _database.ref()
              .child('skillbench/leaderboard/all_time');
      }
      
      final snapshot = await leaderboardRef.orderByChild('points').get();
      if (!snapshot.exists) return 0;
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<MapEntry<dynamic, dynamic>> usersList = data.entries.toList();
      
      usersList.sort((a, b) {
        final aPoints = (a.value as Map)['points'] ?? 0;
        final bPoints = (b.value as Map)['points'] ?? 0;
        return bPoints.compareTo(aPoints);
      });
      
      for (int i = 0; i < usersList.length; i++) {
        if (usersList[i].key == user.uid) {
          return i + 1;
        }
      }
      
      return 0;
    } catch (e) {
      print('Error getting user ranking: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    required String filter,
    int limit = 50,
    String? college,
    String? department,
  }) async {
    try {
      DatabaseReference leaderboardRef;
      
      if (college != null && department != null) {
        leaderboardRef = _database.ref()
            .child('skillbench/leaderboard/departments/$college/$department');
      } else {
        switch (filter) {
          case 'weekly':
            final now = DateTime.now();
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
            leaderboardRef = _database.ref()
                .child('skillbench/leaderboard/weekly/$weekStartStr');
            break;
          case 'all_time':
          default:
            leaderboardRef = _database.ref()
                .child('skillbench/leaderboard/all_time');
        }
      }
      
      final snapshot = await leaderboardRef
          .orderByChild('points')
          .limitToLast(limit)
          .get();
      
      if (!snapshot.exists) return [];
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> leaderboardList = [];
      
      data.forEach((key, value) {
        if (value is Map && key != 'info') {
          final userMap = Map<String, dynamic>.from(value);
          userMap['user_id'] = key;
          leaderboardList.add(userMap);
        }
      });
      
      leaderboardList.sort((a, b) {
        final aPoints = a['points'] ?? 0;
        final bPoints = b['points'] ?? 0;
        return bPoints.compareTo(aPoints);
      });
      
      return leaderboardList.take(limit).toList();
    } catch (e) {
      print('Error getting leaderboard: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserLeaderboardStats() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final statsSnapshot = await _database
          .ref('skillbench/users/${user.uid}')
          .get();
      
      if (!statsSnapshot.exists) return null;
      
      final statsData = statsSnapshot.value as Map<dynamic, dynamic>;
      
      final allTimeRanking = await getUserRanking('all_time');
      final weeklyRanking = await getUserRanking('weekly');
      
      return {
        'points': statsData['points'] ?? 0,
        'all_time_ranking': allTimeRanking,
        'weekly_ranking': weeklyRanking,
        'last_updated': statsData['last_updated'],
      };
    } catch (e) {
      print('Error getting user leaderboard stats: $e');
      return null;
    }
  }
}