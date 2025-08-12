import 'package:flutter/material.dart';

/// Theme tokens and constants for the new leaderboard design
class SBColors {
  // Gradient colors
  static const Color gradientStart = Color(0xFFFF6B8B);
  static const Color gradientEnd = Color(0xFFEDA6B7);
  
  // Purple colors
  static const Color deepPurple = Color(0xFF3A226A);
  static const Color pillPurple = Color(0xFF4B2C80);
  
  // Pink colors
  static const Color softPink = Color(0xFFFBD4DD);
  
  // Basic colors
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF6B6B6B);
  
  // Points colors
  static const Color pointsBg = Color(0xFFEFE6FF);
  static const Color pointsText = Color(0xFF4B2C80);
  
  // Status colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
}

class SBRadii {
  static const double lg = 24.0;
  static const double md = 20.0;
  static const double sm = 12.0;
  static const double xs = 8.0;
}

class SBInsets {
  static const double h = 16.0;
  static const double v = 16.0;
  static const double sm = 8.0;
  static const double lg = 24.0;
}

class SBGap {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}

class SBTypography {
  // Title styles
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  
  // Section headers
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: SBColors.textPrimary,
  );
  
  // Body text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: SBColors.textPrimary,
  );
  
  // Small labels
  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: SBColors.textSecondary,
  );
  
  // Welcome hub title
  static const TextStyle welcomeTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  
  // Chip text
  static const TextStyle chip = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white,
  );
}

class SBElevation {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
  
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

class SBConstants {
  static const double headerHeight = 180.0;
  static const double statsCardOverlap = 40.0;
  static const double avatarSize = 36.0;
  static const double avatarSizeLarge = 54.0;
  static const double minTouchTarget = 48.0;
  static const int pageSize = 10;
  static const Duration animationDuration = Duration(milliseconds: 250);
  static const Duration staggerDelay = Duration(milliseconds: 150);
}