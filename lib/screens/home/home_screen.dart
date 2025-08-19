import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:math' show pi, cos, sin;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../secure_storage.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/home/ongoing_programs_widget.dart';
import '../../theme/default_theme.dart';
import '../../widgets/home/stats_row_widget.dart';
import '../../widgets/home/technologies_widget.dart';
import '../../widgets/home/programming_languages_widget.dart';
import '../../utils/dynamic_status_bar.dart';

class HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Color.fromRGBO(168, 130, 201, 0.452)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final centerX = size.width * 1.1;
    final centerY = size.height * 0.2;

    for (int i = 1; i <= 7; i++) {
      canvas.drawCircle(
        Offset(centerX, centerY),
        23.0 * i,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class CirclePatternPainter extends CustomPainter {
  final Color color;

  CirclePatternPainter({
    this.color = const Color.fromRGBO(100, 68, 128, 1),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topRight = Offset(size.width, 0);

    final paint1 = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      topRight,
      size.width * 0.9,
      paint1,
    );

    final paint2 = Paint()
      ..color = color.withOpacity(0.20)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      topRight,
      size.width * 0.7,
      paint2,
    );

    final paint3 = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      topRight,
      size.width * 0.5,
      paint3,
    );

    final paint4 = Paint()
      ..color = color.withOpacity(0.30)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      topRight,
      size.width * 0.3,
      paint4,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PentagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = size.width / 2;

    path.moveTo(centerX, 0);
    for (int i = 1; i <= 5; i++) {
      final angle = (i * 2 * pi / 5) - (pi / 2);
      final x = centerX + radius * cos(angle);
      final y = centerY + radius * sin(angle);
      path.lineTo(x, y);
    }

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, DynamicStatusBarMixin {
  String _username = '';
  int _coins = 0;
  int _streaks = 0;
  int _xp = 0;
  int _rankPosition = 24;
  int _completed = 2;
  int _studyHours = 128;
  bool _isLoading = true;

  List<String> _categoryTitles = [];
  Map<String, List<Map<String, dynamic>>> _categoryItems = {};

  late List<AnimationController> _shapeControllers;
  late List<Animation<double>> _shapeAnimations;

  static const Map<String, String> _topicAssetMap = {
    'c': 'assets/home_page/c.png',
    'c++': 'assets/home_page/cpp.png',
    'cpp': 'assets/home_page/cpp.png',
    'java': 'assets/home_page/java.png',
    'python': 'assets/home_page/python.png',
    'kotlin': 'assets/home_page/kotlin.png',
    'swift': 'assets/home_page/swift.png',
    'flutter': 'assets/home_page/flutter.png',
    'react': 'assets/home_page/react.png',
    'web development': 'assets/home_page/web_development.png',
    'web': 'assets/home_page/web_development.png',
    'aws': 'assets/home_page/aws.png',
    'amazon web services': 'assets/home_page/aws.png',
    'google cloud': 'assets/home_page/google-cloud.png',
    'gcp': 'assets/home_page/google-cloud.png',
    'azure': 'assets/home_page/azure.png',
    'microsoft azure': 'assets/home_page/azure.png',
    'excel': 'assets/home_page/excel.png',
    'microsoft excel': 'assets/home_page/excel.png',
    'css': 'assets/home_page/css.png',
    'css3': 'assets/home_page/css.png',
    'javascript': 'assets/home_page/javascript.png',
    'js': 'assets/home_page/javascript.png',
    'powerpoint': 'assets/home_page/powerpoint.png',
    'microsoft powerpoint': 'assets/home_page/powerpoint.png',
    'ppt': 'assets/home_page/powerpoint.png',
    'html': 'assets/home_page/html.png',
    'html5': 'assets/home_page/html.png',
    'react native': 'assets/home_page/react.png',
    'react-native': 'assets/home_page/react.png',
    'reactnative': 'assets/home_page/react.png',
  };

  @override
  void initState() {
    super.initState();

    _shapeControllers = List.generate(12, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 2000 + (index * 300)),
        vsync: this,
      )..repeat(reverse: true);
    });

    _shapeAnimations = _shapeControllers.map((controller) {
      return Tween<double>(begin: -10, end: 10).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    _loadData();
  }

  void _loadData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadUserData();
    await _loadCategoryTitles();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _shapeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _getAssetForTopic(String topicName) {
    final String normalizedName = topicName.toLowerCase().trim();

    if (_topicAssetMap.containsKey(normalizedName)) {
      return _topicAssetMap[normalizedName]!;
    }

    for (String key in _topicAssetMap.keys) {
      if (normalizedName.contains(key) || key.contains(normalizedName)) {
        return _topicAssetMap[key]!;
      }
    }

    return 'assets/icons/code_icon.png';
  }

  bool _assetExists(String assetPath) {
    try {
      return true;
    } catch (e) {
      print('Asset not found: $assetPath');
      return false;
    }
  }

  Color _getColorForTopic(String topicName) {
    final String normalizedName = topicName.toLowerCase().trim();

    const Map<String, Color> categoryColors = {
      'c': Color(0xFF5C6BC0),
      'c++': Color(0xFF42A5F5),
      'cpp': Color(0xFF42A5F5),
      'java': Color(0xFFEF5350),
      'python': Color(0xFF66BB6A),
      'kotlin': Color(0xFFAB47BC),
      'swift': Color(0xFFFF7043),
      'flutter': Color(0xFF29B6F6),
      'react native': Color(0xFF26C6DA),
      'react-native': Color(0xFF26C6DA),
      'reactnative': Color(0xFF26C6DA),
      'react': Color(0xFF26C6DA),
      'web development': Color(0xFF26A69A),
      'web': Color(0xFF26A69A),
      'aws': Color(0xFFFF9800),
      'amazon web services': Color(0xFFFF9800),
      'google cloud': Color(0xFF4285F4),
      'gcp': Color(0xFF4285F4),
      'azure': Color(0xFF0078D4),
      'microsoft azure': Color(0xFF0078D4),
      'excel': Color(0xFF4CAF50),
      'microsoft excel': Color(0xFF4CAF50),
      'css': Color(0xFF1572B6),
      'css3': Color(0xFF1572B6),
      'javascript': Color(0xFFF7DF1E),
      'js': Color(0xFFF7DF1E),
      'powerpoint': Color(0xFFB7472A),
      'microsoft powerpoint': Color(0xFFB7472A),
      'ppt': Color(0xFFB7472A),
      'html': Color(0xFFE34F26),
      'html5': Color(0xFFE34F26),
    };

    if (categoryColors.containsKey(normalizedName)) {
      return categoryColors[normalizedName]!;
    }

    for (String key in categoryColors.keys) {
      if (normalizedName.contains(key) || key.contains(normalizedName)) {
        return categoryColors[key]!;
      }
    }

    return const Color(0xFF366D9C);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'GOOD MORNING';
    } else if (hour < 17) {
      return 'GOOD AFTERNOON';
    } else {
      return 'GOOD EVENING';
    }
  }

  Future<void> _loadUserData() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final firestoreData = await authProvider.getCurrentUserData();
      final realtimeData = await authProvider.getUserStatsFromRealtimeDB();

      if (firestoreData != null) {
        final username = firestoreData['username'] ?? 'User';

        if (mounted) {
          setState(() {
            _username = username;
            if (realtimeData != null) {
              _coins = realtimeData['coins'] ?? 0;
              _streaks = realtimeData['streaks'] ?? 0;
              _xp = realtimeData['xp'] ?? 0;
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _username = 'User';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _username = 'User';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadCategoryTitles() async {
    try {
      final titlesRef = FirebaseFirestore.instance.doc('/prep/Title');
      final docSnapshot = await titlesRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data.containsKey('Title') && data['Title'] is List) {
          final List<String> titles = List<String>.from(data['Title']);

          if (mounted) {
            setState(() {
              _categoryTitles = titles;
            });
          }

          print('Loaded category titles: $_categoryTitles');

          for (final title in titles) {
            if (title != 'Programming Language') {
              await _loadCategoryItems(title);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading category titles: $e');
    }
  }

  Future<void> _loadCategoryItems(String category) async {
    try {
      print('Loading items for category: $category');
      final categoryItemsRef =
          FirebaseFirestore.instance.doc('/prep/Title/$category/$category');
      final docSnapshot = await categoryItemsRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;

        print('Category document data: $data');

        if (data.containsKey(category) && data[category] is List) {
          final List<dynamic> rawItems = data[category];
          print('Raw items for $category: $rawItems');

          final List<Map<String, dynamic>> formattedItems = [];

          for (var item in rawItems) {
            Map<String, dynamic> formattedItem;
            String itemName;

            if (item is Map) {
              formattedItem = Map<String, dynamic>.from(item as Map);
              itemName =
                  formattedItem['name'] ?? formattedItem.keys.first.toString();
            } else if (item is String) {
              itemName = item;
              formattedItem = {'name': itemName};
            } else {
              itemName = item.toString();
              formattedItem = {'name': itemName};
            }

            String assetPath = _getAssetForTopic(itemName);
            formattedItem['iconPath'] = assetPath;
            formattedItem['icon'] = assetPath;
            formattedItem['color'] = _getColorForTopic(itemName);

            if (!formattedItem.containsKey('name')) {
              formattedItem['name'] = itemName;
            }

            print('Item: $itemName -> Asset: $assetPath');

            formattedItems.add(formattedItem);
          }

          print('Formatted items for $category: $formattedItems');

          if (mounted) {
            setState(() {
              _categoryItems[category] = formattedItems;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading items for $category: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicStatusBar.buildDynamicScaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadCategoryTitles();
              },
              color: Color(0xFF341B58),
              backgroundColor: Colors.white,
              child: CustomScrollView(
                controller: scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildWelcomeHeader(),
                  ),
                  SliverToBoxAdapter(
                    child: _buildStatsBox(),
                  ),
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OngoingProgramsWidget(
                            categoryItems: _categoryItems,
                            getAssetForTopic: _getAssetForTopic,
                            getColorForTopic: _getColorForTopic,
                          ),
                          TechnologiesWidget(
                            categoryItems: _categoryItems,
                            categoryTitles: _categoryTitles,
                            getAssetForTopic: _getAssetForTopic,
                            getColorForTopic: _getColorForTopic,
                          ),
                          ProgrammingLanguagesWidget(
                            getAssetForTopic: _getAssetForTopic,
                            getColorForTopic: _getColorForTopic,
                          ),
                          SizedBox(height: 80.h),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeHeader() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          height: isSmallScreen ? 240 : 265,
          decoration: BoxDecoration(
            color: Color(0xFF341B58),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(60),
              bottomRight: Radius.circular(60),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 20 : 40, 
              MediaQuery.of(context).padding.top + 20, 
              20, 
              20
            ),
            child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 1),
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        color: Color.fromRGBO(255, 214, 221, 1),
                        size: isSmallScreen ? 15 : 17,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: Color.fromRGBO(255, 214, 221, 1),
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "Hi, ",
                        style: TextStyle(
                          color: Color.fromRGBO(223, 103, 140, 1),
                          fontSize: isSmallScreen ? 24 : 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          _username,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 24 : 28,
                            fontWeight: FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    margin: EdgeInsets.only(top: 5.h, bottom: 25.h),
                    width: 75.w,
                    height: 3.h,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57896),
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  const Spacer(flex: 1),
                  _buildWelcomeHeaderStatsRow(),
                  SizedBox(height: isSmallScreen ? 5 : 10),
                ],
              ),
            ),
          ),
        Positioned(
          top: -60,
          right: 20,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.5,
            height: 280,
            child: CustomPaint(
              painter: HeaderPatternPainter(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeHeaderStatsRow() {
    final screenWidth = MediaQuery.of(context).size.width;

    final double rowSpacing = screenWidth < 360
        ? 15
        : screenWidth < 400
            ? 20
            : 30;
    final double containerHeight = screenWidth < 360 ? 40 : 50;

    return Container(
      height: containerHeight,
      width: double.infinity,
      margin: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatPill(
              Icons.local_fire_department, _streaks.toString(), null),
          _buildStatPill(Icons.currency_rupee, _coins.toString(), null),
          _buildStatPill(Icons.emoji_events, _xp.toString(), null),
        ],
      ),
    );
  }

  Widget _buildStatPill(IconData icon, String value, String? suffix) {
    String getImageAsset() {
      if (icon == Icons.local_fire_department) {
        return 'assets/icons/streak_icon.png';
      } else if (icon == Icons.currency_rupee) {
        return 'assets/icons/coin_icon.png';
      } else if (icon == Icons.emoji_events) {
        return 'assets/icons/xp_icon.png';
      }
      return 'assets/icons/streak_icon.png';
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final scale = screenWidth < 360 ? 0.8 : 1.0;

    final double horizontalPadding = screenWidth < 360 ? 1 : 2;
    final double rightPadding = screenWidth < 360 ? 12 : 23;
    final double iconTextSpacing = screenWidth < 360 ? 6 : 12;
    final double iconSize = scale * 40;
    final double fontSize = scale * 16;

    return Container(
      padding: EdgeInsets.only(
          left: horizontalPadding, right: rightPadding, top: 1, bottom: 1),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color.fromRGBO(95, 38, 105, 1),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            getImageAsset(),
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                icon,
                color: Colors.white,
                size: iconSize * 0.6,
              );
            },
          ),
          SizedBox(width: iconTextSpacing),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
          ),
          if (suffix != null) ...[
            const SizedBox(width: 4),
            Text(
              suffix,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsBox() {
    return FirebaseStatsRowWidget();
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    bool isProgrammingLanguageSection =
        title == 'Programming Language' || title == 'Programming Languages';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          isProgrammingLanguageSection
              ? Text(
                  "View all",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromRGBO(237, 85, 100, 1),
                    fontWeight: FontWeight.w500,
                  ),
                )
              : SizedBox(),
        ],
      ),
    );
  }
}
