// File: lib/screens/quiz/quiz_report_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:async';
import '../../theme/default_theme.dart';

class QuizReportViewerScreen extends StatefulWidget {
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
  final Map<String, Map<String, dynamic>> topicBreakdown;
  final Map<String, Map<String, dynamic>> difficultyBreakdown;
  final List<String> weakAreas;
  final List<String> strongAreas;
  final Map<String, dynamic> timeAnalysis;

  const QuizReportViewerScreen({
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
    required this.topicBreakdown,
    required this.difficultyBreakdown,
    required this.weakAreas,
    required this.strongAreas,
    required this.timeAnalysis,
  }) : super(key: key);

  @override
  State<QuizReportViewerScreen> createState() => _QuizReportViewerScreenState();
}

class _QuizReportViewerScreenState extends State<QuizReportViewerScreen> {
  bool _isGeneratingPDF = false;
  bool _isPreviewMode = true;

  @override
  Widget build(BuildContext context) {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Performance Report',
          style: GoogleFonts.poppins(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPreviewMode ? Icons.visibility_off : Icons.visibility,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              setState(() {
                _isPreviewMode = !_isPreviewMode;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isPreviewMode) ...[
            _buildPreviewContent(accuracy),
          ] else ...[
            _buildPDFPreview(),
          ],
          if (_isGeneratingPDF)
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
                        'Generating and preparing report...',
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
      bottomNavigationBar: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isGeneratingPDF ? null : _previewPDF,
                icon: Icon(
                  Icons.preview,
                  color: _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
                ),
                label: Text(
                  'PDF Preview',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color:
                        _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  side: BorderSide(
                    color:
                        _isGeneratingPDF ? Colors.grey : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPDF ? null : _generateAndDownloadPDF,
                icon: Icon(
                  Icons.download,
                  color: Colors.white,
                ),
                label: Text(
                  _isGeneratingPDF ? 'Generating...' : 'Download PDF',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isGeneratingPDF ? Colors.grey : AppTheme.secondaryColor,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(int accuracy) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          _buildReportHeader(accuracy),
          SizedBox(height: 24.h),

          // Quiz Overview
          _buildQuizOverview(accuracy),
          SizedBox(height: 20.h),

          // Performance Summary
          _buildPerformanceSummary(),
          SizedBox(height: 20.h),

          // Topic Analysis
          if (widget.topicBreakdown.isNotEmpty) ...[
            _buildTopicAnalysis(),
            SizedBox(height: 20.h),
          ],

          // Difficulty Analysis
          if (widget.difficultyBreakdown.isNotEmpty) ...[
            _buildDifficultyAnalysis(),
            SizedBox(height: 20.h),
          ],

          // Time Analysis
          if (widget.timeAnalysis.isNotEmpty) ...[
            _buildTimeAnalysisSection(),
            SizedBox(height: 20.h),
          ],

          // Strengths and Improvement Areas
          _buildStrengthsAndImprovements(),
          SizedBox(height: 20.h),

          // Recommendations
          _buildRecommendations(),
          SizedBox(height: 20.h),

          // Detailed Question History
          _buildQuestionHistory(),
          SizedBox(height: 80.h), // Extra space for bottom nav
        ],
      ),
    );
  }

  Widget _buildPDFPreview() {
    return Container(
      child: PdfPreview(
        build: (format) => _generatePDF(),
        allowPrinting: false,
        allowSharing: true,
        canChangePageFormat: false,
        canDebug: false,
      ),
    );
  }

  Widget _buildReportHeader(int accuracy) {
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
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.assessment,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quiz Performance Report',
                      style: GoogleFonts.poppins(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Generated on ${DateTime.now().toString().split(' ')[0]}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat('Score', '$accuracy%'),
                _buildHeaderStat('Grade', _getPerformanceGrade()),
                _buildHeaderStat('XP', '${widget.totalXP}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.sp,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildQuizOverview(int accuracy) {
    return _buildSectionCard(
      title: 'Quiz Overview',
      icon: Icons.info_outline,
      color: Colors.blue,
      child: Column(
        children: [
          _buildOverviewRow('Mode', widget.mode.toUpperCase()),
          _buildOverviewRow('Type', widget.type.toUpperCase()),
          _buildOverviewRow('Topic', widget.topicName),
          _buildOverviewRow('Subtopic', widget.subtopicName),
          _buildOverviewRow('Total Questions', '${widget.totalQuestions}'),
          _buildOverviewRow('Correct Answers', '${widget.correctAnswers}'),
          _buildOverviewRow('Accuracy', '$accuracy%'),
          if (widget.timeSpent != null)
            _buildOverviewRow('Time Spent', _formatTime(widget.timeSpent!)),
          _buildOverviewRow('XP Earned', '${widget.totalXP}'),
          _buildOverviewRow('Grade', _getPerformanceGrade()),
        ],
      ),
    );
  }

  Widget _buildPerformanceSummary() {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    return _buildSectionCard(
      title: 'Performance Summary',
      icon: Icons.trending_up,
      color: Colors.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Performance: ${_getPerformanceDescription(accuracy)}',
            style: GoogleFonts.poppins(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.primaryColor,
            ),
          ),
          SizedBox(height: 12.h),
          LinearProgressIndicator(
            value: accuracy / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_getGradeColor(accuracy)),
            minHeight: 8.h,
          ),
          SizedBox(height: 8.h),
          Text(
            '$accuracy% accuracy (${widget.correctAnswers}/${widget.totalQuestions} correct)',
            style: GoogleFonts.poppins(
              fontSize: 12.sp,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicAnalysis() {
    return _buildSectionCard(
      title: 'Topic Performance Analysis',
      icon: Icons.analytics,
      color: Colors.purple,
      child: Column(
        children: widget.topicBreakdown.entries.map((entry) {
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
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: accuracyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: accuracyColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: accuracyColor,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '${accuracy.toInt()}%',
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '$correct out of $total questions correct',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (stats['averageTime'] != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Average time: ${(stats['averageTime'] as double).toInt()} seconds',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                LinearProgressIndicator(
                  value: accuracy / 100,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(accuracyColor),
                  minHeight: 4.h,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDifficultyAnalysis() {
    return _buildSectionCard(
      title: 'Difficulty Level Analysis',
      icon: Icons.speed,
      color: Colors.orange,
      child: Column(
        children: widget.difficultyBreakdown.entries.map((entry) {
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
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: difficultyColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: difficultyColor.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$difficulty Questions',
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
                SizedBox(height: 8.h),
                Text(
                  '$correct out of $total correct',
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
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
      ),
    );
  }

  Widget _buildTimeAnalysisSection() {
    double avgTime = (widget.timeAnalysis['averageTime'] ?? 0).toDouble();
    double consistency = (widget.timeAnalysis['consistency'] ?? 0).toDouble();
    int minTime = (widget.timeAnalysis['minTime'] ?? 0).toInt();
    int maxTime = (widget.timeAnalysis['maxTime'] ?? 0).toInt();

    return _buildSectionCard(
      title: 'Time Analysis',
      icon: Icons.timer,
      color: Colors.teal,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTimeAnalysisItem(
                    'Average Time', '${avgTime.toInt()}s', Colors.blue),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTimeAnalysisItem(
                    'Consistency',
                    '${consistency.toInt()}%',
                    consistency >= 70 ? Colors.green : Colors.orange),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildTimeAnalysisItem(
                    'Fastest', '${minTime}s', Colors.green),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildTimeAnalysisItem(
                    'Slowest', '${maxTime}s', Colors.red),
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
                  Icon(Icons.lightbulb, color: Colors.orange, size: 16.sp),
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

  Widget _buildTimeAnalysisItem(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
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

  Widget _buildStrengthsAndImprovements() {
    return _buildSectionCard(
      title: 'Strengths & Areas for\nImprovement',
      icon: Icons.insights,
      color: Colors.indigo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.strongAreas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.star, color: Colors.green, size: 16.sp),
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
              children: widget.strongAreas
                  .map((area) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
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
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 16.h),
          ],
          if (widget.weakAreas.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.red, size: 16.sp),
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
              children: widget.weakAreas
                  .map((area) => Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12.r),
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
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (widget.strongAreas.isEmpty && widget.weakAreas.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.grey.shade600, size: 16.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Complete more questions to get detailed area analysis',
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
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

  Widget _buildRecommendations() {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    List<String> recommendations = _generateRecommendations(accuracy);

    return _buildSectionCard(
      title: 'Recommendations',
      icon: Icons.lightbulb,
      color: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recommendations
            .map((recommendation) => Container(
                  margin: EdgeInsets.only(bottom: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.w,
                        margin: EdgeInsets.only(top: 6.h, right: 8.w),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          recommendation,
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            color: Colors.amber.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildQuestionHistory() {
    return _buildSectionCard(
      title:
          'Detailed Question Analysis\n(${widget.questionHistory.length} questions)',
      icon: Icons.history,
      color: Colors.grey,
      child: Container(
        height: 300.h, // Fixed height with scroll
        child: ListView.builder(
          itemCount: widget.questionHistory.length,
          itemBuilder: (context, index) {
            final history = widget.questionHistory[index];
            final isCorrect = history['is_correct'] ?? false;
            final question = history['question'];
            final selectedAnswer = history['selected_answer'];
            final timeSpent = history['time_spent_on_question'] ?? 0;

            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(
                  color: isCorrect
                      ? Colors.green.withOpacity(0.3)
                      : Colors.red.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: isCorrect ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'Q${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          question['question'] ?? 'Question text not available',
                          style: GoogleFonts.poppins(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          '${timeSpent}s',
                          style: GoogleFonts.poppins(
                            fontSize: 10.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Selected: $selectedAnswer',
                    style: GoogleFonts.poppins(
                      fontSize: 11.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (!isCorrect && question['correct_answer'] != null) ...[
                    Text(
                      'Correct: ${question['correct_answer']}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.sp,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // PDF Generation Methods
  Future<Uint8List> _generatePDF() async {
    final pdf = pw.Document();
    
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    // Add main report page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          List<pw.Widget> widgets = [
            // Header Section
            _buildPDFHeader(accuracy),
            pw.SizedBox(height: 20),
            
            // Quiz Information Section
            _buildPDFQuizInfo(accuracy),
            pw.SizedBox(height: 20),
          ];
          
          // Topic Performance Analysis
          if (widget.topicBreakdown.isNotEmpty) {
            widgets.add(_buildPDFTopicAnalysis());
            widgets.add(pw.SizedBox(height: 20));
          }
          
          // Strengths and Areas for Improvement
          widgets.add(_buildPDFStrengthsAndImprovements());
          widgets.add(pw.SizedBox(height: 20));
          
          // Time Analysis
          if (widget.timeAnalysis.isNotEmpty) {
            widgets.add(_buildPDFTimeAnalysis());
            widgets.add(pw.SizedBox(height: 20));
          }
          
          // Recommendations
          widgets.add(_buildPDFRecommendations());
          
          return widgets;
        },
      ),
    );

    // Add detailed questions if available
    if (widget.questionHistory.isNotEmpty) {
      _addDetailedQuestions(pdf);
    }

    return pdf.save();
  }

  pw.Widget _buildPDFHeader(int accuracy) {
    return pw.Container(
      width: double.infinity,
      padding: pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Quiz Performance Analysis Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on ${DateTime.now().toString().split(' ')[0]}',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.purple,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              'Adaptive Learning Applied',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFQuizInfo(int accuracy) {
    return pw.Container(
      padding: pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Quiz Information',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
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
              pw.SizedBox(width: 40),
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
          pw.SizedBox(height: 16),
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.green100,
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
                pw.SizedBox(height: 4),
                pw.Text(
                  'Final Score: ${_calculateFinalScore(accuracy)}/100',
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.green700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFTopicAnalysis() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Topic Performance Analysis',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildTableCell('Topic', isHeader: true),
                _buildTableCell('Questions', isHeader: true),
                _buildTableCell('Accuracy', isHeader: true),
                _buildTableCell('Avg Time', isHeader: true),
              ],
            ),
            // Data rows
            ...widget.topicBreakdown.entries.map<pw.TableRow>((entry) {
              String topic = entry.key;
              Map<String, dynamic> stats = entry.value;
              double accuracy = (stats['accuracy'] ?? 0).toDouble();
              int correct = stats['correct'] ?? 0;
              int total = stats['total'] ?? 0;
              double avgTime = (stats['averageTime'] ?? 0).toDouble();

              return pw.TableRow(
                children: [
                  _buildTableCell(topic),
                  _buildTableCell('$total'),
                  _buildTableCell('${accuracy.toInt()}%'),
                  _buildTableCell('${avgTime.toInt()}s'),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
        ),
      ),
    );
  }

  pw.Widget _buildPDFStrengthsAndImprovements() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Strengths and Areas for Improvement',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Strengths column
            pw.Expanded(
              child: pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Strengths (85%+ Accuracy)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...widget.strongAreas.map((area) => pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        children: [
                          pw.Text('✓ ', style: pw.TextStyle(color: PdfColors.green800)),
                          pw.Expanded(child: pw.Text(area, style: pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                    )).toList(),
                    if (widget.strongAreas.isEmpty)
                      pw.Text(
                        'Complete more questions to identify strengths',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 20),
            // Areas for improvement column
            pw.Expanded(
              child: pw.Container(
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.red100,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Areas for Improvement (<60% Accuracy)',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    ...widget.weakAreas.map((area) => pw.Padding(
                      padding: pw.EdgeInsets.only(bottom: 2),
                      child: pw.Row(
                        children: [
                          pw.Text('✗ ', style: pw.TextStyle(color: PdfColors.red800)),
                          pw.Expanded(child: pw.Text(area, style: pw.TextStyle(fontSize: 10))),
                        ],
                      ),
                    )).toList(),
                    if (widget.weakAreas.isEmpty)
                      pw.Text(
                        'No significant weaknesses identified',
                        style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPDFTimeAnalysis() {
    double avgTime = (widget.timeAnalysis['averageTime'] ?? 0).toDouble();
    double consistency = (widget.timeAnalysis['consistency'] ?? 0).toDouble();
    int minTime = (widget.timeAnalysis['minTime'] ?? 0).toInt();
    int maxTime = (widget.timeAnalysis['maxTime'] ?? 0).toInt();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Time Analysis',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildPDFTimeAnalysisItem('Average Time', '${avgTime.toInt()}s'),
              _buildPDFTimeAnalysisItem('Fastest', '${minTime}s'),
              _buildPDFTimeAnalysisItem('Slowest', '${maxTime}s'),
              _buildPDFTimeAnalysisItem('Consistency', '${consistency.toInt()}%'),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFTimeAnalysisItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue800,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFRecommendations() {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    List<String> recommendations = _generateRecommendations(accuracy);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Recommendations for Improvement',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: recommendations.map<pw.Widget>((recommendation) => pw.Padding(
              padding: pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('✓ ', style: pw.TextStyle(color: PdfColors.orange800)),
                  pw.Expanded(
                    child: pw.Text(
                      recommendation,
                      style: pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.orange800,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  void _addDetailedQuestions(pw.Document pdf) {
    // Add detailed question analysis pages
    for (int i = 0; i < widget.questionHistory.length; i++) {
      final questionData = widget.questionHistory[i];
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return _buildQuestionPage(questionData, i + 1);
          },
        ),
      );
    }
  }

  pw.Widget _buildQuestionPage(Map<String, dynamic> questionData, int questionNumber) {
    final isCorrect = questionData['is_correct'] ?? false;
    final question = questionData['question'] ?? {};
    final selectedAnswer = questionData['selected_answer'] ?? '';
    final correctAnswer = question['correct_answer'] ?? '';
    final explanation = question['explanation'] ?? '';
    final difficulty = question['difficulty'] ?? 'Medium';
    final options = question['options'] ?? [];
    final questionText = question['question'] ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Question header
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Question $questionNumber',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: pw.BoxDecoration(
                color: difficulty == 'Easy' ? PdfColors.green : 
                       difficulty == 'Hard' ? PdfColors.red : PdfColors.orange,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Text(
                difficulty,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        
        // Question text
        pw.Text(
          questionText,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.normal),
        ),
        pw.SizedBox(height: 16),
        
        // Options
        ...options.asMap().entries.map<pw.Widget>((entry) {
          int index = entry.key;
          String option = entry.value;
          bool isSelected = option == selectedAnswer;
          bool isCorrectOption = option == correctAnswer;
          
          return pw.Container(
            margin: pw.EdgeInsets.only(bottom: 8),
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: isCorrectOption ? PdfColors.green100 : 
                     (isSelected && !isCorrect) ? PdfColors.red100 : 
                     PdfColors.grey100,
              border: pw.Border.all(
                color: isCorrectOption ? PdfColors.green : 
                       (isSelected && !isCorrect) ? PdfColors.red : 
                       PdfColors.grey300,
              ),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    color: isCorrectOption ? PdfColors.green : 
                           (isSelected && !isCorrect) ? PdfColors.red : 
                           PdfColors.grey300,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      isCorrectOption ? '✓' : (isSelected && !isCorrect) ? '✗' : '',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Text(
                    option,
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        pw.SizedBox(height: 20),
        
        // Answer status
        pw.Container(
          padding: pw.EdgeInsets.all(16),
          decoration: pw.BoxDecoration(
            color: isCorrect ? PdfColors.green100 : PdfColors.red100,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isCorrect ? 'Correct Answer' : 'Incorrect Answer',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: isCorrect ? PdfColors.green800 : PdfColors.red800,
                ),
              ),
              if (!isCorrect) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Your answer: $selectedAnswer',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.Text(
                  'Correct answer: $correctAnswer',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        
        pw.SizedBox(height: 16),
        
        // Explanation
        if (explanation.isNotEmpty) ...[
          pw.Text(
            'Explanation:',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              explanation,
              style: pw.TextStyle(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ],
    );
  }

  // Helper Methods
  int _calculateFinalScore(int accuracy) {
    // Calculate final score based on accuracy and other factors
    int baseScore = accuracy;
    
    // Bonus for XP earned
    int xpBonus = (widget.totalXP / 10).round();
    
    // Time bonus/penalty based on consistency
    double consistency = (widget.timeAnalysis['consistency'] ?? 0).toDouble();
    int timeBonus = consistency >= 70 ? 5 : 0;
    
    int finalScore = (baseScore + xpBonus + timeBonus).clamp(0, 100);
    return finalScore;
  }

  String _getPerformanceGrade() {
    final accuracy = widget.totalQuestions > 0
        ? ((widget.correctAnswers / widget.totalQuestions) * 100).toInt()
        : 0;

    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Very Good';
    if (accuracy >= 70) return 'Good';
    if (accuracy >= 60) return 'Satisfactory';
    return 'Needs Improvement';
  }

  String _getPerformanceDescription(int accuracy) {
    if (accuracy >= 90) return 'Outstanding performance! You have mastered this topic.';
    if (accuracy >= 80) return 'Very good performance with minor areas for improvement.';
    if (accuracy >= 70) return 'Good performance, but there\'s room for growth.';
    if (accuracy >= 60) return 'Satisfactory performance, focus on weak areas.';
    return 'Needs significant improvement. Review fundamental concepts.';
  }

  Color _getGradeColor(int accuracy) {
    if (accuracy >= 80) return Colors.green;
    if (accuracy >= 60) return Colors.orange;
    return Colors.red;
  }

  String _formatTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }

  List<String> _generateRecommendations(int accuracy) {
    List<String> recommendations = [];

    if (widget.weakAreas.isNotEmpty) {
      recommendations.add(
        'Focus on practicing ${widget.weakAreas.join(', ')} topics more extensively'
      );
    }

    double consistency = (widget.timeAnalysis['consistency'] ?? 0).toDouble();
    if (consistency < 70) {
      recommendations.add('Practice maintaining consistent pacing throughout the quiz');
    }

    if (accuracy < 60) {
      recommendations.add('Review fundamental concepts before attempting more advanced topics');
    }

    if (widget.totalQuestions < 20) {
      recommendations.add('Try completing more questions to build stamina and consistency');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Continue practicing to maintain your excellent performance');
      recommendations.add('Challenge yourself with harder difficulty levels');
    }

    return recommendations;
  }

  Widget _buildOverviewRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120.w,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }

  Future<void> _previewPDF() async {
    setState(() {
      _isPreviewMode = false;
    });
  }

  Future<void> _generateAndDownloadPDF() async {
    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      print('=== PDF Generation Debug ===');
      
      // Step 1: Generate PDF data
      print('Step 1: Generating PDF data...');
      final pdfData = await _generatePDF();
      print('PDF data generated successfully. Size: ${pdfData.length} bytes');
      
      // Step 2: Always use app's documents directory (no special permissions needed)
      print('Step 2: Using app documents directory...');
      final directory = await getApplicationDocumentsDirectory();
      print('Directory: ${directory.path}');
      
      // Step 3: Create file
      final fileName = 'Quiz_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      print('Target file: ${file.path}');
      
      // Step 4: Write file
      print('Step 4: Writing PDF data to file...');
      await file.writeAsBytes(pdfData);
      
      // Step 5: Verify file creation
      bool fileExists = await file.exists();
      int fileSize = fileExists ? await file.length() : 0;
      print('File exists: $fileExists, Size: $fileSize bytes');
      
      if (fileExists && fileSize > 0) {
        print('=== PDF Generation SUCCESS ===');
        
        // Show success message with options
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF generated successfully!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'File: $fileName',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  'Size: ${(fileSize / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await Share.shareXFiles([XFile(file.path)], text: 'Quiz Performance Report');
                } catch (e) {
                  print('Share error: $e');
                }
              },
            ),
          ),
        );
      } else {
        throw Exception('File was not created properly. Exists: $fileExists, Size: $fileSize');
      }
      
    } catch (e, stackTrace) {
      print('=== PDF Generation ERROR ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Error generating PDF',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6),
        ),
      );
    } finally {
      setState(() {
        _isGeneratingPDF = false;
      });
    }
  }

  void _showPDFActionsBottomSheet(String filePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'PDF Actions',
              style: GoogleFonts.poppins(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 20),
            
            // Share PDF Button (since we can't guarantee opening)
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.share, color: Colors.green),
              ),
              title: Text(
                'Share PDF',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text('Share with other apps'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await Share.shareXFiles([XFile(filePath)], text: 'Quiz Performance Report');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error sharing PDF: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            
            SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _openPDF(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // Just share the file - this will open options including PDF viewers
        await Share.shareXFiles([XFile(filePath)], text: 'Quiz Performance Report');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF file not found at: $filePath'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error opening PDF: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening PDF: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}