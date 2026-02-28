import '../../datasources/models/plans_model.dart';
import '../../../../shared/features/query/shared_query_controller.dart';

class PlansQueryController {
  final SharedQueryController _sharedQuery = SharedQueryController();

  static const String allFilter = 'All';
  static const List<String> deadlineFilters = [
    'deadline_Overdue',
    'deadline_Today',
    'deadline_Upcoming',
    'deadline_None',
  ];
  static final List<String> allFilters = [allFilter, ...deadlineFilters];

  List<Plan> applyQuery({
    required List<Plan> plans,
    required String searchQuery,
    required Set<String> selectedFilters,
    required String sortBy,
  }) {
    return _sharedQuery.apply<Plan>(
      items: plans,
      searchQuery: searchQuery,
      searchPredicate: (plan, normalized) =>
          plan.planTitle.toLowerCase().contains(normalized) ||
          plan.planDescription.toLowerCase().contains(normalized),
      filterPredicate: (plan) => _matchesFilter(plan, selectedFilters),
      sortComparator: _buildSortComparator(sortBy),
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
    if (filter == allFilter) return 'All plans';
    if (filter.startsWith('deadline_')) {
      return 'Deadline: ${filter.replaceFirst('deadline_', '')}';
    }
    return filter;
  }

  bool _matchesFilter(Plan plan, Set<String> selectedFilters) {
    if (selectedFilters.contains(allFilter)) return true;

    final selectedDeadlines = selectedFilters
        .where((filter) => deadlineFilters.contains(filter))
        .toSet();

    final deadlineMatch =
        selectedDeadlines.isEmpty ||
        selectedDeadlines.any((filter) => _matchesDeadlineFilter(plan, filter));

    return deadlineMatch;
  }

  bool _matchesDeadlineFilter(Plan plan, String filter) {
    final deadline = plan.planDeadline;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (filter == 'deadline_None') return deadline == null;
    if (deadline == null) return false;

    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    switch (filter) {
      case 'deadline_Overdue':
        return deadlineDate.isBefore(todayDate);
      case 'deadline_Today':
        return _isSameDay(deadlineDate, todayDate);
      case 'deadline_Upcoming':
        return deadlineDate.isAfter(todayDate);
      default:
        return false;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int Function(Plan a, Plan b) _buildSortComparator(String sortBy) {
    switch (sortBy) {
      case 'alphabetical_asc':
        return (a, b) =>
            a.planTitle.toLowerCase().compareTo(b.planTitle.toLowerCase());
      case 'alphabetical_desc':
        return (a, b) =>
            b.planTitle.toLowerCase().compareTo(a.planTitle.toLowerCase());
      case 'created_asc':
        return (a, b) => a.planCreatedAt.compareTo(b.planCreatedAt);
      case 'deadline_asc':
        return (a, b) {
          final aDeadline = a.planDeadline ?? DateTime(2099);
          final bDeadline = b.planDeadline ?? DateTime(2099);
          return aDeadline.compareTo(bDeadline);
        };
      case 'deadline_desc':
        return (a, b) {
          final aDeadline = a.planDeadline ?? DateTime(1970);
          final bDeadline = b.planDeadline ?? DateTime(1970);
          return bDeadline.compareTo(aDeadline);
        };
      case 'completion_desc':
        return (a, b) =>
            b.completionPercentage.compareTo(a.completionPercentage);
      case 'completion_asc':
        return (a, b) =>
            a.completionPercentage.compareTo(b.completionPercentage);
      case 'created_desc':
      default:
        return (a, b) => b.planCreatedAt.compareTo(a.planCreatedAt);
    }
  }
}
