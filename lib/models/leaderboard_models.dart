import 'package:flutter/foundation.dart';

/// Enum for different timeframe filters
enum Timeframe {
  daily('Daily'),
  weekly('Weekly'), 
  monthly('Monthly'),
  allTime('All Time');
  
  const Timeframe(this.displayName);
  final String displayName;
  
  static Timeframe fromString(String value) {
    return Timeframe.values.firstWhere(
      (e) => e.displayName == value,
      orElse: () => Timeframe.weekly,
    );
  }
}

/// Model for individual leaderboard users
@immutable
class LeaderboardUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? organization;
  final int points;
  final int rank;
  final bool isYou;
  final bool isOnline;
  final DateTime? lastSeen;
  final Map<String, dynamic> metadata;

  const LeaderboardUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.organization,
    required this.points,
    required this.rank,
    this.isYou = false,
    this.isOnline = false,
    this.lastSeen,
    this.metadata = const {},
  });

  LeaderboardUser copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    String? organization,
    int? points,
    int? rank,
    bool? isYou,
    bool? isOnline,
    DateTime? lastSeen,
    Map<String, dynamic>? metadata,
  }) {
    return LeaderboardUser(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      organization: organization ?? this.organization,
      points: points ?? this.points,
      rank: rank ?? this.rank,
      isYou: isYou ?? this.isYou,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      metadata: metadata ?? this.metadata,
    );
  }

  factory LeaderboardUser.fromJson(Map<String, dynamic> json, {bool isYou = false}) {
    return LeaderboardUser(
      id: json['id']?.toString() ?? json['phone_number']?.toString() ?? '',
      name: json['name']?.toString() ?? json['username']?.toString() ?? 'Unknown',
      avatarUrl: json['avatarUrl']?.toString() ?? json['profile_image']?.toString(),
      organization: json['organization']?.toString() ?? 
                   json['college']?.toString() ?? 
                   json['department']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      isYou: isYou,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null 
          ? DateTime.tryParse(json['last_seen'].toString())
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'organization': organization,
      'points': points,
      'rank': rank,
      'isYou': isYou,
      'isOnline': isOnline,
      'last_seen': lastSeen?.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'LeaderboardUser(id: $id, name: $name, points: $points, rank: $rank)';
  }
}

/// Model for leaderboard statistics
@immutable
class LeaderboardStats {
  final int totalUsers;
  final int activeUsers; 
  final int inRankings;
  final DateTime lastUpdated;

  const LeaderboardStats({
    required this.totalUsers,
    required this.activeUsers,
    required this.inRankings,
    required this.lastUpdated,
  });

  factory LeaderboardStats.fromJson(Map<String, dynamic> json) {
    return LeaderboardStats(
      totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
      activeUsers: (json['activeUsers'] as num?)?.toInt() ?? 0,
      inRankings: (json['inRankings'] as num?)?.toInt() ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'inRankings': inRankings,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardStats &&
        other.totalUsers == totalUsers &&
        other.activeUsers == activeUsers &&
        other.inRankings == inRankings;
  }

  @override
  int get hashCode {
    return Object.hash(totalUsers, activeUsers, inRankings);
  }
}

/// Complete leaderboard data snapshot  
@immutable
class LeaderboardSnapshot {
  final LeaderboardStats stats;
  final List<LeaderboardUser> topThree;
  final LeaderboardUser? currentUser;
  final List<LeaderboardUser> users;
  final int totalPages;
  final int currentPage;
  final bool hasMorePages;
  final DateTime timestamp;

  const LeaderboardSnapshot({
    required this.stats,
    required this.topThree,
    this.currentUser,
    required this.users,
    required this.totalPages,
    required this.currentPage,
    required this.hasMorePages,
    required this.timestamp,
  });

  factory LeaderboardSnapshot.empty() {
    return LeaderboardSnapshot(
      stats: LeaderboardStats(
        totalUsers: 0,
        activeUsers: 0,
        inRankings: 0,
        lastUpdated: DateTime.now(),
      ),
      topThree: [],
      currentUser: null,
      users: [],
      totalPages: 0,
      currentPage: 0,
      hasMorePages: false,
      timestamp: DateTime.now(),
    );
  }

  LeaderboardSnapshot copyWith({
    LeaderboardStats? stats,
    List<LeaderboardUser>? topThree,
    LeaderboardUser? currentUser,
    List<LeaderboardUser>? users,
    int? totalPages,
    int? currentPage,
    bool? hasMorePages,
    DateTime? timestamp,
  }) {
    return LeaderboardSnapshot(
      stats: stats ?? this.stats,
      topThree: topThree ?? this.topThree,
      currentUser: currentUser ?? this.currentUser,
      users: users ?? this.users,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardSnapshot &&
        listEquals(other.topThree, topThree) &&
        other.currentUser == currentUser &&
        listEquals(other.users, users) &&
        other.stats == stats;
  }

  @override
  int get hashCode {
    return Object.hash(
      stats,
      Object.hashAll(topThree),
      currentUser,
      Object.hashAll(users),
    );
  }
}

/// Filter options for leaderboard queries
@immutable
class LeaderboardFilters {
  final Timeframe timeframe;
  final String? group;
  final String? category;

  const LeaderboardFilters({
    required this.timeframe,
    this.group,
    this.category,
  });

  LeaderboardFilters copyWith({
    Timeframe? timeframe,
    String? group,
    String? category,
  }) {
    return LeaderboardFilters(
      timeframe: timeframe ?? this.timeframe,
      group: group ?? this.group,
      category: category ?? this.category,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaderboardFilters &&
        other.timeframe == timeframe &&
        other.group == group &&
        other.category == category;
  }

  @override
  int get hashCode {
    return Object.hash(timeframe, group, category);
  }

  @override
  String toString() {
    return 'LeaderboardFilters(timeframe: $timeframe, group: $group, category: $category)';
  }
}