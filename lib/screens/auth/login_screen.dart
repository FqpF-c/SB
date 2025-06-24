import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../../providers/auth_provider.dart';
import '../../services/otp_service.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _countryCode = '+91';
  bool _isLoading = false;
  
  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onCountryChanged(CountryCode code) {
    setState(() {
      _countryCode = code.dialCode ?? '+91';
    });
  }

  Future<void> _sendOTP() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phoneNumber = '$_countryCode${_phoneController.text.trim()}';
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final userExists = await authProvider.checkIfUserExists(phoneNumber);
      
      await OTPService().sendOTPWithCallback(
        phoneNumber: phoneNumber,
        onSuccess: () {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
          });
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OTPScreen(
                phoneNumber: phoneNumber,
                userExists: userExists,
              ),
            ),
          );
        },
        onError: (error) {
          if (!mounted) return;
          
          setState(() {
            _isLoading = false;
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
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 50.w,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: const Color(0xFF3D1560),
            size: 20.sp,
          ),
          onPressed: () {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 30.h),
                Text(
                  'Enter Phone Number',
                  style: GoogleFonts.roboto(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF3D1560),
                  ),
                ),
                SizedBox(height: 80.h),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5.r),
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: _onCountryChanged,
                        initialSelection: 'IN',
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        padding: EdgeInsets.zero,
                        textStyle: GoogleFonts.roboto(
                          fontSize: 16.sp,
                          color: Colors.black,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          style: GoogleFonts.roboto(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: '1234567890',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              color: Colors.grey,
                            ),
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(horizontal: 10.w),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 15.h),
                Text(
                  "We'll Send you a code by SMS to confirm your phone number.",
                  style: GoogleFonts.roboto(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 30.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDF678C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.0,
                            ),
                          )
                        : Text(
                            'Send OTP',
                            style: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const Spacer(),
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 20.h),
                    child: Text(
                      'By continuing, you agree to our terms of service\nand privacy policy',
                      style: GoogleFonts.roboto(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}