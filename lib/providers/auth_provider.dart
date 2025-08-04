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
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();
      return docSnapshot.exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }

  Future<bool> doesCurrentUserExistInFirestore() async {
    final phoneNumber = await getCurrentUserPhone();
    if (phoneNumber == null) return false;
    return await checkIfUserExists(phoneNumber);
  }

  Future<bool> isUserLoggedIn() async {
    try {
      final isLoggedIn = await SecureStorage.read('is_logged_in') == 'true';
      final phoneNumber = await SecureStorage.read('phone_number');
      if (isLoggedIn && phoneNumber != null) {
        final exists = await checkIfUserExists(phoneNumber);
        if (!exists) {
          await SecureStorage.delete('is_logged_in');
          await SecureStorage.delete('phone_number');
          return false;
        }

        if (_auth.currentUser == null) {
          await _auth.signInAnonymously();
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
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) return;

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();

      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      final lastUsageDate = data?['last_usage_date'];
      final streaks = data?['streaks'] ?? 0;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 1)));

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

      final exists = await checkIfUserExists(phoneNumber);
      if (exists) {
        await _firestore
            .collection('skillbench')
            .doc('ALL_USERS')
            .collection('users')
            .doc(phoneNumber)
            .update({
          'last_login': Timestamp.now(),
          'current_firebase_uid': user!.uid,
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
            .doc('ALL_USERS')
            .collection('users')
            .doc(phoneNumber);

        final userSnapshot = await transaction.get(mainUserRef);
        final existingData = userSnapshot.exists ? userSnapshot.data() : null;

        final completeUserData = {
          ...userData,
          'phone_number': phoneNumber,
          'username': userData['username'] ?? (existingData?['username'] ?? 'User'),
          'current_firebase_uid': firebaseUID,
          'created_at':
              userSnapshot.exists ? (existingData?['created_at'] ?? Timestamp.now()) : Timestamp.now(),
          'last_login': Timestamp.now(),
          'streaks': userData['streaks'] ?? (existingData?['streaks'] ?? 0),
          'coins': userData['coins'] ?? (existingData?['coins'] ?? 5),
          'xp': userData['xp'] ?? (existingData?['xp'] ?? 20),
          'daily_usage': userData['daily_usage'] ?? (existingData?['daily_usage'] ?? 0),
          'total_usage': userData['total_usage'] ?? (existingData?['total_usage'] ?? 0),
          'gender': userData['gender'] ?? (existingData?['gender'] ?? 'prefer_not_to_say'),
          'total_request': userData['total_request'] ?? (existingData?['total_request'] ?? {
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
            .doc(phoneNumber);

        transaction.set(collegeUserRef, {
          'phone_number': phoneNumber,
          'username': userData['username'],
          'current_firebase_uid': firebaseUID,
          'reference': mainUserRef,
        }, SetOptions(merge: true));
      });

      await setLoggedIn(phoneNumber);
    } catch (e) {
      print('Error registering user: $e');
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
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) return null;

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final currentUser = _auth.currentUser;
        if (currentUser != null && data != null && data['current_firebase_uid'] != currentUser.uid) {
          await docSnapshot.reference.update({'current_firebase_uid': currentUser.uid});
          data['current_firebase_uid'] = currentUser.uid;
        }
        return data;
      }

      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<void> updateUserStats({int? streaks, int? coins, int? xp}) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');

      final updateData = <String, dynamic>{};
      if (streaks != null) updateData['streaks'] = streaks;
      if (coins != null) updateData['coins'] = coins;
      if (xp != null) updateData['xp'] = xp;

      if (updateData.isEmpty) return;

      await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .update(updateData);

      // Optional: sync to Realtime Database
      await FirebaseDatabase.instance
          .ref('skillbench/users/$phoneNumber')
          .update(updateData);

      notifyListeners();
    } catch (e) {
      print('Error updating user stats: $e');
      throw e;
    }
  }

  Future<void> updateDailyUsage(int minutes) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();

      int currentUsage = 0;
      int totalUsage = 0;

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          currentUsage = data['daily_usage'] ?? 0;
          totalUsage = data['total_usage'] ?? 0;
        }
      }

      await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .update({
        'daily_usage': currentUsage + minutes,
        'total_usage': totalUsage + minutes,
        'last_usage_date': today,
      });

      notifyListeners();
    } catch (e) {
      print('Error updating daily usage: $e');
      throw e;
    }
  }

  Future<void> updateTotalRequests(String mode) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .get();

      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('total_request')) return;

      final totalRequest = data['total_request'] as Map<String, dynamic>;
      int practiceMode = totalRequest['practice_mode'] ?? 0;
      int testMode = totalRequest['test_mode'] ?? 0;

      if (mode == 'practice_mode') {
        practiceMode++;
      } else if (mode == 'test_mode') {
        testMode++;
      }

      await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
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

  Future<String?> getCurrentUserUID() async {
    return await getCurrentUserPhone(); // phone number used as identifier
  }
}
