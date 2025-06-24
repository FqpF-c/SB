import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  // Get current user's phone number from SharedPreferences
  Future<String?> getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }
  
  // Check if a user with the given phone number exists
  Future<bool> checkIfUserExists(String phoneNumber) async {
    try {
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)  // Use phone number as document ID
          .get();
      
      bool exists = docSnapshot.exists;
      print('CRITICAL: User exists check for $phoneNumber: $exists');
      return exists;
    } catch (e) {
      print('Error checking user existence: $e');
      return false;
    }
  }
  
  // Check if the current user exists in Firestore
  Future<bool> doesCurrentUserExistInFirestore() async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) return false;
      
      return await checkIfUserExists(phoneNumber);
    } catch (e) {
      print('Error checking current user existence: $e');
      return false;
    }
  }
  
  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      final storedPhoneNumber = prefs.getString('phone_number');
      
      print('CRITICAL: Checking login status - isLoggedIn: $isLoggedIn, phone: $storedPhoneNumber');
      
      if (isLoggedIn && storedPhoneNumber != null) {
        // Check if user exists in Firestore
        final exists = await checkIfUserExists(storedPhoneNumber);
        if (!exists) {
          // If user doesn't exist in Firestore, consider them not logged in
          await prefs.setBool('is_logged_in', false);
          await prefs.remove('phone_number');
          return false;
        }
        
        // Ensure Firebase Auth has an active user for storage operations
        User? user = _auth.currentUser;
        if (user == null) {
          try {
            await _auth.signInAnonymously();
            print('CRITICAL: Created anonymous Firebase user for session');
          } catch (e) {
            print('CRITICAL ERROR: Failed to create anonymous user: $e');
            return false;
          }
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking if user is logged in: $e');
      return false;
    }
  }
  
  // Set user as logged in
  Future<void> setLoggedIn(String phoneNumber) async {
    try {
      print('CRITICAL: Setting user as logged in for phone: $phoneNumber');
      
      // Ensure Firebase Auth has an active user (needed for storage operations)
      User? user = _auth.currentUser;
      if (user == null) {
        try {
          final userCredential = await _auth.signInAnonymously();
          user = userCredential.user;
          print('CRITICAL: Created anonymous Firebase user: ${user?.uid}');
        } catch (e) {
          print('CRITICAL ERROR: Failed to create Firebase user: $e');
          throw Exception('Failed to create user session. Please try again.');
        }
      }
      
      if (user == null) {
        throw Exception('No authenticated user found. Please try again.');
      }
      
      // Update SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('phone_number', phoneNumber);
      
      print('CRITICAL: SharedPreferences updated successfully');
      
      // Check if user already exists in Firestore
      final exists = await checkIfUserExists(phoneNumber);
      
      if (exists) {
        print('CRITICAL: Existing user found, updating last login');
        // Update last login timestamp for existing user
        await _firestore
            .collection('skillbench')
            .doc('ALL_USERS')
            .collection('users')
            .doc(phoneNumber)
            .update({
              'last_login': Timestamp.now(),
              'current_firebase_uid': user.uid, // Store current Firebase UID for reference
            });
        print('CRITICAL: Updated existing user last login');
      } else {
        print('CRITICAL: New user detected, will need registration');
      }
      
      notifyListeners();
    } catch (e) {
      print('Error setting user as logged in: $e');
      throw e;
    }
  }
  
  // Register a new user
  Future<void> registerUser(Map<String, dynamic> userData) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        // Try to create anonymous user if none exists
        try {
          final userCredential = await _auth.signInAnonymously();
          user = userCredential.user;
          print('CRITICAL: Created anonymous user for registration: ${user?.uid}');
        } catch (e) {
          throw Exception('User session not found. Please try login again.');
        }
      }
      
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      final firebaseUID = user.uid;
      final phoneNumber = userData['phone_number'];
      final college = userData['college'];
      final department = userData['department'];
      final batch = userData['batch'];
      
      print('CRITICAL: Registering user with Phone: $phoneNumber, Firebase UID: $firebaseUID');
      
      // Transaction to ensure atomicity of operations
      await _firestore.runTransaction((transaction) async {
        // 1. Create/update user in ALL_USERS collection using phone number as document ID
        final mainUserRef = _firestore
            .collection('skillbench')
            .doc('ALL_USERS')
            .collection('users')
            .doc(phoneNumber);  // Use phone number as document ID
            
        final userSnapshot = await transaction.get(mainUserRef);
        
        // Get existing data safely
        final existingData = userSnapshot.exists ? userSnapshot.data() : null;
        
        // Prepare complete user data with additional fields
        final completeUserData = {
          ...userData,
          'phone_number': phoneNumber,  // Ensure phone number is stored in document
          'current_firebase_uid': firebaseUID,  // Store Firebase UID for reference
          'created_at': userSnapshot.exists ? (existingData?['created_at'] ?? Timestamp.now()) : Timestamp.now(),
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
        
        // 2. Create reference in college > department > batch > users collection
        final collegeUserRef = _firestore
            .collection('skillbench')
            .doc(college)
            .collection(department)
            .doc(batch)
            .collection('users')
            .doc(phoneNumber);  // Use phone number as document ID here too
            
        // Set a reference to the main user document
        transaction.set(collegeUserRef, {
          'phone_number': phoneNumber,
          'username': userData['username'],
          'current_firebase_uid': firebaseUID,
          'reference': mainUserRef,  // Store reference to main user document
        }, SetOptions(merge: true));
        
        print('CRITICAL: Created user reference in college collection');
      });
      
      // Set login status (this should already be set, but ensure consistency)
      await setLoggedIn(phoneNumber);
      
      print('CRITICAL: User registration completed successfully');
      
    } catch (e) {
      print('Error registering user: $e');
      throw e;
    }
  }
  
  // Sign out the user
  Future<void> signOut() async {
    try {
      print('CRITICAL: Starting sign out process');
      
      // Update SharedPreferences first (in case Firebase Auth fails)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.remove('phone_number');
      
      print('CRITICAL: Cleared SharedPreferences');
      
      // Then sign out from Firebase
      await _auth.signOut();
      
      print('CRITICAL: Firebase sign out completed');
      
      notifyListeners();
    } catch (e) {
      print('Error signing out: $e');
      throw e;
    }
  }
  
  // Get current user data from Firestore
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) {
        print('CRITICAL: No phone number found in SharedPreferences');
        return null;
      }
      
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)  // Use phone number as document ID
          .get();
      
      if (docSnapshot.exists) {
        print('CRITICAL: Retrieved user data successfully for phone: $phoneNumber');
        final data = docSnapshot.data();
        
        // Update current Firebase UID if needed
        final currentUser = _auth.currentUser;
        if (currentUser != null && data != null && data['current_firebase_uid'] != currentUser.uid) {
          print('CRITICAL: Updating Firebase UID in user data');
          await docSnapshot.reference.update({'current_firebase_uid': currentUser.uid});
          data!['current_firebase_uid'] = currentUser.uid;
        }
        
        return data;
      }
      
      print('CRITICAL: No user data found in Firestore for phone: $phoneNumber');
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
  
  // Update user streaks, coins, and XP
  Future<void> updateUserStats({
    int? streaks,
    int? coins,
    int? xp,
  }) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');
      
      final updateData = <String, dynamic>{};
      if (streaks != null) updateData['streaks'] = streaks;
      if (coins != null) updateData['coins'] = coins;
      if (xp != null) updateData['xp'] = xp;
      
      if (updateData.isEmpty) return;
      
      // Update in Firestore using phone number as document ID
      await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .update(updateData);
      
      notifyListeners();
    } catch (e) {
      print('Error updating user stats: $e');
      throw e;
    }
  }
  
  // Update daily usage time
  Future<void> updateDailyUsage(int minutes) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');
      
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Get current daily usage
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
          if (data.containsKey('daily_usage')) {
            currentUsage = data['daily_usage'] as int;
          }
          if (data.containsKey('total_usage')) {
            totalUsage = data['total_usage'] as int;
          }
        }
      }
      
      // Update the usage
      final newDailyUsage = currentUsage + minutes;
      final newTotalUsage = totalUsage + minutes;
      
      // Update in Firestore
      await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber)
          .update({
            'daily_usage': newDailyUsage,
            'total_usage': newTotalUsage,
            'last_usage_date': today,
          });
      
      notifyListeners();
    } catch (e) {
      print('Error updating daily usage: $e');
      throw e;
    }
  }
  
  // Update total requests
  Future<void> updateTotalRequests(String mode) async {
    try {
      final phoneNumber = await getCurrentUserPhone();
      if (phoneNumber == null) throw Exception('User not authenticated');
      
      // Get current request counts
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
      int practiceMode = totalRequest['practice_mode'] as int? ?? 0;
      int testMode = totalRequest['test_mode'] as int? ?? 0;
      
      if (mode == 'practice_mode') {
        practiceMode++;
      } else if (mode == 'test_mode') {
        testMode++;
      }
      
      // Update in Firestore
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
  
  // Helper method to get current user's phone number (for compatibility with UID-based calls)
  Future<String?> getCurrentUserUID() async {
    // Return phone number instead of UID for backward compatibility
    return await getCurrentUserPhone();
  }
}