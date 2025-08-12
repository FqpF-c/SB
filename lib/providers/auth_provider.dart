import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../secure_storage.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> getCurrentUserPhone() async {
    try {
      return await SecureStorage.read('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

  Future<bool> checkIfUserExists(String phoneNumber) async {
    try {
      final query = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .where('phone_number', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<bool> doesCurrentUserExistInFirestore() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    try {
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(currentUser.uid)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      print('Error checking current user existence: $e');
      return false;
    }
  }

  Future<bool> isUserLoggedIn() async {
    try {
      final isLoggedIn = await SecureStorage.read('is_logged_in') == 'true';
      final phoneNumber = await SecureStorage.read('phone_number');
      if (isLoggedIn && phoneNumber != null) {
        if (_auth.currentUser == null) {
          await _auth.signInAnonymously();
        }
        
        final exists = await doesCurrentUserExistInFirestore();
        if (!exists) {
          await SecureStorage.delete('is_logged_in');
          await SecureStorage.delete('phone_number');
          return false;
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  Future<void> checkStreakStatusAndNotify() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final dataSnapshot =
          await _database.ref('skillbench/users/${currentUser.uid}').get();

      if (!dataSnapshot.exists) return;

      final data = dataSnapshot.value as Map<dynamic, dynamic>?;
      final lastUsageDate = data?['last_usage_date'];
      final streaks = data?['streaks'] ?? 0;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr =
          DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 1)));

      if (lastUsageDate == yesterdayStr) {
        await NotificationService.sendStreakReminderNotification(streaks + 1);
      }
    } catch (e) {
      print('Error checking streak status: $e');
    }
  }

  Future<void> setLoggedIn(String phoneNumber) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final userCredential = await _auth.signInAnonymously();
        user = userCredential.user;
      }

      await SecureStorage.write('is_logged_in', 'true');
      await SecureStorage.write('phone_number', phoneNumber);

      final exists = await doesCurrentUserExistInFirestore();
      if (exists) {
        await _firestore
            .collection('skillbench')
            .doc('users')
            .collection('users')
            .doc(user!.uid)
            .update({
          'last_login': Timestamp.now(),
        });
      }

      notifyListeners();
    } catch (e) {
      print('Error setting logged in: $e');
      throw e;
    }
  }

  Future<void> registerUser(Map<String, dynamic> userData) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        final userCredential = await _auth.signInAnonymously();
        user = userCredential.user;
      }

      final phoneNumber = userData['phone_number'];
      final college = userData['college'];
      final department = userData['department'];
      final batch = userData['batch'];
      final firebaseUID = user!.uid;

      await _firestore.runTransaction((transaction) async {
        final mainUserRef = _firestore
            .collection('skillbench')
            .doc('users')
            .collection('users')
            .doc(firebaseUID);

        final userSnapshot = await transaction.get(mainUserRef);
        final existingData = userSnapshot.exists ? userSnapshot.data() : null;

        final completeUserData = {
          'phone_number': phoneNumber,
          'username':
              userData['username'] ?? (existingData?['username'] ?? 'User'),
          'college': userData['college'],
          'email': userData['email'],
          'department': userData['department'],
          'batch': userData['batch'],
          'gender': userData['gender'] ??
              (existingData?['gender'] ?? 'prefer_not_to_say'),
          'profile_pic_type': userData['profile_pic_type'],
          'selectedProfileImage': userData['selectedProfileImage'],
          'profilePicUrl': userData['profilePicUrl'],
          'current_firebase_uid': firebaseUID,
          'created_at': userSnapshot.exists
              ? (existingData?['created_at'] ?? Timestamp.now())
              : Timestamp.now(),
          'last_login': Timestamp.now(),
          'total_request': userData['total_request'] ??
              (existingData?['total_request'] ??
                  {
                    'practice_mode': 0,
                    'test_mode': 0,
                  }),
        };

        transaction.set(mainUserRef, completeUserData, SetOptions(merge: true));

        final collegeUserRef = _firestore
            .collection('skillbench')
            .doc(college)
            .collection(department)
            .doc(batch)
            .collection('users')
            .doc(firebaseUID);

        transaction.set(
            collegeUserRef,
            {
              'phone_number': phoneNumber,
              'username': userData['username'],
              'current_firebase_uid': firebaseUID,
              'reference': mainUserRef,
            },
            SetOptions(merge: true));
      });

      await _initializeRealtimeUserData(firebaseUID, userData);
      await setLoggedIn(phoneNumber);
    } catch (e) {
      print('Error registering user: $e');
      throw e;
    }
  }

  Future<void> _initializeRealtimeUserData(
      String firebaseUID, Map<String, dynamic> userData) async {
    try {
      final realtimeUserData = {
        'phone_number': userData['phone_number'],
        'streaks': 0,
        'coins': 5,
        'xp': 20,
        'points': 0,
        'daily_usage': 0,
        'total_usage': 0,
        'study_hours': 0,
        'last_usage_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'last_updated': ServerValue.timestamp,
      };

      await _database
          .ref('skillbench/users/$firebaseUID')
          .set(realtimeUserData);
    } catch (e) {
      print('Error initializing realtime user data: $e');
      throw e;
    }
  }

  Future<void> signOut() async {
    try {
      await SecureStorage.delete('is_logged_in');
      await SecureStorage.delete('phone_number');
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (docSnapshot.exists) {
        return docSnapshot.data();
      }

      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserStatsFromRealtimeDB() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final dataSnapshot =
          await _database.ref('skillbench/users/${currentUser.uid}').get();

      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>;
        return Map<String, dynamic>.from(data);
      }

      return null;
    } catch (e) {
      print('Error getting user stats from realtime database: $e');
      return null;
    }
  }

  Future<void> updateUserStats(
      {int? streaks, int? coins, int? xp, int? points}) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{};
      if (streaks != null) updateData['streaks'] = streaks;
      if (coins != null) updateData['coins'] = coins;
      if (xp != null) updateData['xp'] = xp;
      if (points != null) updateData['points'] = points;

      if (updateData.isEmpty) return;

      updateData['last_updated'] = ServerValue.timestamp;

      await _database
          .ref('skillbench/users/${currentUser.uid}')
          .update(updateData);

      notifyListeners();
    } catch (e) {
      print('Error updating user stats: $e');
      throw e;
    }
  }

  Future<void> updateDailyUsage(int minutes) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final dataSnapshot =
          await _database.ref('skillbench/users/${currentUser.uid}').get();

      int currentUsage = 0;
      int totalUsage = 0;
      int studyHours = 0;

      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>;
        currentUsage = data['daily_usage'] ?? 0;
        totalUsage = data['total_usage'] ?? 0;
        studyHours = data['study_hours'] ?? 0;
      }

      final newTotalUsage = totalUsage + minutes;
      final newStudyHours = (newTotalUsage / 60).floor();

      await _database.ref('skillbench/users/${currentUser.uid}').update({
        'daily_usage': currentUsage + minutes,
        'total_usage': newTotalUsage,
        'study_hours': newStudyHours,
        'last_usage_date': today,
        'last_updated': ServerValue.timestamp,
      });

      notifyListeners();
    } catch (e) {
      print('Error updating daily usage: $e');
      throw e;
    }
  }

  Future<void> updateTotalRequests(String mode) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('total_request')) return;

      final totalRequest = data['total_request'] as Map<String, dynamic>;
      int practiceMode = totalRequest['practice_mode'] ?? 0;
      int testMode = totalRequest['test_mode'] ?? 0;

      if (mode == 'practice') {
        practiceMode++;
      } else if (mode == 'test') {
        testMode++;
      }

      await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'total_request': {
          'practice_mode': practiceMode,
          'test_mode': testMode,
        },
      });

      notifyListeners();
    } catch (e) {
      print('Error updating total requests: $e');
      throw e;
    }
  }

  Future<void> addXP(int xpToAdd) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final dataSnapshot =
          await _database.ref('skillbench/users/${currentUser.uid}/xp').get();

      int currentXP = 0;
      if (dataSnapshot.exists) {
        currentXP = dataSnapshot.value as int? ?? 0;
      }

      await _database.ref('skillbench/users/${currentUser.uid}').update({
        'xp': currentXP + xpToAdd,
        'last_updated': ServerValue.timestamp,
      });

      notifyListeners();
    } catch (e) {
      print('Error adding XP: $e');
      throw e;
    }
  }

  Future<void> addCoins(int coinsToAdd) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final dataSnapshot = await _database
          .ref('skillbench/users/${currentUser.uid}/coins')
          .get();

      int currentCoins = 0;
      if (dataSnapshot.exists) {
        currentCoins = dataSnapshot.value as int? ?? 0;
      }

      await _database.ref('skillbench/users/${currentUser.uid}').update({
        'coins': currentCoins + coinsToAdd,
        'last_updated': ServerValue.timestamp,
      });

      notifyListeners();
    } catch (e) {
      print('Error adding coins: $e');
      throw e;
    }
  }

  Future<void> updateStreak() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final yesterday = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().subtract(Duration(days: 1)));

      final dataSnapshot =
          await _database.ref('skillbench/users/${currentUser.uid}').get();

      int currentStreak = 0;
      String? lastUsageDate;

      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>;
        currentStreak = data['streaks'] ?? 0;
        lastUsageDate = data['last_usage_date'];
      }

      int newStreak = currentStreak;

      if (lastUsageDate == null || lastUsageDate != today) {
        if (lastUsageDate == yesterday) {
          newStreak = currentStreak + 1;
        } else if (lastUsageDate != today) {
          newStreak = 1;
        }

        await _database.ref('skillbench/users/${currentUser.uid}').update({
          'streaks': newStreak,
          'last_usage_date': today,
          'last_updated': ServerValue.timestamp,
        });
      }

      notifyListeners();
    } catch (e) {
      print('Error updating streak: $e');
      throw e;
    }
  }
}
