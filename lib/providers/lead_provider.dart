import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../secure_storage.dart'; // Replace with actual path

class LeadProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  Map<String, dynamic>? _currentUserData;
  int _currentUserRank = 0;

  String _timeFilter = 'Weekly';
  String _collegeFilter = 'All';
  String _departmentFilter = 'All';

  List<String> _availableColleges = ['All'];
  List<String> _availableDepartments = ['All'];

  String get timeFilter => _timeFilter;
  String get collegeFilter => _collegeFilter;
  String get departmentFilter => _departmentFilter;
  List<String> get availableColleges => _availableColleges;
  List<String> get availableDepartments => _availableDepartments;
  Map<String, dynamic>? get currentUserData => _currentUserData;
  int get currentUserRank => _currentUserRank;

  LeadProvider() {
    _loadSavedFilters();
  }

  Future<void> _loadSavedFilters() async {
    try {
      _timeFilter = await SecureStorage.read('lead_time_filter') ?? 'Weekly';
      _collegeFilter = await SecureStorage.read('lead_college_filter') ?? 'All';
      _departmentFilter = await SecureStorage.read('lead_department_filter') ?? 'All';
      notifyListeners();
    } catch (e) {
      print('Error loading saved filters: $e');
    }
  }

  Future<void> _saveFilters() async {
    try {
      await SecureStorage.write('lead_time_filter', _timeFilter);
      await SecureStorage.write('lead_college_filter', _collegeFilter);
      await SecureStorage.write('lead_department_filter', _departmentFilter);
    } catch (e) {
      print('Error saving filters: $e');
    }
  }

  Future<void> setTimeFilter(String filter) async {
    if (_timeFilter != filter) {
      _timeFilter = filter;
      await _saveFilters();
      await _applyFilters();
      notifyListeners();
    }
  }

  Future<void> setCollegeFilter(String filter) async {
    if (_collegeFilter != filter) {
      _collegeFilter = filter;
      _departmentFilter = 'All';
      await _saveFilters();
      await _loadAvailableDepartments();
      await _applyFilters();
      notifyListeners();
    }
  }

  Future<void> setDepartmentFilter(String filter) async {
    if (_departmentFilter != filter) {
      _departmentFilter = filter;
      await _saveFilters();
      await _applyFilters();
      notifyListeners();
    }
  }

  int _calculatePoints(Map<String, dynamic> userData) {
    try {
      if (_timeFilter == 'Weekly') {
        final weeklyXP = userData['weekly_xp'] ?? userData['xp'] ?? 0;
        final weeklyStreaks = userData['weekly_streaks'] ?? 0;
        final weeklyCoins = userData['weekly_coins'] ?? 0;
        return (weeklyXP * 1) + (weeklyStreaks * 10) + (weeklyCoins * 2);
      } else {
        final totalXP = userData['xp'] ?? 0;
        final totalStreaks = userData['streaks'] ?? 0;
        final totalCoins = userData['coins'] ?? 0;
        final totalUsage = userData['total_usage'] ?? 0;
        return (totalXP * 1) + (totalStreaks * 15) + (totalCoins * 3) + (totalUsage ~/ 60);
      }
    } catch (e) {
      print('Error calculating points: $e');
      return 0;
    }
  }

  Future<String?> _getCurrentUserPhone() async {
    try {
      return await SecureStorage.read('phone_number');
    } catch (e) {
      print('Error getting current user phone: $e');
      return null;
    }
  }

  Future<void> fetchLeaderboardData() async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('skillbench')
          .doc('ALL_USERS')
          .collection('users')
          .get();

      _allUsers = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final points = _calculatePoints(data);
        return {
          ...data,
          'points': points,
          'doc_id': doc.id,
        };
      }).toList();

      await _loadAvailableColleges();
      await _loadAvailableDepartments();
      await _applyFilters();
      await _findCurrentUserRank();

    } catch (e) {
      print('Error fetching leaderboard data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      _availableColleges = ['All'];
    }
  }

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
            .where((user) => user['college'] == _collegeFilter && user['department'] != null)
            .map((user) => user['department'].toString())
            .toSet()
            .toList();
      }

      departments.sort();
      _availableDepartments = ['All', ...departments];
    } catch (e) {
      _availableDepartments = ['All'];
    }
  }

  Future<void> _applyFilters() async {
    try {
      _filteredUsers = List.from(_allUsers);

      if (_collegeFilter != 'All') {
        _filteredUsers = _filteredUsers
            .where((user) => user['college'] == _collegeFilter)
            .toList();
      }

      if (_departmentFilter != 'All') {
        _filteredUsers = _filteredUsers
            .where((user) => user['department'] == _departmentFilter)
            .toList();
      }

      _filteredUsers.sort((a, b) => (b['points'] ?? 0).compareTo(a['points'] ?? 0));

    } catch (e) {
      print('Error applying filters: $e');
    }
  }

  Future<void> _findCurrentUserRank() async {
    try {
      final phone = await _getCurrentUserPhone();
      if (phone == null) return;

      for (int i = 0; i < _filteredUsers.length; i++) {
        final user = _filteredUsers[i];
        if (user['phone_number'] == phone) {
          _currentUserData = user;
          _currentUserRank = i + 1;
          return;
        }
      }

      for (int i = 0; i < _allUsers.length; i++) {
        final user = _allUsers[i];
        if (user['phone_number'] == phone) {
          _currentUserData = user;
          _currentUserRank = _calculateUserRankInFilteredContext(user);
          return;
        }
      }

      _currentUserData = null;
      _currentUserRank = 0;
    } catch (e) {
      print('Error finding current user rank: $e');
    }
  }

  int _calculateUserRankInFilteredContext(Map<String, dynamic> userData) {
    final userPoints = userData['points'] ?? 0;
    int rank = 1;
    for (final user in _filteredUsers) {
      if ((user['points'] ?? 0) > userPoints) rank++;
    }
    return rank;
  }

  List<Map<String, dynamic>> getTopThreeUsers() {
    return _filteredUsers.length >= 3 ? _filteredUsers.take(3).toList() : _filteredUsers;
  }

  List<Map<String, dynamic>> getRemainingUsers() {
    return _filteredUsers.length > 3 ? _filteredUsers.skip(3).toList() : [];
  }

  bool isUserInTopThree() => _currentUserRank > 0 && _currentUserRank <= 3;

  Future<void> refreshData() async => await fetchLeaderboardData();

  Map<String, int> getUserStats() {
    try {
      int total = _allUsers.length;
      int filtered = _filteredUsers.length;
      int active = _allUsers.where((user) {
        final lastLogin = user['last_login'];
        final loginDate = lastLogin is Timestamp ? lastLogin.toDate() : DateTime.tryParse(lastLogin.toString());
        return loginDate != null && DateTime.now().difference(loginDate).inDays <= 7;
      }).length;
      return {'total_users': total, 'filtered_users': filtered, 'active_users': active};
    } catch (_) {
      return {'total_users': 0, 'filtered_users': 0, 'active_users': 0};
    }
  }

  String? getUserProfileImage(Map<String, dynamic> user) {
    if (user['profile_image'] != null && user['profile_image'].toString().isNotEmpty) {
      return user['profile_image'].toString();
    }
    final picType = user['profile_pic_type'];
    switch (picType) {
      case 0:
        return 'assets/profile_page/profile_images/profile_6.png';
      case 1:
        return 'assets/profile_page/profile_images/profile_7.png';
      case 2:
        return 'assets/profile_page/profile_images/profile_0.png';
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> searchUsers(String query) {
    if (query.isEmpty) return _filteredUsers;
    return _filteredUsers.where((user) =>
        (user['username']?.toLowerCase() ?? '').contains(query.toLowerCase())).toList();
  }

  Map<String, dynamic>? getUserByRank(int rank) =>
      rank > 0 && rank <= _filteredUsers.length ? _filteredUsers[rank - 1] : null;

  String getLeaderboardPeriodInfo() {
    if (_timeFilter == 'Weekly') {
      final start = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
      final end = start.add(const Duration(days: 6));
      return 'Week of ${_formatDate(start)} - ${_formatDate(end)}';
    }
    return 'All Time Rankings';
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  void clearData() {
    _allUsers.clear();
    _filteredUsers.clear();
    _currentUserData = null;
    _currentUserRank = 0;
    _availableColleges = ['All'];
    _availableDepartments = ['All'];
    notifyListeners();
  }

  void debugPrintLeaderboard() {
    print('=== LEADERBOARD DEBUG ===');
    print('Total: ${_allUsers.length}, Filtered: ${_filteredUsers.length}, Rank: $_currentUserRank');
    for (int i = 0; i < _filteredUsers.take(10).length; i++) {
      final user = _filteredUsers[i];
      print('${i + 1}. ${user['username']} - ${user['points']} pts');
    }
  }
}
