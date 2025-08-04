import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../lib/main.dart';
import '../lib/providers/auth_provider.dart';
import '../lib/providers/theme_provider.dart';
import '../lib/providers/progress_provider.dart';
import '../lib/providers/lead_provider.dart';

void main() {
  testWidgets('SkillBench app smoke test', (WidgetTester tester) async {

    await tester.pumpWidget(
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

    // Verify that the MaterialApp is created
    expect(find.byType(MaterialApp), findsOneWidget);
    
    // Verify that ScreenUtilInit is present (for responsive design)
    expect(find.byType(ScreenUtilInit), findsOneWidget);
    
    // Verify that AuthCheckScreen is the initial screen
    expect(find.byType(AuthCheckScreen), findsOneWidget);
    
    // Since AuthCheckScreen shows loading initially, verify CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('MyApp widget creates MaterialApp with correct properties', (WidgetTester tester) async {
    // Test just the MyApp widget without providers
    await tester.pumpWidget(
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

    // Find the MaterialApp widget
    final materialAppFinder = find.byType(MaterialApp);
    expect(materialAppFinder, findsOneWidget);

    // Get the MaterialApp widget to check its properties
    final MaterialApp materialApp = tester.widget(materialAppFinder);
    
    // Verify app properties
    expect(materialApp.debugShowCheckedModeBanner, false);
    expect(materialApp.title, 'Skill Bench');
    expect(materialApp.home, isA<AuthCheckScreen>());
  });
}