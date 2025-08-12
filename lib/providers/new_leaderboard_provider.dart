import 'package:flutter/foundation.dart';
import '../models/leaderboard_models.dart';
import '../repositories/leaderboard_repository.dart';
import '../theme/leaderboard_theme.dart';

/// Provider for the new leaderboard screen with advanced state management
class NewLeaderboardProvider with ChangeNotifier {
  final LeaderboardRepository _repository;
  
  // State
  LeaderboardSnapshot _snapshot = LeaderboardSnapshot.empty();
  LeaderboardFilters _filters = const LeaderboardFilters(timeframe: Timeframe.weekly);
  Map<String, List<String>> _filterOptions = {'groups': ['All'], 'categories': ['All']};
  
  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isRefreshing = false;
  String? _error;
  
  // Pagination state
  int _currentPage = 0;
  final List<LeaderboardUser> _allLoadedUsers = [];
  
  NewLeaderboardProvider(this._repository) {
    _initializeData();
  }

  // Getters
  LeaderboardSnapshot get snapshot => _snapshot;
  LeaderboardFilters get filters => _filters;
  Map<String, List<String>> get filterOptions => _filterOptions;
  
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  
  List<LeaderboardUser> get topThree => _snapshot.topThree;
  LeaderboardUser? get currentUser => _snapshot.currentUser;
  List<LeaderboardUser> get allUsers => List.unmodifiable(_allLoadedUsers);
  LeaderboardStats get stats => _snapshot.stats;
  
  bool get hasMorePages => _snapshot.hasMorePages;
  bool get canLoadMore => !_isLoadingMore && hasMorePages;

  /// Initialize data on provider creation
  Future<void> _initializeData() async {
    await Future.wait([
      _loadFilterOptions(),
      refresh(),
    ]);
  }

  /// Load available filter options
  Future<void> _loadFilterOptions() async {
    try {
      _filterOptions = await _repository.getFilterOptions();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading filter options: $e');
    }
  }

  /// Refresh all data (pull-to-refresh)
  Future<void> refresh() async {
    if (_isRefreshing) return;
    
    _isRefreshing = true;
    _error = null;
    _currentPage = 0;
    _allLoadedUsers.clear();
    notifyListeners();
    
    try {
      _repository.clearCache();
      await _fetchData(isRefresh: true);
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// Load initial data or refresh
  Future<void> loadData() async {
    if (_isLoading) return;
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _fetchData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load next page of users
  Future<void> loadMoreUsers() async {
    if (!canLoadMore) return;
    
    _isLoadingMore = true;
    notifyListeners();
    
    try {
      final nextPage = _currentPage + 1;
      final nextSnapshot = await _repository.fetchLeaderboard(
        timeframe: _filters.timeframe,
        group: _filters.group,
        category: _filters.category,
        page: nextPage,
        pageSize: SBConstants.pageSize,
      );
      
      _currentPage = nextPage;
      _allLoadedUsers.addAll(nextSnapshot.users);
      _snapshot = _snapshot.copyWith(
        users: nextSnapshot.users,
        currentPage: nextSnapshot.currentPage,
        hasMorePages: nextSnapshot.hasMorePages,
      );
      
    } catch (e) {
      _error = 'Failed to load more users: $e';
      if (kDebugMode) print(_error);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Update timeframe filter
  Future<void> setTimeframe(Timeframe timeframe) async {
    if (_filters.timeframe == timeframe) return;
    
    _filters = _filters.copyWith(timeframe: timeframe);
    await _applyFiltersAndReload();
  }

  /// Update group filter
  Future<void> setGroup(String? group) async {
    if (_filters.group == group) return;
    
    _filters = _filters.copyWith(group: group);
    await _applyFiltersAndReload();
  }

  /// Update category filter  
  Future<void> setCategory(String? category) async {
    if (_filters.category == category) return;
    
    _filters = _filters.copyWith(category: category);
    await _applyFiltersAndReload();
  }

  /// Apply filters and reload data
  Future<void> _applyFiltersAndReload() async {
    _currentPage = 0;
    _allLoadedUsers.clear();
    await loadData();
  }

  /// Core data fetching logic
  Future<void> _fetchData({bool isRefresh = false}) async {
    try {
      final newSnapshot = await _repository.fetchLeaderboard(
        timeframe: _filters.timeframe,
        group: _filters.group,
        category: _filters.category,
        page: 0,
        pageSize: SBConstants.pageSize,
      );
      
      _snapshot = newSnapshot;
      _allLoadedUsers.clear();
      _allLoadedUsers.addAll(newSnapshot.users);
      _currentPage = 0;
      _error = null;
      
    } catch (e) {
      _error = isRefresh ? 'Failed to refresh data' : 'Failed to load data';
      if (kDebugMode) print('$_error: $e');
      
      // Keep existing data on error unless it's the first load
      if (_snapshot == LeaderboardSnapshot.empty()) {
        _snapshot = LeaderboardSnapshot.empty();
      }
    }
  }

  /// Get user by rank (1-indexed)
  LeaderboardUser? getUserByRank(int rank) {
    if (rank <= 0) return null;
    
    // Check top three first
    if (rank <= topThree.length) {
      return topThree[rank - 1];
    }
    
    // Check all loaded users
    final adjustedIndex = rank - topThree.length - 1;
    if (adjustedIndex >= 0 && adjustedIndex < _allLoadedUsers.length) {
      return _allLoadedUsers[adjustedIndex];
    }
    
    return null;
  }

  /// Check if current user is in top 3
  bool get isCurrentUserInTopThree {
    return currentUser != null && currentUser!.rank <= 3;
  }

  /// Get display name for current timeframe
  String get timeframeDisplayName => _filters.timeframe.displayName;

  /// Get formatted period info
  String get periodInfo {
    switch (_filters.timeframe) {
      case Timeframe.daily:
        final today = DateTime.now();
        return 'Today - ${_formatDate(today)}';
      case Timeframe.weekly:
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return 'Week of ${_formatDate(startOfWeek)} - ${_formatDate(endOfWeek)}';
      case Timeframe.monthly:
        final now = DateTime.now();
        return 'Month of ${_getMonthName(now.month)} ${now.year}';
      case Timeframe.allTime:
        return 'All Time Rankings';
    }
  }

  /// Check if there's an error that should be retried
  bool get hasRetriableError => _error != null && _snapshot == LeaderboardSnapshot.empty();

  /// Retry after error
  Future<void> retry() async {
    if (!hasRetriableError) return;
    await loadData();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Utility method to format date
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Utility method to get month name
  String _getMonthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  /// Reset all data (useful for logout/user change)
  void reset() {
    _snapshot = LeaderboardSnapshot.empty();
    _filters = const LeaderboardFilters(timeframe: Timeframe.weekly);
    _currentPage = 0;
    _allLoadedUsers.clear();
    _isLoading = false;
    _isLoadingMore = false;
    _isRefreshing = false;
    _error = null;
    _repository.clearCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.clearCache();
    super.dispose();
  }

  /// Debug helper to print current state
  void debugPrint() {
    if (kDebugMode) {
      print('=== New Leaderboard Provider State ===');
      print('Filters: $_filters');
      print('Top 3: ${topThree.map((u) => '${u.name} (${u.points})').toList()}');
      print('Current User: ${currentUser?.name} (Rank: ${currentUser?.rank})');
      print('Total Loaded Users: ${_allLoadedUsers.length}');
      print('Has More Pages: $hasMorePages');
      print('Stats: ${stats.totalUsers} total, ${stats.activeUsers} active');
      print('Error: $_error');
      print('=====================================');
    }
  }
}