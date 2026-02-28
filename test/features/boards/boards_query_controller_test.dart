import 'package:flutter_test/flutter_test.dart';
import 'package:mind_manager_final/features/boards/datasources/models/board_model.dart';
import 'package:mind_manager_final/features/boards/datasources/models/board_stats_model.dart';
import 'package:mind_manager_final/features/boards/presentation/controllers/boards_query_controller.dart';

Board _board({
  required String id,
  required String title,
  required String type,
  required String purpose,
  required DateTime createdAt,
}) {
  return Board(
    boardId: id,
    boardManagerId: 'u1',
    boardManagerName: 'User',
    boardCreatedAt: createdAt,
    boardTitle: title,
    boardGoal: 'Goal',
    boardGoalDescription: 'Desc',
    stats: BoardStats(),
    boardType: type,
    boardPurpose: purpose,
    boardLastModifiedAt: createdAt,
    boardLastModifiedBy: 'u1',
  );
}

void main() {
  group('BoardsQueryController', () {
    final controller = BoardsQueryController();

    test('keeps Personal board pinned to top', () {
      final boards = [
        _board(
          id: '1',
          title: 'Zeta',
          type: 'team',
          purpose: 'project',
          createdAt: DateTime(2026, 1, 1),
        ),
        _board(
          id: '2',
          title: 'Personal',
          type: 'personal',
          purpose: 'category',
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = controller.applyQuery(
        boards: boards,
        searchQuery: '',
        selectedFilters: {BoardsQueryController.allFilter},
        sortBy: 'alphabetical_asc',
      );

      expect(result.first.boardTitle, 'Personal');
    });

    test('filters by board type', () {
      final boards = [
        _board(
          id: '1',
          title: 'Team Board',
          type: 'team',
          purpose: 'project',
          createdAt: DateTime(2026, 1, 1),
        ),
        _board(
          id: '2',
          title: 'Personal',
          type: 'personal',
          purpose: 'category',
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      final result = controller.applyQuery(
        boards: boards,
        searchQuery: '',
        selectedFilters: {'type_team'},
        sortBy: 'created_desc',
      );

      expect(result.length, 1);
      expect(result.first.boardType, 'team');
    });
  });
}
