import 'package:flutter/material.dart';

/// Model for tracking individual topic progress and performance
class TopicProgress {
  final String topicId;
  final String topicName;
  final String categoryId;
  final String subcategory;
  final String type; // 'programming' or 'academic'
  final double maxTestScore; // Highest test score percentage (0-100)
  final double practiceAccuracy; // Latest practice accuracy percentage (0-100)
  final double averagePracticeAccuracy; // Average of all practice sessions
  final int totalAttempts;
  final int testAttempts;
  final int practiceAttempts;
  final DateTime lastAttempted;
  final DateTime firstAttempted;
  final int totalXPEarned;
  final int totalTimeSpent; // in seconds
  final String difficulty; // 'beginner', 'intermediate', 'advanced'
  final bool isCompleted; // Based on progress threshold
  final Map<String, dynamic> metadata; // Additional topic-specific data

  const TopicProgress({
    required this.topicId,
    required this.topicName,
    required this.categoryId,
    required this.subcategory,
    required this.type,
    this.maxTestScore = 0.0,
    this.practiceAccuracy = 0.0,
    this.averagePracticeAccuracy = 0.0,
    this.totalAttempts = 0,
    this.testAttempts = 0,
    this.practiceAttempts = 0,
    required this.lastAttempted,
    required this.firstAttempted,
    this.totalXPEarned = 0,
    this.totalTimeSpent = 0,
    this.difficulty = 'beginner',
    this.isCompleted = false,
    this.metadata = const {},
  });

  /// Calculate display progress (0.0 to 1.0)
  /// Priority: Max test score > Average practice accuracy > Latest practice accuracy
  double get displayProgress {
    if (maxTestScore > 0) {
      return maxTestScore / 100.0;
    } else if (averagePracticeAccuracy > 0) {
      return averagePracticeAccuracy / 100.0;
    } else {
      return practiceAccuracy / 100.0;
    }
  }

  /// Get progress percentage as integer (0-100)
  int get progressPercentage => (displayProgress * 100).round();

  /// Get formatted progress string
  String get progressString => '${progressPercentage}%';

  /// Check if topic has been attempted
  bool get hasBeenAttempted => totalAttempts > 0;

  /// Get performance level based on progress
  String get performanceLevel {
    final progress = progressPercentage;
    if (progress >= 90) return 'Excellent';
    if (progress >= 80) return 'Great';
    if (progress >= 70) return 'Good';
    if (progress >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  /// Get performance color
  Color get performanceColor {
    final progress = progressPercentage;
    if (progress >= 90) return Colors.green;
    if (progress >= 80) return Colors.lightGreen;
    if (progress >= 70) return Colors.orange;
    if (progress >= 60) return Colors.deepOrange;
    return Colors.red;
  }

  /// Calculate learning streak (days since first attempt)
  int get learningStreakDays {
    return DateTime.now().difference(firstAttempted).inDays;
  }

  /// Get average time per attempt
  double get averageTimePerAttempt {
    return totalAttempts > 0 ? totalTimeSpent / totalAttempts : 0.0;
  }

  /// Check if user is consistent (attempted recently)
  bool get isConsistent {
    final daysSinceLastAttempt = DateTime.now().difference(lastAttempted).inDays;
    return daysSinceLastAttempt <= 7; // Within last week
  }

  /// Get improvement trend
  String get improvementTrend {
    if (totalAttempts < 2) return 'New';
    if (maxTestScore > averagePracticeAccuracy) return 'Improving';
    if (maxTestScore == averagePracticeAccuracy) return 'Stable';
    return 'Declining';
  }

  /// Create a copy with updated values
  TopicProgress copyWith({
    String? topicId,
    String? topicName,
    String? categoryId,
    String? subcategory,
    String? type,
    double? maxTestScore,
    double? practiceAccuracy,
    double? averagePracticeAccuracy,
    int? totalAttempts,
    int? testAttempts,
    int? practiceAttempts,
    DateTime? lastAttempted,
    DateTime? firstAttempted,
    int? totalXPEarned,
    int? totalTimeSpent,
    String? difficulty,
    bool? isCompleted,
    Map<String, dynamic>? metadata,
  }) {
    return TopicProgress(
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      categoryId: categoryId ?? this.categoryId,
      subcategory: subcategory ?? this.subcategory,
      type: type ?? this.type,
      maxTestScore: maxTestScore ?? this.maxTestScore,
      practiceAccuracy: practiceAccuracy ?? this.practiceAccuracy,
      averagePracticeAccuracy: averagePracticeAccuracy ?? this.averagePracticeAccuracy,
      totalAttempts: totalAttempts ?? this.totalAttempts,
      testAttempts: testAttempts ?? this.testAttempts,
      practiceAttempts: practiceAttempts ?? this.practiceAttempts,
      lastAttempted: lastAttempted ?? this.lastAttempted,
      firstAttempted: firstAttempted ?? this.firstAttempted,
      totalXPEarned: totalXPEarned ?? this.totalXPEarned,
      totalTimeSpent: totalTimeSpent ?? this.totalTimeSpent,
      difficulty: difficulty ?? this.difficulty,
      isCompleted: isCompleted ?? this.isCompleted,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to Map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'topicId': topicId,
      'topicName': topicName,
      'categoryId': categoryId,
      'subcategory': subcategory,
      'type': type,
      'maxTestScore': maxTestScore,
      'practiceAccuracy': practiceAccuracy,
      'averagePracticeAccuracy': averagePracticeAccuracy,
      'totalAttempts': totalAttempts,
      'testAttempts': testAttempts,
      'practiceAttempts': practiceAttempts,
      'lastAttempted': lastAttempted.millisecondsSinceEpoch,
      'firstAttempted': firstAttempted.millisecondsSinceEpoch,
      'totalXPEarned': totalXPEarned,
      'totalTimeSpent': totalTimeSpent,
      'difficulty': difficulty,
      'isCompleted': isCompleted,
      'metadata': metadata,
    };
  }

  /// Create from Map (Firebase data)
  factory TopicProgress.fromMap(Map<String, dynamic> map) {
    return TopicProgress(
      topicId: map['topicId'] ?? '',
      topicName: map['topicName'] ?? '',
      categoryId: map['categoryId'] ?? '',
      subcategory: map['subcategory'] ?? '',
      type: map['type'] ?? 'programming',
      maxTestScore: (map['maxTestScore'] ?? 0.0).toDouble(),
      practiceAccuracy: (map['practiceAccuracy'] ?? 0.0).toDouble(),
      averagePracticeAccuracy: (map['averagePracticeAccuracy'] ?? 0.0).toDouble(),
      totalAttempts: map['totalAttempts'] ?? 0,
      testAttempts: map['testAttempts'] ?? 0,
      practiceAttempts: map['practiceAttempts'] ?? 0,
      lastAttempted: DateTime.fromMillisecondsSinceEpoch(map['lastAttempted'] ?? 0),
      firstAttempted: DateTime.fromMillisecondsSinceEpoch(map['firstAttempted'] ?? 0),
      totalXPEarned: map['totalXPEarned'] ?? 0,
      totalTimeSpent: map['totalTimeSpent'] ?? 0,
      difficulty: map['difficulty'] ?? 'beginner',
      isCompleted: map['isCompleted'] ?? false,
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'TopicProgress(topicId: $topicId, topicName: $topicName, progress: ${progressString}, attempts: $totalAttempts)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TopicProgress && other.topicId == topicId;
  }

  @override
  int get hashCode => topicId.hashCode;
}

/// Model for tracking recent quiz activities
class RecentActivity {
  final String activityId;
  final String topicId;
  final String topicName;
  final String categoryId;
  final String subcategory;
  final String mode; // 'practice' or 'test'
  final String type; // 'programming' or 'academic'
  final double score; // Percentage score (0-100)
  final int questionsAnswered;
  final int correctAnswers;
  final int xpEarned;
  final int timeSpent; // in seconds
  final DateTime timestamp;
  final String iconPath;
  final Color color;
  final Map<String, dynamic> sessionData; // Additional session info

  const RecentActivity({
    required this.activityId,
    required this.topicId,
    required this.topicName,
    required this.categoryId,
    required this.subcategory,
    required this.mode,
    required this.type,
    required this.score,
    this.questionsAnswered = 0,
    this.correctAnswers = 0,
    this.xpEarned = 0,
    this.timeSpent = 0,
    required this.timestamp,
    required this.iconPath,
    required this.color,
    this.sessionData = const {},
  });

  /// Get formatted score string
  String get scoreString => '${score.round()}%';

  /// Get time ago string
  String get timeAgoString {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  /// Get formatted time spent
  String get formattedTimeSpent {
    final minutes = timeSpent ~/ 60;
    final seconds = timeSpent % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Get performance level
  String get performanceLevel {
    if (score >= 90) return 'Excellent';
    if (score >= 80) return 'Great';
    if (score >= 70) return 'Good';
    if (score >= 60) return 'Fair';
    return 'Needs Improvement';
  }

  /// Get mode badge color
  Color get modeBadgeColor {
    switch (mode.toLowerCase()) {
      case 'test':
        return Colors.orange;
      case 'practice':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// Check if activity is recent (within 24 hours)
  bool get isRecent {
    final difference = DateTime.now().difference(timestamp);
    return difference.inHours <= 24;
  }

  /// Create a copy with updated values
  RecentActivity copyWith({
    String? activityId,
    String? topicId,
    String? topicName,
    String? categoryId,
    String? subcategory,
    String? mode,
    String? type,
    double? score,
    int? questionsAnswered,
    int? correctAnswers,
    int? xpEarned,
    int? timeSpent,
    DateTime? timestamp,
    String? iconPath,
    Color? color,
    Map<String, dynamic>? sessionData,
  }) {
    return RecentActivity(
      activityId: activityId ?? this.activityId,
      topicId: topicId ?? this.topicId,
      topicName: topicName ?? this.topicName,
      categoryId: categoryId ?? this.categoryId,
      subcategory: subcategory ?? this.subcategory,
      mode: mode ?? this.mode,
      type: type ?? this.type,
      score: score ?? this.score,
      questionsAnswered: questionsAnswered ?? this.questionsAnswered,
      correctAnswers: correctAnswers ?? this.correctAnswers,
      xpEarned: xpEarned ?? this.xpEarned,
      timeSpent: timeSpent ?? this.timeSpent,
      timestamp: timestamp ?? this.timestamp,
      iconPath: iconPath ?? this.iconPath,
      color: color ?? this.color,
      sessionData: sessionData ?? this.sessionData,
    );
  }

  /// Convert to Map for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'activityId': activityId,
      'topicId': topicId,
      'topicName': topicName,
      'categoryId': categoryId,
      'subcategory': subcategory,
      'mode': mode,
      'type': type,
      'score': score,
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'xpEarned': xpEarned,
      'timeSpent': timeSpent,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'iconPath': iconPath,
      'colorValue': color.value,
      'sessionData': sessionData,
    };
  }

  /// Create from Map (Firebase data)
  factory RecentActivity.fromMap(Map<String, dynamic> map) {
    return RecentActivity(
      activityId: map['activityId'] ?? '',
      topicId: map['topicId'] ?? '',
      topicName: map['topicName'] ?? '',
      categoryId: map['categoryId'] ?? '',
      subcategory: map['subcategory'] ?? '',
      mode: map['mode'] ?? 'practice',
      type: map['type'] ?? 'programming',
      score: (map['score'] ?? 0.0).toDouble(),
      questionsAnswered: map['questionsAnswered'] ?? 0,
      correctAnswers: map['correctAnswers'] ?? 0,
      xpEarned: map['xpEarned'] ?? 0,
      timeSpent: map['timeSpent'] ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      iconPath: map['iconPath'] ?? '',
      color: Color(map['colorValue'] ?? 0xFF000000),
      sessionData: Map<String, dynamic>.from(map['sessionData'] ?? {}),
    );
  }

  @override
  String toString() {
    return 'RecentActivity(topicName: $topicName, mode: $mode, score: ${scoreString}, time: $timeAgoString)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecentActivity && other.activityId == activityId;
  }

  @override
  int get hashCode => activityId.hashCode;
}