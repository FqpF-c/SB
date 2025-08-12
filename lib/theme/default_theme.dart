import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppTheme {
  // Primary and secondary colors
  static const Color primaryColor = Color(0xFF3D1560);
  static const Color secondaryColor = Color(0xFFDF678C);

  // Background colors
  static const Color backgroundColor = Colors.white;
  static const Color lightPurpleBackground = Color(0xFFF9F1FF);

  // Text colors
  static const Color textPrimaryColor = Color(0xFF3D1560);
  static const Color textSecondaryColor = Color(0xFFDF678C);
  static const Color textDarkColor = Color(0xFF333333);
  static const Color textLightColor = Color(0xFF767676);

  // Accent colors
  static const Color accentColor = Color(0xFFE37A8E); // Slightly lighter pink
  static const Color highlightColor = Color(0xFFF5EEFB); // Very light purple

  // Button variants
  static final Color primaryButtonColor = secondaryColor;
  static final Color secondaryButtonColor = primaryColor;
  static final Color disabledButtonColor = Colors.grey.shade400;

  // Border colors
  static final Color borderColor = Colors.grey.shade300;

  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color infoColor = Color(0xFF2196F3);

  // Get default theme data
  static ThemeData get defaultTheme {
    return ThemeData(
      // Base colors
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // Color scheme
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textDarkColor,
        error: errorColor,
        onError: Colors.white,
      ),
      useMaterial3: true,

      // Typography - using Roboto from Google Fonts
      textTheme: GoogleFonts.robotoTextTheme().copyWith(
        displayLarge: GoogleFonts.roboto(
          fontSize: 28.sp,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displayMedium: GoogleFonts.roboto(
          fontSize: 24.sp,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displaySmall: GoogleFonts.roboto(
          fontSize: 20.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        headlineMedium: GoogleFonts.roboto(
          fontSize: 18.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        headlineSmall: GoogleFonts.roboto(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        titleLarge: GoogleFonts.roboto(
          fontSize: 16.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        titleMedium: GoogleFonts.roboto(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        titleSmall: GoogleFonts.roboto(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        bodyLarge: GoogleFonts.roboto(
          fontSize: 16.sp,
          fontWeight: FontWeight.normal,
          color: textDarkColor,
        ),
        bodyMedium: GoogleFonts.roboto(
          fontSize: 14.sp,
          fontWeight: FontWeight.normal,
          color: textDarkColor,
        ),
        bodySmall: GoogleFonts.roboto(
          fontSize: 12.sp,
          fontWeight: FontWeight.normal,
          color: textLightColor,
        ),
        labelLarge: GoogleFonts.roboto(
          fontSize: 14.sp,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),

      // App bar theme
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 18.sp,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        iconTheme: const IconThemeData(
          color: primaryColor,
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButtonColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: 12.h,
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
          minimumSize: Size(double.infinity, 50.h),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 24.w,
            vertical: 12.h,
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
          minimumSize: Size(double.infinity, 50.h),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 8.h,
          ),
          textStyle: GoogleFonts.roboto(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 14.h,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: errorColor, width: 1.5),
        ),
        hintStyle: GoogleFonts.roboto(
          fontSize: 16.sp,
          color: Colors.grey,
        ),
        errorStyle: GoogleFonts.roboto(
          fontSize: 12.sp,
          color: errorColor,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12.r)),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 8.h,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12.sp,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Chip theme
      chipTheme: ChipThemeData(
        backgroundColor: highlightColor,
        disabledColor: Colors.grey.shade200,
        selectedColor: primaryColor,
        secondarySelectedColor: secondaryColor,
        padding: EdgeInsets.symmetric(
          horizontal: 12.w,
          vertical: 8.h,
        ),
        labelStyle: GoogleFonts.roboto(
          fontSize: 14.sp,
          color: textPrimaryColor,
        ),
        secondaryLabelStyle: GoogleFonts.roboto(
          fontSize: 14.sp,
          color: Colors.white,
        ),
      ),

      // Dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        contentTextStyle: GoogleFonts.roboto(
          fontSize: 16.sp,
          color: textDarkColor,
        ),
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDarkColor,
        contentTextStyle: GoogleFonts.roboto(
          fontSize: 14.sp,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Progress indicator theme
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondaryColor,
        circularTrackColor: highlightColor,
        linearTrackColor: highlightColor,
      ),

      // Divider theme
      dividerTheme: DividerThemeData(
        color: borderColor,
        thickness: 1,
        space: 24.h,
      ),

      // Checkbox theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          return primaryColor;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.r),
        ),
      ),

      // Radio theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          return primaryColor;
        }),
      ),

      // Switch theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade400;
          }
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return Colors.white;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return Colors.grey.shade300;
          }
          if (states.contains(WidgetState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return Colors.grey.shade300;
        }),
      ),
    );
  }
}
