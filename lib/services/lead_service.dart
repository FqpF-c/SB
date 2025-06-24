import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeaderboardService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Get current user's phone number
  Future<String?> _getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('phone_number');
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
      if (phoneNumber == null) {
        throw Exception('User not authenticated');
      }
      
      // Get current user data using phone number
      final userDoc = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)  // Use phone number as document ID
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User data not found');
      }
      
      final userData = userDoc.data()!;
      final int currentPoints = userData['points'] ?? 0;
      final int newPoints = currentPoints + pointsEarned;
      
      // Get current date in format YYYY-MM-DD
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get current week's start date (Monday)
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      // Perform updates as a batch operation
      final batch = _firestore.batch();
      
      // 1. Update user points in main user document
      final userRef = _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber);  // Use phone number as document ID
          
      batch.update(userRef, {
        'points': newPoints,
        'last_activity': Timestamp.now(),
      });
      
      // 2. Record activity in user history
      final activityRef = _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)  // Use phone number as document ID
          .collection('activities')
          .doc(); // Auto-generate ID
          
      batch.set(activityRef, {
        'activity': activity,
        'category': category,
        'points': pointsEarned,
        'timestamp': Timestamp.now(),
        'date': today,
      });
      
      // Execute the batch
      await batch.commit();
      
      // Update Realtime Database for leaderboards
      // 1. Update all-time leaderboard using phone number as key
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
      
      // 2. Update weekly leaderboard
      await _updateWeeklyLeaderboard(phoneNumber, userData, pointsEarned, weekStartStr);
      
      // 3. Update college leaderboard
      if (userData.containsKey('college')) {
        await _updateCollegeLeaderboard(phoneNumber, userData, newPoints);
      }
      
      // 4. Update department leaderboard
      if (userData.containsKey('college') && userData.containsKey('department')) {
        await _updateDepartmentLeaderboard(phoneNumber, userData, newPoints);
      }
      
    } catch (e) {
      print('Error updating user points: $e');
      throw e;
    }
  }
  
  // Update weekly leaderboard
  Future<void> _updateWeeklyLeaderboard(
    String phoneNumber, 
    Map<String, dynamic> userData, 
    int pointsEarned,
    String weekStartStr,
  ) async {
    try {
      // First check if user already exists in the weekly leaderboard
      final weeklyRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$weekStartStr/$phoneNumber');
          
      final snapshot = await weeklyRef.get();
      
      if (snapshot.exists) {
        // User exists, update points
        final data = snapshot.value as Map<dynamic, dynamic>;
        final currentPoints = data['points'] as int? ?? 0;
        final newPoints = currentPoints + pointsEarned;
        
        await weeklyRef.update({
          'points': newPoints,
          'last_updated': ServerValue.timestamp,
        });
      } else {
        // User doesn't exist in weekly leaderboard, create new entry
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
      // Continue with other updates - non-critical
    }
  }
  
  // Update college leaderboard
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
      // Continue with other updates - non-critical
    }
  }
  
  // Update department leaderboard
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
      // Continue with other updates - non-critical
    }
  }
  
  // Reset weekly leaderboards (should be called by a Cloud Function)
  Future<void> resetWeeklyLeaderboards() async {
    try {
      // Get previous week's start date
      final now = DateTime.now();
      final previousWeekStart = now.subtract(Duration(days: now.weekday + 6));
      final previousWeekStartStr = DateFormat('yyyy-MM-dd').format(previousWeekStart);
      
      // Get new week's start date
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateFormat('yyyy-MM-dd').format(weekStart);
      
      // Archive previous week's data
      final previousWeekRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$previousWeekStartStr');
          
      final snapshot = await previousWeekRef.get();
      
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        
        // Store in archive
        await _database.ref()
            .child('skillbench/leaderboard/weekly_archive/$previousWeekStartStr')
            .set(data);
            
        // Clear previous week's data
        await previousWeekRef.remove();
      }
      
      // Initialize new week if needed (this is optional)
      final newWeekRef = _database.ref()
          .child('skillbench/leaderboard/weekly/$weekStartStr');
          
      final newWeekSnapshot = await newWeekRef.get();
      
      if (!newWeekSnapshot.exists) {
        // Create placeholder to indicate week has started
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
  
  // Get user ranking
  Future<int> getUserRanking(String filter) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      if (phoneNumber == null) return 0;
      
      // Determine which leaderboard to query
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
          leaderboardRef = _database.ref()
              .child('skillbench/leaderboard/all_time');
          break;
          
        default:
          leaderboardRef = _database.ref()
              .child('skillbench/leaderboard/all_time');
      }
      
      // Get all users and sort by points
      final snapshot = await leaderboardRef.orderByChild('points').get();
      
      if (!snapshot.exists) return 0;
      
      final data = snapshot.value as Map<dynamic, dynamic>;
      
      // Convert to list and sort by points (descending)
      final List<MapEntry<dynamic, dynamic>> usersList = data.entries.toList();
      usersList.sort((a, b) {
        final aPoints = (a.value as Map<dynamic, dynamic>)['points'] as int? ?? 0;
        final bPoints = (b.value as Map<dynamic, dynamic>)['points'] as int? ?? 0;
        return bPoints.compareTo(aPoints);
      });
      
      // Find current user's position using phone number
      for (int i = 0; i < usersList.length; i++) {
        if (usersList[i].key == phoneNumber) {
          return i + 1; // +1 because ranks start at 1, not 0
        }
      }
      
      return 0; // User not found
    } catch (e) {
      print('Error getting user ranking: $e');
      return 0;
    }
  }
}