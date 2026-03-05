import '../../../features/tasks/datasources/models/task_model.dart';
import 'shared_query_controller.dart';

class TaskQueryController {
  final SharedQueryController _sharedQuery = SharedQueryController();

  static const String allFilter = 'All';
  static const List<String> taskStatuses = [
    Task.statusToDo,
    Task.statusInProgress,
    Task.statusPaused,
    Task.statusSubmitted,
    Task.statusCompleted,
  ];
  static const List<String> deadlineFilters = [
    'Overdue',
    'Today',
    'Upcoming',
    'None',
  ];
  static final List<String> allFilters = [
    allFilter,
    ...taskStatuses,
    ...deadlineFilters,
  ];

  static const Map<String, String> statusLabels = {
    Task.statusToDo: Task.statusToDo,
    Task.statusInProgress: Task.statusInProgress,
    Task.statusPaused: Task.statusPaused,
    Task.statusSubmitted: Task.statusSubmitted,
    Task.statusCompleted: Task.statusCompleted,
  };

  static const Map<String, String> deadlineLabels = {
    'Overdue': 'Overdue',
    'Today': 'Today',
    'Upcoming': 'Upcoming',
    'None': 'None',
  };

  List<Task> applyQuery({
    required List<Task> tasks,
    required Set<String> selectedFilters,
    String? sortBy,
  }) {
    return _sharedQuery.apply<Task>(
      items: tasks,
      filterPredicate: (task) => _matchesFilter(task, selectedFilters),
      sortComparator: sortBy == null ? null : _buildSortComparator(sortBy),
    );
  }

  Set<String> addFilter({
    required Set<String> selectedFilters,
    required String filter,
  }) {
    return _sharedQuery.addFilter(
      selectedFilters: selectedFilters,
      filter: filter,
      allFilter: allFilter,
    );
  }

  Set<String> removeFilter({
    required Set<String> selectedFilters,
    required String filter,
  }) {
    return _sharedQuery.removeFilter(
      selectedFilters: selectedFilters,
      filter: filter,
      allFilter: allFilter,
    );
  }

  String getFilterLabel(String filter) {
    if (taskStatuses.contains(filter)) {
      return 'Status: ${statusLabels[filter] ?? filter}';
    }
    if (deadlineFilters.contains(filter)) {
      return 'Deadline: ${deadlineLabels[filter] ?? filter}';
    }
    return filter;
  }

  bool _matchesFilter(Task task, Set<String> selectedFilters) {
    if (selectedFilters.contains(allFilter)) return true;

    final selectedStatuses = selectedFilters
        .where((f) => taskStatuses.contains(f))
        .toSet();
    final selectedDeadlineFilters = selectedFilters
        .where((f) => deadlineFilters.contains(f))
        .toSet();

    if (selectedStatuses.isEmpty) return false;
    final statusMatch = selectedStatuses.contains(task.taskStatus);
    if (selectedDeadlineFilters.isEmpty) return statusMatch;

    final deadlineMatch = selectedDeadlineFilters.any(
      (filter) => _matchesDeadlineFilter(task, filter),
    );
    return statusMatch && deadlineMatch;
  }

  bool _matchesDeadlineFilter(Task task, String filter) {
    switch (filter) {
      case 'Overdue':
        return task.isOverdue;
      case 'Today':
        return task.isDueToday;
      case 'Upcoming':
        return task.isDueUpcoming;
      case 'None':
        return task.taskDeadline == null;
      default:
        return false;
    }
  }

  int _priorityToInt(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  int Function(Task a, Task b) _buildSortComparator(String sortBy) {
    switch (sortBy) {
      case 'priority_asc':
        return (a, b) => _priorityToInt(
          a.taskPriorityLevel,
        ).compareTo(_priorityToInt(b.taskPriorityLevel));
      case 'priority_desc':
        return (a, b) => _priorityToInt(
          b.taskPriorityLevel,
        ).compareTo(_priorityToInt(a.taskPriorityLevel));
      case 'alphabetical_asc':
        return (a, b) =>
            a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase());
      case 'alphabetical_desc':
        return (a, b) =>
            b.taskTitle.toLowerCase().compareTo(a.taskTitle.toLowerCase());
      case 'created_asc':
        return (a, b) => a.taskCreatedAt.compareTo(b.taskCreatedAt);
      case 'deadline_asc':
        return (a, b) {
          final aDeadline = a.taskDeadline ?? DateTime(2099);
          final bDeadline = b.taskDeadline ?? DateTime(2099);
          return aDeadline.compareTo(bDeadline);
        };
      case 'deadline_desc':
        return (a, b) {
          final aDeadline = a.taskDeadline ?? DateTime(1970);
          final bDeadline = b.taskDeadline ?? DateTime(1970);
          return bDeadline.compareTo(aDeadline);
        };
      case 'created_desc':
      default:
        return (a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt);
    }
  }
}
