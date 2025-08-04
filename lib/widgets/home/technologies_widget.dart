import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../screens/home/listtopics_screen.dart';

class TechnologiesWidget extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> categoryItems;
  final List<String> categoryTitles;
  final String Function(String) getAssetForTopic;
  final Color Function(String) getColorForTopic;

  const TechnologiesWidget({
    Key? key,
    required this.categoryItems,
    required this.categoryTitles,
    required this.getAssetForTopic,
    required this.getColorForTopic,
  }) : super(key: key);

  @override
  State<TechnologiesWidget> createState() => _TechnologiesWidgetState();
}

class _TechnologiesWidgetState extends State<TechnologiesWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _animationControllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();

    _animationControllers = List.generate(8, (index) {
      final randomDuration = 3000 + (math.Random().nextInt(2000));
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: randomDuration),
      )..repeat(reverse: true);
    });

    _animations = _animationControllers.map((controller) {
      return Tween<double>(
        begin: -3.0,
        end: 3.0,
      ).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _animationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Navigation function
  void _navigateToTechnology(String technologyName) {
    try {
      // Map technology names to category IDs that match your ListTopicsScreen structure
      String categoryId = _getCategoryIdForTechnology(technologyName);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ListTopicsScreen(
            categoryName: technologyName,
            categoryId: categoryId,
          ),
        ),
      );
    } catch (e) {
      print('Navigation error for $technologyName: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to navigate to $technologyName'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper function to map technology names to category IDs
  String _getCategoryIdForTechnology(String technologyName) {
    switch (technologyName.toLowerCase()) {
      case 'web development':
        return 'Web Development';
      case 'devops':
        return 'DevOps';
      case 'cloud computing':
        return 'Cloud Computing';
      case 'ui/ux design':
      case 'ui/ux':
        return 'UI/UX';
      case 'app development':
        return 'App Development';
      case 'database':
        return 'Database';
      case 'machine learning':
        return 'Machine Learning';
      default:
        return technologyName; // Fallback to the original name
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> technologies = [];

    for (final category in widget.categoryTitles) {
      if (category != 'Programming Language') {
        String iconAsset = widget.getAssetForTopic(category);
        Color iconColor = widget.getColorForTopic(category);

        technologies.add(
            {'name': category, 'iconAsset': iconAsset, 'iconColor': iconColor});
      }
    }

    if (technologies.isEmpty) {
      technologies.addAll([
        {
          'name': 'Web Development',
          'iconAsset': widget.getAssetForTopic('Web Development'),
          'iconColor': widget.getColorForTopic('Web Development')
        },
        {
          'name': 'DevOps',
          'iconAsset': widget.getAssetForTopic('DevOps'),
          'iconColor': widget.getColorForTopic('DevOps')
        },
        {
          'name': 'Cloud Computing',
          'iconAsset': widget.getAssetForTopic('Cloud Computing'),
          'iconColor': widget.getColorForTopic('Cloud Computing')
        },
        {
          'name': 'UI/UX Design',
          'iconAsset': widget.getAssetForTopic('UI/UX'),
          'iconColor': widget.getColorForTopic('UI/UX')
        },
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Text(
            'Technologies',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Column(
          children: [
            Container(
              height: 70.h,
              margin: EdgeInsets.only(bottom: 0.2.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedTechnologyCard(technologies[0], 0),
                    SizedBox(width: 10.w),
                    _buildAnimatedTechnologyCard(
                        technologies.length > 1
                            ? technologies[1]
                            : technologies[0],
                        1),
                  ],
                ),
              ),
            ),
            Container(
              height: 70.h,
              margin: EdgeInsets.only(bottom: 5.h),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedTechnologyCard(
                        technologies.length > 2
                            ? technologies[2]
                            : technologies[0],
                        2),
                    SizedBox(width: 10.w),
                    _buildAnimatedTechnologyCard(
                        technologies.length > 3
                            ? technologies[3]
                            : technologies.length > 1
                                ? technologies[1]
                                : technologies[0],
                        3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedTechnologyCard(
      Map<String, dynamic> technology, int animationIndex) {
    return AnimatedBuilder(
      animation: _animationControllers[animationIndex],
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_animations[animationIndex].value, 0),
          child: child,
        );
      },
      child: _buildDynamicTechnologyCard(technology),
    );
  }

  Widget _buildDynamicTechnologyCard(Map<String, dynamic> technology) {
    final double cardHeight = 58.h;
    final double iconSize = 24.sp;

    return GestureDetector(
      onTap: () => _navigateToTechnology(technology['name'] as String),
      child: Container(
        height: cardHeight,
        padding: EdgeInsets.symmetric(horizontal: 12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: const Color.fromRGBO(247, 237, 248, 1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(252, 247, 252, 1),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildTechnologyIcon(
                  technology['iconAsset'], technology['iconColor'], iconSize),
              SizedBox(width: 8.w),
              Text(
                technology['name'] as String,
                style: TextStyle(
                  fontSize: 15.5.sp,
                  fontWeight: FontWeight.w500,
                  color: Color.fromRGBO(61, 21, 96, 1),
                ),
              ),
              SizedBox(width: 4.w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTechnologyIcon(
      String iconAsset, Color iconColor, double iconSize) {
    return Image.asset(
      iconAsset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        print('Failed to load technology icon: $iconAsset');
        return Icon(
          Icons.code,
          color: iconColor,
          size: iconSize,
        );
      },
    );
  }
}
