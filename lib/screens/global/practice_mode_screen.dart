import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../../services/quiz_service.dart';
import '../../services/quiz_storage_service.dart';
import '../../providers/auth_provider.dart';
import '../../theme/default_theme.dart';
import 'quiz_result_screen.dart';

class PracticeModeScreen extends StatefulWidget {
  final String type;
  final Map<String, dynamic> quizParams;
  final String topicName;
  final String subtopicName;
  final List<Map<String, dynamic>> initialQuestions;
  final String? sessionId;

  const PracticeModeScreen({
    Key? key,
    required this.type,
    required this.quizParams,
    required this.topicName,
    required this.subtopicName,
    required this.initialQuestions,
    this.sessionId,
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
  bool _isDisposed = false; // Add disposed flag

  int _totalQuestions = 0;
  int _correctAnswers = 0;
  int _totalXP = 0;
  List<Map<String, dynamic>> _questionHistory = [];

  // Enhanced performance tracking for adaptive learning
  List<Map<String, dynamic>> _performanceData = [];
  Map<String, List<int>> _topicTimings = {};
  Map<String, List<bool>> _topicAccuracy = {};
  Map<String, List<bool>> _difficultyAccuracy = {};

  List<Map<String, dynamic>>? _nextBatch;
  Timer? _feedbackTimer;
  Timer? _preloadTimer;
  Timer? _timeTracker;

  String? _sessionId;
  int _sessionStartTime = 0;
  int _currentQuestionStartTime = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePracticeSession();
    _startTimeTracking();
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
    _sessionId = widget.sessionId;

    print(
        'PRACTICE: Initialized with ${_currentBatch.length} questions in first batch');
    print('PRACTICE: Session ID: $_sessionId');

    Timer(const Duration(seconds: 5), () {
      if (!_isDisposed && mounted) {
        _preloadNextBatch();
      }
    });
  }

  void _startTimeTracking() {
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    _currentQuestionStartTime = _sessionStartTime;

    _timeTracker = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    _feedbackController.dispose();
    _confettiController.dispose();
    _feedbackTimer?.cancel();
    _preloadTimer?.cancel();
    _timeTracker?.cancel();

    // Store abandonment only if session exists and questions were attempted
    if (_sessionId != null && _totalQuestions > 0) {
      // Fire and forget - don't await in dispose
      _storeQuizAbandonment();
    }

    super.dispose();
  }

  Map<String, dynamic>? get _currentQuestion {
    if (_currentBatch.isEmpty ||
        _currentQuestionIndex >= _currentBatch.length ||
        _currentQuestionIndex < 0) {
      return null;
    }
    return _currentBatch[_currentQuestionIndex];
  }

  // Check if current question number triggers adaptive generation
  bool _shouldTriggerAdaptiveGeneration() {
    // For practice mode: at questions 8, 18, 28, 38, etc.
    return (_totalQuestions % 10 == 8);
  }

  // Enhanced performance analysis for adaptive generation
  Map<String, dynamic> _analyzePerformanceForAdaptive() {
    if (_performanceData.length < 7) return {};

    // Get last 7-10 questions for analysis (sliding window)
    List<Map<String, dynamic>> recentPerformance = _performanceData.toList();
    if (recentPerformance.length > 10) {
      // Take last 10 questions for analysis
      recentPerformance =
          recentPerformance.sublist(recentPerformance.length - 10);
    }

    Map<String, Map<String, dynamic>> topicAnalysis = {};
    Map<String, Map<String, dynamic>> difficultyAnalysis = {};
    List<int> recentTimes = [];
    int correctCount = 0;

    for (var data in recentPerformance) {
      String topic = data['topic'] ?? 'General';
      String difficulty = data['difficulty'] ?? 'Medium';
      bool isCorrect = data['isCorrect'] ?? false;
      int timeSpent = data['timeSpent'] ?? 30;

      if (isCorrect) correctCount++;
      recentTimes.add(timeSpent);

      // Topic analysis
      if (!topicAnalysis.containsKey(topic)) {
        topicAnalysis[topic] = {
          'total': 0,
          'correct': 0,
          'totalTime': 0,
          'questions': [],
          'recentlyAnswered': true,
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

    double overallAccuracy = recentPerformance.isNotEmpty
        ? (correctCount / recentPerformance.length) * 100
        : 0;

    double averageTime = recentTimes.isNotEmpty
        ? recentTimes.reduce((a, b) => a + b) / recentTimes.length
        : 30;

    // Generate insights for better adaptive generation
    Map<String, String> insights = {};
    if (weakTopics.isNotEmpty) {
      insights['weak_areas'] =
          'Focus on ${weakTopics.join(", ")} with foundational questions';
    }
    if (strongTopics.isNotEmpty) {
      insights['strong_areas'] =
          'Challenge ${strongTopics.join(", ")} with advanced questions';
    }
    if (averageTime > 40) {
      insights['time_improvement'] = 'Generate clearer, more direct questions';
    }
    if (overallAccuracy < 60) {
      insights['difficulty'] = 'Reduce complexity and focus on basics';
    }

    return {
      'recentQuestions': recentPerformance,
      'topicAnalysis': topicAnalysis,
      'difficultyAnalysis': difficultyAnalysis,
      'weakTopics': weakTopics,
      'slowTopics': slowTopics,
      'strongTopics': strongTopics,
      'overallAccuracy': overallAccuracy,
      'averageTime': averageTime,
      'analysisTriggeredAt': _totalQuestions,
      'questionWindow': recentPerformance.length,
      'insights': insights,
      'recommendedDifficulty': overallAccuracy > 80
          ? 'Hard'
          : overallAccuracy > 60
              ? 'Medium'
              : 'Easy',
    };
  }

  Future<void> _preloadNextBatch() async {
    if (_isDisposed || !mounted || _isPreloadingNext || _nextBatch != null)
      return;

    setState(() {
      _isPreloadingNext = true;
    });

    try {
      print('PRACTICE: Preloading next batch...');

      // Prepare performance data for adaptive generation if we have enough data
      Map<String, dynamic> performanceAnalysis = {};
      bool isAdaptive = false;

      if (_performanceData.length >= 7) {
        performanceAnalysis = _analyzePerformanceForAdaptive();
        isAdaptive = true;
        print('PRACTICE: Sending performance data for adaptive generation');
        print(
            'Performance summary: ${performanceAnalysis['overallAccuracy']}% accuracy, ${performanceAnalysis['averageTime']}s avg time');
        print('Weak topics: ${performanceAnalysis['weakTopics']}');
        print('Strong topics: ${performanceAnalysis['strongTopics']}');
      }

      final nextBatch = await QuizService.generateNextPracticeBatch(
        type: widget.type,
        params: widget.quizParams,
        setCount: _currentBatchIndex + 1,
        performanceData: performanceAnalysis,
      );

      if (!_isDisposed && mounted) {
        _nextBatch = QuizService.validateQuestions(nextBatch);
        print(
            'PRACTICE: Preloaded ${_nextBatch?.length ?? 0} ${isAdaptive ? "adaptive" : "standard"} questions for next batch');
      }
    } catch (e) {
      print('PRACTICE: Error preloading next batch: $e');
    } finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isPreloadingNext = false;
        });
      }
    }
  }

  Future<void> _selectAnswer(String answer) async {
    if (_isDisposed || !mounted || _showFeedback || _currentQuestion == null)
      return;

    final questionStartTime = _currentQuestionStartTime;
    final answerTime = DateTime.now().millisecondsSinceEpoch;
    final timeSpent = ((answerTime - questionStartTime) / 1000).round();

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

    // Enhanced performance tracking
    String topic = _extractTopicFromQuestion(_currentQuestion!);
    String difficulty = _currentQuestion!['difficulty'] ?? 'Medium';

    Map<String, dynamic> performanceEntry = {
      'questionIndex': _totalQuestions - 1,
      'topic': topic,
      'difficulty': difficulty,
      'isCorrect': _isCorrect,
      'timeSpent': timeSpent,
      'selectedAnswer': answer,
      'correctAnswer': _currentQuestion!['correct_answer'],
      'timestamp': DateTime.now().toIso8601String(),
      'question': _currentQuestion!['question'],
      'questionType':
          _currentQuestion!['is_adaptive'] == true ? 'adaptive' : 'standard',
      'batchIndex': _currentBatchIndex,
    };

    _performanceData.add(performanceEntry);

    // Track by topic and difficulty for analysis
    if (!_topicAccuracy.containsKey(topic)) {
      _topicAccuracy[topic] = [];
      _topicTimings[topic] = [];
    }
    _topicAccuracy[topic]!.add(_isCorrect);
    _topicTimings[topic]!.add(timeSpent);

    if (!_difficultyAccuracy.containsKey(difficulty)) {
      _difficultyAccuracy[difficulty] = [];
    }
    _difficultyAccuracy[difficulty]!.add(_isCorrect);

    // Store in database with error handling
    if (_sessionId != null) {
      try {
        await QuizStorageService.updateQuizProgress(
          sessionId: _sessionId!,
          questionIndex: _totalQuestions - 1,
          selectedAnswer: answer,
          isCorrect: _isCorrect,
          xpEarned: _isCorrect ? 2 : 0,
          timeSpent: _getTotalTimeSpent(),
        );
      } catch (e) {
        print('Error updating quiz progress: $e');
        // Continue anyway - don't block user experience
      }
    }

    _questionHistory.add({
      'question': _currentQuestion!,
      'selected_answer': answer,
      'is_correct': _isCorrect,
      'xp_earned': _isCorrect ? 2 : 0,
      'timestamp': DateTime.now().toIso8601String(),
      'time_spent_on_question': timeSpent,
      'topic': topic,
      'difficulty': difficulty,
      'is_adaptive': _currentQuestion!['is_adaptive'] == true,
      'adaptive_reason': _currentQuestion!['adaptive_reason'],
    });

    if (_isCorrect && !_isDisposed && mounted) {
      _updateUserXP(2).catchError((e) {
        print('Error updating XP: $e');
        // Don't block user experience
      });
    }

    if (!_isDisposed && mounted) {
      _feedbackController.forward();
    }

    // Check if we need to trigger adaptive generation
    if (_shouldTriggerAdaptiveGeneration()) {
      print(
          'PRACTICE: Triggering adaptive generation at question $_totalQuestions');
      _triggerAdaptiveGeneration();
    }
  }

  String _extractTopicFromQuestion(Map<String, dynamic> question) {
    String questionText = question['question'] ?? '';
    String lowerText = questionText.toLowerCase();

    // Check if question has explicit topic field (from adaptive generation)
    if (question.containsKey('topic') && question['topic'] != null) {
      return question['topic'];
    }

    // Enhanced topic extraction based on programming language and content
    if (widget.type == 'programming') {
      // Common programming topics
      if (lowerText.contains('variable') ||
          lowerText.contains('declaration') ||
          lowerText.contains('var ') ||
          lowerText.contains('let ')) return 'Variables';
      if (lowerText.contains('function') ||
          lowerText.contains('method') ||
          lowerText.contains('def ') ||
          lowerText.contains('func ')) return 'Functions';
      if (lowerText.contains('loop') ||
          lowerText.contains('for') ||
          lowerText.contains('while') ||
          lowerText.contains('iteration')) return 'Loops';
      if (lowerText.contains('array') ||
          lowerText.contains('list') ||
          lowerText.contains('[]')) return 'Arrays';
      if (lowerText.contains('object') ||
          lowerText.contains('class') ||
          lowerText.contains('instance')) return 'OOP';
      if (lowerText.contains('condition') ||
          lowerText.contains('if') ||
          lowerText.contains('else') ||
          lowerText.contains('switch')) return 'Conditionals';
      if (lowerText.contains('exception') ||
          lowerText.contains('error') ||
          lowerText.contains('try') ||
          lowerText.contains('catch')) return 'Error Handling';
      if (lowerText.contains('string') ||
          lowerText.contains('text') ||
          lowerText.contains('"') ||
          lowerText.contains("'")) return 'Strings';
      if (lowerText.contains('algorithm') ||
          lowerText.contains('sort') ||
          lowerText.contains('search')) return 'Algorithms';
      if (lowerText.contains('data structure') ||
          lowerText.contains('stack') ||
          lowerText.contains('queue')) return 'Data Structures';
      if (lowerText.contains('recursive') || lowerText.contains('recursion'))
        return 'Recursion';
      if (lowerText.contains('pointer') ||
          lowerText.contains('reference') ||
          lowerText.contains('memory')) return 'Memory Management';
    } else if (widget.type == 'academic') {
      // Academic topics based on subject
      String subject = widget.topicName.toLowerCase();
      if (subject.contains('math') || subject.contains('calculus')) {
        if (lowerText.contains('derivative') ||
            lowerText.contains('differentiation')) return 'Derivatives';
        if (lowerText.contains('integral') || lowerText.contains('integration'))
          return 'Integrals';
        if (lowerText.contains('limit')) return 'Limits';
        if (lowerText.contains('equation')) return 'Equations';
      }
      // Add more academic topic extractions as needed
    }

    return widget.subtopicName; // Fallback to subtopic
  }

  void _triggerAdaptiveGeneration() {
    if (_isDisposed || !mounted) return;
    // Clear current preload and generate new adaptive batch
    _nextBatch = null;
    _preloadNextBatch();
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

  Future<void> _nextQuestion() async {
    if (_isDisposed || !mounted) return;

    _feedbackTimer?.cancel();

    if (!_showFeedback && _currentQuestion != null) {
      // Handle skipped question
      String topic = _extractTopicFromQuestion(_currentQuestion!);
      String difficulty = _currentQuestion!['difficulty'] ?? 'Medium';
      int timeSpent = _getQuestionTimeSpent();

      _performanceData.add({
        'questionIndex': _totalQuestions,
        'topic': topic,
        'difficulty': difficulty,
        'isCorrect': false,
        'timeSpent': timeSpent,
        'selectedAnswer': null,
        'correctAnswer': _currentQuestion!['correct_answer'],
        'timestamp': DateTime.now().toIso8601String(),
        'question': _currentQuestion!['question'],
        'skipped': true,
        'questionType':
            _currentQuestion!['is_adaptive'] == true ? 'adaptive' : 'standard',
        'batchIndex': _currentBatchIndex,
      });

      _questionHistory.add({
        'question': _currentQuestion!,
        'selected_answer': null,
        'is_correct': false,
        'xp_earned': 0,
        'timestamp': DateTime.now().toIso8601String(),
        'skipped': true,
        'time_spent_on_question': timeSpent,
        'topic': topic,
        'difficulty': difficulty,
        'is_adaptive': _currentQuestion!['is_adaptive'] == true,
      });
      _totalQuestions++;

      if (_sessionId != null) {
        try {
          await QuizStorageService.updateQuizProgress(
            sessionId: _sessionId!,
            questionIndex: _totalQuestions - 1,
            selectedAnswer: null,
            isCorrect: false,
            xpEarned: 0,
            timeSpent: _getTotalTimeSpent(),
          );
        } catch (e) {
          print('Error updating skipped question progress: $e');
        }
      }
    }

    if (_currentQuestionIndex >= _currentBatch.length - 1) {
      await _loadNextBatch();
    } else {
      if (!_isDisposed && mounted) {
        setState(() {
          _currentQuestionIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
          _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (!_isDisposed && mounted) {
          _slideController.forward();
        }
      }
    }
  }

  Future<void> _loadNextBatch() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isLoadingNextBatch = true;
    });

    try {
      List<Map<String, dynamic>> nextBatch;
      bool isAdaptiveBatch = false;

      if (_nextBatch != null && _nextBatch!.isNotEmpty) {
        nextBatch = _nextBatch!;
        _nextBatch = null;
        isAdaptiveBatch = _performanceData.length >= 7;
        print(
            'PRACTICE: Using preloaded ${isAdaptiveBatch ? "adaptive" : "standard"} batch with ${nextBatch.length} questions');
      } else {
        print('PRACTICE: Generating new batch on demand...');

        Map<String, dynamic> performanceAnalysis = {};
        if (_performanceData.length >= 7) {
          performanceAnalysis = _analyzePerformanceForAdaptive();
          isAdaptiveBatch = true;
        }

        nextBatch = await QuizService.generateNextPracticeBatch(
          type: widget.type,
          params: widget.quizParams,
          setCount: _currentBatchIndex + 1,
          performanceData: performanceAnalysis,
        );
        nextBatch = QuizService.validateQuestions(nextBatch);
      }

      if (nextBatch.isEmpty) {
        throw Exception('No valid questions in next batch');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _currentBatch = nextBatch;
          _allQuestions.addAll(nextBatch);
          _currentQuestionIndex = 0;
          _currentBatchIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
          _isLoadingNextBatch = false;
          _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (!_isDisposed && mounted) {
          _slideController.forward();
        }

        Timer(const Duration(seconds: 3), () {
          if (!_isDisposed && mounted) {
            _preloadNextBatch();
          }
        });

        // Show adaptive notification if this was an adaptive batch
        if (isAdaptiveBatch) {
          _showAdaptiveNotification();
        }
      }
    } catch (e) {
      print('Error loading next batch: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingNextBatch = false;
        });
        _showErrorDialog('Failed to load next batch: $e');
      }
    }
  }

  void _showAdaptiveNotification() {
    if (_isDisposed || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.psychology, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'Questions adapted based on your performance!',
                style: GoogleFonts.poppins(
                  fontSize: 14.sp,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(16.w),
      ),
    );
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
                _endPractice();
              }
            },
            child: Text('End Practice'),
          ),
          TextButton(
            onPressed: () {
              if (mounted) {
                Navigator.pop(context);
                _retryLoadBatch();
              }
            },
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }

  Future<void> _retryLoadBatch() async {
    if (_isDisposed || !mounted) return;

    setState(() {
      _isLoadingNextBatch = true;
      _nextBatch = null;
    });

    try {
      Map<String, dynamic> performanceAnalysis = {};
      if (_performanceData.length >= 7) {
        performanceAnalysis = _analyzePerformanceForAdaptive();
      }

      final nextBatch = await QuizService.generateNextPracticeBatch(
        type: widget.type,
        params: widget.quizParams,
        setCount: _currentBatchIndex + 1,
        performanceData: performanceAnalysis,
      );

      final validatedBatch = QuizService.validateQuestions(nextBatch);

      if (validatedBatch.isEmpty) {
        throw Exception('No valid questions generated');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _currentBatch = validatedBatch;
          _allQuestions.addAll(validatedBatch);
          _currentQuestionIndex = 0;
          _currentBatchIndex++;
          _selectedAnswer = null;
          _showFeedback = false;
          _isLoadingNextBatch = false;
          _currentQuestionStartTime = DateTime.now().millisecondsSinceEpoch;
        });

        _slideController.reset();
        _feedbackController.reset();
        _confettiController.reset();
        if (!_isDisposed && mounted) {
          _slideController.forward();
        }

        Timer(const Duration(seconds: 3), () {
          if (!_isDisposed && mounted) {
            _preloadNextBatch();
          }
        });
      }
    } catch (e) {
      print('Error retrying batch load: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoadingNextBatch = false;
        });
        _showErrorDialog('Failed to load questions after retry: $e');
      }
    }
  }

  Future<void> _endPractice() async {
    if (_isDisposed) return;

    if (_sessionId != null && _totalQuestions > 0) {
      try {
        await QuizStorageService.storeQuizCompletion(
          sessionId: _sessionId!,
          totalQuestions: _totalQuestions,
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
      // Navigate to enhanced result screen with performance analysis
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
            timeSpent: _getTotalTimeSpent(),
            performanceData: _performanceData, // Add performance data
            adaptiveTriggered: _performanceData.any((q) =>
                q['questionType'] == 'adaptive'), // Check if adaptive was used
          ),
        ),
      );
    }
  }

  Future<void> _storeQuizAbandonment() async {
    // Fire and forget - don't await in dispose to prevent blocking
    if (_sessionId != null) {
      QuizStorageService.storeQuizAbandonment(
        sessionId: _sessionId!,
        questionsAnswered: _totalQuestions,
        correctAnswers: _correctAnswers,
        xpEarned: _totalXP,
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

  int _getQuestionTimeSpent() {
    return ((DateTime.now().millisecondsSinceEpoch -
                _currentQuestionStartTime) /
            1000)
        .round();
  }

  void _showHint() {
    if (_isDisposed || !mounted || _currentQuestion == null) return;

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
    if (_isDisposed || !mounted || _totalQuestions <= 1) return;

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
                    'Practice History & Performance',
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

            // Performance summary
            if (_performanceData.length >= 5) ...[
              Container(
                padding: EdgeInsets.all(16.w),
                color: Colors.purple.shade50,
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.purple, size: 20.sp),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Recent Performance: ${(_performanceData.where((q) => q['isCorrect'] == true).length / _performanceData.length * 100).toInt()}% accuracy',
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: _questionHistory.length,
                itemBuilder: (context, index) {
                  final item = _questionHistory[index];
                  final isCorrect = item['is_correct'];
                  final isSkipped = item['skipped'] ?? false;
                  final isAdaptive = item['is_adaptive'] ?? false;

                  return Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isSkipped
                          ? Colors.orange.shade50
                          : (isCorrect
                              ? Colors.green.shade50
                              : Colors.red.shade50),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: isSkipped
                            ? Colors.orange.shade300
                            : (isCorrect
                                ? Colors.green.shade300
                                : Colors.red.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24.w,
                          height: 24.w,
                          decoration: BoxDecoration(
                            color: isSkipped
                                ? Colors.orange
                                : (isCorrect ? Colors.green : Colors.red),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['question']['question'] ??
                                    'Question ${index + 1}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.sp,
                                  color: AppTheme.primaryColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isAdaptive) ...[
                                SizedBox(height: 4.h),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 6.w, vertical: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.purple,
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Text(
                                    'Adaptive',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8.sp,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Icon(
                              isSkipped
                                  ? Icons.skip_next
                                  : (isCorrect
                                      ? Icons.check_circle
                                      : Icons.cancel),
                              color: isSkipped
                                  ? Colors.orange
                                  : (isCorrect ? Colors.green : Colors.red),
                              size: 20.sp,
                            ),
                            if (item['time_spent_on_question'] != null) ...[
                              SizedBox(height: 2.h),
                              Text(
                                '${item['time_spent_on_question']}s',
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
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

  void _showPerformanceInsights() {
    if (_isDisposed || !mounted || _performanceData.length < 5) return;

    Map<String, dynamic> analysis = _analyzePerformanceForAdaptive();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.analytics, color: Colors.purple),
            SizedBox(width: 8.w),
            Text('Performance Insights'),
          ],
        ),
        content: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Overall Accuracy: ${analysis['overallAccuracy']?.toInt() ?? 0}%',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Average Time: ${analysis['averageTime']?.toInt() ?? 0}s per question',
                  style: GoogleFonts.poppins(fontSize: 14.sp),
                ),
                SizedBox(height: 16.h),
                if (analysis['weakTopics']?.isNotEmpty == true) ...[
                  Text(
                    'Areas to Focus On:',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  ...((analysis['weakTopics'] as List).map((topic) => Padding(
                        padding: EdgeInsets.only(left: 8.w, bottom: 2.h),
                        child: Text(
                          '• $topic',
                          style: GoogleFonts.poppins(fontSize: 12.sp),
                        ),
                      ))),
                  SizedBox(height: 12.h),
                ],
                if (analysis['strongTopics']?.isNotEmpty == true) ...[
                  Text(
                    'Areas of Strength:',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  ...((analysis['strongTopics'] as List).map((topic) => Padding(
                        padding: EdgeInsets.only(left: 8.w, bottom: 2.h),
                        child: Text(
                          '• $topic',
                          style: GoogleFonts.poppins(fontSize: 12.sp),
                        ),
                      ))),
                  SizedBox(height: 12.h),
                ],
                if (analysis['insights'] != null) ...[
                  Text(
                    'Adaptive Insights:',
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  ...((analysis['insights'] as Map<String, dynamic>)
                      .values
                      .map((insight) => Padding(
                            padding: EdgeInsets.only(left: 8.w, bottom: 2.h),
                            child: Text(
                              '• $insight',
                              style: GoogleFonts.poppins(fontSize: 12.sp),
                            ),
                          ))),
                ],
              ],
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

  @override
  Widget build(BuildContext context) {
    if (_isDisposed) {
      return Container(); // Return empty container if disposed
    }

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
                  _totalQuestions >= 7
                      ? 'Generating adaptive questions...'
                      : 'Loading next 10 questions...',
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
                if (_totalQuestions >= 7) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology,
                            color: Colors.white, size: 16.sp),
                        SizedBox(width: 6.w),
                        Text(
                          'Adapting to your performance...',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.white),
          onPressed: () {
            if (_isDisposed || !mounted) return;

            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('End Practice?'),
                content: Text(
                    'Are you sure you want to end this practice session? Your progress will be saved.'),
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
        child: Stack(
          children: [
            // Main content
            Column(
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
                      // Main row with topic info and actions
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
                                    fontSize: 14.sp, // Reduced from 16.sp
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1, // Reduced from 2
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Q${_totalQuestions + 1} • Batch ${_currentBatchIndex + 1} • ${((_correctAnswers / (_totalQuestions > 0 ? _totalQuestions : 1)) * 100).toInt()}%',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 11.sp, // Compact info in one line
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Compact action buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_performanceData.length >= 5)
                                GestureDetector(
                                  onTap: _showPerformanceInsights,
                                  child: Container(
                                    padding: EdgeInsets.all(6.w),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.analytics,
                                      color: Colors.purple.shade200,
                                      size: 18.sp,
                                    ),
                                  ),
                                ),
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: _showHint,
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.help_outline,
                                    color: Colors.amber,
                                    size: 18.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              if (_totalQuestions > 0)
                                GestureDetector(
                                  onTap: _showQuestionNavigator,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.history,
                                            color: Colors.white, size: 14.sp),
                                        SizedBox(width: 4.w),
                                        Text(
                                          'History',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),

                      // Status indicators row (only show important ones)
                      if (_isPreloadingNext || _sessionId != null) ...[
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Preloading indicator
                            if (_isPreloadingNext)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10.w,
                                      height: 10.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      _performanceData.length >= 7
                                          ? 'Adapting...'
                                          : 'Loading...',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 9.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Session tracking (compact)
                            if (_sessionId != null)
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
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10.w, vertical: 4.h),
                                      decoration: BoxDecoration(
                                        color: _getDifficultyColor(
                                            _currentQuestion!['difficulty']),
                                        borderRadius:
                                            BorderRadius.circular(20.r),
                                      ),
                                      child: Text(
                                        _currentQuestion!['difficulty'] ??
                                            'Medium',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (_currentQuestion!['is_adaptive'] ==
                                        true) ...[
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius:
                                              BorderRadius.circular(20.r),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.psychology,
                                              size: 10.sp,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 4.w),
                                            Text(
                                              'Adaptive',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: 10.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${_currentQuestionIndex + 1}/10',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    color: Colors.grey.shade600,
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
                            ),
                            SizedBox(height: 20.h),
                            Column(
                              children: List.generate(
                                (_currentQuestion!['options'] as List?)
                                        ?.length ??
                                    0,
                                (index) {
                                  final option =
                                      _currentQuestion!['options'][index];
                                  final isSelected = _selectedAnswer == option;
                                  final isCorrect = option ==
                                      _currentQuestion!['correct_answer'];

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
                                    backgroundColor = AppTheme.secondaryColor
                                        .withOpacity(0.1);
                                    borderColor = AppTheme.secondaryColor;
                                  }

                                  return Container(
                                    margin: EdgeInsets.only(bottom: 10.h),
                                    child: Material(
                                      color: backgroundColor,
                                      borderRadius: BorderRadius.circular(12.r),
                                      child: InkWell(
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                        onTap: _showFeedback
                                            ? null
                                            : () => _selectAnswer(option),
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.all(14.w),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: borderColor, width: 2),
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
                                                      ? borderColor
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                      color: borderColor,
                                                      width: 2),
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
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
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
                                              if (_showFeedback &&
                                                  isSelected &&
                                                  !isCorrect)
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
                                        color: _isCorrect
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                        border: Border.all(
                                          color: _isCorrect
                                              ? Colors.green
                                              : Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                _isCorrect
                                                    ? Icons.check_circle
                                                    : Icons.cancel,
                                                color: _isCorrect
                                                    ? Colors.green
                                                    : Colors.red,
                                                size: 20.sp,
                                              ),
                                              SizedBox(width: 8.w),
                                              Text(
                                                _isCorrect
                                                    ? 'Correct! +2 XP'
                                                    : 'Incorrect',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: _isCorrect
                                                      ? Colors.green.shade700
                                                      : Colors.red.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (_currentQuestion![
                                                      'explanation'] !=
                                                  null &&
                                              _currentQuestion!['explanation']
                                                  .toString()
                                                  .isNotEmpty) ...[
                                            SizedBox(height: 8.h),
                                            Text(
                                              _currentQuestion![
                                                      'explanation'] ??
                                                  '',
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
                          onPressed: () {
                            if (!_isDisposed && mounted) {
                              _nextQuestion();
                            }
                          },
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
                            onPressed: () {
                              if (!_isDisposed && mounted) {
                                _endPractice();
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
                          padding: EdgeInsets.symmetric(
                              horizontal: 14.w, vertical: 10.h),
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

            // Fixed confetti overlay - positioned within the body instead of floatingActionButton
            if (_isCorrect && _showFeedback)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _confettiAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: ConstrainedConfettiPainter(
                            _confettiAnimation.value),
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

// Fixed and constrained confetti painter to prevent layout issues
class ConstrainedConfettiPainter extends CustomPainter {
  final double animationValue;

  ConstrainedConfettiPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Ensure we have valid size constraints
    if (size.width <= 0 || size.height <= 0) return;

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

    // Limit confetti to reasonable bounds
    final maxWidth = size.width;
    final maxHeight = size.height;

    for (int i = 0; i < 20; i++) {
      // Reduced from 30 to 20
      paint.color = colors[i % colors.length];

      final baseX = (maxWidth * 0.1) + (i * maxWidth * 0.04) % maxWidth;
      final baseY = -30.0 + (animationValue * (maxHeight + 60));

      final offsetX = (i % 3 - 1) * 15.0 * animationValue; // Reduced movement
      final offsetY = (i % 5) * 8.0;

      final x = (baseX + offsetX).clamp(0.0, maxWidth);
      final y = (baseY + offsetY).clamp(-20.0, maxHeight + 20);

      // Only draw if within reasonable bounds
      if (x >= 0 && x <= maxWidth && y >= -10 && y <= maxHeight + 10) {
        if (i % 3 == 0) {
          canvas.drawCircle(Offset(x, y), 2.5, paint); // Smaller particles
        } else if (i % 3 == 1) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 4, height: 4),
            paint,
          );
        } else {
          final path = Path();
          path.moveTo(x, y - 2);
          path.lineTo(x - 2, y + 2);
          path.lineTo(x + 2, y + 2);
          path.close();
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(ConstrainedConfettiPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
