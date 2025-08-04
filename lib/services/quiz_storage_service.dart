import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizStorageService {
  static final rtdb.FirebaseDatabase _database = rtdb.FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's phone number from SharedPreferences
  static Future<String?> _getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

  // Safe type conversion helpers
  static int _safeToInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static double _safeToDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static String _safeToString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString();
  }

  static bool _safeToBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return defaultValue;
  }

  static Map<String, dynamic> _safeToMap(dynamic value) {
    if (value == null) return {};
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  static List<dynamic> _safeToList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value;
    return [];
  }

  // Store quiz session when user starts a quiz
  static Future<String?> storeQuizStart({
    required String mode, // 'practice' or 'test'
    required String type, // 'programming' or 'academic'
    required String topicName,
    required String subtopicName,
    required Map<String, dynamic> quizParams,
    required List<Map<String, dynamic>> questions,
  }) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      final user = _auth.currentUser;
      
      if (phoneNumber == null || user == null) {
        throw Exception('User not authenticated');
      }

      final sessionId = '${DateTime.now().millisecondsSinceEpoch}_${user.uid}';
      final timestamp = rtdb.ServerValue.timestamp;

      // Prepare quiz session data
      final quizSessionData = {
        'sessionId': sessionId,
        'userId': user.uid,
        'phoneNumber': phoneNumber,
        'mode': mode,
        'type': type,
        'topicName': topicName,
        'subtopicName': subtopicName,
        'quizParams': quizParams,
        'status': 'in_progress',
        'startedAt': timestamp,
        'totalQuestions': questions.length,
        'questions': questions.asMap().map((index, question) => MapEntry(
          index.toString(),
          {
            'questionIndex': index,
            'question': _safeToString(question['question']),
            'options': _safeToList(question['options']),
            'correctAnswer': _safeToString(question['correct_answer']),
            'difficulty': _safeToString(question['difficulty'], defaultValue: 'medium'),
            'explanation': _safeToString(question['explanation']),
            'hint': _safeToString(question['hint']),
            'answered': false,
            'selectedAnswer': null,
            'isCorrect': null,
            'answeredAt': null,
          }
        )),
        'progress': {
          'currentQuestionIndex': 0,
          'answeredQuestions': 0,
          'correctAnswers': 0,
          'xpEarned': 0,
          'timeSpent': 0,
        },
        'metadata': {
          'deviceInfo': await _getDeviceInfo(),
          'appVersion': '1.0.0', // You can get this from package_info_plus
          'quizGenerationTime': DateTime.now().toIso8601String(),
        }
      };

      // Store in Realtime Database
      final databaseRef = _database.ref().child('skillbench/quiz_sessions/$phoneNumber/$sessionId');
      await databaseRef.set(quizSessionData);

      // Also store a summary in Firestore for quick queries
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_sessions')
          .doc(sessionId)
          .set({
            'sessionId': sessionId,
            'phoneNumber': phoneNumber,
            'mode': mode,
            'type': type,
            'topicName': topicName,
            'subtopicName': subtopicName,
            'status': 'in_progress',
            'startedAt': Timestamp.now(),
            'totalQuestions': questions.length,
          });

      print('Quiz session started and stored: $sessionId');
      return sessionId;
    } catch (e) {
      print('Error storing quiz start: $e');
      return null;
    }
  }

  // Update quiz progress (called after each question is answered)
  static Future<void> updateQuizProgress({
    required String sessionId,
    required int questionIndex,
    required String? selectedAnswer,
    required bool isCorrect,
    required int xpEarned,
    required int timeSpent,
  }) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      if (phoneNumber == null) return;

      final databaseRef = _database.ref().child('skillbench/quiz_sessions/$phoneNumber/$sessionId');
      
      // Update specific question
      await databaseRef.child('questions/$questionIndex').update({
        'answered': true,
        'selectedAnswer': selectedAnswer,
        'isCorrect': isCorrect,
        'answeredAt': rtdb.ServerValue.timestamp,
      });

      // Get current progress to calculate new values
      final progressSnapshot = await databaseRef.child('progress').get();
      Map<String, dynamic> currentProgress = {};
      
      if (progressSnapshot.exists && progressSnapshot.value != null) {
        currentProgress = _safeToMap(progressSnapshot.value);
      }
      
      final currentAnswered = _safeToInt(currentProgress['answeredQuestions']);
      final currentCorrect = _safeToInt(currentProgress['correctAnswers']);
      final currentXP = _safeToInt(currentProgress['xpEarned']);

      // Update progress
      await databaseRef.child('progress').update({
        'currentQuestionIndex': questionIndex + 1,
        'answeredQuestions': currentAnswered + 1,
        'correctAnswers': isCorrect ? currentCorrect + 1 : currentCorrect,
        'xpEarned': currentXP + xpEarned,
        'timeSpent': timeSpent,
        'lastUpdated': rtdb.ServerValue.timestamp,
      });

      print('Quiz progress updated for session: $sessionId, question: $questionIndex');
    } catch (e) {
      print('Error updating quiz progress: $e');
    }
  }

  // Store quiz completion
  static Future<void> storeQuizCompletion({
    required String sessionId,
    required int totalQuestions,
    required int correctAnswers,
    required int totalXP,
    required int timeSpent,
    required List<Map<String, dynamic>> questionHistory,
    String status = 'completed',
  }) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      final user = _auth.currentUser;
      
      if (phoneNumber == null || user == null) return;

      final databaseRef = _database.ref().child('skillbench/quiz_sessions/$phoneNumber/$sessionId');
      final timestamp = rtdb.ServerValue.timestamp;
      
      // Calculate additional stats
      final accuracy = totalQuestions > 0 ? ((correctAnswers / totalQuestions) * 100).round() : 0;
      final grade = _calculateGrade(accuracy);
      final score = accuracy;

      // Update session with completion data
      final completionData = {
        'status': status,
        'completedAt': timestamp,
        'finalResults': {
          'totalQuestions': totalQuestions,
          'correctAnswers': correctAnswers,
          'wrongAnswers': totalQuestions - correctAnswers,
          'accuracy': accuracy,
          'grade': grade,
          'score': score,
          'totalXP': totalXP,
          'timeSpent': timeSpent,
        },
        'detailedHistory': questionHistory.asMap().map((index, history) => MapEntry(
          index.toString(),
          {
            'questionIndex': index,
            'question': _safeToMap(history['question']),
            'selectedAnswer': history['selected_answer'],
            'isCorrect': _safeToBool(history['is_correct']),
            'xpEarned': _safeToInt(history['xp_earned']),
            'timestamp': _safeToString(history['timestamp'], defaultValue: DateTime.now().toIso8601String()),
            'skipped': _safeToBool(history['skipped']),
            'timeSpentOnQuestion': _safeToInt(history['time_spent_on_question']),
          }
        )),
        'analytics': {
          'averageTimePerQuestion': totalQuestions > 0 ? (timeSpent / totalQuestions).round() : 0,
          'difficultyBreakdown': _analyzeDifficultyBreakdown(questionHistory),
          'topicPerformance': _analyzeTopicPerformance(questionHistory),
        }
      };

      await databaseRef.update(completionData);

      // Update Firestore summary
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_sessions')
          .doc(sessionId)
          .update({
            'status': status,
            'completedAt': Timestamp.now(),
            'accuracy': accuracy,
            'grade': grade,
            'totalXP': totalXP,
            'timeSpent': timeSpent,
          });

      // Update user's overall stats
      await _updateUserOverallStats(phoneNumber, totalXP, accuracy, status == 'completed');

      print('Quiz completion stored for session: $sessionId');
    } catch (e) {
      print('Error storing quiz completion: $e');
    }
  }

  // Store quiz abandonment (when user exits without completing)
  static Future<void> storeQuizAbandonment({
    required String sessionId,
    required int questionsAnswered,
    required int correctAnswers,
    required int xpEarned,
    required int timeSpent,
    String reason = 'user_exit',
  }) async {
    try {
      final phoneNumber = await _getCurrentUserPhone();
      if (phoneNumber == null) return;

      final databaseRef = _database.ref().child('skillbench/quiz_sessions/$phoneNumber/$sessionId');
      
      await databaseRef.update({
        'status': 'abandoned',
        'abandonedAt': rtdb.ServerValue.timestamp,
        'abandonmentReason': reason,
        'partialResults': {
          'questionsAnswered': questionsAnswered,
          'correctAnswers': correctAnswers,
          'xpEarned': xpEarned,
          'timeSpent': timeSpent,
          'completionRate': questionsAnswered,
        }
      });

      // Update user stats with partial XP if any questions were answered correctly
      if (xpEarned > 0) {
        await _updateUserOverallStats(phoneNumber, xpEarned, 0, false);
      }

      print('Quiz abandonment stored for session: $sessionId');
    } catch (e) {
      print('Error storing quiz abandonment: $e');
    }
  }

  // Get user's quiz history
  static Future<List<Map<String, dynamic>>> getUserQuizHistory({
    required String phoneNumber,
    int? limit,
    String? status, // 'completed', 'in_progress', 'abandoned'
    String? mode, // 'practice', 'test'
    String? type, // 'programming', 'academic'
  }) async {
    try {
      rtdb.Query query = _database.ref().child('skillbench/quiz_sessions/$phoneNumber');
      
      // Apply filters
      if (status != null) {
        query = query.orderByChild('status').equalTo(status);
      }
      
      if (limit != null) {
        query = query.limitToLast(limit);
      }

      final snapshot = await query.get();
      
      if (!snapshot.exists || snapshot.value == null) return [];

      final sessions = _safeToMap(snapshot.value);
      List<Map<String, dynamic>> quizHistory = [];

      sessions.forEach((sessionId, sessionData) {
        final session = _safeToMap(sessionData);
        
        // Apply additional filters
        if (mode != null && _safeToString(session['mode']) != mode) return;
        if (type != null && _safeToString(session['type']) != type) return;
        
        quizHistory.add({
          'sessionId': sessionId,
          ...session,
        });
      });

      // Sort by startedAt timestamp (most recent first)
      quizHistory.sort((a, b) {
        final aTime = _safeToInt(a['startedAt']);
        final bTime = _safeToInt(b['startedAt']);
        return bTime.compareTo(aTime);
      });

      return quizHistory;
    } catch (e) {
      print('Error getting user quiz history: $e');
      return [];
    }
  }

  // Get quiz session details
  static Future<Map<String, dynamic>?> getQuizSession({
    required String phoneNumber,
    required String sessionId,
  }) async {
    try {
      final snapshot = await _database
          .ref()
          .child('skillbench/quiz_sessions/$phoneNumber/$sessionId')
          .get();
      
      if (snapshot.exists && snapshot.value != null) {
        return _safeToMap(snapshot.value);
      }
      return null;
    } catch (e) {
      print('Error getting quiz session: $e');
      return null;
    }
  }

  // Get user's quiz statistics
  static Future<Map<String, dynamic>> getUserQuizStats(String phoneNumber) async {
    try {
      final sessions = await getUserQuizHistory(phoneNumber: phoneNumber);
      
      int totalQuizzes = 0;
      int completedQuizzes = 0;
      int totalQuestions = 0;
      int totalCorrect = 0;
      int totalXP = 0;
      int totalTimeSpent = 0;
      int practiceQuizzes = 0;
      int testQuizzes = 0;
      Map<String, int> topicCounts = {};
      Map<String, int> gradeCounts = {};

      for (final session in sessions) {
        totalQuizzes++;
        
        final sessionStatus = _safeToString(session['status']);
        if (sessionStatus == 'completed') {
          completedQuizzes++;
          
          final results = _safeToMap(session['finalResults']);
          totalQuestions += _safeToInt(results['totalQuestions']);
          totalCorrect += _safeToInt(results['correctAnswers']);
          totalXP += _safeToInt(results['totalXP']);
          totalTimeSpent += _safeToInt(results['timeSpent']);
          
          final grade = _safeToString(results['grade'], defaultValue: 'Unknown');
          gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
        }
        
        final mode = _safeToString(session['mode']);
        if (mode == 'practice') practiceQuizzes++;
        if (mode == 'test') testQuizzes++;
        
        final topic = _safeToString(session['topicName'], defaultValue: 'Unknown');
        topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
      }

      final overallAccuracy = totalQuestions > 0 ? ((totalCorrect / totalQuestions) * 100).round() : 0;
      final completionRate = totalQuizzes > 0 ? ((completedQuizzes / totalQuizzes) * 100).round() : 0;
      final averageTimePerQuiz = completedQuizzes > 0 ? (totalTimeSpent / completedQuizzes).round() : 0;

      return {
        'totalQuizzes': totalQuizzes,
        'completedQuizzes': completedQuizzes,
        'completionRate': completionRate,
        'overallAccuracy': overallAccuracy,
        'totalXP': totalXP,
        'totalTimeSpent': totalTimeSpent,
        'averageTimePerQuiz': averageTimePerQuiz,
        'practiceQuizzes': practiceQuizzes,
        'testQuizzes': testQuizzes,
        'topicBreakdown': topicCounts,
        'gradeBreakdown': gradeCounts,
        'lastQuizDate': sessions.isNotEmpty ? _safeToInt(sessions.first['startedAt']) : null,
      };
    } catch (e) {
      print('Error getting user quiz stats: $e');
      return {};
    }
  }

  // Helper method to calculate grade based on accuracy
  static String _calculateGrade(int accuracy) {
    if (accuracy >= 90) return 'Excellent';
    if (accuracy >= 80) return 'Great';
    if (accuracy >= 70) return 'Good';
    if (accuracy >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  // Helper method to analyze difficulty breakdown
  static Map<String, dynamic> _analyzeDifficultyBreakdown(List<Map<String, dynamic>> questionHistory) {
    Map<String, Map<String, int>> breakdown = {
      'easy': {'total': 0, 'correct': 0},
      'medium': {'total': 0, 'correct': 0},
      'hard': {'total': 0, 'correct': 0},
    };

    for (final history in questionHistory) {
      final question = _safeToMap(history['question']);
      final difficulty = _safeToString(question['difficulty'], defaultValue: 'medium').toLowerCase();
      final isCorrect = _safeToBool(history['is_correct']);

      if (breakdown.containsKey(difficulty)) {
        breakdown[difficulty]!['total'] = breakdown[difficulty]!['total']! + 1;
        if (isCorrect) {
          breakdown[difficulty]!['correct'] = breakdown[difficulty]!['correct']! + 1;
        }
      }
    }

    // Calculate accuracy for each difficulty
    breakdown.forEach((difficulty, stats) {
      final total = stats['total']!;
      final correct = stats['correct']!;
      stats['accuracy'] = total > 0 ? ((correct / total) * 100).round() : 0;
    });

    return breakdown;
  }

  // Helper method to analyze topic performance
  static Map<String, dynamic> _analyzeTopicPerformance(List<Map<String, dynamic>> questionHistory) {
    Map<String, Map<String, int>> performance = {};

    for (final history in questionHistory) {
      final question = _safeToMap(history['question']);
      final topic = _safeToString(question['topic'], defaultValue: 'General');
      final isCorrect = _safeToBool(history['is_correct']);

      if (!performance.containsKey(topic)) {
        performance[topic] = {'total': 0, 'correct': 0};
      }

      performance[topic]!['total'] = performance[topic]!['total']! + 1;
      if (isCorrect) {
        performance[topic]!['correct'] = performance[topic]!['correct']! + 1;
      }
    }

    // Calculate accuracy for each topic
    performance.forEach((topic, stats) {
      final total = stats['total']!;
      final correct = stats['correct']!;
      stats['accuracy'] = total > 0 ? ((correct / total) * 100).round() : 0;
    });

    return performance;
  }

  // Helper method to get device info
  static Future<Map<String, String>> _getDeviceInfo() async {
    // You can use device_info_plus package for more detailed info
    return {
      'platform': 'mobile',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Helper method to update user's overall stats
  static Future<void> _updateUserOverallStats(
    String phoneNumber, 
    int xpEarned, 
    int accuracy, 
    bool completed
  ) async {
    try {
      // Update in Firestore (main user document)
      final userRef = _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .doc(phoneNumber);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        
        if (snapshot.exists && snapshot.data() != null) {
          final currentData = snapshot.data()!;
          final currentXP = _safeToInt(currentData['xp']);
          final currentStreaks = _safeToInt(currentData['streaks']);
          
          // Update XP
          final newXP = currentXP + xpEarned;
          
          // Update streaks if quiz was completed with good accuracy
          int newStreaks = currentStreaks;
          if (completed && accuracy >= 70) {
            newStreaks = currentStreaks + 1;
          }
          
          transaction.update(userRef, {
            'xp': newXP,
            'streaks': newStreaks,
            'last_quiz_date': Timestamp.now(),
          });
        }
      });
    } catch (e) {
      print('Error updating user overall stats: $e');
    }
  }

  // Clean up old quiz sessions (optional - call periodically)
  static Future<void> cleanupOldSessions({
    required String phoneNumber,
    int daysToKeep = 30,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final cutoffTimestamp = cutoffDate.millisecondsSinceEpoch;
      
      final snapshot = await _database
          .ref()
          .child('skillbench/quiz_sessions/$phoneNumber')
          .orderByChild('startedAt')
          .endAt(cutoffTimestamp)
          .get();
      
      if (snapshot.exists && snapshot.value != null) {
        final sessions = _safeToMap(snapshot.value);
        
        for (final sessionId in sessions.keys) {
          await _database
              .ref()
              .child('skillbench/quiz_sessions/$phoneNumber/$sessionId')
              .remove();
        }
        
        print('Cleaned up ${sessions.length} old quiz sessions');
      }
    } catch (e) {
      print('Error cleaning up old sessions: $e');
    }
  }
}