import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math';
import '../../services/quiz_service.dart';
import '../../theme/default_theme.dart';
import 'practice_mode_screen.dart';
import 'test_mode_screen.dart';

class QuizLoadingScreen extends StatefulWidget {
  final String mode; // 'practice' or 'test'
  final String type; // 'programming' or 'academic'
  final Map<String, dynamic> quizParams;
  final String topicName;
  final String subtopicName;

  const QuizLoadingScreen({
    Key? key,
    required this.mode,
    required this.type,
    required this.quizParams,
    required this.topicName,
    required this.subtopicName,
  }) : super(key: key);

  @override
  State<QuizLoadingScreen> createState() => _QuizLoadingScreenState();
}

class _QuizLoadingScreenState extends State<QuizLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;

  Timer? _loadingTimer;
  bool _isGenerating = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentStep = 0;
  
  final List<String> _practiceLoadingMessages = [
    'Initializing AI...',
    'Analyzing topic content...',
    'Generating 10 practice questions...',
    'Optimizing difficulty levels...',
    'Preparing interactive session...',
  ];
  
  final List<String> _testLoadingMessages = [
    'Initializing AI...',
    'Analyzing topic content...',
    'Generating first set (10 questions)...',
    'Generating second set (10 questions)...',
    'Optimizing question difficulty...',
    'Finalizing 20-question test...',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startQuizGeneration();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_rotationController);

    _progressController.forward();

    // Step through loading messages with different timing for test vs practice
    final stepDuration = widget.mode == 'test' 
        ? const Duration(seconds: 3) // Longer steps for test mode (6 steps)
        : const Duration(seconds: 4); // Standard steps for practice mode (5 steps)
    
    _loadingTimer = Timer.periodic(stepDuration, (timer) {
      final maxSteps = widget.mode == 'test' 
          ? _testLoadingMessages.length - 1
          : _practiceLoadingMessages.length - 1;
          
      if (mounted && _currentStep < maxSteps) {
        setState(() {
          _currentStep++;
        });
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _startQuizGeneration() async {
    setState(() {
      _isGenerating = true;
      _hasError = false;
    });

    try {
      List<Map<String, dynamic>> questions;

      if (widget.mode == 'practice') {
        // For practice mode, generate initial 10 questions
        questions = await QuizService.generatePracticeQuestions(
          type: widget.type,
          params: widget.quizParams,
        );
        
        print('QUIZ_LOADING: Generated ${questions.length} questions for practice mode');
      } else {
        // For test mode, generate 20 questions (2 sets of 10)
        questions = await QuizService.generateTestQuestions(
          type: widget.type,
          params: widget.quizParams,
        );
        
        print('QUIZ_LOADING: Generated ${questions.length} questions for test mode');
      }

      // Validate questions
      questions = QuizService.validateQuestions(questions);

      if (questions.isEmpty) {
        throw Exception('No valid questions generated');
      }

      // Ensure minimum questions count
      final minQuestions = widget.mode == 'practice' ? 5 : 15; // Allow some buffer
      if (questions.length < minQuestions) {
        throw Exception('Insufficient questions generated: ${questions.length}/$minQuestions');
      }

      // Wait for minimum loading time (20 seconds)
      final elapsed = _progressController.value * 20;
      if (elapsed < 20) {
        await Future.delayed(Duration(seconds: (20 - elapsed).round()));
      }

      if (mounted) {
        if (widget.mode == 'practice') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PracticeModeScreen(
                type: widget.type,
                quizParams: widget.quizParams,
                topicName: widget.topicName,
                subtopicName: widget.subtopicName,
                initialQuestions: questions, // Initial 10 questions
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TestModeScreen(
                type: widget.type,
                quizParams: widget.quizParams,
                topicName: widget.topicName,
                subtopicName: widget.subtopicName,
                questions: questions, // All 20 questions
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Quiz generation error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  void _retryGeneration() {
    setState(() {
      _hasError = false;
      _currentStep = 0;
    });
    _progressController.reset();
    _progressController.forward();
    _startQuizGeneration();
  }

  @override
  Widget build(BuildContext context) {
    final currentMessages = widget.mode == 'test' 
        ? _testLoadingMessages 
        : _practiceLoadingMessages;
        
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
                const Color(0xFF2A1045),
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                ),

                const Spacer(),

                // Main loading animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120.w,
                        height: 120.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.secondaryColor.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _rotationAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.secondaryColor,
                                    width: 4.w,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    widget.mode == 'practice'
                                        ? Icons.fitness_center
                                        : Icons.quiz,
                                    color: Colors.white,
                                    size: 48.sp,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 40.h),

                // Topic information
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.mode == 'practice' ? 'Practice Mode' : 'Test Mode',
                        style: GoogleFonts.poppins(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        widget.topicName,
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        widget.subtopicName,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 12.h),
                      // Mode-specific info
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          widget.mode == 'practice' 
                              ? 'Generating 10 questions per batch'
                              : 'Generating 20 questions total',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 40.h),

                if (_hasError) ...[
                  // Error state
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48.sp,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Failed to Generate Quiz',
                          style: GoogleFonts.poppins(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          _errorMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 14.sp,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20.h),
                        ElevatedButton(
                          onPressed: _retryGeneration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor,
                            padding: EdgeInsets.symmetric(
                              horizontal: 32.w,
                              vertical: 12.h,
                            ),
                          ),
                          child: Text(
                            'Retry',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Loading state
                  AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return Column(
                        children: [
                          // Progress bar
                          Container(
                            width: double.infinity,
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progressAnimation.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.secondaryColor,
                                      AppTheme.secondaryColor.withOpacity(0.8),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            '${(_progressAnimation.value * 100).toInt()}%',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            currentMessages[_currentStep],
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              color: Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                ],

                const Spacer(),

                // Tips or information
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.amber,
                        size: 20.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          widget.mode == 'practice'
                              ? 'Practice mode: 10 questions per batch, unlimited attempts with immediate feedback!'
                              : 'Test mode: 20 total questions, answer carefully for maximum XP!',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}