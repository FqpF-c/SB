import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../theme/default_theme.dart';
import 'quiz_result_screen.dart';

class TestModeScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic> quizParams;
  final String topicName;
  final String subtopicName;
  final List<Map<String, dynamic>> questions;

  const TestModeScreen({
    Key? key,
    required this.type,
    required this.quizParams,
    required this.topicName,
    required this.subtopicName,
    required this.questions,
  }) : super(key: key);

  @override
  State<TestModeScreen> createState() => _TestModeScreenState();
}

class _TestModeScreenState extends State<TestModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _timerController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _timerAnimation;

  int _currentQuestionIndex = 0;
  List<String?> _selectedAnswers = [];
  bool _isSubmitted = false;
  bool _isLoading = false;
  
  Timer? _quizTimer;
  int _timeRemaining = 1200;
  bool _showTimeWarning = false;
  
  int _correctAnswers = 0;
  int _totalXP = 0;
  List<Map<String, dynamic>> _questionHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeQuiz();
    _startTimer();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _timerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _timerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_timerController);

    _slideController.forward();
  }

  void _initializeQuiz() {
    if (widget.questions.isEmpty) {
      _showErrorDialog('No questions available');
      return;
    }
    _selectedAnswers = List.filled(widget.questions.length, null);
  }

  void _startTimer() {
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
            _showTimeWarning = _timeRemaining <= 300;
          } else {
            _autoSubmitQuiz();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _timerController.dispose();
    _quizTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _currentQuestion {
    if (widget.questions.isEmpty || _currentQuestionIndex >= widget.questions.length || _currentQuestionIndex < 0) {
      return null;
    }
    return widget.questions[_currentQuestionIndex];
  }

  void _selectAnswer(String answer) {
    if (_isSubmitted || _currentQuestion == null) return;

    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
      _slideController.reset();
      _slideController.forward();
    }
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < widget.questions.length) {
      setState(() {
        _currentQuestionIndex = index;
      });
      _slideController.reset();
      _slideController.forward();
      Navigator.pop(context);
    }
  }

  void _showQuestionNavigator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.r),
            topRight: Radius.circular(20.r),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question Navigator',
                    style: GoogleFonts.poppins(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                  ),
                  itemCount: widget.questions.length,
                  itemBuilder: (context, index) {
                    final isAnswered = _selectedAnswers[index] != null;
                    final isCurrent = index == _currentQuestionIndex;
                    
                    Color backgroundColor = Colors.grey.shade200;
                    Color textColor = Colors.grey.shade600;
                    
                    if (isCurrent) {
                      backgroundColor = AppTheme.primaryColor;
                      textColor = Colors.white;
                    } else if (isAnswered) {
                      backgroundColor = AppTheme.secondaryColor;
                      textColor = Colors.white;
                    }
                    
                    return GestureDetector(
                      onTap: () => _goToQuestion(index),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(8.r),
                          border: isCurrent ? Border.all(
                            color: AppTheme.secondaryColor,
                            width: 2,
                          ) : null,
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit Quiz?'),
        content: Text('Are you sure you want to submit? You cannot change your answers after submission.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue Quiz'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _processResults();
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _autoSubmitQuiz() {
    _quizTimer?.cancel();
    _processResults();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8.w),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Go Back'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _retryQuiz();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryQuiz() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _currentQuestionIndex = 0;
        _selectedAnswers = List.filled(widget.questions.length, null);
        _isSubmitted = false;
        _timeRemaining = 1200;
        _showTimeWarning = false;
        _correctAnswers = 0;
        _totalXP = 0;
        _questionHistory = [];
        _isLoading = false;
      });

      _slideController.reset();
      _slideController.forward();
      _startTimer();
    }
  }

  Future<void> _processResults() async {
    setState(() {
      _isSubmitted = true;
    });

    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final selectedAnswer = _selectedAnswers[i];
      final correctAnswer = question['correct_answer'];
      final isCorrect = selectedAnswer == correctAnswer;
      
      if (isCorrect) {
        _correctAnswers++;
        _totalXP += 4;
      }
      
      _questionHistory.add({
        'question': question,
        'selected_answer': selectedAnswer,
        'is_correct': isCorrect,
        'xp_earned': isCorrect ? 4 : 0,
      });
    }

    if (_totalXP > 0) {
      await _updateUserXP(_totalXP);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          mode: 'test',
          topicName: widget.topicName,
          subtopicName: widget.subtopicName,
          totalQuestions: widget.questions.length,
          correctAnswers: _correctAnswers,
          totalXP: _totalXP,
          questionHistory: _questionHistory,
          type: widget.type,
          quizParams: widget.quizParams,
          timeSpent: 1200 - _timeRemaining,
        ),
      ),
    );
  }

  Future<void> _updateUserXP(int xp) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = await authProvider.getCurrentUserData();
      
      if (userData != null) {
        final currentXP = userData['xp'] ?? 0;
        await authProvider.updateUserStats(xp: currentXP + xp);
      }
    } catch (e) {
      print('Error updating XP: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int get _answeredCount => _selectedAnswers.where((answer) => answer != null).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading || widget.questions.isEmpty || _currentQuestion == null) {
      return Scaffold(
        backgroundColor: AppTheme.primaryColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4.w,
                  ),
                ),
                SizedBox(height: 24.h),
                Text(
                  'Loading quiz questions...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitted) return true;
        
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit Quiz?'),
            content: Text('Your progress will be lost. Are you sure you want to exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Continue Quiz'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Exit'),
              ),
            ],
          ),
        );
        
        return shouldExit ?? false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () async {
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Exit Quiz?'),
                  content: Text('Your progress will be lost. Are you sure you want to exit?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('Continue Quiz'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Exit'),
                    ),
                  ],
                ),
              );
              
              if (shouldExit == true) {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            'Test Mode',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            AnimatedBuilder(
              animation: _timerAnimation,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  margin: EdgeInsets.only(right: 16.w),
                  decoration: BoxDecoration(
                    color: _showTimeWarning ? Colors.red : AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: _showTimeWarning ? [
                      BoxShadow(
                        color: Colors.red.withOpacity(_timerAnimation.value * 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatTime(_timeRemaining),
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.topicName,
                                style: GoogleFonts.poppins(
                                  color: AppTheme.secondaryColor,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.subtopicName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _showQuestionNavigator,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.grid_view,
                                  color: Colors.white,
                                  size: 16.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${_answeredCount}/${widget.questions.length}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: 10.h),
                    
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentQuestionIndex + 1) / widget.questions.length,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                            minHeight: 8.h,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          '${_currentQuestionIndex + 1}/${widget.questions.length}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(20.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(_currentQuestion!['difficulty']),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  _currentQuestion!['difficulty'] ?? 'Medium',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.lightbulb, color: Colors.amber),
                                          SizedBox(width: 8.w),
                                          Text('Hint'),
                                        ],
                                      ),
                                      content: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: 300.h,
                                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            _currentQuestion!['hint'] ?? 'No hint available',
                                            style: GoogleFonts.poppins(fontSize: 14.sp),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Got it!'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: Icon(
                                  Icons.help_outline,
                                  color: Colors.amber,
                                  size: 22.sp,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 16.h),
                          
                          Text(
                            _currentQuestion!['question'] ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                              height: 1.4,
                            ),
                            softWrap: true,
                          ),
                          
                          SizedBox(height: 20.h),
                          
                          Column(
                            children: List.generate(
                              (_currentQuestion!['options'] as List?)?.length ?? 0,
                              (index) {
                                final option = _currentQuestion!['options'][index];
                                final isSelected = _selectedAnswers[_currentQuestionIndex] == option;
                                
                                return Container(
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  child: Material(
                                    color: isSelected
                                        ? AppTheme.secondaryColor.withOpacity(0.1)
                                        : Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12.r),
                                      onTap: () => _selectAnswer(option),
                                      child: Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(14.w),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.secondaryColor
                                                : Colors.grey.shade300,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(12.r),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 22.w,
                                              height: 22.w,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected
                                                    ? AppTheme.secondaryColor
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? AppTheme.secondaryColor
                                                      : Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? Icon(
                                                      Icons.check,
                                                      color: Colors.white,
                                                      size: 15.sp,
                                                    )
                                                  : null,
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15.sp,
                                                  color: isSelected
                                                      ? AppTheme.secondaryColor
                                                      : AppTheme.primaryColor,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  height: 1.4,
                                                ),
                                                softWrap: true,
                                              ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              Container(
                padding: EdgeInsets.all(18.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (_currentQuestionIndex > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousQuestion,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: AppTheme.primaryColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'Previous',
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                    
                    if (_currentQuestionIndex > 0) SizedBox(width: 16.w),
                    
                    Expanded(
                      flex: _currentQuestionIndex == 0 ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _currentQuestionIndex == widget.questions.length - 1
                            ? _submitQuiz
                            : _nextQuestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentQuestionIndex == widget.questions.length - 1
                              ? Colors.green
                              : AppTheme.secondaryColor,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          _currentQuestionIndex == widget.questions.length - 1
                              ? 'Submit Quiz'
                              : 'Next',
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
    );
  }

  Color _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}