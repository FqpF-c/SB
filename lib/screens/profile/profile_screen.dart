import 'dart:io';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../screens/auth/login_screen.dart';
import '../../providers/auth_provider.dart' as app_auth;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    // Draw concentric circles
    final centerX = size.width * 0.7;
    final centerY = size.height * 0.3;
    
    for (int i = 1; i <= 6; i++) {
      canvas.drawCircle(
        Offset(centerX, centerY),
        20.0 * i,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();

  int selectedProfileImage = 1;
  String? profileImageUrl;
  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => isLoading = true);

      // Get the auth provider
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Get user data from provider
      final userData = await authProvider.getCurrentUserData();
      
      if (userData == null) {
        throw Exception('User data not found');
      }
      
      if (mounted) {
        setState(() {
          this.userData = userData;
          profileImageUrl = userData['profilePicUrl'];
          // Get the selected profile image from user data
          selectedProfileImage = userData['selectedProfileImage'] ?? 1;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Error loading user data', isError: true);
      }
    }
  }

  Future<void> _updateProfilePicture(String source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => isLoading = true);

      // Get the auth provider
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Get current user from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User session not found');
      }
      
      // Get user data to find phone number
      final userData = await authProvider.getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }
      final phoneNumber = userData['phone_number'];

      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Use Firebase UID as document ID and clear selectedProfileImage when custom image is uploaded
      await FirebaseFirestore.instance
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(user.uid)  // Use Firebase UID as document ID
          .set({
            'phone_number': phoneNumber,
            'firebase_uid': user.uid,
            'profilePicUrl': downloadUrl,
            'selectedProfileImage': null, // Clear preset selection when custom image is uploaded
          }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          profileImageUrl = downloadUrl;
          selectedProfileImage = 0; // Reset to indicate custom image
          isLoading = false;
        });
        _showSnackBar('Profile picture updated successfully');
      }
    } catch (e) {
      print('Error updating profile picture: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showSnackBar('Failed to update profile picture', isError: true);
      }
    }
  }
  
  Future<void> _setPresetProfileImage(int imageNumber) async {
    try {
      // Get the auth provider
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Get current user from Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User session not found');
      }
      
      // Get user data to find phone number
      final userData = await authProvider.getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }
      final phoneNumber = userData['phone_number'];

      // Update Firestore with the new preset selection
      await FirebaseFirestore.instance
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(user.uid)
          .set({
            'phone_number': phoneNumber,
            'firebase_uid': user.uid,
            'selectedProfileImage': imageNumber,
            'profilePicUrl': null, // Clear custom image URL when preset is selected
          }, SetOptions(merge: true));

      setState(() {
        selectedProfileImage = imageNumber;
        profileImageUrl = null; // Clear custom image
        isLoading = false;
      });
      _showSnackBar('Profile picture updated successfully');
    } catch (e) {
      print('Error updating preset profile picture: $e');
      _showSnackBar('Failed to update profile picture', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // Profile illustration that matches the design
  Widget _buildProfileIllustration() {
    return Container(
      color: const Color(0xFFF8E1EC), // Light pink background
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Person silhouette
            Image.asset(
              'assets/profile_page/profile_icons/persona_avatar.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback icon if image isn't found
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFF4A148C), // Purple color
                    ),
                    // White shirt/collar dots
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          3,
                          (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          width: MediaQuery.of(context).size.width, // Ensure full width
          padding: const EdgeInsets.only(top: 24, bottom: 24), // Removed horizontal padding
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  "Choose Profile Picture",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Grid layout for profile images with padding to maintain spacing from edges
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16, // horizontal space
                    runSpacing: 16, // vertical space
                    children: List.generate(
                      7, // 7 profile images
                      (index) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _setPresetProfileImage(index + 1);
                        },
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selectedProfileImage == (index + 1)
                                  ? const Color(0xFFEC407A) // Highlight selected image
                                  : const Color(0xFFEC407A).withOpacity(0.3),
                              width: selectedProfileImage == (index + 1) ? 3 : 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/profile_page/profile_images/profile_${index + 1}.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person_rounded,
                                  size: 40,
                                  color: Colors.purple[900],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Custom image options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Divider(),
                      const SizedBox(height: 16),
                      const Text(
                        "Or upload a custom image",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Camera option
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _updateProfilePicture('camera');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8E1EC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 32,
                                    color: Color(0xFFEC407A),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Camera',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Gallery option
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              _updateProfilePicture('gallery');
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8E1EC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    size: 32,
                                    color: Color(0xFFEC407A),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Gallery',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String title, String value, dynamic icon) {
    // Determine which icon to use based on the title
    IconData iconData;
    
    switch (title) {
      case 'Phone Number':
        iconData = Icons.phone;
        break;
      case 'College':
        iconData = Icons.school;
        break;
      case 'Department':
        iconData = Icons.business;
        break;
      case 'Batch':
        iconData = Icons.groups;
        break;
      default:
        iconData = Icons.info;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 6),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color.fromRGBO(61, 21, 96, 1), // Changed to RGB 61, 21, 96
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color.fromRGBO(223, 103, 140, 0.1), // Changed to RGB 223 103 140 with 10% opacity
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color.fromRGBO(247, 239, 247, 0.4), // Changed to RGB 247 239 247
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(253, 244, 247, 1), // Changed to RGB 253 244 247
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: icon is IconData
                      ? Icon(
                          icon,
                          color: const Color(0xFFEC407A),
                          size: 24,
                        )
                      : icon is String
                          ? Image.asset(
                              icon,
                              width: 24,
                              height: 24,
                              color: const Color(0xFFEC407A),
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to Material icon
                                return Icon(
                                  iconData,
                                  color: const Color(0xFFEC407A),
                                  size: 24,
                                );
                              },
                            )
                          : Icon(
                              iconData,
                              color: const Color(0xFFEC407A),
                              size: 24,
                            ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black, // Changed to pure black
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSignOutDialog() {
    // Prevent showing dialog if already in process of logging out
    if (_isLoggingOut || isLoading) return;
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.logout_rounded, 
                color: Color(0xFFEC407A),
                size: 24,
              ),
              SizedBox(width: 10),
              Text('Sign Out'),
            ],
          ),
          content: Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Close dialog first to prevent context issues
                Navigator.pop(dialogContext);
                
                // Perform logout after dialog is closed
                _performSignOut();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFEC407A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSignOut() async {
    if (_isLoggingOut) return;
    
    try {
      // Set loading state first
      setState(() {
        _isLoggingOut = true;
        isLoading = true;
      });
      
      // Simple loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Signing out...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFEC407A),
        ),
      );
      
      // Get auth provider
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      
      // Sign out using the auth provider
      await authProvider.signOut();
      
      // Clear preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // Wait briefly to ensure logout processes complete
      await Future.delayed(Duration(milliseconds: 300));
      
      // Only proceed if still mounted
      if (!mounted) return;
      
      // Navigate to login screen, removing all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      
      // Reset state if still mounted
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
          isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildProfileImage() {
    // Priority: Custom uploaded image > Preset selected image > Default fallback
    if (profileImageUrl != null && profileImageUrl!.isNotEmpty) {
      // Show custom uploaded image
      return Image.network(
        profileImageUrl!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // If custom image fails to load, fall back to preset
          return _buildPresetImage();
        },
      );
    } else {
      // Show preset image
      return _buildPresetImage();
    }
  }

  Widget _buildPresetImage() {
    // Use the selectedProfileImage value (1-based)
    final imageIndex = selectedProfileImage > 0 ? selectedProfileImage : 1;
    
    return Image.asset(
      'assets/profile_page/profile_images/profile_$imageIndex.png',
      width: 140,
      height: 140,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Final fallback if preset image also fails
        return _buildProfileIllustration();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEC407A),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // Remove any appbar to allow full scrolling
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Pink header with curved bottom and profile cutout as a SliverAppBar
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: false, // Set to false to completely hide when scrolling
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Stack(
  clipBehavior: Clip.none,
  alignment: Alignment.bottomCenter,
  children: [
    // Main pink header with pattern
    Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Color.fromRGBO(223, 103, 140, 1),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(55),
            bottomRight: Radius.circular(55),
          ),
        ),
        child: Stack(
          children: [
            // Curved pattern overlay
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                height: 170,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Image.asset(
                    'assets/profile_page/Profile_design.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topRight,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),

    // Back button (unchanged)
    Positioned(
      top: 40,
      left: 16,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: (){},
      ),
    ),

    // ✅ Settings button — TOP RIGHT
    Positioned(
      top: 40,
      right: 16,
      child: IconButton(
        icon: const Icon(Icons.settings, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      ),
    ),

    // Profile image “notch” (unchanged)
    Positioned(
      bottom: -70,
      child: GestureDetector(
        onTap: _showImagePickerOptions,
        child: Container(
          width: 155,
          height: 155,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color.fromRGBO(255, 207, 222, 1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            color: const Color(0xFFF8E1EC),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(70),
            child: _buildProfileImage(),
          ),
        ),
      ),
    ),
  ],
),

          ),
          
          // Main content
          SliverList(
            delegate: SliverChildListDelegate([
              // Create a GestureDetector to wrap both the profile image space and name/email area
              Column(
                children: [
                  // Add spacing to account for the profile image
                  const SizedBox(height: 80),
                  
                  // Profile info without card - directly below profile picture
                  Container(
                    margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Text(
                          userData?['username'] ?? 'User Name',
                          style: GoogleFonts.roboto(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF4A148C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userData?['email'] ?? 'user@example.com',
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 5),
              
              // User Info Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Phone Number
                    _buildInfoItem(
                      'Phone Number',
                      userData?['phone_number'] ?? '+910000000000',
                      "assets/profile_page/profile_icons/phonenumber_icon.png",
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // College
                    _buildInfoItem(
                      'College',
                      userData?['college'] ?? 'Not specified',
                      "assets/profile_page/profile_icons/college_icon.png",
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Department
                    _buildInfoItem(
                      'Department',
                      userData?['department'] ?? 'Not specified',
                      "assets/profile_page/profile_icons/department_icon.png",
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Batch
                    _buildInfoItem(
                      'Batch',
                      userData?['batch'] ?? 'Not specified',
                      "assets/profile_page/profile_icons/baatch_icon.png",
                    ),
                    
                    const SizedBox(height: 20),
                                
                    // Email Verification
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, bottom: 12),
                          child: Text(
                            'Email Verification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color.fromRGBO(61, 21, 96, 1),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color.fromRGBO(223, 103, 140, 0.2),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color.fromRGBO(247, 239, 247, 1),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Status indicator at the top with light gray background
                              Padding(
                                padding: const EdgeInsets.fromLTRB(0.5, 5, 0.5, 0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100], // Very light gray background
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end, // Align to the right
                                      children: [
                                        // X icon with light pink circular background
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFCE4EC), // Very light pink
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.close,
                                              size: 14,
                                              color: Color(0xFFE53935), // Red
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 12), // Space between icon and text
                                        
                                        // "Not yet Verified" text
                                        const Text(
                                          'Not yet Verified',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color.fromRGBO(61, 21, 96, 1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Explanatory text with decreased vertical and horizontal padding
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                child: Text(
                                  'You will be approved once our faculty reviews it, usually within a week!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Color.fromRGBO(61, 21, 96, 0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                                
                    const SizedBox(height: 60),
                                
                    // Log Out Button
                    Center(
                      child: Container(
                        width: 160, // Fixed smaller width
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: ElevatedButton(
                          onPressed: () => _showSignOutDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF1F6), // Light pink background
                            foregroundColor: const Color(0xFFDF678C), // Pink accent color
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            minimumSize: const Size(0, 48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30), // Pill shape
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFDF678C),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Log Out',
                                style: TextStyle(
                                  color: Color(0xFFDF678C),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}