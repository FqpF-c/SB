import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleOTPService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  
  // Test values for development
  static const String testPhoneNumber = '+911234567890';
  static const String testOTP = '123456';
  
  // Key for storing verification ID in SharedPreferences
  static const String verificationIdKey = 'firebase_verification_id';

  // Store verification ID to persistent storage
  Future<void> _saveVerificationId(String verificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(verificationIdKey, verificationId);
      print('CRITICAL: Verification ID saved: $verificationId');
    } catch (e) {
      print('CRITICAL ERROR: Error saving verification ID: $e');
    }
  }

  // Get verification ID from persistent storage
  Future<String?> _getVerificationId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verificationId = prefs.getString(verificationIdKey);
      print('CRITICAL: Retrieved verification ID: $verificationId');
      return verificationId;
    } catch (e) {
      print('CRITICAL ERROR: Error retrieving verification ID: $e');
      return null;
    }
  }

  // Send OTP to the user's phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function onSuccess,
    required Function(String) onError,
    required BuildContext context,
  }) async {
    try {
      print('CRITICAL: Sending OTP to: $phoneNumber');
      
      // For test phone number, immediately succeed without Firebase call
      if (phoneNumber == testPhoneNumber) {
        print('CRITICAL: Using test phone number flow');
        await _saveVerificationId('test-verification-id');
        onSuccess();
        return;
      }

      // Configure timeout - longer timeout helps with network issues
      final timeout = Duration(seconds: 120);
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: timeout,
        verificationCompleted: (firebase_auth.PhoneAuthCredential credential) async {
          print('CRITICAL: Auto-verification completed - but we ignore this for consistency');
          // We don't auto-sign in to ensure user enters OTP manually
        },
        verificationFailed: (firebase_auth.FirebaseAuthException e) {
          print('CRITICAL ERROR: Firebase verification failed: ${e.code} - ${e.message}');
          
          // Translate error codes to user-friendly messages
          switch (e.code) {
            case 'invalid-phone-number':
              onError('The phone number format is incorrect');
              break;
            case 'too-many-requests':
              onError('Too many requests from this device. Try again later');
              break;
            case 'app-not-authorized':
              onError('App is not authorized to use Firebase Authentication');
              break;
            case 'quota-exceeded':
              onError('SMS quota exceeded. Try again tomorrow');
              break;
            case 'missing-client-identifier':
              onError('Device verification failed. Please try again later.');
              break;
            default:
              onError(e.message ?? 'Verification failed');
          }
        },
        codeSent: (String verificationId, int? resendToken) async {
          print('CRITICAL: SMS code sent successfully - verificationId: $verificationId');
          // Save verification ID
          await _saveVerificationId(verificationId);
          onSuccess();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('CRITICAL: Auto retrieval timeout - saving verificationId: $verificationId');
          // Also save verification ID on timeout
          _saveVerificationId(verificationId);
        },
      );
    } catch (e) {
      print('CRITICAL ERROR: Exception during OTP send: $e');
      onError('Error sending verification code: ${e.toString()}');
    }
  }

  // Verify the OTP entered by the user
  Future<void> verifyOTP({
    required String otp,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      print('CRITICAL: Verifying OTP code: $otp');
      
      // Get verification ID from SharedPreferences
      String? verificationId = await _getVerificationId();
      
      if (verificationId == null || verificationId.isEmpty) {
        print('CRITICAL ERROR: Empty verification ID');
        onError('Session expired. Please request a new verification code.');
        return;
      }
      
      // For test verification ID and OTP, immediately succeed
      if (verificationId == 'test-verification-id' && otp == testOTP) {
        print('CRITICAL: Using test verification flow');
        
        // Ensure we have a FirebaseAuth user for testing
        if (_auth.currentUser == null) {
          try {
            await _auth.signInAnonymously();
            print('CRITICAL: Created anonymous user for testing');
          } catch (e) {
            print('CRITICAL ERROR: Anonymous sign-in failed: $e');
          }
        }
        
        // Use a small delay to simulate real authentication
        await Future.delayed(Duration(milliseconds: 300));
        onSuccess();
        return;
      }

      print('CRITICAL: Creating credential with verification ID: $verificationId');
      
      // Create credential from verification ID and OTP
      final firebase_auth.PhoneAuthCredential credential = 
          firebase_auth.PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otp,
          );

      // DIRECT APPROACH: Separate the credential creation and sign-in
      print('CRITICAL: Beginning sign-in with credential');
      firebase_auth.UserCredential? userCredential;
      
      try {
        // Sign in with credential
        userCredential = await _auth.signInWithCredential(credential)
            .timeout(Duration(seconds: 30));
            
        print('CRITICAL: Sign-in completed. User = ${userCredential.user?.uid ?? "NULL"}');
      } catch (signInError) {
        print('CRITICAL ERROR: During signInWithCredential: $signInError');
        throw signInError;  // Re-throw to outer catch
      }
      
      if (userCredential.user != null) {
        print('CRITICAL: OTP verification successful for user: ${userCredential.user!.uid}');
        
        // IMPORTANT: Add a pause to ensure Firebase Auth state is fully updated
        await Future.delayed(Duration(milliseconds: 500));
        
        // IMPORTANT: Double-check the current user
        final currentUser = _auth.currentUser;
        if (currentUser == null) {
          print('CRITICAL ERROR: currentUser is null after successful sign-in!');
          onError('Authentication failed. Please try again.');
          return;
        }
        
        print('CRITICAL: Final currentUser check passed: ${currentUser.uid}');
        onSuccess();
      } else {
        print('CRITICAL ERROR: Authentication completed but no user was returned');
        onError('Authentication failed. Please try again.');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      print('CRITICAL ERROR: Firebase Auth Exception: ${e.code} - ${e.message}');
      
      switch (e.code) {
        case 'invalid-verification-code':
          onError('The code you entered is incorrect. Please check and try again.');
          break;
        case 'invalid-verification-id':
          onError('Session expired. Please request a new verification code.');
          break;
        case 'session-expired':
          onError('The verification session has expired. Please request a new code.');
          break;
        default:
          onError(e.message ?? 'Verification failed. Please try again.');
      }
    } catch (e) {
      print('CRITICAL ERROR: Generic exception during verification: $e');
      onError('Verification error: ${e.toString()}');
    }
  }

  // Helper method to check if a phone number is the test number
  bool isTestPhoneNumber(String phoneNumber) {
    return phoneNumber == testPhoneNumber;
  }

  // Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print('CRITICAL: User signed out successfully');
    } catch (e) {
      print('CRITICAL ERROR: Error signing out: $e');
      throw e;
    }
  }

  // Get the current user's UID
  String? getCurrentUserUid() {
    final user = _auth.currentUser;
    return user?.uid;
  }

  // Get the current authentication state
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();
}