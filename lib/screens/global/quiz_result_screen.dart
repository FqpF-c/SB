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
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:math';
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

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
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
      end: widget.totalQuestions > 0 ? (widget.correctAnswers / widget.totalQuestions) : 0.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _slideController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _progressController.forward();
    });

    if (widget.totalQuestions > 0 && (_getPerformanceGrade() == 'Excellent' || _getPerformanceGrade() == 'Great')) {
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
        'accuracy': widget.totalQuestions > 0 ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt() : 0,
        'totalXP': widget.totalXP,
        'timeSpent': widget.timeSpent ?? 0,
        'quizParams': widget.quizParams,
        'questionHistory': widget.questionHistory,
        'completedAt': ServerValue.timestamp,
        'grade': _getPerformanceGrade(),
        'score': _calculateScore(),
        'modeDetails': {
          'practiceMode': {
            'questionsPerBatch': widget.mode == 'practice' ? 10 : null,
            'batchesCompleted': widget.mode == 'practice' ? (widget.totalQuestions / 10).ceil() : null,
            'xpPerQuestion': widget.mode == 'practice' ? 2 : null,
          },
          'testMode': {
            'totalQuestions': widget.mode == 'test' ? 20 : null,
            'timeLimit': widget.mode == 'test' ? 1200 : null,
            'xpPerQuestion': widget.mode == 'test' ? 4 : null,
            'setsCompleted': widget.mode == 'test' ? 2 : null,
          }
        },
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
        'accuracy': widget.totalQuestions > 0 ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt() : 0,
        'totalXP': widget.totalXP,
        'grade': _getPerformanceGrade(),
        'completedAt': Timestamp.now(),
        'questionsAnswered': widget.totalQuestions,
        'modeSpecific': widget.mode == 'practice' 
            ? {
                'batchesCompleted': widget.totalQuestions > 0 ? (widget.totalQuestions / 10).ceil() : 0,
                'averageAccuracy': widget.totalQuestions > 0 ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt() : 0,
              }
            : {
                'timeSpent': widget.timeSpent ?? 0,
                'completionRate': widget.totalQuestions > 0 ? 100 : 0,
              },
      });

      print('Quiz session saved successfully: $_sessionId');
    } catch (e) {
      print('Error saving quiz session: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showErrorSnackBar('Failed to save quiz session');
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSavingSession = false;
        });
      }
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
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      final pdf = pw.Document();
      final accuracy = ((widget.correctAnswers / widget.totalQuestions) * 100).toInt();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Quiz Results Report',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Generated on ${DateTime.now().toString().split('.')[0]}',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Quiz Information',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildPDFInfoRow('Mode:', widget.mode.toUpperCase()),
                              _buildPDFInfoRow('Type:', widget.type.toUpperCase()),
                              _buildPDFInfoRow('Topic:', widget.topicName),
                              _buildPDFInfoRow('Subtopic:', widget.subtopicName),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _buildPDFInfoRow('Total Questions:', '${widget.totalQuestions}'),
                              _buildPDFInfoRow('Correct Answers:', '${widget.correctAnswers}'),
                              _buildPDFInfoRow('Accuracy:', '$accuracy%'),
                              _buildPDFInfoRow('XP Earned:', '${widget.totalXP}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green50,
                  border: pw.Border.all(color: PdfColors.green200),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Performance Grade: ${_getPerformanceGrade()}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Final Score: ${_calculateScore()}/100',
                      style: pw.TextStyle(fontSize: 14, color: PdfColors.green700),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'Question-wise Analysis',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),

              pw.SizedBox(height: 12),
            ];
          },
        ),
      );

      for (int i = 0; i < widget.questionHistory.length; i++) {
        final questionData = widget.questionHistory[i];
        final question = questionData['question'];
        final selectedAnswer = questionData['selected_answer'];
        final isCorrect = questionData['is_correct'];

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Question ${i + 1}',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: _getDifficultyColor(question['difficulty']),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          question['difficulty'] ?? 'Medium',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),

                  pw.Text(
                    question['question'] ?? '',
                    style: const pw.TextStyle(fontSize: 14),
                  ),

                  pw.SizedBox(height: 16),

                  ...((question['options'] as List?) ?? []).map((option) {
                    final isSelectedOption = selectedAnswer == option;
                    final isCorrectOption = option == question['correct_answer'];

                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: isCorrectOption 
                            ? PdfColors.green100 
                            : isSelectedOption && !isCorrectOption 
                                ? PdfColors.red100 
                                : PdfColors.grey50,
                        border: pw.Border.all(
                          color: isCorrectOption 
                              ? PdfColors.green 
                              : isSelectedOption && !isCorrectOption 
                                  ? PdfColors.red 
                                  : PdfColors.grey300,
                        ),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 16,
                            height: 16,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              color: isCorrectOption 
                                  ? PdfColors.green 
                                  : isSelectedOption && !isCorrectOption 
                                      ? PdfColors.red 
                                      : PdfColors.grey300,
                            ),
                            child: pw.Center(
                              child: pw.Text(
                                isCorrectOption ? '✓' : isSelectedOption ? '✗' : '',
                                style: const pw.TextStyle(
                                  fontSize: 10,
                                  color: PdfColors.white,
                                ),
                              ),
                            ),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Expanded(
                            child: pw.Text(
                              option,
                              style: const pw.TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  pw.SizedBox(height: 16),

                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: isCorrect ? PdfColors.green50 : PdfColors.red50,
                      border: pw.Border.all(
                        color: isCorrect ? PdfColors.green : PdfColors.red,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          isCorrect ? 'Correct Answer' : 'Incorrect Answer',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: isCorrect ? PdfColors.green800 : PdfColors.red800,
                          ),
                        ),
                        if (selectedAnswer != null) ...[
                          pw.SizedBox(height: 4),
                          pw.Text(
                            'Your answer: $selectedAnswer',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        ],
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Correct answer: ${question['correct_answer']}',
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  if (question['explanation'] != null && question['explanation'].isNotEmpty) ...[
                    pw.Text(
                      'Explanation:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(
                        question['explanation'],
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      }

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/quiz_result_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quiz Results - ${widget.topicName}',
      );

      _showSuccessSnackBar('PDF generated and ready to share!');
    } catch (e) {
      print('Error generating PDF: $e');
      _showErrorSnackBar('Failed to generate PDF');
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  pw.Widget _buildPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  PdfColor _getDifficultyColor(String? difficulty) {
    switch (difficulty?.toLowerCase()) {
      case 'easy':
        return PdfColors.green;
      case 'medium':
        return PdfColors.orange;
      case 'hard':
        return PdfColors.red;
      default:
        return PdfColors.orange;
    }
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

  void _retakeQuiz() {
    if (widget.mode == 'practice') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeModeScreen(
            type: widget.type,
            quizParams: widget.quizParams,
            topicName: widget.topicName,
            subtopicName: widget.subtopicName,
            initialQuestions: [],
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
            questions: [],
          ),
        ),
      );
    }
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
                      
                      if (widget.mode == 'test' || widget.questionHistory.isNotEmpty)
                        _buildQuestionsReview(),
                      
                      SizedBox(height: 30.h),
                      
                      _buildActionButtons(),
                      
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
            
            if (widget.totalQuestions > 0 && 
                (_getPerformanceGrade() == 'Excellent' || _getPerformanceGrade() == 'Great'))
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
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          _isSavingSession ? 'Saving session...' : 'Generating PDF...',
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
              : _getPerformanceGrade() == 'Excellent' ? 'Excellent!' :
                _getPerformanceGrade() == 'Great' ? 'Great Job!' :
                _getPerformanceGrade() == 'Good' ? 'Good Work!' :
                _getPerformanceGrade() == 'Fair' ? 'Keep Trying!' : 'Keep Learning!',
          style: GoogleFonts.poppins(
            fontSize: 28.sp,
            fontWeight: FontWeight.bold,
            color: widget.totalQuestions <= 0 ? Colors.grey : _getGradeColor(),
          ),
        ),
        
        SizedBox(height: 8.h),
        
        Text(
          widget.totalQuestions <= 0 
              ? 'No questions were answered'
              : 'Quiz Completed',
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            color: Colors.grey.shade600,
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
                      value: widget.totalQuestions <= 0 ? 0 : _progressAnimation.value,
                      strokeWidth: 12.w,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.totalQuestions <= 0 ? Colors.grey : _getGradeColor()
                      ),
                    ),
                  );
                },
              ),
              
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.totalQuestions <= 0 ? Icons.info_outline : _getGradeIcon(),
                    size: 40.sp,
                    color: widget.totalQuestions <= 0 ? Colors.grey : _getGradeColor(),
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
            subtitle: widget.mode == 'practice' ? '2 XP per correct' : '4 XP per correct',
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

  Widget _buildQuestionsReview() {
    if (widget.questionHistory.isEmpty) {
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
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 48.sp,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16.h),
            Text(
              'No Questions Answered',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Start a new quiz to see your performance review',
              style: GoogleFonts.poppins(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
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
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Text(
              'Question Review',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          
          Container(
            height: 300.h,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              itemCount: widget.questionHistory.length,
              itemBuilder: (context, index) {
                final questionData = widget.questionHistory[index];
                final question = questionData['question'];
                final selectedAnswer = questionData['selected_answer'];
                final isCorrect = questionData['is_correct'];
                
                return Container(
                  margin: EdgeInsets.only(bottom: 12.h),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: isCorrect 
                        ? Colors.green.shade50 
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isCorrect 
                          ? Colors.green.shade300 
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24.w,
                            height: 24.w,
                            decoration: BoxDecoration(
                              color: isCorrect ? Colors.green : Colors.red,
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
                              question['question'] ?? 'Question ${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            isCorrect ? Icons.check_circle : Icons.cancel,
                            color: isCorrect ? Colors.green : Colors.red,
                            size: 20.sp,
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 8.h),
                      
                      if (selectedAnswer != null) ...[
                        Text(
                          'Your answer: $selectedAnswer',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      Text(
                        'Correct answer: ${question['correct_answer']}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      
                      if (question['difficulty'] != null) ...[
                        SizedBox(height: 8.h),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: _getDifficultyColorFlutter(question['difficulty']),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            question['difficulty'],
                            style: GoogleFonts.poppins(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          SizedBox(height: 20.h),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToHome,
                icon: Icon(Icons.home, size: 20.sp, color: Colors.white,),
                label: Text(
                  'Home',
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
            SizedBox(width: 16.w),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _retakeQuiz,
                icon: Icon(Icons.refresh, size: 20.sp),
                label: Text(
                  'Retake',
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: 16.h),
        
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isGeneratingPDF ? null : _generateAndDownloadPDF,
            icon: Icon(
              Icons.download,
              size: 20.sp,
              color: _isGeneratingPDF 
                  ? Colors.grey 
                  : AppTheme.primaryColor,
            ),
            label: Text(
              _isGeneratingPDF ? 'Generating PDF...' : 'Download PDF Report',
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: _isGeneratingPDF 
                    ? Colors.grey 
                    : AppTheme.primaryColor,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              side: BorderSide(
                color: _isGeneratingPDF 
                    ? Colors.grey 
                    : AppTheme.primaryColor,
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

  Color _getDifficultyColorFlutter(String? difficulty) {
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
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
    
    for (int i = 0; i < 50; i++) {
      paint.color = colors[i % colors.length];
      
      final baseX = (size.width * 0.1) + (i * size.width * 0.02) % size.width;
      final baseY = -100.0 + (animationValue * (size.height + 200));
      
      final offsetX = (i % 5 - 2) * 30.0 * sin(animationValue * 2 * pi + i);
      final offsetY = (i % 7) * 15.0;
      
      final x = baseX + offsetX;
      final y = baseY + offsetY;
      
      if (y >= -20 && y <= size.height + 20) {
        if (i % 4 == 0) {
          canvas.drawCircle(Offset(x, y), 4 + (i % 3), paint);
        } else if (i % 4 == 1) {
          canvas.drawRect(
            Rect.fromCenter(center: Offset(x, y), width: 8, height: 8),
            paint,
          );
        } else if (i % 4 == 2) {
          final path = Path();
          path.moveTo(x, y - 4);
          path.lineTo(x - 4, y + 4);
          path.lineTo(x + 4, y + 4);
          path.close();
          canvas.drawPath(path, paint);
        } else {
          final path = Path();
          for (int j = 0; j < 5; j++) {
            final angle = (j * 2 * pi / 5) - (pi / 2);
            final radius = j % 2 == 0 ? 4.0 : 2.0;
            final starX = x + radius * cos(angle);
            final starY = y + radius * sin(angle);
            if (j == 0) {
              path.moveTo(starX, starY);
            } else {
              path.lineTo(starX, starY);
            }
          }
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