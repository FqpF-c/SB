import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeadProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Loading states
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Leaderboard data
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, dynamic>? _currentUserData;
  int _currentUserRank = 0;

  // Filters
  String _timeFilter = 'Weekly';
  String _collegeFilter = 'All';
  String _departmentFilter = 'All';

  // Available filter options
  List<String> _availableColleges = ['All'];
  List<String> _availableDepartments = ['All'];

  // Getters
  String get timeFilter => _timeFilter;
  String get collegeFilter => _collegeFilter;
  String get departmentFilter => _departmentFilter;
  List<String> get availableColleges => _availableColleges;
  List<String> get availableDepartments => _availableDepartments;
  Map<String, dynamic>? get currentUserData => _currentUserData;
  int get currentUserRank => _currentUserRank;

  // Constructor
  LeadProvider() {
    _loadSavedFilters();
  }

  // Load saved filter preferences
  Future<void> _loadSavedFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _timeFilter = prefs.getString('lead_time_filter') ?? 'Weekly';
      _collegeFilter = prefs.getString('lead_college_filter') ?? 'All';
      _departmentFilter = prefs.getString('lead_department_filter') ?? 'All';
      notifyListeners();
    } catch (e) {
      print('Error loading saved filters: $e');
    }
  }

  // Save filter preferences
  Future<void> _saveFilters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lead_time_filter', _timeFilter);
      await prefs.setString('lead_college_filter', _collegeFilter);
      await prefs.setString('lead_department_filter', _departmentFilter);
    } catch (e) {
      print('Error saving filters: $e');
    }
  }

  // Set time filter
  Future<void> setTimeFilter(String filter) async {
    if (_timeFilter != filter) {
      _timeFilter = filter;
      await _saveFilters();
      await _applyFilters();
      notifyListeners();
    }
  }

  // Set college filter
  Future<void> setCollegeFilter(String filter) async {
    if (_collegeFilter != filter) {
      _collegeFilter = filter;
      _departmentFilter = 'All'; // Reset department when college changes
      await _saveFilters();
      await _loadAvailableDepartments();
      await _applyFilters();
      notifyListeners();
    }
  }

  // Set department filter
  Future<void> setDepartmentFilter(String filter) async {
    if (_departmentFilter != filter) {
      _departmentFilter = filter;
      await _saveFilters();
      await _applyFilters();
      notifyListeners();
    }
  }

  // Calculate points based on time filter
  int _calculatePoints(Map<String, dynamic> userData) {
    try {
      if (_timeFilter == 'Weekly') {
        // Calculate weekly points based on recent activity
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        
        // Get XP gained this week (you might need to track this separately)
        int weeklyXP = userData['weekly_xp'] ?? userData['xp'] ?? 0;
        int weeklyStreaks = userData['weekly_streaks'] ?? 0;
        int weeklyCoins = userData['weekly_coins'] ?? 0;
        
        // Weekly points calculation
        return (weeklyXP * 1) + (weeklyStreaks * 10) + (weeklyCoins * 2);
      } else {
        // All time points calculation
        int totalXP = userData['xp'] ?? 0;
        int totalStreaks = userData['streaks'] ?? 0;
        int totalCoins = userData['coins'] ?? 0;
        int totalUsage = userData['total_usage'] ?? 0;
        
        // All time points calculation with more weight
        return (totalXP * 1) + (totalStreaks * 15) + (totalCoins * 3) + (totalUsage ~/ 60); // Usage in hours
      }
    } catch (e) {
      print('Error calculating points: $e');
      return 0;
    }
  }

  // Get current user's phone number
  Future<String?> _getCurrentUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

  // Fetch leaderboard data
  Future<void> fetchLeaderboardData() async {
    try {
      _isLoading = true;
      notifyListeners();

      print('CRITICAL: Starting leaderboard data fetch');

      // Fetch all users from Firestore
      final querySnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .get();

      print('CRITICAL: Found ${querySnapshot.docs.length} users');

      _allUsers = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final points = _calculatePoints(data);
        
        return {
          ...data,
          'points': points,
          'doc_id': doc.id,
        };
      }).toList();

      // Load available filter options
      await _loadAvailableColleges();
      await _loadAvailableDepartments();

      // Apply current filters
      await _applyFilters();

      // Find current user data and rank
      await _findCurrentUserRank();

      print('CRITICAL: Leaderboard data loaded successfully');

    } catch (e) {
      print('CRITICAL ERROR: Error fetching leaderboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load available colleges
  Future<void> _loadAvailableColleges() async {
    try {
      final colleges = _allUsers
          .where((user) => user['college'] != null)
          .map((user) => user['college'].toString())
          .toSet()
          .toList();
      
      colleges.sort();
      _availableColleges = ['All', ...colleges];
    } catch (e) {
      print('Error loading available colleges: $e');
      _availableColleges = ['All'];
    }
  }

  // Load available departments
  Future<void> _loadAvailableDepartments() async {
    try {
      List<String> departments;
      
      if (_collegeFilter == 'All') {
        departments = _allUsers
            .where((user) => user['department'] != null)
            .map((user) => user['department'].toString())
            .toSet()
            .toList();
      } else {
        departments = _allUsers
            .where((user) => 
                user['college'] == _collegeFilter && 
                user['department'] != null)
            .map((user) => user['department'].toString())
            .toSet()
            .toList();
      }
      
      departments.sort();
      _availableDepartments = ['All', ...departments];
    } catch (e) {
      print('Error loading available departments: $e');
      _availableDepartments = ['All'];
    }
  }

  // Apply filters to user data
  Future<void> _applyFilters() async {
    try {
      _filteredUsers = List.from(_allUsers);

      // Apply college filter
      if (_collegeFilter != 'All') {
        _filteredUsers = _filteredUsers
            .where((user) => user['college'] == _collegeFilter)
            .toList();
      }

      // Apply department filter
      if (_departmentFilter != 'All') {
        _filteredUsers = _filteredUsers
            .where((user) => user['department'] == _departmentFilter)
            .toList();
      }

      // Sort by points (descending)
      _filteredUsers.sort((a, b) {
        final pointsA = a['points'] ?? 0;
        final pointsB = b['points'] ?? 0;
        return pointsB.compareTo(pointsA);
      });

      print('CRITICAL: Applied filters, ${_filteredUsers.length} users remaining');

    } catch (e) {
      print('Error applying filters: $e');
    }
  }

  // Find current user's rank
  Future<void> _findCurrentUserRank() async {
    try {
      final currentUserPhone = await _getCurrentUserPhone();
      if (currentUserPhone == null) {
        print('CRITICAL: No current user phone found');
        return;
      }

      print('CRITICAL: Looking for current user with phone: $currentUserPhone');

      // Find current user in filtered list
      for (int i = 0; i < _filteredUsers.length; i++) {
        final user = _filteredUsers[i];
        if (user['phone_number'] == currentUserPhone) {
          _currentUserData = user;
          _currentUserRank = i + 1;
          print('CRITICAL: Found current user at rank $_currentUserRank');
          return;
        }
      }

      // If not found in filtered list, check all users
      for (int i = 0; i < _allUsers.length; i++) {
        final user = _allUsers[i];
        if (user['phone_number'] == currentUserPhone) {
          _currentUserData = user;
          // Calculate rank in filtered context (approximate)
          _currentUserRank = _calculateUserRankInFilteredContext(user);
          print('CRITICAL: Found current user in all users, estimated rank $_currentUserRank');
          return;
        }
      }

      print('CRITICAL: Current user not found in leaderboard');
      _currentUserData = null;
      _currentUserRank = 0;

    } catch (e) {
      print('Error finding current user rank: $e');
    }
  }

  // Calculate user rank in filtered context
  int _calculateUserRankInFilteredContext(Map<String, dynamic> userData) {
    try {
      final userPoints = userData['points'] ?? 0;
      int rank = 1;
      
      for (final user in _filteredUsers) {
        final points = user['points'] ?? 0;
        if (points > userPoints) {
          rank++;
        }
      }
      
      return rank;
    } catch (e) {
      print('Error calculating user rank: $e');
      return 0;
    }
  }

  // Get top 3 users
  List<Map<String, dynamic>> getTopThreeUsers() {
    if (_filteredUsers.length >= 3) {
      return _filteredUsers.take(3).toList();
    }
    return _filteredUsers;
  }

  // Get remaining users (after top 3)
  List<Map<String, dynamic>> getRemainingUsers() {
    if (_filteredUsers.length > 3) {
      return _filteredUsers.skip(3).toList();
    }
    return [];
  }

  // Check if current user is in top 3
  bool isUserInTopThree() {
    return _currentUserRank > 0 && _currentUserRank <= 3;
  }

  // Refresh data
  Future<void> refreshData() async {
    await fetchLeaderboardData();
  }

  // Get user statistics for display
  Map<String, int> getUserStats() {
    try {
      int totalUsers = _allUsers.length;
      int filteredUsers = _filteredUsers.length;
      int activeUsers = _allUsers.where((user) {
        final lastLogin = user['last_login'];
        if (lastLogin == null) return false;
        
        final lastLoginDate = lastLogin is Timestamp 
            ? lastLogin.toDate() 
            : DateTime.tryParse(lastLogin.toString());
            
        if (lastLoginDate == null) return false;
        
        // Consider active if logged in within last 7 days
        return DateTime.now().difference(lastLoginDate).inDays <= 7;
      }).length;

      return {
        'total_users': totalUsers,
        'filtered_users': filteredUsers,
        'active_users': activeUsers,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'total_users': 0,
        'filtered_users': 0,
        'active_users': 0,
      };
    }
  }

  // Get user profile image URL or path
  String? getUserProfileImage(Map<String, dynamic> userData) {
    try {
      // Check for profile image URL
      if (userData['profile_image'] != null && 
          userData['profile_image'].toString().isNotEmpty) {
        return userData['profile_image'].toString();
      }

      // Fallback to profile pic type for local assets
      final profilePicType = userData['profile_pic_type'];
      if (profilePicType != null) {
        switch (profilePicType) {
          case 0:
            return 'assets/profile_page/profile_images/profile_6.png'; // Female
          case 1:
            return 'assets/profile_page/profile_images/profile_7.png'; // Male
          case 2:
            return 'assets/profile_page/profile_images/profile_0.png'; // Robot
          default:
            return null;
        }
      }

      return null;
    } catch (e) {
      print('Error getting user profile image: $e');
      return null;
    }
  }

  // Search users by name
  List<Map<String, dynamic>> searchUsers(String query) {
    if (query.isEmpty) return _filteredUsers;
    
    final lowerQuery = query.toLowerCase();
    return _filteredUsers.where((user) {
      final username = user['username']?.toString().toLowerCase() ?? '';
      return username.contains(lowerQuery);
    }).toList();
  }

  // Get user by rank
  Map<String, dynamic>? getUserByRank(int rank) {
    if (rank > 0 && rank <= _filteredUsers.length) {
      return _filteredUsers[rank - 1];
    }
    return null;
  }

  // Get leaderboard period info
  String getLeaderboardPeriodInfo() {
    if (_timeFilter == 'Weekly') {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(Duration(days: 6));
      
      return 'Week of ${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
    } else {
      return 'All Time Rankings';
    }
  }

  // Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Clear all data (useful for logout)
  void clearData() {
    _allUsers.clear();
    _filteredUsers.clear();
    _currentUserData = null;
    _currentUserRank = 0;
    _availableColleges = ['All'];
    _availableDepartments = ['All'];
    notifyListeners();
  }

  // Debug method to print leaderboard data
  void debugPrintLeaderboard() {
    print('=== LEADERBOARD DEBUG ===');
    print('Total users: ${_allUsers.length}');
    print('Filtered users: ${_filteredUsers.length}');
    print('Current user rank: $_currentUserRank');
    print('Filters: Time=$_timeFilter, College=$_collegeFilter, Department=$_departmentFilter');
    
    for (int i = 0; i < _filteredUsers.take(10).length; i++) {
      final user = _filteredUsers[i];
      print('${i + 1}. ${user['username']} - ${user['points']} points');
    }
    print('========================');
  }
}