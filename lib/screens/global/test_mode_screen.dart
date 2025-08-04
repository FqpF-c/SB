import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/auth_provider.dart';
import '../../services/quiz_storage_service.dart';
import '../../theme/default_theme.dart';
import 'quiz_result_screen.dart';

class TestModeScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic> quizParams;
  final String topicName;
  final String subtopicName;
  final List<Map<String, dynamic>> questions;
  final String? sessionId;

  const TestModeScreen({
    Key? key,
    required this.type,
    required this.quizParams,
    required this.topicName,
    required this.subtopicName,
    required this.questions,
    this.sessionId,
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
  bool _isDisposed = false; // Add disposed flag

  Timer? _quizTimer;
  Timer? _timeTracker;
  int _timeRemaining = 1200;
  bool _showTimeWarning = false;

  int _correctAnswers = 0;
  int _totalXP = 0;
  List<Map<String, dynamic>> _questionHistory = [];

  // Performance tracking for analytics (but no adaptive generation)
  List<Map<String, dynamic>> _performanceData = [];

  String? _sessionId;
  int _sessionStartTime = 0;
  Map<int, int> _questionStartTimes = {};
  Map<int, int> _questionAnswerTimes = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeQuiz();
    _startTimer();
    _startTimeTracking();
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
    _sessionId = widget.sessionId;

    _questionStartTimes[0] = DateTime.now().millisecondsSinceEpoch;

    print('TEST: Session ID: $_sessionId');
    print('TEST: Total questions: ${widget.questions.length}');
  }

  void _startTimer() {
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
          _showTimeWarning = _timeRemaining <= 300;
        } else {
          _autoSubmitQuiz();
        }
      });
    });
  }

  void _startTimeTracking() {
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;

    _timeTracker = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      // Track session duration
    });
  }

  @override
  void dispose() {
    _isDisposed = true; // Set disposed flag first

    _slideController.dispose();
    _timerController.dispose();
    _quizTimer?.cancel();
    _timeTracker?.cancel();

    // Store abandonment only if session exists and not submitted
    if (_sessionId != null && !_isSubmitted) {
      // Fire and forget - don't await in dispose
      _storeQuizAbandonment();
    }

    super.dispose();
  }

  Map<String, dynamic>? get _currentQuestion {
    if (widget.questions.isEmpty ||
        _currentQuestionIndex >= widget.questions.length ||
        _currentQuestionIndex < 0) {
      return null;
    }
    return widget.questions[_currentQuestionIndex];
  }

  // Performance analysis for tracking weak areas (analytics only)
  Map<String, dynamic> _analyzePerformance() {
    if (_performanceData.isEmpty) return {};

    Map<String, Map<String, dynamic>> topicAnalysis = {};
    Map<String, Map<String, dynamic>> difficultyAnalysis = {};

    for (var data in _performanceData) {
      String topic = data['topic'] ?? 'General';
      String difficulty = data['difficulty'] ?? 'Medium';
      bool isCorrect = data['isCorrect'] ?? false;
      int timeSpent = data['timeSpent'] ?? 30;

      // Topic analysis
      if (!topicAnalysis.containsKey(topic)) {
        topicAnalysis[topic] = {
          'total': 0,
          'correct': 0,
          'totalTime': 0,
          'questions': [],
        };
      }
      topicAnalysis[topic]!['total'] += 1;
      if (isCorrect) topicAnalysis[topic]!['correct'] += 1;
      topicAnalysis[topic]!['totalTime'] += timeSpent;
      topicAnalysis[topic]!['questions'].add(data);

      // Difficulty analysis
      if (!difficultyAnalysis.containsKey(difficulty)) {
        difficultyAnalysis[difficulty] = {
          'total': 0,
          'correct': 0,
          'totalTime': 0,
        };
      }
      difficultyAnalysis[difficulty]!['total'] += 1;
      if (isCorrect) difficultyAnalysis[difficulty]!['correct'] += 1;
      difficultyAnalysis[difficulty]!['totalTime'] += timeSpent;
    }

    // Calculate accuracies and average times
    topicAnalysis.forEach((key, value) {
      value['accuracy'] =
          value['total'] > 0 ? (value['correct'] / value['total']) * 100 : 0;
      value['averageTime'] =
          value['total'] > 0 ? value['totalTime'] / value['total'] : 30;
    });

    difficultyAnalysis.forEach((key, value) {
      value['accuracy'] =
          value['total'] > 0 ? (value['correct'] / value['total']) * 100 : 0;
      value['averageTime'] =
          value['total'] > 0 ? value['totalTime'] / value['total'] : 30;
    });

    // Identify weak areas (accuracy < 70%) and slow areas (time > 40s)
    List<String> weakTopics = topicAnalysis.entries
        .where((entry) => entry.value['accuracy'] < 70)
        .map((entry) => entry.key)
        .toList();

    List<String> slowTopics = topicAnalysis.entries
        .where((entry) => entry.value['averageTime'] > 40)
        .map((entry) => entry.key)
        .toList();

    List<String> strongTopics = topicAnalysis.entries
        .where((entry) => entry.value['accuracy'] >= 85)
        .map((entry) => entry.key)
        .toList();

    double overallAccuracy = _performanceData.isNotEmpty
        ? (_performanceData.where((q) => q['isCorrect'] == true).length /
                _performanceData.length) *
            100
        : 0;

    return {
      'analyzedQuestions': _performanceData,
      'topicAnalysis': topicAnalysis,
      'difficultyAnalysis': difficultyAnalysis,
      'weakTopics': weakTopics,
      'slowTopics': slowTopics,
      'strongTopics': strongTopics,
      'overallAccuracy': overallAccuracy,
      'averageTime': _performanceData.isNotEmpty
          ? _performanceData
                  .map((q) => q['timeSpent'] ?? 30)
                  .reduce((a, b) => a + b) /
              _performanceData.length
          : 30,
    };
  }

  String _extractTopicFromQuestion(Map<String, dynamic> question) {
    String questionText = question['question'] ?? '';
    String lowerText = questionText.toLowerCase();

    // Enhanced topic extraction based on programming language and content
    if (widget.type == 'programming') {
      if (lowerText.contains('variable') || lowerText.contains('declaration'))
        return 'Variables';
      if (lowerText.contains('function') || lowerText.contains('method'))
        return 'Functions';
      if (lowerText.contains('loop') ||
          lowerText.contains('for') ||
          lowerText.contains('while')) return 'Loops';
      if (lowerText.contains('array') || lowerText.contains('list'))
        return 'Arrays';
      if (lowerText.contains('object') || lowerText.contains('class'))
        return 'OOP';
      if (lowerText.contains('condition') || lowerText.contains('if'))
        return 'Conditionals';
      if (lowerText.contains('exception') || lowerText.contains('error'))
        return 'Error Handling';
      if (lowerText.contains('string')) return 'Strings';
      if (lowerText.contains('algorithm') || lowerText.contains('sort'))
        return 'Algorithms';
      if (lowerText.contains('data structure')) return 'Data Structures';
    }

    return widget.subtopicName;
  }

  void _selectAnswer(String answer) {
    if (_isDisposed || !mounted || _isSubmitted || _currentQuestion == null)
      return;

    // Record answer time and performance data
    _questionAnswerTimes[_currentQuestionIndex] =
        DateTime.now().millisecondsSinceEpoch;

    final questionStartTime = _questionStartTimes[_currentQuestionIndex] ??
        DateTime.now().millisecondsSinceEpoch;
    final timeSpent =
        ((DateTime.now().millisecondsSinceEpoch - questionStartTime) / 1000)
            .round();
    final isCorrect = answer == _currentQuestion!['correct_answer'];

    setState(() {
      _selectedAnswers[_currentQuestionIndex] = answer;
    });

    // Track performance for analytics only (no adaptive generation)
    String topic = _extractTopicFromQuestion(_currentQuestion!);
    String difficulty = _currentQuestion!['difficulty'] ?? 'Medium';

    _performanceData.add({
      'questionIndex': _currentQuestionIndex,
      'topic': topic,
      'difficulty': difficulty,
      'isCorrect': isCorrect,
      'timeSpent': timeSpent,
      'selectedAnswer': answer,
      'correctAnswer': _currentQuestion!['correct_answer'],
      'timestamp': DateTime.now().toIso8601String(),
      'question': _currentQuestion!['question'],
    });

    // Update progress in database with error handling
    if (_sessionId != null) {
      QuizStorageService.updateQuizProgress(
        sessionId: _sessionId!,
        questionIndex: _currentQuestionIndex,
        selectedAnswer: answer,
        isCorrect: isCorrect,
        xpEarned: isCorrect ? 4 : 0,
        timeSpent: _getTotalTimeSpent(),
      ).catchError((e) {
        print('Error updating quiz progress: $e');
        // Continue anyway - don't block user experience
      });
    }
  }

  void _nextQuestion() {
    if (_isDisposed ||
        !mounted ||
        _currentQuestionIndex >= widget.questions.length - 1) return;

    setState(() {
      _currentQuestionIndex++;
      _questionStartTimes[_currentQuestionIndex] =
          DateTime.now().millisecondsSinceEpoch;
    });
    _slideController.reset();
    _slideController.forward();
  }

  void _previousQuestion() {
    if (_isDisposed || !mounted || _currentQuestionIndex <= 0) return;

    setState(() {
      _currentQuestionIndex--;
    });
    _slideController.reset();
    _slideController.forward();
  }

  void _goToQuestion(int index) {
    if (_isDisposed ||
        !mounted ||
        index < 0 ||
        index >= widget.questions.length) return;

    setState(() {
      _currentQuestionIndex = index;
      if (!_questionStartTimes.containsKey(index)) {
        _questionStartTimes[index] = DateTime.now().millisecondsSinceEpoch;
      }
    });
    _slideController.reset();
    _slideController.forward();
    Navigator.pop(context);
  }

  void _showQuestionNavigator() {
    if (_isDisposed || !mounted) return;

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
                          border: isCurrent
                              ? Border.all(
                                  color: AppTheme.secondaryColor,
                                  width: 2,
                                )
                              : null,
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
    if (_isDisposed || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit Quiz?'),
        content: Text(
            'Are you sure you want to submit? You cannot change your answers after submission.'),
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
    if (_isDisposed || !mounted) return;

    _quizTimer?.cancel();
    _processResults();
  }

  void _showErrorDialog(String message) {
    if (_isDisposed || !mounted) return;

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
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: Text('Go Back'),
          ),
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
                _retryQuiz();
              }
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryQuiz() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 2));

    if (!_isDisposed && mounted) {
      setState(() {
        _currentQuestionIndex = 0;
        _selectedAnswers = List.filled(widget.questions.length, null);
        _isSubmitted = false;
        _timeRemaining = 1200;
        _showTimeWarning = false;
        _correctAnswers = 0;
        _totalXP = 0;
        _questionHistory = [];
        _performanceData = [];
        _isLoading = false;
        _questionStartTimes.clear();
        _questionAnswerTimes.clear();
      });

      _questionStartTimes[0] = DateTime.now().millisecondsSinceEpoch;

      _slideController.reset();
      _slideController.forward();
      _startTimer();
    }
  }

  Future<void> _processResults() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isSubmitted = true;
    });

    // Calculate detailed question history with timing and performance data
    for (int i = 0; i < widget.questions.length; i++) {
      final question = widget.questions[i];
      final selectedAnswer = _selectedAnswers[i];
      final correctAnswer = question['correct_answer'];
      final isCorrect = selectedAnswer == correctAnswer;

      if (isCorrect) {
        _correctAnswers++;
        _totalXP += 4;
      }

      // Calculate time spent on this specific question
      int questionTime = 0;
      if (_questionStartTimes.containsKey(i)) {
        final startTime = _questionStartTimes[i]!;
        final endTime =
            _questionAnswerTimes[i] ?? DateTime.now().millisecondsSinceEpoch;
        questionTime = ((endTime - startTime) / 1000).round();
      }

      String topic = _extractTopicFromQuestion(question);
      String difficulty = question['difficulty'] ?? 'Medium';

      _questionHistory.add({
        'question': question,
        'selected_answer': selectedAnswer,
        'is_correct': isCorrect,
        'xp_earned': isCorrect ? 4 : 0,
        'timestamp': DateTime.now().toIso8601String(),
        'time_spent_on_question': questionTime,
        'question_index': i,
        'topic': topic,
        'difficulty': difficulty,
        'is_adaptive': false, // No adaptive questions anymore
      });
    }

    if (_totalXP > 0) {
      _updateUserXP(_totalXP).catchError((e) {
        print('Error updating XP: $e');
        // Don't block user experience
      });
    }

    // Store quiz completion in database
    if (_sessionId != null) {
      try {
        await QuizStorageService.storeQuizCompletion(
          sessionId: _sessionId!,
          totalQuestions: widget.questions.length,
          correctAnswers: _correctAnswers,
          totalXP: _totalXP,
          timeSpent: _getTotalTimeSpent(),
          questionHistory: _questionHistory,
          status: 'completed',
        );

        _sessionId = null;
      } catch (e) {
        print('Error storing quiz completion: $e');
        // Continue to results anyway
      }
    }

    if (!_isDisposed && mounted) {
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
            performanceData:
                _performanceData, // Keep performance data for analytics
            adaptiveTriggered: false, // No adaptive questions triggered
          ),
        ),
      );
    }
  }

  Future<void> _updateUserXP(int xp) async {
    if (_isDisposed || !mounted) return;

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

  Future<void> _storeQuizAbandonment() async {
    // Fire and forget - don't await in dispose to prevent blocking
    if (_sessionId != null) {
      final answeredCount =
          _selectedAnswers.where((answer) => answer != null).length;
      int correctCount = 0;
      int xpEarned = 0;

      for (int i = 0; i < widget.questions.length; i++) {
        if (_selectedAnswers[i] != null) {
          final isCorrect =
              _selectedAnswers[i] == widget.questions[i]['correct_answer'];
          if (isCorrect) {
            correctCount++;
            xpEarned += 4;
          }
        }
      }

      QuizStorageService.storeQuizAbandonment(
        sessionId: _sessionId!,
        questionsAnswered: answeredCount,
        correctAnswers: correctCount,
        xpEarned: xpEarned,
        timeSpent: _getTotalTimeSpent(),
        reason: 'user_exit',
      ).catchError((e) {
        print('Error storing quiz abandonment: $e');
      });
    }
  }

  int _getTotalTimeSpent() {
    return ((DateTime.now().millisecondsSinceEpoch - _sessionStartTime) / 1000)
        .round();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int get _answeredCount =>
      _selectedAnswers.where((answer) => answer != null).length;

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return Container(); // Return empty container if disposed
    }

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
                  'Loading test questions...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_sessionId != null) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Session: ${_sessionId!.substring(0, 8)}...',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10.sp,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        if (_isSubmitted || _isDisposed || !mounted) return true;

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Exit Quiz?'),
            content: Text(
                'Your progress will be lost. Are you sure you want to exit?'),
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
              if (_isDisposed || !mounted) return;

              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Exit Quiz?'),
                  content: Text(
                      'Your progress will be lost. Are you sure you want to exit?'),
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

              if (shouldExit == true && mounted) {
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  margin: EdgeInsets.only(right: 16.w),
                  decoration: BoxDecoration(
                    color:
                        _showTimeWarning ? Colors.red : AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: _showTimeWarning
                        ? [
                            BoxShadow(
                              color: Colors.red
                                  .withOpacity(_timerAnimation.value * 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
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
              // COMPACT HEADER SECTION
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 16.w, vertical: 12.h), // Reduced padding
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
                    // Main row with topic info and navigation
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
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Question ${_currentQuestionIndex + 1}/${widget.questions.length} • ${_answeredCount} answered',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Question navigator button
                        GestureDetector(
                          onTap: _showQuestionNavigator,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.grid_view,
                                  color: Colors.white,
                                  size: 14.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '${_answeredCount}/${widget.questions.length}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 8.h),

                    // Progress bar row
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: (_currentQuestionIndex + 1) /
                                widget.questions.length,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.secondaryColor),
                            minHeight: 6.h,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          '${(((_currentQuestionIndex + 1) / widget.questions.length) * 100).toInt()}%',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Session tracking (if exists)
                    if (_sessionId != null) ...[
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'Tracked',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 9.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 10.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: _getDifficultyColor(
                                      _currentQuestion!['difficulty']),
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
                                  if (_isDisposed || !mounted) return;

                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Row(
                                        children: [
                                          Icon(Icons.lightbulb,
                                              color: Colors.amber),
                                          SizedBox(width: 8.w),
                                          Text('Hint'),
                                        ],
                                      ),
                                      content: Container(
                                        constraints: BoxConstraints(
                                          maxHeight: 300.h,
                                          maxWidth: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.8,
                                        ),
                                        child: SingleChildScrollView(
                                          child: Text(
                                            _currentQuestion!['hint'] ??
                                                'No hint available',
                                            style: GoogleFonts.poppins(
                                                fontSize: 14.sp),
                                          ),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
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
                              (_currentQuestion!['options'] as List?)?.length ??
                                  0,
                              (index) {
                                final option =
                                    _currentQuestion!['options'][index];
                                final isSelected =
                                    _selectedAnswers[_currentQuestionIndex] ==
                                        option;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 10.h),
                                  child: Material(
                                    color: isSelected
                                        ? AppTheme.secondaryColor
                                            .withOpacity(0.1)
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
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                          onPressed: () {
                            if (!_isDisposed && mounted) {
                              _previousQuestion();
                            }
                          },
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
                        onPressed: () {
                          if (_isDisposed || !mounted) return;

                          if (_currentQuestionIndex ==
                              widget.questions.length - 1) {
                            _submitQuiz();
                          } else {
                            _nextQuestion();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _currentQuestionIndex ==
                                  widget.questions.length - 1
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
