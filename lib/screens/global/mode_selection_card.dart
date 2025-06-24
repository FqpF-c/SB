import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/default_theme.dart';
import '../../providers/auth_provider.dart';
import 'quiz_loading_screen.dart';

class ModeSelectionCard extends StatelessWidget {
  final String topicName;
  final String subcategoryName;
  final String type;
  final Map<String, dynamic> quizParams;
  final Function()? onPracticeModeSelected;
  final Function()? onTestModeSelected;
  
  const ModeSelectionCard({
    Key? key,
    required this.topicName,
    required this.subcategoryName,
    required this.type,
    required this.quizParams,
    this.onPracticeModeSelected,
    this.onTestModeSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(48),
          topRight: Radius.circular(48),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 20.h),
              width: 90.w,
              height: 6.h,
              decoration: BoxDecoration(
                color: Color.fromRGBO(230, 150, 180, 1),
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D1B69),
                  ),
                ),
                
                SizedBox(height: 0.h),
                
                Text(
                  topicName,
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    color: Colors.grey[500],
                  ),
                ),
                
                if (subcategoryName.isNotEmpty) ...[
                  SizedBox(height: 0.h),
                  Text(
                    subcategoryName,
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          SizedBox(height: 16.h),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: _buildModeCard(
              context: context,
              icon: Icons.fitness_center,
              title: 'Practice Mode',
              description: 'Practice at your own pace with immediate feedback and explanations.',
              buttonText: 'Start Practice',
              iconColor: Color(0xFFE91E63),
              onPressed: () => _startMode(context, 'practice'),
            ),
          ),
          
          SizedBox(height: 16.h),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: _buildModeCard(
              context: context,
              icon: Icons.quiz,
              title: 'Test Mode',
              description: 'Challenge yourself with a timed test and get a final score.',
              buttonText: 'Start Test',
              iconColor: Color(0xFFE91E63),
              onPressed: () => _startMode(context, 'test'),
            ),
          ),
        ],
      ),
    );
  }
  
  void _startMode(BuildContext context, String mode) {
    Navigator.pop(context);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizLoadingScreen(
          mode: mode,
          type: type,
          quizParams: quizParams,
          topicName: topicName,
          subtopicName: subcategoryName,
        ),
      ),
    );
    
    if (mode == 'practice' && onPracticeModeSelected != null) {
      onPracticeModeSelected!();
    } else if (mode == 'test' && onTestModeSelected != null) {
      onTestModeSelected!();
    }
  }
  
  Widget _buildModeCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String buttonText,
    required Color iconColor,
    Function()? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Color.fromRGBO(240, 222, 240, 1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 20.sp,
                          color: Color.fromRGBO(223, 103, 140, 1),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w600,
                            color: Color.fromRGBO(223, 103, 140, 1),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20.h),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF2D1B69),
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          buttonText,
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward,
                          size: 18.sp,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModeSelectionBottomSheet {
  static Future<void> show({
    required BuildContext context,
    required String topicName,
    required String subcategoryName,
    String type = 'programming',
    Map<String, dynamic>? quizParams,
    Function()? onPracticeModeSelected,
    Function()? onTestModeSelected,
    String? categoryId,
    String? subcategory,
    String? topic,
  }) async {
    Map<String, dynamic> finalQuizParams = quizParams ?? {};
    
    if (finalQuizParams.isEmpty) {
      if (type == 'academic') {
        try {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final userData = await authProvider.getCurrentUserData();
          
          finalQuizParams = {
            'college': userData?['college'] ?? '',
            'department': '',
            'semester': '',
            'subject': topicName,
            'unit': subcategoryName,
          };
        } catch (e) {
          print('Error getting user data for academic quiz: $e');
        }
      } else {
        finalQuizParams = {
          'mainTopic': 'Programming',
          'programmingLanguage': topicName,
          'subTopic': subcategoryName,
          if (categoryId != null) 'categoryId': categoryId,
          if (subcategory != null) 'subcategory': subcategory, 
          if (topic != null) 'topic': topic,
        };
      }
    }
    
    if (type == 'programming') {
      finalQuizParams['categoryId'] = categoryId ?? finalQuizParams['categoryId'];
      finalQuizParams['subcategory'] = subcategory ?? finalQuizParams['subcategory'];
      finalQuizParams['topic'] = topic ?? finalQuizParams['topic'];
      
      print('ModeSelection: Firebase path params - categoryId: $categoryId, subcategory: $subcategory, topic: $topic');
    }
    
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.transparent,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 380.h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(48),
                      topRight: Radius.circular(48),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        color: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: ModeSelectionCard(
                      topicName: topicName,
                      subcategoryName: subcategoryName,
                      type: type,
                      quizParams: finalQuizParams,
                      onPracticeModeSelected: onPracticeModeSelected,
                      onTestModeSelected: onTestModeSelected,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}