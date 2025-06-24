import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sms_autofill/sms_autofill.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../providers/auth_provider.dart';
import '../../services/otp_service.dart';
import 'signup_screen.dart';
import '../../navbar/navbar.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final bool userExists;

  const OTPScreen({
    Key? key,
    required this.phoneNumber,
    required this.userExists,
  }) : super(key: key);

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _enableResend = false;
  String _errorMessage = '';
  bool _hasError = false;
  bool _isAuthenticating = false;
  
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _setupSmsListener();
  }
  
  void _setupSmsListener() async {
    try {
      await SmsAutoFill().listenForCode();
      
      _subscription = SmsAutoFill().code.listen((code) {
        if (!mounted) return;
        
        setState(() {
          _otpController.text = code;
        });
        
        if (code.length == 6 && !_isLoading && !_isAuthenticating) {
          _verifyOTP();
        }
      }, onError: (error) {
        
      });
    } catch (e) {
      
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _enableResend = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    
    if (_subscription != null) {
      _subscription!.cancel();
    }
    
    try {
      SmsAutoFill().unregisterListener();
    } catch (e) {
      
    }
    
    super.dispose();
  }

  void _handleNavigation() {
    if (!mounted) return;
      
    if (widget.userExists) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const NavBar()),
        (route) => false,
      );
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => 
            SignupScreen(phoneNumber: widget.phoneNumber),
          transitionDuration: Duration.zero,
        ),
        (route) => false,
      );
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    
    if (otp.length != 6) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Please enter a valid 6-digit OTP';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isAuthenticating = true;
      _hasError = false;
      _errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      await OTPService().verifyOTPWithCallback(
        otp: otp,
        onSuccess: () async {
          if (!mounted) return;
          
          try {
            await authProvider.setLoggedIn(widget.phoneNumber);
            
            if (!mounted) return;
            
            setState(() {
              _isLoading = false;
            });
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _handleNavigation();
            });
          } catch (e) {
            if (!mounted) return;
            
            setState(() {
              _isLoading = false;
              _isAuthenticating = false;
              _hasError = true;
              _errorMessage = 'Error updating login status. Please try again.';
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error updating login status. Please try again.')),
            );
          }
        },
        onError: (error) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
            _isAuthenticating = false;
            _hasError = true;
            _errorMessage = error;
          });
          
          _otpController.clear();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $error'),
              duration: Duration(seconds: 4),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _isAuthenticating = false;
        _hasError = true;
        _errorMessage = 'Verification failed. Please try again.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification failed. Please try again.')),
      );
    }
  }

  Future<void> _resendOTP() async {
    if (!mounted || !_enableResend) return;
    
    setState(() {
      _isLoading = true;
      _enableResend = false;
      _secondsRemaining = 30;
      _hasError = false;
      _errorMessage = '';
      _otpController.clear();
    });
    
    try {
      try {
        SmsAutoFill().unregisterListener();
        if (_subscription != null) {
          _subscription!.cancel();
          _subscription = null;
        }
      } catch (e) {
        
      }
      
      await OTPService().sendOTPWithCallback(
        phoneNumber: widget.phoneNumber,
        onSuccess: () {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP sent successfully')),
          );
          
          _startTimer();
          _setupSmsListener();
        },
        onError: (error) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
            _enableResend = true;
            _hasError = true;
            _errorMessage = error;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sending OTP: $error')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _enableResend = true;
        _hasError = true;
        _errorMessage = 'Failed to send OTP. Please try again.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send OTP. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isAuthenticating;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 50.w,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: Colors.grey.shade600,
              size: 20.sp,
            ),
            onPressed: _isAuthenticating ? null : () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 
                  MediaQuery.of(context).padding.top - 
                  kToolbarHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 20.h),
                  Text(
                    'We have sent a verification code to',
                    style: GoogleFonts.roboto(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.phoneNumber,
                    style: GoogleFonts.roboto(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 30.h),
                  Text(
                    'OTP Verification',
                    style: GoogleFonts.roboto(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF3D1560),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  
                  Container(
                    margin: EdgeInsets.only(bottom: 15.h),
                    padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EEFB),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Please enter the 6-digit code sent to your phone',
                      style: GoogleFonts.roboto(
                        fontSize: 14.sp,
                        color: const Color(0xFF3D1560),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  if (_hasError && _errorMessage.isNotEmpty)
                    Container(
                      margin: EdgeInsets.only(bottom: 15.h),
                      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: Text(
                        _errorMessage,
                        style: GoogleFonts.roboto(
                          fontSize: 14.sp,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    child: PinCodeTextField(
                      appContext: context,
                      length: 6,
                      controller: _otpController,
                      enableActiveFill: true,
                      autoFocus: true,
                      autoDisposeControllers: false,
                      enabled: !_isAuthenticating,
                      keyboardType: TextInputType.number,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8.r),
                        fieldHeight: 45.h,
                        fieldWidth: 45.w,
                        activeFillColor: Colors.white,
                        inactiveFillColor: Colors.white,
                        selectedFillColor: Colors.white,
                        activeColor: _hasError ? Colors.red : const Color(0xFF3D1560),
                        inactiveColor: _hasError ? Colors.red.shade300 : Colors.grey.shade300,
                        selectedColor: _hasError ? Colors.red : const Color(0xFF3D1560),
                      ),
                      textStyle: GoogleFonts.roboto(
                        fontSize: 18.sp,
                        color: const Color(0xFF3D1560),
                      ),
                      onChanged: (value) {
                        if (_hasError && mounted) {
                          setState(() {
                            _hasError = false;
                          });
                        }
                      },
                      onCompleted: (value) {
                        if (mounted && !_isLoading && !_isAuthenticating) {
                          _verifyOTP();
                        }
                      },
                    ),
                  ),
                  SizedBox(height: 30.h),
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _isAuthenticating) ? null : _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDF678C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        elevation: 0,
                      ),
                      child: (_isLoading || _isAuthenticating)
                          ? SizedBox(
                              width: 20.w,
                              height: 20.h,
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.0,
                              ),
                            )
                          : Text(
                              'Verify and Proceed',
                              style: GoogleFonts.roboto(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  TextButton(
                    onPressed: (_isLoading || !_enableResend || _isAuthenticating) ? null : _resendOTP,
                    child: Text(
                      "Didn't receive the OTP? Resend",
                      style: GoogleFonts.roboto(
                        fontSize: 14.sp,
                        color: (_isLoading || !_enableResend || _isAuthenticating) 
                            ? Colors.grey.shade400 
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  if (!_enableResend && !_isAuthenticating)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5EEFB),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16.sp,
                            color: const Color(0xFF3D1560),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'Wait ${_secondsRemaining} seconds',
                            style: GoogleFonts.roboto(
                              fontSize: 12.sp,
                              color: const Color(0xFF3D1560),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (_isAuthenticating)
                    Container(
                      margin: EdgeInsets.only(top: 20.h),
                      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF351C59).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.w,
                              valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF351C59)),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Verifying and redirecting...',
                            style: GoogleFonts.roboto(
                              fontSize: 14.sp,
                              color: const Color(0xFF351C59),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}