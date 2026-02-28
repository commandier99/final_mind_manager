import '../../../../shared/features/query/task_query_controller.dart';
import '../../../tasks/datasources/models/task_model.dart';

class BoardTasksQueryController {
  final TaskQueryController _taskQueryController = TaskQueryController();

  static const String allFilter = TaskQueryController.allFilter;
  static const List<String> taskStatuses = TaskQueryController.taskStatuses;
  static const List<String> deadlineFilters =
      TaskQueryController.deadlineFilters;
  static final List<String> allFilters = TaskQueryController.allFilters;

  List<Task> applyQuery({
    required List<Task> tasks,
    required Set<String> selectedFilters,
    required String sortBy,
  }) {
    return _taskQueryController.applyQuery(
      tasks: tasks,
      selectedFilters: selectedFilters,
      sortBy: sortBy,
    );
  }

  Set<String> addFilter({
    required Set<String> selectedFilters,
    required String filter,
  }) {
    return _taskQueryController.addFilter(
      selectedFilters: selectedFilters,
      filter: filter,
    );
  }

  Set<String> removeFilter({
    required Set<String> selectedFilters,
    required String filter,
  }) {
    return _taskQueryController.removeFilter(
      selectedFilters: selectedFilters,
      filter: filter,
    );
  }

  String getFilterLabel(String filter) {
    return _taskQueryController.getFilterLabel(filter);
  }
}
