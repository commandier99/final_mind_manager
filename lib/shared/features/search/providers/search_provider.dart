import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/search_service.dart';
import '../../users/datasources/models/user_model.dart';
import '../../users/datasources/services/user_services.dart';
import '../../../../features/boards/datasources/models/board_model.dart';
import '../../../../features/tasks/datasources/models/task_model.dart';

class SearchProvider extends ChangeNotifier {
  final SearchService _searchService = SearchService();
  final UserService _userService = UserService();

  // Search query
  String _query = '';
  String get query => _query;

  // Search results
  List<UserModel> _userResults = [];
  List<Board> _boardResults = [];
  List<Task> _taskResults = [];

  // Stream subscription for discoverable users
  StreamSubscription<List<UserModel>>? _userStreamSubscription;

  List<UserModel> get userResults => _userResults;
  List<Board> get boardResults => _boardResults;
  List<Task> get taskResults => _taskResults;

  // Loading states
  bool _isLoadingUsers = false;
  bool _isLoadingBoards = false;
  bool _isLoadingTasks = false;

  bool get isLoadingUsers => _isLoadingUsers;
  bool get isLoadingBoards => _isLoadingBoards;
  bool get isLoadingTasks => _isLoadingTasks;

  // Task filters
  String _priorityFilter = '';
  String _statusFilter = '';
  bool? _completionFilter;
  String _deadlineFilter = '';
  String _sortBy = 'dateNewest';

  String get priorityFilter => _priorityFilter;
  String get statusFilter => _statusFilter;
  bool? get completionFilter => _completionFilter;
  String get deadlineFilter => _deadlineFilter;
  String get sortBy => _sortBy;

  // Filtered task results (after applying filters)
  List<Task> get filteredTaskResults {
    List<Task> results = List.from(_taskResults);

    // Apply filters
    if (_priorityFilter.isNotEmpty) {
      results = _searchService.filterTasksByPriority(results, _priorityFilter);
    }
    if (_statusFilter.isNotEmpty) {
      results = _searchService.filterTasksByStatus(results, _statusFilter);
    }
    if (_completionFilter != null) {
      results = _searchService.filterTasksByCompletion(
        results,
        _completionFilter,
      );
    }
    if (_deadlineFilter.isNotEmpty) {
      results = _searchService.filterTasksByDeadline(results, _deadlineFilter);
    }

    // Apply sorting
    results = _searchService.sortTasks(results, _sortBy);

    return results;
  }

  // ========================
  // STREAM METHODS
  // ========================

  /// Stream discoverable users in real-time
  void streamDiscoverableUsers() {
    print('[SearchProvider] Starting stream for discoverable users');
    _isLoadingUsers = true;
    notifyListeners();

    _userStreamSubscription?.cancel();
    _userStreamSubscription = _searchService.streamDiscoverableUsers().listen(
      (users) {
        print('[SearchProvider] Received ${users.length} discoverable users');
        _userResults = users;
        _isLoadingUsers = false;
        notifyListeners();
      },
      onError: (e) {
        print('[SearchProvider] Error streaming users: $e');
        _userResults = [];
        _isLoadingUsers = false;
        notifyListeners();
      },
    );
  }

  /// Stop streaming users
  void stopStreamingUsers() {
    _userStreamSubscription?.cancel();
    _userStreamSubscription = null;
  }

  // ========================
  // SEARCH METHODS
  // ========================

  /// Search users (filters the streamed results)
  void searchUsers(String query) {
    _query = query;
    notifyListeners();
  }

  /// Get filtered user results based on search query
  List<UserModel> get filteredUserResults {
    if (_query.trim().isEmpty) {
      return _userResults;
    }

    final lowerQuery = _query.toLowerCase().trim();
    return _userResults.where((user) {
      final nameMatch = user.userName.toLowerCase().contains(lowerQuery);
      final handleMatch = user.userHandle.toLowerCase().contains(lowerQuery);
      final skillsMatch = user.userSkills.any(
        (skill) => skill.toLowerCase().contains(lowerQuery),
      );
      return nameMatch || handleMatch || skillsMatch;
    }).toList();
  }

  /// Search public boards
  Future<void> searchBoards(String query, String? currentUserId) async {
    _query = query;
    _isLoadingBoards = true;
    notifyListeners();

    try {
      _boardResults = await _searchService.searchPublicBoards(
        query,
        currentUserId: currentUserId,
      );
    } catch (e) {
      print('[SearchProvider] Error searching boards: $e');
      _boardResults = [];
    }

    _isLoadingBoards = false;
    notifyListeners();
  }

  /// Search user's tasks
  Future<void> searchTasks(String query, String userId) async {
    _query = query;
    _isLoadingTasks = true;
    notifyListeners();

    try {
      _taskResults = await _searchService.searchUserTasks(query, userId);
    } catch (e) {
      print('[SearchProvider] Error searching tasks: $e');
      _taskResults = [];
    }

    _isLoadingTasks = false;
    notifyListeners();
  }

  // ========================
  // FILTER METHODS
  // ========================

  void setPriorityFilter(String priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setCompletionFilter(bool? isDone) {
    _completionFilter = isDone;
    notifyListeners();
  }

  void setDeadlineFilter(String filter) {
    _deadlineFilter = filter;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void clearFilters() {
    _priorityFilter = '';
    _statusFilter = '';
    _completionFilter = null;
    _deadlineFilter = '';
    _sortBy = 'dateNewest';
    notifyListeners();
  }

  // ========================
  // CLEAR METHODS
  // ========================

  void clearUserResults() {
    _userResults = [];
    notifyListeners();
  }

  void clearBoardResults() {
    _boardResults = [];
    notifyListeners();
  }

  void clearTaskResults() {
    _taskResults = [];
    notifyListeners();
  }

  void clearAll() {
    _query = '';
    _userResults = [];
    _boardResults = [];
    _taskResults = [];
    clearFilters();
    notifyListeners();
  }

  @override
  void dispose() {
    _userStreamSubscription?.cancel();
    super.dispose();
  }
}
