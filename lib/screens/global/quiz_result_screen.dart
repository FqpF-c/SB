// File: lib/screens/quiz/quiz_result_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/progress_service.dart';
import '../../providers/progress_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'quiz_report_viewer_screen.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../providers/auth_provider.dart';
import '../../theme/default_theme.dart';
import '../../navbar/navbar.dart';
import 'practice_mode_screen.dart';
import 'test_mode_screen.dart';

class QuizResultScreen extends StatefulWidget {
  final String mode;
  final String topicName;
  final String subtopicName;
  final int totalQuestions;
  final int correctAnswers;
  final int totalXP;
  final List<Map<String, dynamic>> questionHistory;
  final String type;
  final Map<String, dynamic> quizParams;
  final int? timeSpent;
  final List<Map<String, dynamic>>? performanceData;
  final bool? adaptiveTriggered;

  const QuizResultScreen({
    Key? key,
    required this.mode,
    required this.topicName,
    required this.subtopicName,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.totalXP,
    required this.questionHistory,
    required this.type,
    required this.quizParams,
    this.timeSpent,
    this.performanceData,
    this.adaptiveTriggered,
  }) : super(key: key);

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _slideController;
  late AnimationController _progressController;
  late Animation<double> _confettiAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _progressAnimation;

  bool _isSavingSession = false;
  bool _isGeneratingPDF = false;
  String? _sessionId;

  // Performance analysis data
  Map<String, dynamic> _performanceAnalysis = {};
  Map<String, Map<String, dynamic>> _topicBreakdown = {};
  Map<String, Map<String, dynamic>> _difficultyBreakdown = {};
  List<String> _weakAreas = [];
  List<String> _strongAreas = [];
  Map<String, dynamic> _timeAnalysis = {};

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _analyzePerformance();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveQuizSession();
    });
  }

  void _initializeAnimations() {
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _confettiAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _confettiController,
      curve: Curves.easeOutBack,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.totalQuestions > 0
          ? (widget.correctAnswers / widget.totalQuestions)
          : 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _progressController.forward();
    });

    if (widget.totalQuestions > 0 &&
        (_getPerformanceGrade() == 'Excellent' ||
            _getPerformanceGrade() == 'Great')) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _confettiController.forward();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _slideController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _analyzePerformance() {
    if (widget.performanceData == null || widget.performanceData!.isEmpty) {
      _analyzeFromQuestionHistory();
      return;
    }

    // Analyze topics
    Map<String, Map<String, dynamic>> topicStats = {};
    Map<String, Map<String, dynamic>> difficultyStats = {};
    Map<String, List<int>> topicTimes = {};

    for (var data in widget.performanceData!) {
      String topic = data['topic'] ?? 'General';
      String difficulty = data['difficulty'] ?? 'Medium';
      bool isCorrect = data['isCorrect'] ?? false;
      int timeSpent = data['timeSpent'] ?? 30;

      // Topic analysis
      if (!topicStats.containsKey(topic)) {
        topicStats[topic] = {
          'total': 0,
          'correct': 0,
          'totalTime': 0,
          'minTime': 999,
          'maxTime': 0,
        };
        topicTimes[topic] = [];
      }

      topicStats[topic]!['total'] += 1;
      if (isCorrect) topicStats[topic]!['correct'] += 1;
      topicStats[topic]!['totalTime'] += timeSpent;
      topicStats[topic]!['minTime'] =
          math.min<int>(topicStats[topic]!['minTime'] as int, timeSpent);
      topicStats[topic]!['maxTime'] =
          math.max<int>(topicStats[topic]!['maxTime'] as int, timeSpent);
      topicTimes[topic]!.add(timeSpent);

      // Difficulty analysis
      if (!difficultyStats.containsKey(difficulty)) {
        difficultyStats[difficulty] = {
          'total': 0,
          'correct': 0,
          'totalTime': 0,
        };
      }

      difficultyStats[difficulty]!['total'] += 1;
      if (isCorrect) difficultyStats[difficulty]!['correct'] += 1;
      difficultyStats[difficulty]!['totalTime'] += timeSpent;
    }

    // Calculate averages and percentages
    topicStats.forEach((topic, stats) {
      stats['accuracy'] =
          stats['total'] > 0 ? (stats['correct'] / stats['total']) * 100 : 0;
      stats['averageTime'] =
          stats['total'] > 0 ? stats['totalTime'] / stats['total'] : 0;

      // Calculate median time
      List<int> times = topicTimes[topic]!..sort();
      if (times.isNotEmpty) {
        int middle = times.length ~/ 2;
        stats['medianTime'] = times.length % 2 == 0
            ? (times[middle - 1] + times[middle]) / 2
            : times[middle];
      }
    });

    difficultyStats.forEach((difficulty, stats) {
      stats['accuracy'] =
          stats['total'] > 0 ? (stats['correct'] / stats['total']) * 100 : 0;
      stats['averageTime'] =
          stats['total'] > 0 ? stats['totalTime'] / stats['total'] : 0;
    });

    // Identify weak and strong areas
    List<String> weakAreas = [];
    List<String> strongAreas = [];

    topicStats.forEach((topic, stats) {
      double accuracy = stats['accuracy'];
      if (accuracy < 60) {
        weakAreas.add(topic);
      } else if (accuracy >= 85) {
        strongAreas.add(topic);
      }
    });

    // Time analysis
    List<int> allTimes = widget.performanceData!
        .map((d) => d['timeSpent'] ?? 30)
        .cast<int>()
        .toList();
    allTimes.sort();

    Map<String, dynamic> timeAnalysis = {
      'averageTime': allTimes.isNotEmpty
          ? allTimes.reduce((a, b) => a + b) / allTimes.length
          : 0,
      'medianTime': allTimes.isNotEmpty ? allTimes[allTimes.length ~/ 2] : 0,
      'minTime': allTimes.isNotEmpty ? allTimes.first : 0,
      'maxTime': allTimes.isNotEmpty ? allTimes.last : 0,
      'consistency': _calculateTimeConsistency(allTimes),
    };

    setState(() {
      _topicBreakdown = topicStats;
      _difficultyBreakdown = difficultyStats;
      _weakAreas = weakAreas;
      _strongAreas = strongAreas;
      _timeAnalysis = timeAnalysis;
      _performanceAnalysis = {
        'overallAccuracy': widget.totalQuestions > 0
            ? (widget.correctAnswers / widget.totalQuestions) * 100
            : 0,
        'totalQuestions': widget.totalQuestions,
        'correctAnswers': widget.correctAnswers,
        'adaptiveTriggered': widget.adaptiveTriggered ?? false,
      };
    });
  }

  void _analyzeFromQuestionHistory() {
    // Fallback analysis from question history if performance data is not available
    Map<String, Map<String, dynamic>> topicStats = {};

    for (var history in widget.questionHistory) {
      String topic = history['topic'] ?? 'General';
      bool isCorrect = history['is_correct'] ?? false;

      if (!topicStats.containsKey(topic)) {
        topicStats[topic] = {'total': 0, 'correct': 0};
      }

      topicStats[topic]!['total'] += 1;
      if (isCorrect) topicStats[topic]!['correct'] += 1;
    }

    topicStats.forEach((topic, stats) {
      stats['accuracy'] =
          stats['total'] > 0 ? (stats['correct'] / stats['total']) * 100 : 0;
    });

    // Identify weak and strong areas from question history
    List<String> weakAreas = [];
    List<String> strongAreas = [];

    topicStats.forEach((topic, stats) {
      double accuracy = stats['accuracy'];
      if (accuracy < 60) {
        weakAreas.add(topic);
      } else if (accuracy >= 85) {
        strongAreas.add(topic);
      }
    });

    setState(() {
      _topicBreakdown = topicStats;
      _weakAreas = weakAreas;
      _strongAreas = strongAreas;
      _performanceAnalysis = {
        'overallAccuracy': widget.totalQuestions > 0
            ? (widget.correctAnswers / widget.totalQuestions) * 100
            : 0,
        'totalQuestions': widget.totalQuestions,
        'correctAnswers': widget.correctAnswers,
      };
    });
  }

  double _calculateTimeConsistency(List<int> times) {
    if (times.length < 2) return 100.0;

    double mean = times.reduce((a, b) => a + b) / times.length;
    double variance = times
            .map((t) => math.pow(t - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        times.length;
    double stdDev = math.sqrt(variance);

    double result = 100 - (stdDev / mean * 100);
    return math.max<double>(0.0, result).clamp(0.0, 100.0);
  }

  Future<void> _saveQuizSession() async {
    if (widget.totalQuestions <= 0) {
      print('No questions answered - creating minimal session record');
      setState(() {
        _isSavingSession = false;
      });
      return;
    }

    setState(() {
      _isSavingSession = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      _sessionId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';

      final accuracy = widget.totalQuestions > 0
          ? ((widget.correctAnswers / widget.totalQuestions) * 100).round()
          : 0;

      await _updateProgressInFirebase(accuracy);

      final sessionData = {
        'sessionId': _sessionId,
        'userId': user.uid,
        'mode': widget.mode,
        'type': widget.type,
        'topicName': widget.topicName,
        'subtopicName': widget.subtopicName,
        'totalQuestions': widget.totalQuestions,
        'correctAnswers': widget.correctAnswers,
        'wrongAnswers': widget.totalQuestions - widget.correctAnswers,
        'accuracy': accuracy,
        'totalXP': widget.totalXP,
        'timeSpent': widget.timeSpent ?? 0,
        'quizParams': widget.quizParams,
        'questionHistory': widget.questionHistory,
        'completedAt': ServerValue.timestamp,
        'grade': _getPerformanceGrade(),
        'score': _calculateScore(),
        'performanceAnalysis': _performanceAnalysis,
        'topicBreakdown': _topicBreakdown,
        'difficultyBreakdown': _difficultyBreakdown,
        'weakAreas': _weakAreas,
        'strongAreas': _strongAreas,
        'timeAnalysis': _timeAnalysis,
        'adaptiveTriggered': widget.adaptiveTriggered ?? false,
      };

      final databaseRef = FirebaseDatabase.instance.ref();
      await databaseRef
          .child('skillbench/quiz_sessions/${user.uid}/$_sessionId')
          .set(sessionData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('quiz_history')
          .doc(_sessionId)
          .set({
        'sessionId': _sessionId,
        'mode': widget.mode,
        'type': widget.type,
        'topicName': widget.topicName,
        'subtopicName': widget.subtopicName,
        'accuracy': accuracy,
        'totalXP': widget.totalXP,
        'grade': _getPerformanceGrade(),
        'completedAt': Timestamp.now(),
        'questionsAnswered': widget.totalQuestions,
        'adaptiveTriggered': widget.adaptiveTriggered ?? false,
      });

      print('Quiz session saved successfully: $_sessionId');
    } catch (e) {
      print('Error saving quiz session: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to save quiz session');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      }
    }
  }

  Future<void> _updateProgressInFirebase(int accuracy) async {
    if (widget.mode != 'test') {
      print(
          'Progress update skipped - not in test mode (current mode: ${widget.mode})');
      return;
    }

    try {
      final progressProvider =
          Provider.of<ProgressProvider>(context, listen: false);

      Map<String, dynamic> additionalData = {};

      if (widget.type == 'academic') {
        additionalData = {
          'college': widget.quizParams['college'] ?? '',
          'department': widget.quizParams['department'] ?? '',
          'semester': widget.quizParams['semester'] ?? '',
          'unit': widget.quizParams['unit'] ?? '',
        };
      } else if (widget.type == 'programming') {
        // Extract parameters correctly
        String categoryId =
            widget.quizParams['categoryId'] ?? 'Programming Language';
        String subcategory =
            widget.quizParams['subcategory'] ?? widget.topicName;
        String topic = widget.quizParams['topic'] ?? widget.subtopicName;

        // Normalize for the new format: {main_topic}_{subtopic}_{topic}
        String normalizeString(String input) {
          return input
              .replaceAll(' ', '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
              .toLowerCase();
        }

        // Create the new ID format
        String normalizedMainTopic =
            normalizeString(categoryId); // programminglanguage
        String normalizedSubtopic = normalizeString(subcategory); // c
        String normalizedTopic = normalizeString(topic); // cintroduction

        String progressId =
            '${normalizedMainTopic}_${normalizedSubtopic}_${normalizedTopic}';

        print('=== NEW PROGRESS FORMAT DEBUG ===');
        print('Main Topic: $categoryId → $normalizedMainTopic');
        print('Subtopic: $subcategory → $normalizedSubtopic');
        print('Topic: $topic → $normalizedTopic');
        print('Generated Progress ID: $progressId');
        print('================================');

        additionalData = {
          'categoryId': categoryId,
          'subcategory': subcategory,
          'programmingLanguage':
              subcategory, // Use subcategory as programming language
          'mainTopic': categoryId,
          'progressId': progressId,
        };

        // Use the new format for saving
        await progressProvider.updateProgress(
          type: widget.type,
          subject: categoryId, // Main topic (Programming Language)
          subtopic:
              '$subcategory|$topic', // Combined format for internal processing
          score: accuracy,
          totalQuestions: widget.totalQuestions,
          correctAnswers: widget.correctAnswers,
          additionalData: additionalData,
        );

        print('Programming progress saved with new format: $progressId');
        return;
      }

      // For non-programming types, use the original logic
      await progressProvider.updateProgress(
        type: widget.type,
        subject: widget.topicName,
        subtopic: widget.subtopicName,
        score: accuracy,
        totalQuestions: widget.totalQuestions,
        correctAnswers: widget.correctAnswers,
        additionalData: additionalData,
      );

      print(
          'Progress updated successfully for ${widget.topicName} - ${widget.subtopicName} (Test Mode)');
    } catch (e) {
      print('Error updating progress: $e');
    }
  }

  String _getPerformanceGrade() {
    if (widget.totalQuestions <= 0) return 'No Questions Attempted';

    final accuracy = (widget.correctAnswers / widget.totalQuestions) * 100;
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Great';
    if (accuracy >= 70) return 'Good';
    if (accuracy >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  int _calculateScore() {
    if (widget.totalQuestions <= 0) return 0;
    return ((widget.correctAnswers / widget.totalQuestions) * 100).round();
  }

  Color _getGradeColor() {
    switch (_getPerformanceGrade()) {
      case 'Excellent':
        return Colors.green;
      case 'Great':
        return Colors.lightGreen;
      case 'Good':
        return Colors.orange;
      case 'Fair':
        return Colors.deepOrange;
      default:
        return Colors.red;
    }
  }

  IconData _getGradeIcon() {
    switch (_getPerformanceGrade()) {
      case 'Excellent':
        return Icons.emoji_events;
      case 'Great':
        return Icons.star;
      case 'Good':
        return Icons.thumb_up;
      case 'Fair':
        return Icons.trending_up;
      default:
        return Icons.school;
    }
  }

  Future<void> _generateAndDownloadPDF() async {
  // Navigate to the report viewer screen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => QuizReportViewerScreen(
        mode: widget.mode,
        topicName: widget.topicName,
        subtopicName: widget.subtopicName,
        totalQuestions: widget.totalQuestions,
        correctAnswers: widget.correctAnswers,
        totalXP: widget.totalXP,
        questionHistory: widget.questionHistory,
        type: widget.type,
        quizParams: widget.quizParams,
        timeSpent: widget.timeSpent,
        performanceData: widget.performanceData,
        topicBreakdown: _topicBreakdown,
        difficultyBreakdown: _difficultyBreakdown,
        weakAreas: _weakAreas,
        strongAreas: _strongAreas,
        timeAnalysis: _timeAnalysis,
      ),
    ),
  );
}


  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const NavBar()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    return WillPopScope(
      onWillPop: () async {
        _navigateToHome();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: Stack(
          children: [
            SafeArea(
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      SizedBox(height: 20.h),
                      _buildScoreHeader(accuracy),
                      SizedBox(height: 30.h),
                      _buildStatsCards(),
                      SizedBox(height: 30.h),
                      _buildQuizInfoCard(),
                      SizedBox(height: 30.h),
                      // Performance Analysis Sections
                      if (_topicBreakdown.isNotEmpty) ...[
                        _buildTopicBreakdownCard(),
                        SizedBox(height: 20.h),
                      ],
                      if (_weakAreas.isNotEmpty || _strongAreas.isNotEmpty) ...[
                        _buildAreasAnalysisCard(),
                        SizedBox(height: 20.h),
                      ],
                      if (_difficultyBreakdown.isNotEmpty) ...[
                        _buildDifficultyAnalysisCard(),
                        SizedBox(height: 20.h),
                      ],
                      if (_timeAnalysis.isNotEmpty) ...[
                        _buildTimeAnalysisCard(),
                        SizedBox(height: 20.h),
                      ],
                      _buildActionButtons(),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSavingSession || _isGeneratingPDF)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.secondaryColor),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          _isSavingSession
                              ? 'Saving session and updating progress...'
                              : 'Generating performance report...',
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreHeader(int accuracy) {
    return Column(
      children: [
        Text(
          widget.totalQuestions <= 0
              ? 'Session Ended'
              : _getPerformanceGrade() == 'Excellent'
                  ? 'Excellent!'
                  : _getPerformanceGrade() == 'Great'
                      ? 'Great Job!'
                      : _getPerformanceGrade() == 'Good'
                          ? 'Good Work!'
                          : _getPerformanceGrade() == 'Fair'
                              ? 'Keep Trying!'
                              : 'Keep Learning!',
          style: GoogleFonts.poppins(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: widget.totalQuestions <= 0 ? Colors.grey : _getGradeColor(),
          ),
        ),
        SizedBox(height: 30.h),
        Container(
          width: 200.w,
          height: 200.w,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return SizedBox(
                    width: 180.w,
                    height: 180.w,
                    child: CircularProgressIndicator(
                      value: widget.totalQuestions <= 0
                          ? 0
                          : _progressAnimation.value,
                      strokeWidth: 12.w,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          widget.totalQuestions <= 0
                              ? Colors.grey
                              : _getGradeColor()),
                    ),
                  );
                },
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.totalQuestions <= 0
                        ? Icons.info_outline
                        : _getGradeIcon(),
                    size: 40.sp,
                    color: widget.totalQuestions <= 0
                        ? Colors.grey
                        : _getGradeColor(),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.totalQuestions <= 0 ? '0%' : '$accuracy%',
                    style: GoogleFonts.poppins(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'Accuracy',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Correct',
            value: '${widget.correctAnswers}',
            subtitle: 'out of ${widget.totalQuestions}',
            color: Colors.green,
            icon: Icons.check_circle,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: _buildStatCard(
            title: 'XP Earned',
            value: '${widget.totalXP}',
            subtitle: widget.mode == 'practice'
                ? '2 XP per correct'
                : '4 XP per correct',
            color: AppTheme.secondaryColor,
            icon: Icons.stars,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32.sp,
            color: color,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 10.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuizInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.type == 'programming' ? Icons.code : Icons.school,
                color: Colors.white,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Quiz Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildInfoRow('Mode', widget.mode.toUpperCase()),
          _buildInfoRow('Type', widget.type.toUpperCase()),
          _buildInfoRow('Topic', widget.topicName),
          _buildInfoRow('Subtopic', widget.subtopicName),
          if (widget.timeSpent != null)
            _buildInfoRow('Time Spent', _formatTime(widget.timeSpent!)),
          _buildInfoRow('Grade', _getPerformanceGrade()),
        ],
      ),
    );
  }

  Widget _buildTopicBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics,
                color: Colors.blue,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Topic Performance Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Scrollable container with fixed height to show only 2 items
          Container(
            height: 200.h, // Fixed height to show approximately 2 items
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: _topicBreakdown.entries.length,
              itemBuilder: (context, index) {
                var entry = _topicBreakdown.entries.elementAt(index);
                String topic = entry.key;
                Map<String, dynamic> stats = entry.value;
                double accuracy = (stats['accuracy'] ?? 0).toDouble();
                int correct = stats['correct'] ?? 0;
                int total = stats['total'] ?? 0;

                Color accuracyColor = accuracy >= 80
                    ? Colors.green
                    : accuracy >= 60
                        ? Colors.orange
                        : Colors.red;

                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: accuracyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: accuracyColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First line: Topic name and percentage
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              topic,
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: accuracyColor,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '${accuracy.toInt()}%',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Second line: Statistics
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$correct/$total correct',
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (stats['averageTime'] != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Average time: ${(stats['averageTime'] as double).toInt()}s',
                              style: GoogleFonts.poppins(
                                fontSize: 11.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 8.h),
                      LinearProgressIndicator(
                        value: accuracy / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(accuracyColor),
                        minHeight: 6.h,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          // Show scroll indicator if there are more than 2 items
          if (_topicBreakdown.entries.length > 2) ...[
            SizedBox(height: 8.h),
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.grey.shade500,
                    size: 16.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Scroll to view more topics',
                    style: GoogleFonts.poppins(
                      fontSize: 10.sp,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreasAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights,
                color: Colors.purple,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Strengths & Areas for Improvement',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Strong Areas
          if (_strongAreas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.star, color: Colors.green, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Strong Areas',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _strongAreas
                  .map((area) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.r),
                          border:
                              Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Text(
                          area,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 16.h),
          ],

          // Weak Areas
          if (_weakAreas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.red, size: 20.sp),
                SizedBox(width: 8.w),
                Text(
                  'Areas for Improvement',
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _weakAreas
                  .map((area) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.r),
                          border:
                              Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Text(
                          area,
                          style: GoogleFonts.poppins(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
          ],

          if (_strongAreas.isEmpty && _weakAreas.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey.shade600),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'Complete more questions to get detailed area analysis',
                      style: GoogleFonts.poppins(
                        fontSize: 14.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultyAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: Colors.orange,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Difficulty Level Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ..._difficultyBreakdown.entries.map((entry) {
            String difficulty = entry.key;
            Map<String, dynamic> stats = entry.value;
            double accuracy = (stats['accuracy'] ?? 0).toDouble();
            int correct = stats['correct'] ?? 0;
            int total = stats['total'] ?? 0;

            Color difficultyColor = difficulty == 'Easy'
                ? Colors.green
                : difficulty == 'Medium'
                    ? Colors.orange
                    : Colors.red;

            return Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: difficultyColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: difficultyColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First line: Difficulty name and percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        difficulty,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: difficultyColor,
                        ),
                      ),
                      Text(
                        '${accuracy.toInt()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: difficultyColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  // Second line: Statistics
                  Text(
                    '$correct/$total correct',
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  LinearProgressIndicator(
                    value: accuracy / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
                    minHeight: 4.h,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTimeAnalysisCard() {
    double avgTime = (_timeAnalysis['averageTime'] ?? 0).toDouble();
    double consistency = (_timeAnalysis['consistency'] ?? 0).toDouble();
    int minTime = (_timeAnalysis['minTime'] ?? 0).toInt();
    int maxTime = (_timeAnalysis['maxTime'] ?? 0).toInt();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timer,
                color: Colors.teal,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'Time Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Time stats in 2x2 grid format
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTimeStatItem(
                      'Average Time',
                      '${avgTime.toInt()}s',
                      Icons.access_time,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildTimeStatItem(
                      'Consistency',
                      '${consistency.toInt()}%',
                      Icons.trending_up,
                      consistency >= 70 ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeStatItem(
                      'Fastest',
                      '${minTime}s',
                      Icons.flash_on,
                      Colors.green,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _buildTimeStatItem(
                      'Slowest',
                      '${maxTime}s',
                      Icons.hourglass_bottom,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (consistency < 70) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.orange, size: 20.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Try to maintain consistent timing for better performance',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeStatItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          // First line: Icon and value
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16.sp),
              SizedBox(width: 4.w),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Second line: Label
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80.w,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _navigateToHome,
            icon: Icon(Icons.home, size: 20.sp, color: Colors.white),
            label: Text(
              'Back to Home',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGeneratingPDF ? null : _generateAndDownloadPDF,
            icon: Icon(
              Icons.download,
              size: 20.sp,
              color: _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
            ),
            label: Text(
              _isGeneratingPDF
                  ? 'Generating Analysis Report...'
                  : 'Download Report',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              side: BorderSide(
                color: _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}
