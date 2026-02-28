import 'package:flutter_test/flutter_test.dart';
import 'package:mind_manager_final/features/tasks/datasources/models/task_model.dart';
import 'package:mind_manager_final/features/tasks/datasources/models/task_stats_model.dart';
import 'package:mind_manager_final/shared/features/query/task_query_controller.dart';

Task _task({
  required String id,
  required String title,
  required String status,
  String priority = 'Low',
  DateTime? deadline,
  DateTime? createdAt,
}) {
  return Task(
    taskId: id,
    taskBoardId: 'b1',
    taskOwnerId: 'u1',
    taskOwnerName: 'U',
    taskAssignedBy: 'U',
    taskAssignedTo: 'U',
    taskAssignedToName: 'U',
    taskPriorityLevel: priority,
    taskCreatedAt: createdAt ?? DateTime(2026, 1, 1),
    taskTitle: title,
    taskDescription: '',
    taskDeadline: deadline,
    taskStats: TaskStats(),
    taskStatus: status,
  );
}

void main() {
  group('TaskQueryController', () {
    final controller = TaskQueryController();

    test('filters by status and sorts by priority desc', () {
      final tasks = [
        _task(
          id: '1',
          title: 'A',
          status: 'To Do',
          priority: 'Low',
          createdAt: DateTime(2026, 1, 1),
        ),
        _task(
          id: '2',
          title: 'B',
          status: 'Paused',
          priority: 'High',
          createdAt: DateTime(2026, 1, 2),
        ),
        _task(
          id: '3',
          title: 'C',
          status: 'To Do',
          priority: 'High',
          createdAt: DateTime(2026, 1, 3),
        ),
      ];

      final result = controller.applyQuery(
        tasks: tasks,
        selectedFilters: {'To Do'},
        sortBy: 'priority_desc',
      );

      expect(result.map((t) => t.taskId).toList(), ['3', '1']);
    });

    test('add/remove filter preserves all-filter fallback', () {
      var filters = <String>{TaskQueryController.allFilter};
      filters = controller.addFilter(
        selectedFilters: filters,
        filter: 'Paused',
      );
      expect(filters.contains(TaskQueryController.allFilter), isFalse);
      expect(filters.contains('Paused'), isTrue);

      filters = controller.removeFilter(
        selectedFilters: filters,
        filter: 'Paused',
      );
      expect(filters, {TaskQueryController.allFilter});
    });
  });
}
