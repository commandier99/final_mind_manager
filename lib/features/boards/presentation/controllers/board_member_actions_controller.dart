import '../../datasources/services/board_services.dart';
import '../../datasources/models/board_model.dart';
import '../../datasources/providers/board_provider.dart';

class BoardActionResult {
  final bool success;
  final String message;

  const BoardActionResult({required this.success, required this.message});
}

class BoardMemberActionsController {
  final BoardService _boardService;

  BoardMemberActionsController({BoardService? boardService})
    : _boardService = boardService ?? BoardService();

  Future<BoardActionResult> changeUserRole({
    required Board board,
    required String userId,
    required String currentRole,
    required BoardProvider boardProvider,
  }) async {
    final newRole = currentRole == 'inspector' ? 'member' : 'inspector';

    if (newRole == 'inspector') {
      final existingInspector = board.memberRoles.entries.firstWhere(
        (entry) => entry.value == 'inspector' && entry.key != userId,
        orElse: () => const MapEntry('', ''),
      );
      if (existingInspector.key.isNotEmpty) {
        return const BoardActionResult(
          success: false,
          message:
              'Only one inspector is allowed per board. Remove the current inspector first.',
        );
      }
    }

    try {
      final updatedRoles = Map<String, String>.from(board.memberRoles);
      updatedRoles[userId] = newRole;

      await _boardService.updateBoard(board.boardId, memberRoles: updatedRoles);
      await boardProvider.refreshBoards();

      return BoardActionResult(
        success: true,
        message:
            'Member role changed to ${newRole == 'inspector' ? 'Inspector' : 'Member'}',
      );
    } catch (e) {
      return BoardActionResult(
        success: false,
        message: 'Failed to change role: $e',
      );
    }
  }

  Future<BoardActionResult> kickMember({
    required Board board,
    required String memberIdToKick,
    required String memberName,
    required BoardProvider boardProvider,
  }) async {
    try {
      await _boardService.kickMember(
        boardId: board.boardId,
        memberIdToKick: memberIdToKick,
        memberName: memberName,
      );
      await boardProvider.refreshBoards();
      return BoardActionResult(
        success: true,
        message: '$memberName has been removed from the board',
      );
    } catch (e) {
      return BoardActionResult(
        success: false,
        message: 'Failed to remove member: $e',
      );
    }
  }

  Future<BoardActionResult> leaveBoard({
    required Board board,
    required BoardProvider boardProvider,
  }) async {
    try {
      await _boardService.leaveBoard(boardId: board.boardId);
      await boardProvider.refreshBoards();
      return const BoardActionResult(
        success: true,
        message: 'You have left the board',
      );
    } catch (e) {
      return BoardActionResult(
        success: false,
        message: 'Failed to leave board: $e',
      );
    }
  }
}
