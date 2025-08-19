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
      // First try to get from secure storage
      String? phoneFromStorage = await SecureStorage.read('phone_number');
      if (phoneFromStorage != null) {
        return phoneFromStorage;
      }
      
      // Fallback to Firebase Auth displayName if available
      final currentUser = _auth.currentUser;
      if (currentUser?.displayName != null) {
        return currentUser!.displayName;
      }
      
      return null;
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

  Future<String?> getUidByPhoneNumber(String phoneNumber) async {
    try {
      print('DEBUG getUidByPhoneNumber: Looking up UID for phone: $phoneNumber');
      
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('phone_to_uid')
          .collection('mappings')
          .doc(phoneNumber)
          .get();
      
      if (docSnapshot.exists) {
        final uid = docSnapshot.data()?['uid'];
        print('DEBUG getUidByPhoneNumber: Found existing UID: $uid');
        return uid;
      }
      
      print('DEBUG getUidByPhoneNumber: No existing UID found for phone: $phoneNumber');
      return null;
    } catch (e) {
      print('ERROR getUidByPhoneNumber: $e');
      return null;
    }
  }

  // For testing: Create a phone-to-UID mapping manually
  Future<void> createTestPhoneMapping(String phoneNumber, String uid) async {
    try {
      print('DEBUG createTestPhoneMapping: Creating mapping for $phoneNumber -> $uid');
      
      await _firestore
          .collection('skillbench')
          .doc('phone_to_uid')
          .collection('mappings')
          .doc(phoneNumber)
          .set({
        'uid': uid,
        'phone_number': phoneNumber,
        'created_at': Timestamp.now(),
        'last_updated': Timestamp.now(),
      });
      
      print('DEBUG createTestPhoneMapping: Successfully created mapping');
    } catch (e) {
      print('ERROR createTestPhoneMapping: $e');
      throw e;
    }
  }

  Future<void> _signInWithExistingUID(String uid, String phoneNumber) async {
    try {
      print('DEBUG _signInWithExistingUID: Attempting to sign in with UID: $uid');
      
      // First try to find and sign in with the existing Firebase Auth account
      String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');
      String email = '${cleanPhoneNumber}@skillbench.temp';
      String password = 'temp_${cleanPhoneNumber}';
      
      try {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        print('DEBUG _signInWithExistingUID: Successfully signed in with existing email account');
        
        // Verify the UID matches
        if (_auth.currentUser?.uid == uid) {
          print('DEBUG _signInWithExistingUID: UID matches! Authentication successful');
          return;
        } else {
          print('WARNING _signInWithExistingUID: UID mismatch! Expected: $uid, Got: ${_auth.currentUser?.uid}');
        }
      } catch (e) {
        print('DEBUG _signInWithExistingUID: Email sign-in failed, trying alternative methods: $e');
      }
      
      // If email sign-in failed, sign out current user and create anonymous with specific UID reference
      await _auth.signOut();
      await _auth.signInAnonymously();
      await _auth.currentUser?.updateDisplayName(phoneNumber);
      
      print('WARNING _signInWithExistingUID: Using anonymous auth as fallback for UID: ${_auth.currentUser?.uid}');
      
    } catch (e) {
      print('ERROR _signInWithExistingUID: $e');
      throw e;
    }
  }

  Future<String?> getPhoneNumberByUid(String uid) async {
    try {
      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(uid)
          .get();
      
      if (docSnapshot.exists) {
        return docSnapshot.data()?['phone_number'];
      }
      return null;
    } catch (e) {
      print('Error getting phone number by UID: $e');
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
      
      // If not marked as logged in or no phone number, user is not logged in
      if (!isLoggedIn || phoneNumber == null) {
        return false;
      }
      
      // Ensure Firebase Auth user exists
      if (_auth.currentUser == null) {
        try {
          print('DEBUG isUserLoggedIn: No current user, attempting authentication');
          
          // Check if this phone number has an existing UID
          final existingUID = await getUidByPhoneNumber(phoneNumber);
          
          if (existingUID != null) {
            print('DEBUG isUserLoggedIn: Found existing UID for phone: $existingUID');
            await _signInWithExistingUID(existingUID, phoneNumber);
          } else {
            String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');
            String email = '${cleanPhoneNumber}@skillbench.temp';
            String password = 'temp_${cleanPhoneNumber}';
            
            try {
              await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              print('DEBUG isUserLoggedIn: Signed in with email');
            } catch (signInError) {
              await _auth.signInAnonymously();
              await _auth.currentUser?.updateDisplayName(phoneNumber);
              print('DEBUG isUserLoggedIn: Used anonymous auth fallback');
            }
          }
        } catch (e) {
          print('Error authenticating user: $e');
          // Don't fail login just because of auth issues
        }
      }
      
      // Only check Firestore existence occasionally or if there's a specific reason
      // For normal app launches, trust the secure storage
      try {
        final exists = await doesCurrentUserExistInFirestore().timeout(
          Duration(seconds: 5), // 5 second timeout
          onTimeout: () {
            print('Firestore check timed out, assuming user exists');
            return true; // Assume user exists if network is slow
          },
        );
        
        if (!exists) {
          print('User does not exist in Firestore, logging out');
          await SecureStorage.delete('is_logged_in');
          await SecureStorage.delete('phone_number');
          return false;
        }
      } catch (e) {
        print('Error checking user existence in Firestore: $e');
        // Don't fail login due to network issues, trust secure storage
        print('Assuming user is valid due to network issues');
      }
      
      return true;
    } catch (e) {
      print('Error checking login status: $e');
      // If there's any error, but we have valid secure storage data, assume logged in
      final isLoggedIn = await SecureStorage.read('is_logged_in') == 'true';
      final phoneNumber = await SecureStorage.read('phone_number');
      return isLoggedIn && phoneNumber != null;
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

  Future<void> setLoggedInWithUID(String phoneNumber, String uid) async {
    try {
      print('DEBUG setLoggedInWithUID: Setting login for phone: $phoneNumber with UID: $uid');
      
      // Verify current user matches the expected UID
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception('Current Firebase user does not match expected UID: $uid');
      }
      
      await SecureStorage.write('is_logged_in', 'true');
      await SecureStorage.write('phone_number', phoneNumber);

      // Update last login in Firestore
      final exists = await doesCurrentUserExistInFirestore();
      if (exists) {
        await _firestore
            .collection('skillbench')
            .doc('users')
            .collection('users')
            .doc(uid)
            .update({
          'last_login': Timestamp.now(),
        });
        
        print('DEBUG setLoggedInWithUID: Updated last login for UID: $uid');
      }

      notifyListeners();
      print('DEBUG setLoggedInWithUID: Successfully set logged in for UID: $uid');
    } catch (e) {
      print('ERROR setLoggedInWithUID: $e');
      throw e;
    }
  }

  Future<void> setLoggedIn(String phoneNumber) async {
    try {
      print('DEBUG setLoggedIn: Starting login for phone: $phoneNumber');
      
      // First, check if this phone number already has an associated UID
      final existingUID = await getUidByPhoneNumber(phoneNumber);
      
      if (existingUID != null) {
        print('DEBUG setLoggedIn: Found existing UID for phone: $existingUID');
        await _signInWithExistingUID(existingUID, phoneNumber);
      } else {
        print('DEBUG setLoggedIn: No existing UID found, creating new user');
        
        User? user = _auth.currentUser;
        print('DEBUG setLoggedIn: Current user before auth: ${user?.uid}');
        
        if (user == null) {
          String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');
          String email = '${cleanPhoneNumber}@skillbench.temp';
          String password = 'temp_${cleanPhoneNumber}';
          
          print('DEBUG setLoggedIn: Attempting sign in with email: $email');
          
          try {
            await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            user = _auth.currentUser;
            print('DEBUG setLoggedIn: Successfully signed in existing user: ${user?.uid}');
          } catch (signInError) {
            print('DEBUG setLoggedIn: Sign in failed: $signInError');
            print('DEBUG setLoggedIn: Attempting to create new user');
            
            try {
              await _auth.createUserWithEmailAndPassword(
                email: email,
                password: password,
              );
              await _auth.currentUser?.updateDisplayName(phoneNumber);
              user = _auth.currentUser;
              print('DEBUG setLoggedIn: Successfully created new user: ${user?.uid}');
            } catch (createError) {
              print('DEBUG setLoggedIn: Create user failed: $createError');
              print('DEBUG setLoggedIn: Falling back to anonymous auth');
              
              final userCredential = await _auth.signInAnonymously();
              await userCredential.user?.updateDisplayName(phoneNumber);
              user = userCredential.user;
              print('DEBUG setLoggedIn: Anonymous user created: ${user?.uid}');
            }
          }
        }
      }

      await SecureStorage.write('is_logged_in', 'true');
      await SecureStorage.write('phone_number', phoneNumber);

      final exists = await doesCurrentUserExistInFirestore();
      if (exists) {
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _firestore.runTransaction((transaction) async {
            final userRef = _firestore
                .collection('skillbench')
                .doc('users')
                .collection('users')
                .doc(currentUser.uid);

            transaction.update(userRef, {
              'last_login': Timestamp.now(),
            });

            final phoneToUidRef = _firestore
                .collection('skillbench')
                .doc('phone_to_uid')
                .collection('mappings')
                .doc(phoneNumber);

            transaction.set(phoneToUidRef, {
              'uid': currentUser.uid,
              'phone_number': phoneNumber,
              'last_updated': Timestamp.now(),
            }, SetOptions(merge: true));
          });
        }
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
        final phoneNumber = userData['phone_number'];
        String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');
        String email = '${cleanPhoneNumber}@skillbench.temp';
        String password = 'temp_${cleanPhoneNumber}';
        
        try {
          await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          user = _auth.currentUser;
        } catch (signInError) {
          try {
            await _auth.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
            await _auth.currentUser?.updateDisplayName(phoneNumber);
            user = _auth.currentUser;
          } catch (createError) {
            final userCredential = await _auth.signInAnonymously();
            await userCredential.user?.updateDisplayName(phoneNumber);
            user = userCredential.user;
          }
        }
      }

      final phoneNumber = userData['phone_number'];
      final college = userData['college'];
      final department = userData['department'];
      final batch = userData['batch'];
      final firebaseUID = user!.uid;

      print('DEBUG registerUser: Starting Firestore transaction for UID: $firebaseUID');
      
      await _firestore.runTransaction((transaction) async {
        final mainUserRef = _firestore
            .collection('skillbench')
            .doc('users')
            .collection('users')
            .doc(firebaseUID);

        print('DEBUG registerUser: Main user ref path: skillbench/users/users/$firebaseUID');

        final userSnapshot = await transaction.get(mainUserRef);
        final existingData = userSnapshot.exists ? userSnapshot.data() : null;
        
        print('DEBUG registerUser: User document exists: ${userSnapshot.exists}');
        print('DEBUG registerUser: Existing data: $existingData');

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

        print('DEBUG registerUser: Complete user data to save: $completeUserData');

        transaction.set(mainUserRef, completeUserData, SetOptions(merge: true));

        final phoneToUidRef = _firestore
            .collection('skillbench')
            .doc('phone_to_uid')
            .collection('mappings')
            .doc(phoneNumber);

        transaction.set(phoneToUidRef, {
          'uid': firebaseUID,
          'phone_number': phoneNumber,
          'created_at': Timestamp.now(),
          'last_updated': Timestamp.now(),
        }, SetOptions(merge: true));

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
      print('DEBUG _initializeRealtimeUserData: Starting for UID: $firebaseUID');
      
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

      print('DEBUG _initializeRealtimeUserData: Data to save: $realtimeUserData');
      print('DEBUG _initializeRealtimeUserData: Path: skillbench/users/$firebaseUID');

      await _database
          .ref('skillbench/users/$firebaseUID')
          .set(realtimeUserData);
          
      print('DEBUG _initializeRealtimeUserData: Successfully saved realtime data');
    } catch (e) {
      print('ERROR _initializeRealtimeUserData: $e');
      print('ERROR _initializeRealtimeUserData: Stack trace: ${StackTrace.current}');
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
      print('DEBUG getCurrentUserData: currentUser = ${currentUser?.uid}');
      print('DEBUG getCurrentUserData: currentUser email = ${currentUser?.email}');
      print('DEBUG getCurrentUserData: currentUser displayName = ${currentUser?.displayName}');
      
      if (currentUser == null) {
        print('DEBUG getCurrentUserData: No current user found');
        return null;
      }

      final path = 'skillbench/users/users/${currentUser.uid}';
      print('DEBUG getCurrentUserData: Fetching from path: $path');

      final docSnapshot = await _firestore
          .collection('skillbench')
          .doc('users')
          .collection('users')
          .doc(currentUser.uid)
          .get();

      print('DEBUG getCurrentUserData: Document exists = ${docSnapshot.exists}');
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        print('DEBUG getCurrentUserData: Data = $data');
        return data;
      } else {
        print('DEBUG getCurrentUserData: Document does not exist at path: $path');
      }

      return null;
    } catch (e) {
      print('ERROR getCurrentUserData: $e');
      print('ERROR getCurrentUserData: Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserStatsFromRealtimeDB() async {
    try {
      final currentUser = _auth.currentUser;
      print('DEBUG getUserStatsFromRealtimeDB: currentUser = ${currentUser?.uid}');
      
      if (currentUser == null) {
        print('DEBUG getUserStatsFromRealtimeDB: No current user found');
        return null;
      }

      final path = 'skillbench/users/${currentUser.uid}';
      print('DEBUG getUserStatsFromRealtimeDB: Fetching from path: $path');

      final dataSnapshot = await _database.ref(path).get();

      print('DEBUG getUserStatsFromRealtimeDB: Data exists = ${dataSnapshot.exists}');
      
      if (dataSnapshot.exists) {
        final data = dataSnapshot.value as Map<dynamic, dynamic>;
        print('DEBUG getUserStatsFromRealtimeDB: Data = $data');
        return Map<String, dynamic>.from(data);
      } else {
        print('DEBUG getUserStatsFromRealtimeDB: No data found at path: $path');
      }

      return null;
    } catch (e) {
      print('ERROR getUserStatsFromRealtimeDB: $e');
      print('ERROR getUserStatsFromRealtimeDB: Stack trace: ${StackTrace.current}');
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
