import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../secure_storage.dart'; // ✅ Update with correct path if different

class LeaderboardService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // ✅ Get current user's phone number
  Future<String?> _getCurrentUserPhone() async {
    try {
      return await SecureStorage.read('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }
  
  // Update user points when completing a task or challenge
  Future<void> updateUserPoints({
    required int pointsEarned,
    required String activity,
    String? category,
  }) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');
      
      final userDoc = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();
      
      if (!userDoc.exists) throw Exception('User data not found');
      
      final userData = userDoc.data()!;
      final int currentPoints = userData['points'] ?? 0;
      final int newPoints = currentPoints + pointsEarned;
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      final batch = _firestore.batch();
      
      final userRef = _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber);
          
      batch.update(userRef, {
        'points': newPoints,
        'last_activity': Timestamp.now(),
      });
      
      final activityRef = _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .collection('activities')
          .doc();
          
      batch.set(activityRef, {
        'activity': activity,
        'category': category,
        'points': pointsEarned,
        'timestamp': Timestamp.now(),
        'date': today,
      });
      
      await batch.commit();
      
      await _database.ref()
          .child('skillbench/leaderboard/all_time/$phoneNumber')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['profile_image'] ?? '',
            'college': userData['college'],
            'department': userData['department'],
            'batch': userData['batch'],
            'phone_number': phoneNumber,
            'last_updated': ServerValue.timestamp,
          });
      
      await _updateWeeklyLeaderboard(phoneNumber, userData, pointsEarned, weekStartStr);
      
      if (userData.containsKey('college')) {
        await _updateCollegeLeaderboard(phoneNumber, userData, newPoints);
      }
      if (userData.containsKey('college') && userData.containsKey('department')) {
        await _updateDepartmentLeaderboard(phoneNumber, userData, newPoints);
      }
      
    } catch (e) {
      print('Error updating user points: $e');
      throw e;
    }
  }
  
  Future<void> _updateWeeklyLeaderboard(
    String phoneNumber, 
    Map<String, dynamic> userData, 
    int pointsEarned,
    String weekStartStr,
  ) async {
    try {
      final weeklyRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$weekStartStr/$phoneNumber');
          
      final snapshot = await weeklyRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        final currentPoints = data['points'] as int? ?? 0;
        final newPoints = currentPoints + pointsEarned;
        
        await weeklyRef.update({
          'points': newPoints,
          'last_updated': ServerValue.timestamp,
        });
      } else {
        await weeklyRef.set({
          'points': pointsEarned,
          'username': userData['username'],
          'profile_image': userData['profile_image'] ?? '',
          'college': userData['college'],
          'department': userData['department'],
          'batch': userData['batch'],
          'phone_number': phoneNumber,
          'last_updated': ServerValue.timestamp,
        });
      }
    } catch (e) {
      print('Error updating weekly leaderboard: $e');
    }
  }
  
  Future<void> _updateCollegeLeaderboard(
    String phoneNumber, 
    Map<String, dynamic> userData, 
    int newPoints,
  ) async {
    try {
      final college = userData['college'];
      
      await _database.ref()
          .child('skillbench/leaderboard/colleges/$college/$phoneNumber')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['profile_image'] ?? '',
            'department': userData['department'],
            'batch': userData['batch'],
            'phone_number': phoneNumber,
            'last_updated': ServerValue.timestamp,
          });
    } catch (e) {
      print('Error updating college leaderboard: $e');
    }
  }
  
  Future<void> _updateDepartmentLeaderboard(
    String phoneNumber, 
    Map<String, dynamic> userData, 
    int newPoints,
  ) async {
    try {
      final college = userData['college'];
      final department = userData['department'];
      
      await _database.ref()
          .child('skillbench/leaderboard/colleges/$college/departments/$department/$phoneNumber')
          .update({
            'points': newPoints,
            'username': userData['username'],
            'profile_image': userData['profile_image'] ?? '',
            'batch': userData['batch'],
            'phone_number': phoneNumber,
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
      final phoneNumber = await _getCurrentUserPhone();
      if (phoneNumber == null) return 0;
      
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
        if (usersList[i].key == phoneNumber) return i + 1;
      }
      
      return 0;
    } catch (e) {
      print('Error getting user ranking: $e');
      return 0;
    }
  }
}
