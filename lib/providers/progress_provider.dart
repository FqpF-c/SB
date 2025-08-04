// File: lib/providers/progress_provider.dart

import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import 'dart:async';

class ProgressProvider extends ChangeNotifier {
  Map<String, Map<String, dynamic>> _allProgress = {};
  StreamSubscription<Map<String, Map<String, dynamic>>>? _progressStreamSubscription;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  Map<String, Map<String, dynamic>> get allProgress => _allProgress;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  ProgressProvider() {
    _initializeProgressStream();
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadAllProgress();
    });
  }

  /// Initialize real-time progress stream
  void _initializeProgressStream() {
    _progressStreamSubscription = ProgressService.streamAllProgress().listen(
      (progressData) {
        // Use post frame callback to avoid setState during build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _allProgress = progressData;
          _isInitialized = true;
          notifyListeners();
        });
      },
      onError: (error) {
        print('Progress stream error: $error');
      },
    );
  }

  /// Load all progress from Firebase
  Future<void> loadAllProgress() async {
    _isLoading = true;
    
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });

    try {
      _allProgress = await ProgressService.getAllProgress();
      _isInitialized = true;
      print('Loaded ${_allProgress.length} progress entries');
    } catch (e) {
      print('Error loading progress: $e');
    } finally {
      _isLoading = false;
      
      // Use post frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Get progress for a specific topic (0.0 to 1.0)
  double getProgressForTopic(String topicId) {
    final progressData = _allProgress[topicId];
    if (progressData == null) return 0.0;
    
    final progress = progressData['progress'] ?? 0.0;
    return (progress / 100.0).clamp(0.0, 1.0);
  }

  /// Get progress percentage for a topic (0 to 100)
  int getProgressPercentage(String topicId) {
    final progressData = _allProgress[topicId];
    if (progressData == null) return 0;
    
    final progress = progressData['progress'] ?? 0.0;
    return progress.round().clamp(0, 100);
  }

  /// Check if topic has any progress
  bool hasProgress(String topicId) {
    return _allProgress.containsKey(topicId) && 
           (_allProgress[topicId]?['progress'] ?? 0.0) > 0;
  }

  /// Get best score for a topic
  int getBestScore(String topicId) {
    final progressData = _allProgress[topicId];
    return progressData?['bestScore'] ?? 0;
  }

  /// Get total attempts for a topic
  int getTotalAttempts(String topicId) {
    final progressData = _allProgress[topicId];
    return progressData?['totalAttempts'] ?? 0;
  }

  /// Get average score for a topic
  double getAverageScore(String topicId) {
    final progressData = _allProgress[topicId];
    return progressData?['averageScore'] ?? 0.0;
  }

  /// Get detailed progress data for a topic
  Map<String, dynamic>? getDetailedProgress(String topicId) {
    return _allProgress[topicId];
  }

  /// Update progress for a topic
  Future<void> updateProgress({
    required String type,
    required String subject,
    required String subtopic,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await ProgressService.updateProgress(
        type: type,
        subject: subject,
        subtopic: subtopic,
        score: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
        additionalData: additionalData,
      );
      // Progress will be updated automatically via stream
    } catch (e) {
      print('Error updating progress in provider: $e');
    }
  }

  /// Get academic progress specifically
  Future<double> getAcademicProgress({
    required String college,
    required String department,
    required String semester,
    required String subject,
    required String unit,
  }) async {
    return await ProgressService.getAcademicProgress(
      college: college,
      department: department,
      semester: semester,
      subject: subject,
      unit: unit,
    );
  }

  /// Get programming progress specifically
  Future<double> getProgrammingProgress({
    required String mainTopic,
    required String subtopic,
    String? programmingLanguage,
  }) async {
    return await ProgressService.getProgrammingProgress(
      mainTopic: mainTopic,
      subtopic: subtopic,
      programmingLanguage: programmingLanguage,
    );
  }

  /// Get overall progress for a subject (average of all subtopics)
  double getOverallSubjectProgress(String subjectPrefix) {
    double totalProgress = 0.0;
    int count = 0;

    _allProgress.forEach((key, value) {
      if (key.startsWith(subjectPrefix)) {
        totalProgress += (value['progress'] ?? 0.0);
        count++;
      }
    });

    return count > 0 ? (totalProgress / count) / 100.0 : 0.0;
  }

  /// Get subject-wise progress summary
  Map<String, Map<String, dynamic>> getSubjectProgressSummary() {
    Map<String, Map<String, dynamic>> summary = {};
    
    _allProgress.forEach((key, value) {
      final type = value['type'] ?? 'unknown';
      final subject = value['subject'] ?? 'unknown';
      final subjectKey = '${type}_$subject';
      
      if (!summary.containsKey(subjectKey)) {
        summary[subjectKey] = {
          'type': type,
          'subject': subject,
          'totalProgress': 0.0,
          'count': 0,
          'bestScore': 0,
          'totalAttempts': 0,
        };
      }
      
      summary[subjectKey]!['totalProgress'] += value['progress'] ?? 0.0;
      summary[subjectKey]!['count'] += 1;
      summary[subjectKey]!['bestScore'] = 
          (summary[subjectKey]!['bestScore'] < (value['bestScore'] ?? 0)) 
              ? value['bestScore'] ?? 0 
              : summary[subjectKey]!['bestScore'];
      summary[subjectKey]!['totalAttempts'] += value['totalAttempts'] ?? 0;
    });

    // Calculate averages
    summary.forEach((key, value) {
      value['averageProgress'] = value['count'] > 0 
          ? value['totalProgress'] / value['count']
          : 0.0;
    });

    return summary;
  }

  /// Refresh progress data
  Future<void> refresh() async {
    await loadAllProgress();
  }

  /// Clear all progress (for testing)
  Future<void> clearAllProgress() async {
    await ProgressService.clearAllProgress();
    _allProgress.clear();
    _isInitialized = false;
    
    // Use post frame callback to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _progressStreamSubscription?.cancel();
    super.dispose();
  }
}