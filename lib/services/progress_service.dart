// File: lib/services/progress_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class ProgressService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream controller for progress updates
  static final StreamController<Map<String, double>> _progressController =
      StreamController<Map<String, double>>.broadcast();

  static Stream<Map<String, double>> get progressStream =>
      _progressController.stream;

  /// Update progress for a specific subject/topic
  static Future<void> updateProgress({
    required String type, // 'academic' or 'programming'
    required String subject,
    required String subtopic,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Create unique ID for the subject
      final subjectId =
          _generateSubjectId(type, subject, subtopic, additionalData);

      // Calculate new progress percentage
      final currentProgressData = await getProgressData(subjectId);
      final updatedProgress = _calculateProgress(
        currentData: currentProgressData,
        newScore: score,
        totalQuestions: totalQuestions,
        correctAnswers: correctAnswers,
      );

      // Prepare data to save
      final progressData = {
        'type': type,
        'subject': subject,
        'subtopic': subtopic,
        'progress': updatedProgress,
        'bestScore': currentProgressData?['bestScore'] != null
            ? (score > currentProgressData!['bestScore']
                ? score
                : currentProgressData['bestScore'])
            : score,
        'totalAttempts': (currentProgressData?['totalAttempts'] ?? 0) + 1,
        'totalCorrectAnswers':
            (currentProgressData?['totalCorrectAnswers'] ?? 0) + correctAnswers,
        'totalQuestions':
            (currentProgressData?['totalQuestions'] ?? 0) + totalQuestions,
        'lastUpdated': ServerValue.timestamp,
        'averageScore': _calculateAverageScore(currentProgressData, score),
        ...?additionalData,
      };

      // Save to Firebase Realtime Database
      await _database
          .ref()
          .child('skillbench/progress/${user.uid}/$subjectId')
          .set(progressData);

      print(
          'Progress updated for $subjectId: ${updatedProgress.toStringAsFixed(1)}%');

      // Notify listeners
      _notifyProgressUpdate();
    } catch (e) {
      print('Error updating progress: $e');
      throw e;
    }
  }

  /// Get progress data for a specific subject
  static Future<Map<String, dynamic>?> getProgressData(String subjectId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final snapshot = await _database
          .ref()
          .child('skillbench/progress/${user.uid}/$subjectId')
          .get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      print('Error getting progress data: $e');
      return null;
    }
  }

  /// Get progress percentage for a subject (0.0 to 1.0)
  static Future<double> getProgressPercentage(String subjectId) async {
    try {
      final data = await getProgressData(subjectId);
      return (data?['progress'] ?? 0.0) / 100.0;
    } catch (e) {
      print('Error getting progress percentage: $e');
      return 0.0;
    }
  }

  /// Get all progress data for current user
  static Future<Map<String, Map<String, dynamic>>> getAllProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return {};

      final snapshot =
          await _database.ref().child('skillbench/progress/${user.uid}').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        return data.map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map)));
      }
      return {};
    } catch (e) {
      print('Error getting all progress: $e');
      return {};
    }
  }

  /// Stream progress for real-time updates
  static Stream<Map<String, dynamic>?> streamProgressData(String subjectId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _database
        .ref()
        .child('skillbench/progress/${user.uid}/$subjectId')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      }
      return null;
    });
  }

  /// Stream all progress for real-time updates
  static Stream<Map<String, Map<String, dynamic>>> streamAllProgress() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    return _database
        .ref()
        .child('skillbench/progress/${user.uid}')
        .onValue
        .map((event) {
      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return data.map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value as Map)));
      }
      return <String, Map<String, dynamic>>{};
    });
  }

  static String _generateSubjectId(String type, String subject, String subtopic,
      Map<String, dynamic>? additionalData) {
    String normalizeString(String input) {
      return input
          .replaceAll(' ', '')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
    }

    if (type == 'academic') {
      final college = additionalData?['college'] ?? '';
      final department = additionalData?['department'] ?? '';
      final semester = additionalData?['semester'] ?? '';
      // Keep academic format as is for now
      return 'academic_${normalizeString(college)}_${normalizeString(department)}_${normalizeString(semester)}_${normalizeString(subject)}_${normalizeString(subtopic)}';
    } else if (type == 'programming') {
      // New format: {main_topic}_{subtopic}_{topic}

      // Check if subtopic is in combined format (from quiz result screen)
      if (subtopic.contains('|')) {
        List<String> parts = subtopic.split('|');
        String actualSubtopic = parts[0]; // e.g., "C"
        String actualTopic = parts[1]; // e.g., "C Introduction"

        String normalizedMainTopic =
            normalizeString(subject); // programminglanguage
        String normalizedSubtopic = normalizeString(actualSubtopic); // c
        String normalizedTopic = normalizeString(actualTopic); // cintroduction

        String generatedId =
            '${normalizedMainTopic}_${normalizedSubtopic}_${normalizedTopic}';

        print('Progress Service - New Format Generation:');
        print('  Main Topic: $subject → $normalizedMainTopic');
        print('  Subtopic: $actualSubtopic → $normalizedSubtopic');
        print('  Topic: $actualTopic → $normalizedTopic');
        print('  Generated ID: $generatedId');

        return generatedId;
      }

      // Fallback for direct calls
      String normalizedMainTopic = normalizeString(subject);
      String normalizedSubtopic = normalizeString(subtopic);
      return '${normalizedMainTopic}_${normalizedSubtopic}_${normalizedSubtopic}';
    }

    // Fallback for other types
    return '${normalizeString(type)}_${normalizeString(subject)}_${normalizeString(subtopic)}';
  }

  /// Calculate progress based on performance
  static double _calculateProgress({
    required Map<String, dynamic>? currentData,
    required int newScore,
    required int totalQuestions,
    required int correctAnswers,
  }) {
    // If no previous data, base progress on current score
    if (currentData == null) {
      return newScore.toDouble().clamp(0.0, 100.0);
    }

    final currentProgress = currentData['progress'] ?? 0.0;
    final previousBestScore = currentData['bestScore'] ?? 0;
    final totalAttempts = currentData['totalAttempts'] ?? 0;

    // Weight: 60% best score, 40% consistency (average improvement)
    final bestScoreWeight = 0.6;
    final consistencyWeight = 0.4;

    // Calculate best score component
    final bestScore =
        newScore > previousBestScore ? newScore : previousBestScore;
    final bestScoreComponent = bestScore * bestScoreWeight;

    // Calculate consistency component (gradual improvement)
    final improvementFactor = totalAttempts > 0
        ? (newScore / (totalAttempts + 1)) * consistencyWeight
        : newScore * consistencyWeight;

    final newProgress = bestScoreComponent +
        (currentProgress * consistencyWeight) +
        (improvementFactor * 0.1);

    return newProgress.clamp(0.0, 100.0);
  }

  /// Calculate average score
  static double _calculateAverageScore(
      Map<String, dynamic>? currentData, int newScore) {
    if (currentData == null) return newScore.toDouble();

    final previousAverage = currentData['averageScore'] ?? 0.0;
    final totalAttempts = currentData['totalAttempts'] ?? 0;

    return ((previousAverage * totalAttempts) + newScore) / (totalAttempts + 1);
  }

  /// Notify progress update
  static void _notifyProgressUpdate() {
    getAllProgress().then((allProgress) {
      final progressMap = <String, double>{};
      allProgress.forEach((key, value) {
        progressMap[key] = (value['progress'] ?? 0.0) / 100.0;
      });
      _progressController.add(progressMap);
    });
  }

  /// Get progress for academic subject (specific helper)
  static Future<double> getAcademicProgress({
    required String college,
    required String department,
    required String semester,
    required String subject,
    required String unit,
  }) async {
    final subjectId = _generateSubjectId('academic', subject, unit, {
      'college': college,
      'department': department,
      'semester': semester,
    });

    return await getProgressPercentage(subjectId);
  }

  /// Get progress for programming topic (specific helper)
  static Future<double> getProgrammingProgress({
    required String mainTopic,
    required String subtopic,
    String? programmingLanguage,
  }) async {
    final subjectId = _generateSubjectId('programming', mainTopic, subtopic, {
      'programmingLanguage': programmingLanguage ?? '',
    });

    return await getProgressPercentage(subjectId);
  }

  /// Clear all progress (for testing/reset)
  static Future<void> clearAllProgress() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _database.ref().child('skillbench/progress/${user.uid}').remove();

      print('All progress cleared');
      _notifyProgressUpdate();
    } catch (e) {
      print('Error clearing progress: $e');
    }
  }

  /// Dispose stream controller
  static void dispose() {
    _progressController.close();
  }
}
