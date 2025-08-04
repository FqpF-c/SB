import 'package:http/http.dart' as http;
import 'package:sms_autofill/sms_autofill.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class OTPService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;

  String? _apiKey;

  static const String testPhoneNumber = '1234567890'; // Without +91
  static const String testOTP = '123456';
  static const String testSessionId = 'test-session-id';

  static const String sessionIdKey = 'otp_session_id';

  // Load 2Factor API key from backend
  Future<void> _loadApiKey() async {
    try {
      final response = await http.get(Uri.parse('https://prepbackend.onesite.store/otpget'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _apiKey = data['key'];
        print('CRITICAL: Fetched API key from backend: $_apiKey');
      } else {
        print('CRITICAL ERROR: Failed to load API key. Status: ${response.statusCode}');
        throw Exception('Could not load API key from server');
      }
    } catch (e) {
      print('CRITICAL ERROR: Exception while loading API key from server: $e');
      throw Exception('Could not load API key');
    }
  }

  Future<void> _saveSessionId(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(sessionIdKey, sessionId);
      print('CRITICAL: Session ID saved: $sessionId');
    } catch (e) {
      print('CRITICAL ERROR: Error saving session ID: $e');
    }
  }

  Future<String?> _getSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString(sessionIdKey);
      print('CRITICAL: Retrieved session ID: $sessionId');
      return sessionId;
    } catch (e) {
      print('CRITICAL ERROR: Error retrieving session ID: $e');
      return null;
    }
  }

  Future<void> _clearSessionId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionIdKey);
      print('CRITICAL: Session ID cleared');
    } catch (e) {
      print('CRITICAL ERROR: Error clearing session ID: $e');
    }
  }

  static Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    try {
      final otpService = OTPService();
      await otpService._loadApiKey();

      if (otpService._apiKey == null) {
        throw Exception('API key is null');
      }

      String apiKey = otpService._apiKey!;
      String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');

      print('CRITICAL: Sending OTP to: $cleanPhoneNumber');

      if (cleanPhoneNumber == testPhoneNumber) {
        print('CRITICAL: Using test phone number flow');
        return {'success': true, 'sessionId': testSessionId};
      }

      final appSignature = await SmsAutoFill().getAppSignature;
      print('CRITICAL: App signature: $appSignature');

      final response = await http.get(
        Uri.parse('https://2factor.in/API/V1/$apiKey/SMS/+91$cleanPhoneNumber/AUTOGEN/OTP1'),
        headers: {'app_signature': appSignature},
      ).timeout(Duration(seconds: 30));

      print('CRITICAL: API Response Status: ${response.statusCode}');
      print('CRITICAL: API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Status'] == 'Success') {
          return {'success': true, 'sessionId': data['Details']};
        } else {
          return {'success': false, 'sessionId': null, 'error': data['Details']};
        }
      } else {
        return {
          'success': false,
          'sessionId': null,
          'error': 'HTTP ${response.statusCode}'
        };
      }
    } catch (e) {
      print("CRITICAL ERROR: Exception sending OTP: $e");
      return {'success': false, 'sessionId': null, 'error': e.toString()};
    }
  }

  static Future<bool> verifyOTP(String sessionId, String otp) async {
    try {
      final otpService = OTPService();
      await otpService._loadApiKey();

      if (otpService._apiKey == null) {
        throw Exception('API key is null');
      }

      String apiKey = otpService._apiKey!;

      print('CRITICAL: Verifying OTP: $otp with session: $sessionId');

      if (sessionId == testSessionId && otp == testOTP) {
        print('CRITICAL: Using test verification flow');
        return true;
      }

      final response = await http.get(
        Uri.parse('https://2factor.in/API/V1/$apiKey/SMS/VERIFY/$sessionId/$otp'),
      ).timeout(Duration(seconds: 30));

      print('CRITICAL: Verify Response Status: ${response.statusCode}');
      print('CRITICAL: Verify Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['Status'] == 'Success' && data['Details'] == 'OTP Matched') {
          return true;
        } else {
          print('CRITICAL ERROR: OTP verification failed - ${data['Details']}');
          return false;
        }
      } else {
        print('CRITICAL ERROR: Verify HTTP ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print("CRITICAL ERROR: Exception verifying OTP: $e");
      return false;
    }
  }

  Future<void> sendOTPWithCallback({
    required String phoneNumber,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      final result = await sendOTP(phoneNumber);
      if (result['success']) {
        await _saveSessionId(result['sessionId']);
        onSuccess();
      } else {
        String errorMessage = result['error'] ?? 'Failed to send OTP';

        if (errorMessage.contains('Invalid Mobile Number')) {
          errorMessage = 'Invalid phone number format';
        } else if (errorMessage.contains('DND')) {
          errorMessage = 'SMS blocked by DND. Please try again later';
        } else if (errorMessage.contains('Rate Limit')) {
          errorMessage = 'Too many requests. Please try again later';
        } else if (errorMessage.startsWith('HTTP')) {
          errorMessage = 'Network error. Please check your connection';
        }

        onError(errorMessage);
      }
    } catch (e) {
      print('CRITICAL ERROR: Exception in sendOTPWithCallback: $e');
      onError('Error sending OTP: ${e.toString()}');
    }
  }

  Future<void> verifyOTPWithCallback({
    required String otp,
    required Function onSuccess,
    required Function(String) onError,
  }) async {
    try {
      String? sessionId = await _getSessionId();
      if (sessionId == null || sessionId.isEmpty) {
        print('CRITICAL ERROR: No session ID found');
        onError('Session expired. Please request a new verification code.');
        return;
      }

      final isValid = await verifyOTP(sessionId, otp);
      if (isValid) {
        print('CRITICAL: OTP verification successful');

        if (_auth.currentUser == null) {
          try {
            await _auth.signInAnonymously();
            print('CRITICAL: Created anonymous Firebase user');
          } catch (e) {
            print('CRITICAL ERROR: Anonymous sign-in failed: $e');
          }
        }

        await _clearSessionId();
        await Future.delayed(Duration(milliseconds: 300));
        onSuccess();
      } else {
        onError('The code you entered is incorrect. Please check and try again.');
      }
    } catch (e) {
      print('CRITICAL ERROR: Exception in verifyOTPWithCallback: $e');
      onError('Verification error: ${e.toString()}');
    }
  }

  bool isTestPhoneNumber(String phoneNumber) {
    String cleanPhoneNumber = phoneNumber.replaceFirst('+91', '');
    return cleanPhoneNumber == testPhoneNumber;
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _clearSessionId();
      print('CRITICAL: User signed out successfully');
    } catch (e) {
      print('CRITICAL ERROR: Error signing out: $e');
      throw e;
    }
  }

  String? getCurrentUserUid() {
    final user = _auth.currentUser;
    return user?.uid;
  }

  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();
}
