import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Utility class for managing dynamic status bar behavior
class DynamicStatusBar {
  static const double _defaultScrollThreshold = 100.0;

  /// Creates a scroll listener that dynamically changes the status bar
  /// based on scroll position
  static VoidCallback createScrollListener({
    required ScrollController scrollController,
    Color primaryColor = const Color(0xFFdf678c),
    Color? transparentIconBrightness,
    double scrollThreshold = _defaultScrollThreshold,
  }) {
    return () {
      final offset = scrollController.offset;

      if (offset > scrollThreshold) {
        // When scrolled down, make status bar transparent
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: transparentIconBrightness == null
              ? Brightness.dark
              : _getBrightness(transparentIconBrightness),
        ));
      } else {
        // When at top, keep primary color status bar
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: primaryColor,
          statusBarIconBrightness: _getBrightness(primaryColor),
        ));
      }
    };
  }

  /// Initializes the status bar with a primary color
  static void initialize({
    Color primaryColor = const Color(0xFFdf678c),
  }) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: primaryColor,
      statusBarIconBrightness: _getBrightness(primaryColor),
    ));
  }

  /// Determines the appropriate brightness for status bar icons based on background color
  static Brightness _getBrightness(Color backgroundColor) {
    // Calculate luminance to determine if we need light or dark icons
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Brightness.dark : Brightness.light;
  }

  /// Sets up a scaffold with dynamic status bar support
  static Widget buildDynamicScaffold({
    required Widget body,
    Color backgroundColor = Colors.white,
    bool extendBodyBehindAppBar = true,
    bool safeAreaTop = false,
  }) {
    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: SafeArea(
        top: safeAreaTop,
        child: body,
      ),
    );
  }

  /// Adds status bar padding to a container for proper header positioning
  static EdgeInsets getStatusBarPadding(
    BuildContext context, {
    double additional = 16.0,
  }) {
    return EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + additional,
    );
  }
}

/// A mixin to easily add dynamic status bar functionality to StatefulWidgets
mixin DynamicStatusBarMixin<T extends StatefulWidget> on State<T> {
  late ScrollController _scrollController;
  late VoidCallback _scrollListener;

  Color get primaryColor => const Color(0xFFdf678c);
  Color? get transparentIconColor => null;
  double get scrollThreshold => 100.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollListener = DynamicStatusBar.createScrollListener(
      scrollController: _scrollController,
      primaryColor: primaryColor,
      transparentIconBrightness: transparentIconColor,
      scrollThreshold: scrollThreshold,
    );
    _scrollController.addListener(_scrollListener);

    // Initialize status bar
    DynamicStatusBar.initialize(primaryColor: primaryColor);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  ScrollController get scrollController => _scrollController;
}
