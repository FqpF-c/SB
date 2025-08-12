import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../navbar/navbar.dart';

class SignupScreen extends StatefulWidget {
  final String phoneNumber;

  const SignupScreen({
    Key? key,
    required this.phoneNumber,
  }) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedCollege;
  String? _selectedDepartment;
  String? _selectedBatch;
  String? _selectedGender;
  int _selectedProfilePic = -1;

  List<String> _collegesList = [];
  List<String> _departmentsList = [];
  List<String> _batchesList = [];
  String? _emailSuffix;

  bool _isLoading = false;
  bool _isLoadingColleges = true;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _getGenderFromProfilePic() {
    switch (_selectedProfilePic) {
      case 0:
        return 'female';
      case 1:
        return 'male';
      case 2:
        return 'prefer_not_to_say';
      default:
        return 'other';
    }
  }

  String _getCompleteEmail() {
    final emailPrefix = _emailController.text.trim();
    if (emailPrefix.isEmpty || _emailSuffix == null) {
      return emailPrefix;
    }
    return '$emailPrefix$_emailSuffix';
  }

  Future<void> _loadColleges() async {
    setState(() {
      _isLoadingColleges = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('skillbench')
          .doc('login_credentials')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data.containsKey('colleges')) {
          if (mounted) {
            setState(() {
              _collegesList = [
                'No Organization',
                ...List<String>.from(data['colleges'])
              ];
              _isLoadingColleges = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoadingColleges = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingColleges = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingColleges = false;
        });
      }
    }
  }

  Future<void> _loadCollegeData() async {
    if (_selectedCollege == null) return;

    setState(() {
      _isLoading = true;
      _departmentsList = [];
      _batchesList = [];
      _emailSuffix = null;
      _emailController.clear();
    });

    if (_selectedCollege == 'No Organization') {
      if (mounted) {
        setState(() {
          _departmentsList = ['No Organization'];
          _batchesList = ['No Organization'];
          _emailSuffix = null;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('skillbench')
          .doc('login_credentials')
          .collection(_selectedCollege!)
          .doc('data')
          .get();

      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          if (mounted) {
            setState(() {
              if (data.containsKey('departments')) {
                _departmentsList = List<String>.from(data['departments']);
              }

              if (data.containsKey('batches')) {
                _batchesList = List<String>.from(data['batches']);
              }

              if (data.containsKey('ends_with')) {
                _emailSuffix = data['ends_with'];
              }

              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProfilePic < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a profile picture')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final college = _selectedCollege == 'No Organization' ? null : _selectedCollege;
      final department = _selectedDepartment == 'No Organization' ? null : _selectedDepartment;
      final batch = _selectedBatch == 'No Organization' ? null : _selectedBatch;
      final email = _selectedCollege == 'No Organization' ? null : _getCompleteEmail();

      final userData = {
        'username': _nameController.text.trim(),
        'college': college,
        'email': email,
        'department': department,
        'batch': batch,
        'phone_number': widget.phoneNumber,
        'gender': _getGenderFromProfilePic(),
        'profile_pic_type': _selectedProfilePic,
        'selectedProfileImage': _selectedProfilePic + 1,
        'profilePicUrl': null,
        'total_request': {
          'practice_mode': 0,
          'test_mode': 0,
        },
      };

      await authProvider.registerUser(userData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavBar()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildProfilePicSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a Profile Picture',
          style: GoogleFonts.roboto(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF3D1560),
          ),
        ),
        SizedBox(height: 15.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedProfilePic = 0;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 85.w,
                    height: 85.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedProfilePic == 0
                            ? const Color(0xFFDF678C)
                            : Colors.transparent,
                        width: 3.w,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(85.w),
                      child: Image.asset(
                        'assets/profile_page/profile_images/profile_6.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF9F1FF),
                            child: Icon(
                              Icons.person_rounded,
                              size: 60.sp,
                              color: const Color(0xFFDF678C),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Female',
                    style: GoogleFonts.roboto(
                      fontSize: 12.sp,
                      color: _selectedProfilePic == 0
                          ? const Color(0xFF3D1560)
                          : Colors.grey.shade600,
                      fontWeight: _selectedProfilePic == 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedProfilePic = 1;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 85.w,
                    height: 85.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedProfilePic == 1
                            ? const Color(0xFFDF678C)
                            : Colors.transparent,
                        width: 3.w,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(85.w),
                      child: Image.asset(
                        'assets/profile_page/profile_images/profile_7.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF9F1FF),
                            child: Icon(
                              Icons.person_rounded,
                              size: 60.sp,
                              color: const Color(0xFF3D1560),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Male',
                    style: GoogleFonts.roboto(
                      fontSize: 12.sp,
                      color: _selectedProfilePic == 1
                          ? const Color(0xFF3D1560)
                          : Colors.grey.shade600,
                      fontWeight: _selectedProfilePic == 1
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedProfilePic = 2;
                });
              },
              child: Column(
                children: [
                  Container(
                    width: 85.w,
                    height: 85.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _selectedProfilePic == 2
                            ? const Color(0xFFDF678C)
                            : Colors.transparent,
                        width: 3.w,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(85.w),
                      child: Image.asset(
                        'assets/profile_page/profile_images/profile_0.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFFF9F1FF),
                            child: Icon(
                              Icons.smart_toy_rounded,
                              size: 60.sp,
                              color: Colors.deepPurple,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Prefer Not to Say',
                    style: GoogleFonts.roboto(
                      fontSize: 12.sp,
                      color: _selectedProfilePic == 2
                          ? const Color(0xFF3D1560)
                          : Colors.grey.shade600,
                      fontWeight: _selectedProfilePic == 2
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F1FF),
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
        title: Text(
          'Create Account',
          style: GoogleFonts.roboto(
            fontSize: 18.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF3D1560),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                color: const Color(0xFFF9F1FF),
                height: 100.h,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20.h),
                        Text(
                          'Complete Your Profile',
                          style: GoogleFonts.roboto(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFDF678C),
                          ),
                        ),
                        SizedBox(height: 20.h),

                        _buildProfilePicSelector(),

                        SizedBox(height: 30.h),

                        Text(
                          'Full Name',
                          style: GoogleFonts.roboto(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF3D1560),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.roboto(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter Your Full Name',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: const Color(0xFF3D1560)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20.h),

                        Text(
                          'College',
                          style: GoogleFonts.roboto(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF3D1560),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: _selectedCollege,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Select Your College',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: const Color(0xFF3D1560)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          ),
                          style: GoogleFonts.roboto(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                          items: _isLoadingColleges
                              ? [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Loading colleges...',
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                ]
                              : _collegesList.map((String college) {
                                  return DropdownMenuItem<String>(
                                    value: college,
                                    child: Text(college),
                                  );
                                }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedCollege = newValue;
                              _selectedDepartment = null;
                              _selectedBatch = null;
                            });
                            _loadCollegeData();
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your college';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20.h),

                        Text(
                          'Organization Email',
                          style: GoogleFonts.roboto(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF3D1560),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.roboto(
                                  fontSize: 16.sp,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: _selectedCollege == null
                                      ? 'Select college first'
                                      : 'Enter email prefix',
                                  hintStyle: GoogleFonts.roboto(
                                    fontSize: 16.sp,
                                    color: Colors.grey,
                                  ),
                                  filled: true,
                                  fillColor: _selectedCollege == null
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8.r),
                                      bottomLeft: Radius.circular(8.r),
                                    ),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8.r),
                                      bottomLeft: Radius.circular(8.r),
                                    ),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8.r),
                                      bottomLeft: Radius.circular(8.r),
                                    ),
                                    borderSide: BorderSide(color: const Color(0xFF3D1560)),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                                ),
                                enabled: _selectedCollege != null &&
                                    (_selectedCollege == 'No Organization' || _emailSuffix != null),
                                validator: (value) {
                                  if (_selectedCollege == null) {
                                    return 'Please select your college first';
                                  }
                                  if (_selectedCollege == 'No Organization') {
                                    return null;
                                  }
                                  if (_emailSuffix == null) {
                                    return 'Email domain not available for selected college';
                                  }
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email prefix';
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
                                    return 'Invalid email format. Use only letters, numbers, dots, and underscores';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() {});
                                },
                              ),
                            ),

                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 50.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(8.r),
                                    bottomRight: Radius.circular(8.r),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _selectedCollege == 'No Organization'
                                        ? 'No Email'
                                        : (_emailSuffix ?? '@organization.edu'),
                                    style: GoogleFonts.roboto(
                                      fontSize: 14.sp,
                                      color: _selectedCollege == 'No Organization'
                                          ? Colors.grey
                                          : (_emailSuffix != null ? Colors.black87 : Colors.grey),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (_emailController.text.isNotEmpty &&
                            _emailSuffix != null &&
                            _selectedCollege != 'No Organization')
                          Padding(
                            padding: EdgeInsets.only(top: 8.h, left: 16.w),
                            child: Text(
                              'Complete email: ${_getCompleteEmail()}',
                              style: GoogleFonts.roboto(
                                fontSize: 12.sp,
                                color: const Color(0xFF3D1560),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                        SizedBox(height: 20.h),

                        Text(
                          'Department',
                          style: GoogleFonts.roboto(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF3D1560),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: _selectedDepartment,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Select Your Department',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: const Color(0xFF3D1560)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          ),
                          style: GoogleFonts.roboto(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                          items: _selectedCollege == null
                              ? [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Select college first',
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                ]
                              : _departmentsList.map((String department) {
                                  return DropdownMenuItem<String>(
                                    value: department,
                                    child: Text(department),
                                  );
                                }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDepartment = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your department';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20.h),

                        Text(
                          'Batch',
                          style: GoogleFonts.roboto(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF3D1560),
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: _selectedBatch,
                          isExpanded: true,
                          decoration: InputDecoration(
                            hintText: 'Select Your Batch',
                            hintStyle: GoogleFonts.roboto(
                              fontSize: 16.sp,
                              color: Colors.grey,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: const Color(0xFF3D1560)),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                          ),
                          style: GoogleFonts.roboto(
                            fontSize: 16.sp,
                            color: Colors.black,
                          ),
                          items: _selectedCollege == null
                              ? [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Select college first',
                                      style: GoogleFonts.roboto(
                                        fontSize: 16.sp,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                ]
                              : _batchesList.map((String batch) {
                                  return DropdownMenuItem<String>(
                                    value: batch,
                                    child: Text(batch),
                                  );
                                }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBatch = newValue;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your batch';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 40.h),

                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDF678C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    'Register Now',
                                    style: GoogleFonts.roboto(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 30.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            top: 10.h,
            right: 20.w,
            child: SizedBox(
              height: 90.h,
              child: Image.asset(
                'assets/images/atom_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 80.w,
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F1FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.science,
                      size: 40.sp,
                      color: const Color(0xFF3D1560),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}