import 'package:flutter_test/flutter_test.dart';
import 'package:mind_manager_final/features/plans/datasources/models/plans_model.dart';
import 'package:mind_manager_final/features/plans/presentation/controllers/plans_query_controller.dart';

Plan _plan({
  required String id,
  required String title,
  DateTime? deadline,
  required DateTime createdAt,
}) {
  return Plan(
    planId: id,
    planOwnerId: 'u1',
    planOwnerName: 'U',
    planTitle: title,
    planDescription: 'desc',
    planCreatedAt: createdAt,
    planDeadline: deadline,
    totalTasks: 10,
    completedTasks: 5,
  );
}

void main() {
  group('PlansQueryController', () {
    final controller = PlansQueryController();

    test('searches by title/style and sorts alphabetically', () {
      final plans = [
        _plan(
          id: '1',
          title: 'Write thesis',
          createdAt: DateTime(2026, 1, 1),
        ),
        _plan(
          id: '2',
          title: 'Workout',
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = controller.applyQuery(
        plans: plans,
        searchQuery: 'work',
        selectedFilters: {PlansQueryController.allFilter},
        sortBy: 'alphabetical_asc',
      );

      expect(result.length, 1);
      expect(result.first.planId, '2');
    });

    test('filters by deadline', () {
      final plans = [
        _plan(
          id: '1',
          title: 'A',
          deadline: DateTime(2026, 1, 1),
          createdAt: DateTime(2026, 1, 1),
        ),
        _plan(
          id: '2',
          title: 'B',
          deadline: null,
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = controller.applyQuery(
        plans: plans,
        searchQuery: '',
        selectedFilters: {'deadline_None'},
        sortBy: 'created_desc',
      );

      expect(result.length, 1);
      expect(result.first.planId, '2');
    });
  });
}
