import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../services/quiz_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/default_theme.dart';
import 'quiz_result_screen.dart';

class PracticeModeScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic> quizParams;
  final String topicName;
  final String subtopicName;
  final List<Map<String, dynamic>> initialQuestions;

  const PracticeModeScreen({
    Key? key,
    required this.type,
    required this.quizParams,
    required this.topicName,
    required this.subtopicName,
    required this.initialQuestions,
  }) : super(key: key);

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _feedbackController;
  late AnimationController _confettiController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _feedbackAnimation;
  late Animation<double> _confettiAnimation;

  List<Map<String, dynamic>> _allQuestions = [];
  List<Map<String, dynamic>> _currentBatch = [];
  int _currentQuestionIndex = 0;
  int _currentBatchIndex = 0;
  String? _selectedAnswer;
  bool _showFeedback = false;
  bool _isCorrect = false;
  bool _isLoadingNextBatch = false;
  bool _isPreloadingNext = false;
  
  int _totalQuestions = 0;
  int _correctAnswers = 0;
  int _totalXP = 0;
  List<Map<String, dynamic>> _questionHistory = [];
  
  List<Map<String, dynamic>>? _nextBatch;
  Timer? _feedbackTimer;
  Timer? _preloadTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePracticeSession();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));

    _feedbackAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.elasticOut,
    ));

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOutBack,
    ));

    _slideController.forward();
  }

  void _initializePracticeSession() {
    if (widget.initialQuestions.isEmpty) {
      _showErrorDialog('No initial questions provided');
      return;
    }

    _currentBatch = List.from(widget.initialQuestions);
    _allQuestions.addAll(_currentBatch);
    _currentQuestionIndex = 0;
    _currentBatchIndex = 0;
    
    print('PRACTICE: Initialized with ${_currentBatch.length} questions in first batch');
    
    Timer(const Duration(seconds: 5), () {
      _preloadNextBatch();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _feedbackController.dispose();
    _confettiController.dispose();
    _feedbackTimer?.cancel();
    _preloadTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic>? get _currentQuestion {
    if (_currentBatch.isEmpty || _currentQuestionIndex >= _currentBatch.length || _currentQuestionIndex < 0) {
      return null;
    }
    return _currentBatch[_currentQuestionIndex];
  }

  Future<void> _preloadNextBatch() async {
    if (_isPreloadingNext || _nextBatch != null || !mounted) return;
    
    if (mounted) {
      setState(() {
        _isPreloadingNext = true;
      });
    }

    try {
      print('PRACTICE: Preloading next batch...');
      final nextBatch = await QuizService.generateNextPracticeBatch(
        type: widget.type,
        params: widget.quizParams,
      );

      if (mounted) {
        _nextBatch = QuizService.validateQuestions(nextBatch);
        print('PRACTICE: Preloaded ${_nextBatch?.length ?? 0} questions for next batch');
      }
    } catch (e) {
      print('PRACTICE: Error preloading next batch: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPreloadingNext = false;
        });
      }
    }
  }

  Future<void> _selectAnswer(String answer) async {
    if (_showFeedback || _currentQuestion == null || !mounted) return;

    if (mounted) {
      setState(() {
        _selectedAnswer = answer;
        _isCorrect = answer == _currentQuestion!['correct_answer'];
        _showFeedback = true;
        _totalQuestions++;
        
        if (_isCorrect) {
          _correctAnswers++;
          _totalXP += 2;
          _confettiController.forward();
        }
      });
    }

    _questionHistory.add({
      'question': _currentQuestion!,
      'selected_answer': answer,
      'is_correct': _isCorrect,
      'xp_earned': _isCorrect ? 2 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_isCorrect && mounted) {
      await _updateUserXP(2);
    }

    if (mounted) {
      _feedbackController.forward();
    }
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

  Future<void> _nextQuestion() async {
    if (!mounted) return;
    
    _feedbackTimer?.cancel();
    
    // If question was not answered, mark it as skipped
    if (!_showFeedback && _currentQuestion != null) {
      _questionHistory.add({
        'question': _currentQuestion!,
        'selected_answer': null,
        'is_correct': false,
        'xp_earned': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'skipped': true,
      });
      _totalQuestions++;
    }
    
    if (_currentQuestionIndex >= _currentBatch.length - 1) {
      await _loadNextBatch();
    } else {
      if (mounted) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (mounted) {
          _slideController.forward();
        }
      }
    }
  }

  Future<void> _loadNextBatch() async {
    if (!mounted) return;
    
    if (mounted) {
      setState(() {
        _isLoadingNextBatch = true;
      });
    }

    try {
      List<Map<String, dynamic>> nextBatch;
      
      if (_nextBatch != null && _nextBatch!.isNotEmpty) {
        nextBatch = _nextBatch!;
        _nextBatch = null;
        print('PRACTICE: Using preloaded batch with ${nextBatch.length} questions');
      } else {
        print('PRACTICE: Generating new batch on demand...');
        nextBatch = await QuizService.generateNextPracticeBatch(
          type: widget.type,
          params: widget.quizParams,
        );
        nextBatch = QuizService.validateQuestions(nextBatch);
      }

      if (nextBatch.isEmpty) {
        throw Exception('No valid questions in next batch');
      }

      if (mounted) {
        setState(() {
          _currentBatch = nextBatch;
          _allQuestions.addAll(nextBatch);
          _currentQuestionIndex = 0;
          _currentBatchIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
          _isLoadingNextBatch = false;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (mounted) {
          _slideController.forward();
        }

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _preloadNextBatch();
          }
        });
      }
    } catch (e) {
      print('Error loading next batch: $e');
      if (mounted) {
        setState(() {
          _isLoadingNextBatch = false;
        });
        _showErrorDialog('Failed to load next batch: $e');
      }
    }
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
              _endPractice();
            },
            child: Text('End Practice'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _retryLoadBatch();
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryLoadBatch() async {
    if (!mounted) return;
    
    if (mounted) {
      setState(() {
        _isLoadingNextBatch = true;
        _nextBatch = null;
      });
    }

    try {
      final nextBatch = await QuizService.generateNextPracticeBatch(
        type: widget.type,
        params: widget.quizParams,
      );
      
      final validatedBatch = QuizService.validateQuestions(nextBatch);
      
      if (validatedBatch.isEmpty) {
        throw Exception('No valid questions generated');
      }

      if (mounted) {
        setState(() {
          _currentBatch = validatedBatch;
          _allQuestions.addAll(validatedBatch);
          _currentQuestionIndex = 0;
          _currentBatchIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
          _isLoadingNextBatch = false;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (mounted) {
          _slideController.forward();
        }

        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            _preloadNextBatch();
          }
        });
      }
    } catch (e) {
      print('Error retrying batch load: $e');
      if (mounted) {
        setState(() {
          _isLoadingNextBatch = false;
        });
        _showErrorDialog('Failed to load questions after retry: $e');
      }
    }
  }

  void _endPractice() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultScreen(
          mode: 'practice',
          topicName: widget.topicName,
          subtopicName: widget.subtopicName,
          totalQuestions: _totalQuestions,
          correctAnswers: _correctAnswers,
          totalXP: _totalXP,
          questionHistory: _questionHistory,
          type: widget.type,
          quizParams: widget.quizParams,
        ),
      ),
    );
  }

  void _showHint() {
    if (_currentQuestion == null) return;
    
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
  }

  void _showQuestionNavigator() {
    if (_totalQuestions <= 1) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
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
                    'Practice History',
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
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _questionHistory.length,
                itemBuilder: (context, index) {
                  final item = _questionHistory[index];
                  final isCorrect = item['is_correct'];
                  final isSkipped = item['skipped'] ?? false;
                  
                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isSkipped ? Colors.orange.shade50 : (isCorrect ? Colors.green.shade50 : Colors.red.shade50),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSkipped ? Colors.orange.shade300 : (isCorrect ? Colors.green.shade300 : Colors.red.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: isSkipped ? Colors.orange : (isCorrect ? Colors.green : Colors.red),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            item['question']['question'] ?? 'Question ${index + 1}',
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: AppTheme.primaryColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          isSkipped ? Icons.skip_next : (isCorrect ? Icons.check_circle : Icons.cancel),
                          color: isSkipped ? Colors.orange : (isCorrect ? Colors.green : Colors.red),
                          size: 20.sp,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingNextBatch || _currentQuestion == null) {
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
                  'Loading next 10 questions...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Batch ${_currentBatchIndex + 2} • Question ${_totalQuestions + 1}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('End Practice?'),
                content: Text('Are you sure you want to end this practice session? Your progress will be saved.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Continue'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _endPractice();
                    },
                    child: Text('End Practice'),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          'Practice Mode',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            margin: EdgeInsets.only(right: 16.w),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars, color: Colors.white, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  '${_totalXP} XP',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
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
                      IconButton(
                        onPressed: _showHint,
                        icon: Icon(
                          Icons.help_outline,
                          color: Colors.amber,
                          size: 22.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Question ${_totalQuestions + 1}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Batch ${_currentBatchIndex + 1} • ${_currentQuestionIndex + 1}/10',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 10.sp,
                              ),
                            ),
                            Text(
                              'Accuracy: ${_totalQuestions > 0 ? ((_correctAnswers / _totalQuestions) * 100).toInt() : 0}%',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          if (_totalQuestions > 0)
                            GestureDetector(
                              onTap: _showQuestionNavigator,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.history, color: Colors.white, size: 16.sp),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'History',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SizedBox(height: 8.h),
                          if (_isPreloadingNext)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12.w,
                                    height: 12.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Preloading...',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 10.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
                        
                        SizedBox(height: 16.h),
                        
                        Text(
                          _currentQuestion!['question'] ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                            height: 1.4,
                          ),
                        ),
                        
                        SizedBox(height: 20.h),
                        
                        Column(
                          children: List.generate(
                            (_currentQuestion!['options'] as List?)?.length ?? 0,
                            (index) {
                              final option = _currentQuestion!['options'][index];
                              final isSelected = _selectedAnswer == option;
                              final isCorrect = option == _currentQuestion!['correct_answer'];
                              
                              Color backgroundColor = Colors.grey.shade50;
                              Color borderColor = Colors.grey.shade300;
                              Color textColor = AppTheme.primaryColor;
                              
                              if (_showFeedback) {
                                if (isCorrect) {
                                  backgroundColor = Colors.green.shade50;
                                  borderColor = Colors.green;
                                  textColor = Colors.green.shade700;
                                } else if (isSelected && !isCorrect) {
                                  backgroundColor = Colors.red.shade50;
                                  borderColor = Colors.red;
                                  textColor = Colors.red.shade700;
                                }
                              } else if (isSelected) {
                                backgroundColor = AppTheme.secondaryColor.withOpacity(0.1);
                                borderColor = AppTheme.secondaryColor;
                              }
                              
                              return Container(
                                margin: EdgeInsets.only(bottom: 10.h),
                                child: Material(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12.r),
                                    onTap: _showFeedback ? null : () => _selectAnswer(option),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(14.w),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: borderColor, width: 2),
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
                                              color: isSelected ? borderColor : Colors.transparent,
                                              border: Border.all(color: borderColor, width: 2),
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
                                                color: textColor,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                height: 1.4,
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                          if (_showFeedback && isCorrect)
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                              size: 20.sp,
                                            ),
                                          if (_showFeedback && isSelected && !isCorrect)
                                            Icon(
                                              Icons.cancel,
                                              color: Colors.red,
                                              size: 20.sp,
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
                        
                        if (_showFeedback) ...[
                          SizedBox(height: 20.h),
                          AnimatedBuilder(
                            animation: _feedbackAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _feedbackAnimation.value,
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(14.w),
                                  decoration: BoxDecoration(
                                    color: _isCorrect ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: _isCorrect ? Colors.green : Colors.red,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            _isCorrect ? Icons.check_circle : Icons.cancel,
                                            color: _isCorrect ? Colors.green : Colors.red,
                                            size: 20.sp,
                                          ),
                                          SizedBox(width: 8.w),
                                          Text(
                                            _isCorrect ? 'Correct! +2 XP' : 'Incorrect',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15.sp,
                                              fontWeight: FontWeight.w600,
                                              color: _isCorrect ? Colors.green.shade700 : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_currentQuestion!['explanation'] != null && _currentQuestion!['explanation'].toString().isNotEmpty) ...[
                                        SizedBox(height: 8.h),
                                        Text(
                                          _currentQuestion!['explanation'] ?? '',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.sp,
                                            color: Colors.grey.shade700,
                                            height: 1.4,
                                          ),
                                          softWrap: true,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            Container(
              width: double.infinity,
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
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextQuestion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFDF678C),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      child: Text(
                        _showFeedback ? 'Next Question' : 'Skip Question',
                        style: GoogleFonts.poppins(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  if (_showFeedback)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _endPractice,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: AppTheme.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Text(
                          'End Practice',
                          style: GoogleFonts.poppins(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  if (!_showFeedback)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_correctAnswers}/${_totalQuestions}',
                            style: GoogleFonts.poppins(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Text(
                            'Correct',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Stack(
        children: [
          if (_isCorrect && _showFeedback)
            AnimatedBuilder(
              animation: _confettiAnimation,
              builder: (context, child) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: ConfettiPainter(_confettiAnimation.value),
                    ),
                  ),
                );
              },
            ),
        ],
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

class ConfettiPainter extends CustomPainter {
  final double animationValue;
  
  ConfettiPainter(this.animationValue);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
    ];
    
    for (int i = 0; i < 30; i++) {
      paint.color = colors[i % colors.length];
      
      final baseX = (size.width * 0.1) + (i * size.width * 0.03) % size.width;
      final baseY = -50.0 + (animationValue * (size.height + 100));
      
      final offsetX = (i % 3 - 1) * 20.0 * animationValue;
      final offsetY = (i % 5) * 10.0;
      
      final x = baseX + offsetX;
      final y = baseY + offsetY;
      
      if (y >= -10 && y <= size.height + 10) {
        if (i % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 3 + (i % 2), paint);
        } else if (i % 3 == 1) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 6, height: 6),
            paint,
          );
        } else {
          final path = Path();
          path.moveTo(x, y - 3);
          path.lineTo(x - 3, y + 3);
          path.lineTo(x + 3, y + 3);
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}