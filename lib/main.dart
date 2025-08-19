import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:permission_handler/permission_handler.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'navbar/navbar.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/lead_provider.dart';
import 'theme/default_theme.dart';
import 'firebase_options.dart';
import 'secure_storage.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Firebase App Check
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    webProvider: ReCaptchaV3Provider(
        'recaptcha-v3-site-key'), // Replace with real site key if used
  );

  // ✅ Initialize Local Notifications
  await NotificationService.initialize();

  // ✅ Request notification permission (Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ProgressProvider()),
        ChangeNotifierProvider(create: (_) => LeadProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Skill Bench',
          theme: AppTheme.defaultTheme,
          // ✅ Change this to `NotificationTestScreen` for testing notifications:
          home: const AuthCheckScreen(),
          // ✅ Later, change back to real app flow:
          // home: const AuthCheckScreen(),
        );
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
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
      // ✅ Migrate SharedPreferences to secure storage
      await SecureStorage.migrateFromSharedPreferences([
        'phone_number',
        'is_logged_in',
      ]);

      final prefs = await SharedPreferences.getInstance();
      final isFirstTime = prefs.getBool('first_time') ?? true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Add timeout and better error handling for login check
      bool userLoggedIn = false;
      try {
        userLoggedIn = await authProvider.isUserLoggedIn().timeout(
          Duration(seconds: 10), // 10 second timeout
          onTimeout: () {
            print('Login check timed out, checking secure storage directly');
            // If network is slow, check secure storage directly
            return _checkSecureStorageDirectly();
          },
        );
      } catch (e) {
        print('Error checking login status: $e');
        userLoggedIn = await _checkSecureStorageDirectly();
      }

      if (mounted) {
        setState(() {
          _isFirstTime = isFirstTime;
          _isLoggedIn = userLoggedIn;
          _isLoading = false;
        });
      }

      if (isFirstTime) {
        await prefs.setBool('first_time', false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        });
      } else {
        if (userLoggedIn) {
          // Try to load additional data, but don't fail if it doesn't work
          try {
            await authProvider.checkStreakStatusAndNotify();
            Provider.of<ProgressProvider>(context, listen: false)
                .loadAllProgress();
          } catch (e) {
            print('Error loading additional data: $e');
            // Continue anyway
          }

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const NavBar()),
            );
          }
        } else {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        }
      }
    } catch (e) {
      print('ERROR in _checkFirstTime: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  Future<bool> _checkSecureStorageDirectly() async {
    try {
      final isLoggedIn = await SecureStorage.read('is_logged_in') == 'true';
      final phoneNumber = await SecureStorage.read('phone_number');
      return isLoggedIn && phoneNumber != null;
    } catch (e) {
      print('Error checking secure storage directly: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _isFirstTime ? const CustomSplashScreen() : const LoginScreen();
  }
}
