import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'navbar/navbar.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/lead_provider.dart'; // Add LeadProvider import
import 'theme/default_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Firebase App Check
  await FirebaseAppCheck.instance.activate(
    // For debug/development:
    androidProvider: AndroidProvider.debug,
    // For production (uncomment when ready for production):
    // androidProvider: AndroidProvider.playIntegrity,
    // iosProvider: IOSProvider.appAttest,
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'), // Replace with your actual site key
  );
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => LeadProvider()), // Add LeadProvider
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // Base design size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Skill Bench',
          theme: AppTheme.defaultTheme,
          home: const AuthCheckScreen(),
        );
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  _AuthCheckScreenState createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isFirstTime = true;
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    try {
      print('CRITICAL: Starting auth check');
      
      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('first_time') ?? true;
      
      print("CRITICAL: Auth check - First time: $isFirstTime");
      
      // For the new OTP system, check login status using AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final bool userLoggedIn = await authProvider.isUserLoggedIn();
      
      print("CRITICAL: User logged in status: $userLoggedIn");
      
      if (mounted) {
        setState(() {
          _isFirstTime = isFirstTime;
          _isLoggedIn = userLoggedIn;
          _isLoading = false;
        });
      }

      if (isFirstTime) {
        print('CRITICAL: First time user, showing splash');
        // Mark as not first time for future app opens
        await prefs.setBool('first_time', false);
        
        // Show splash screen for 3 seconds then navigate to login
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const LoginScreen())
            );
          }
        });
      } else {
        if (userLoggedIn) {
          if (mounted) {
            // Initialize progress provider when user is logged in
            Provider.of<ProgressProvider>(context, listen: false).loadProgressData();
            
            print("CRITICAL: User is logged in, navigating to NavBar");
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const NavBar())
            );
          }
        } else {
          if (mounted) {
            print("CRITICAL: User is not logged in, navigating to LoginScreen");
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const LoginScreen())
            );
          }
        }
      }
    } catch (e) {
      print('CRITICAL ERROR: Error in auth check: $e');
      
      // In case of error, default to login screen
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const LoginScreen())
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return _isFirstTime ? const CustomSplashScreen() : const LoginScreen();
  }
}