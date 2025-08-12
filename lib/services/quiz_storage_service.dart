import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../secure_storage.dart';

class QuizStorageService {
  static final rtdb.FirebaseDatabase _database = rtdb.FirebaseDatabase.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<String?> _getCurrentUserPhone() async {
    try {
      return await SecureStorage.read('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

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

  static Future<String?> storeQuizStart({
    required String mode,
    required String type,
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
        'questions': questions
            .asMap()
            .map((index, question) => MapEntry(index.toString(), {
                  'questionIndex': index,
                  'question': _safeToString(question['question']),
                  'options': _safeToList(question['options']),
                  'correctAnswer': _safeToString(question['correct_answer']),
                  'difficulty': _safeToString(question['difficulty'],
                      defaultValue: 'medium'),
                  'explanation': _safeToString(question['explanation']),
                  'hint': _safeToString(question['hint']),
                  'answered': false,
                  'selectedAnswer': null,
                  'isCorrect': null,
                  'answeredAt': null,
                })),
        'progress': {
          'currentQuestionIndex': 0,
          'answeredQuestions': 0,
          'correctAnswers': 0,
          'xpEarned': 0,
          'timeSpent': 0,
        },
        'metadata': {
          'deviceInfo': await _getDeviceInfo(),
          'appVersion': '1.0.0',
          'quizGenerationTime': DateTime.now().toIso8601String(),
        }
      };

      final databaseRef = _database
          .ref()
          .child('skillbench/quiz_sessions/${user.uid}/$sessionId');
      await databaseRef.set(quizSessionData);

      await _firestore
          .collection('skillbench')
          .doc('users')
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

  static Future<void> updateQuizProgress({
    required String sessionId,
    required int questionIndex,
    required String? selectedAnswer,
    required bool isCorrect,
    required int xpEarned,
    required int timeSpent,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final databaseRef = _database
          .ref()
          .child('skillbench/quiz_sessions/${user.uid}/$sessionId');

      await databaseRef.child('questions/$questionIndex').update({
        'answered': true,
        'selectedAnswer': selectedAnswer,
        'isCorrect': isCorrect,
        'answeredAt': rtdb.ServerValue.timestamp,
      });

      final progressSnapshot = await databaseRef.child('progress').get();
      Map<String, dynamic> currentProgress = {};

      if (progressSnapshot.exists && progressSnapshot.value != null) {
        currentProgress = _safeToMap(progressSnapshot.value);
      }

      final currentAnswered = _safeToInt(currentProgress['answeredQuestions']);
      final currentCorrect = _safeToInt(currentProgress['correctAnswers']);
      final currentXP = _safeToInt(currentProgress['xpEarned']);

      await databaseRef.child('progress').update({
        'currentQuestionIndex': questionIndex + 1,
        'answeredQuestions': currentAnswered + 1,
        'correctAnswers': isCorrect ? currentCorrect + 1 : currentCorrect,
        'xpEarned': currentXP + xpEarned,
        'timeSpent': timeSpent,
        'lastUpdated': rtdb.ServerValue.timestamp,
      });

      print(
          'Quiz progress updated for session: $sessionId, question: $questionIndex');
    } catch (e) {
      print('Error updating quiz progress: $e');
    }
  }

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
      final user = _auth.currentUser;
      if (user == null) return;

      final databaseRef = _database
          .ref()
          .child('skillbench/quiz_sessions/${user.uid}/$sessionId');
      final timestamp = rtdb.ServerValue.timestamp;

      final accuracy = totalQuestions > 0
          ? ((correctAnswers / totalQuestions) * 100).round()
          : 0;
      String grade = 'F';
      if (accuracy >= 90)
        grade = 'A';
      else if (accuracy >= 80)
        grade = 'B';
      else if (accuracy >= 70)
        grade = 'C';
      else if (accuracy >= 60) grade = 'D';

      final completionData = {
        'status': status,
        'completedAt': timestamp,
        'results': {
          'totalQuestions': totalQuestions,
          'correctAnswers': correctAnswers,
          'accuracy': accuracy,
          'grade': grade,
          'totalXP': totalXP,
          'timeSpent': timeSpent,
          'averageTimePerQuestion':
              totalQuestions > 0 ? (timeSpent / totalQuestions).round() : 0,
          'difficultyBreakdown': _analyzeDifficultyBreakdown(questionHistory),
          'topicPerformance': _analyzeTopicPerformance(questionHistory),
        }
      };

      await databaseRef.update(completionData);

      await _firestore
          .collection('skillbench')
          .doc('users')
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

      await _updateUserOverallStats(
          totalXP, accuracy, status == 'completed');

      print('Quiz completion stored for session: $sessionId');
    } catch (e) {
      print('Error storing quiz completion: $e');
    }
  }

  static Future<void> storeQuizAbandonment({
    required String sessionId,
    required int questionsAnswered,
    required int correctAnswers,
    required int xpEarned,
    required int timeSpent,
    String reason = 'user_exit',
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final databaseRef = _database
          .ref()
          .child('skillbench/quiz_sessions/${user.uid}/$sessionId');

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

      if (xpEarned > 0) {
        await _updateUserOverallStats(xpEarned, 0, false);
      }

      print('Quiz abandonment stored for session: $sessionId');
    } catch (e) {
      print('Error storing quiz abandonment: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getUserQuizHistory({
    String? userId,
    int? limit,
    String? status,
    String? mode,
    String? type,
  }) async {
    try {
      final user = _auth.currentUser;
      final userIdToUse = userId ?? user?.uid;
      if (userIdToUse == null) return [];
      
      rtdb.Query query =
          _database.ref().child('skillbench/quiz_sessions/$userIdToUse');

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

        if (mode != null && _safeToString(session['mode']) != mode) return;
        if (type != null && _safeToString(session['type']) != type) return;

        quizHistory.add({
          'sessionId': sessionId,
          ...session,
        });
      });

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

  static Future<Map<String, dynamic>?> getQuizSession({
    String? userId,
    required String sessionId,
  }) async {
    try {
      final user = _auth.currentUser;
      final userIdToUse = userId ?? user?.uid;
      if (userIdToUse == null) return null;
      
      final snapshot = await _database
          .ref()
          .child('skillbench/quiz_sessions/$userIdToUse/$sessionId')
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

  static Future<Map<String, dynamic>> getUserQuizStats(
      {String? userId}) async {
    try {
      final sessions = await getUserQuizHistory(userId: userId);

      int totalQuizzes = 0;
      int completedQuizzes = 0;
      int totalQuestions = 0;
      int totalCorrect = 0;
      int totalXP = 0;
      int totalTime = 0;

      Map<String, int> difficultyStats = {
        'easy': 0,
        'medium': 0,
        'hard': 0,
      };

      Map<String, Map<String, int>> modeStats = {
        'practice': {'completed': 0, 'total': 0},
        'test': {'completed': 0, 'total': 0},
      };

      for (final session in sessions) {
        totalQuizzes++;
        final mode = _safeToString(session['mode']);
        final status = _safeToString(session['status']);

        if (modeStats.containsKey(mode)) {
          modeStats[mode]!['total'] = modeStats[mode]!['total']! + 1;
          if (status == 'completed') {
            modeStats[mode]!['completed'] = modeStats[mode]!['completed']! + 1;
          }
        }

        if (status == 'completed') {
          completedQuizzes++;
          final results = _safeToMap(session['results']);
          totalQuestions += _safeToInt(results['totalQuestions']);
          totalCorrect += _safeToInt(results['correctAnswers']);
          totalXP += _safeToInt(results['totalXP']);
          totalTime += _safeToInt(results['timeSpent']);
        }
      }

      final overallAccuracy = totalQuestions > 0
          ? ((totalCorrect / totalQuestions) * 100).round()
          : 0;

      return {
        'totalQuizzes': totalQuizzes,
        'completedQuizzes': completedQuizzes,
        'completionRate': totalQuizzes > 0
            ? ((completedQuizzes / totalQuizzes) * 100).round()
            : 0,
        'overallAccuracy': overallAccuracy,
        'totalXP': totalXP,
        'totalTimeSpent': totalTime,
        'averageTimePerQuiz':
            completedQuizzes > 0 ? (totalTime / completedQuizzes).round() : 0,
        'modeStats': modeStats,
        'difficultyStats': difficultyStats,
      };
    } catch (e) {
      print('Error getting user quiz stats: $e');
      return {};
    }
  }

  static Map<String, int> _analyzeDifficultyBreakdown(
      List<Map<String, dynamic>> questionHistory) {
    Map<String, int> breakdown = {
      'easy_correct': 0,
      'easy_total': 0,
      'medium_correct': 0,
      'medium_total': 0,
      'hard_correct': 0,
      'hard_total': 0,
    };

    for (final question in questionHistory) {
      final difficulty =
          _safeToString(question['difficulty'], defaultValue: 'medium')
              .toLowerCase();
      final isCorrect = _safeToBool(question['isCorrect']);

      breakdown['${difficulty}_total'] = breakdown['${difficulty}_total']! + 1;
      if (isCorrect) {
        breakdown['${difficulty}_correct'] =
            breakdown['${difficulty}_correct']! + 1;
      }
    }

    return breakdown;
  }

  static Map<String, Map<String, int>> _analyzeTopicPerformance(
      List<Map<String, dynamic>> questionHistory) {
    Map<String, Map<String, int>> performance = {};

    for (final question in questionHistory) {
      final topic = _safeToString(question['topic'], defaultValue: 'general');
      final isCorrect = _safeToBool(question['isCorrect']);

      if (!performance.containsKey(topic)) {
        performance[topic] = {'correct': 0, 'total': 0, 'accuracy': 0};
      }

      performance[topic]!['total'] = performance[topic]!['total']! + 1;
      if (isCorrect) {
        performance[topic]!['correct'] = performance[topic]!['correct']! + 1;
      }
    }

    performance.forEach((topic, stats) {
      final total = stats['total']!;
      final correct = stats['correct']!;
      stats['accuracy'] = total > 0 ? ((correct / total) * 100).round() : 0;
    });

    return performance;
  }

  static Future<Map<String, String>> _getDeviceInfo() async {
    return {
      'platform': 'mobile',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> _updateUserOverallStats(
      int xpEarned, int accuracy, bool completed) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userStatsRef = _database.ref('skillbench/users/${user.uid}');

      await userStatsRef.runTransaction((Object? currentData) {
        Map<String, dynamic> data = {};

        if (currentData != null) {
          final rawData = currentData as Map<dynamic, dynamic>;
          data = Map<String, dynamic>.from(rawData);
        }

        final currentXP = _safeToInt(data['xp']);
        final currentCoins = _safeToInt(data['coins']);

        int coinsEarned = 0;
        if (completed) {
          if (accuracy >= 90)
            coinsEarned = 10;
          else if (accuracy >= 80)
            coinsEarned = 8;
          else if (accuracy >= 70)
            coinsEarned = 5;
          else if (accuracy >= 60)
            coinsEarned = 3;
          else
            coinsEarned = 1;
        }

        data['xp'] = currentXP + xpEarned;
        data['coins'] = currentCoins + coinsEarned;
        data['last_updated'] = rtdb.ServerValue.timestamp;

        return rtdb.Transaction.success(data);
      });

      print('User overall stats updated for user: ${user.uid}');
    } catch (e) {
      print('Error updating user overall stats: $e');
    }
  }
}
