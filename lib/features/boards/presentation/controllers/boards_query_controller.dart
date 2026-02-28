import '../../datasources/models/board_model.dart';
import '../../../../shared/features/query/shared_query_controller.dart';

class BoardsQueryController {
  final SharedQueryController _sharedQuery = SharedQueryController();

  static const String allFilter = 'All';
  static const List<String> boardTypeFilters = ['type_team', 'type_personal'];
  static const List<String> boardPurposeFilters = [
    'purpose_project',
    'purpose_category',
  ];
  static final List<String> allFilters = [
    allFilter,
    ...boardTypeFilters,
    ...boardPurposeFilters,
  ];

  static const Map<String, String> filterLabels = {
    'type_team': 'Team boards',
    'type_personal': 'Personal boards',
    'purpose_project': 'Project boards',
    'purpose_category': 'Category boards',
  };

  List<Board> applyQuery({
    required List<Board> boards,
    required String searchQuery,
    required Set<String> selectedFilters,
    required String sortBy,
  }) {
    return _sharedQuery.apply<Board>(
      items: boards,
      searchQuery: searchQuery,
      searchPredicate: (board, normalized) =>
          board.boardTitle.toLowerCase().contains(normalized) ||
          board.boardGoalDescription.toLowerCase().contains(normalized),
      filterPredicate: (board) => _matchesFilter(board, selectedFilters),
      sortComparator: _buildSortComparator(sortBy),
      pinToTopPredicate: (board) =>
          board.boardTitle.toLowerCase() == 'personal',
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
    if (filter == allFilter) return 'All boards';
    return filterLabels[filter] ?? filter;
  }

  int getNextUntitledBoardNumber(List<Board> existingBoards) {
    var maxNumber = 0;
    final regex = RegExp(r'^Board (\d+)$');

    for (final board in existingBoards) {
      final match = regex.firstMatch(board.boardTitle);
      if (match == null) continue;
      final number = int.tryParse(match.group(1) ?? '');
      if (number != null && number > maxNumber) {
        maxNumber = number;
      }
    }

    return maxNumber + 1;
  }

  bool _matchesFilter(Board board, Set<String> selectedFilters) {
    if (selectedFilters.contains(allFilter)) return true;

    final selectedTypes = selectedFilters
        .where((filter) => boardTypeFilters.contains(filter))
        .map((filter) => filter.replaceFirst('type_', ''))
        .toSet();
    final selectedPurposes = selectedFilters
        .where((filter) => boardPurposeFilters.contains(filter))
        .map((filter) => filter.replaceFirst('purpose_', ''))
        .toSet();

    final typeMatch =
        selectedTypes.isEmpty || selectedTypes.contains(board.boardType);
    final purposeMatch =
        selectedPurposes.isEmpty ||
        selectedPurposes.contains(board.boardPurpose);
    return typeMatch && purposeMatch;
  }

  int Function(Board a, Board b) _buildSortComparator(String sortBy) {
    switch (sortBy) {
      case 'alphabetical_asc':
        return (a, b) =>
            a.boardTitle.toLowerCase().compareTo(b.boardTitle.toLowerCase());
      case 'alphabetical_desc':
        return (a, b) =>
            b.boardTitle.toLowerCase().compareTo(a.boardTitle.toLowerCase());
      case 'created_asc':
        return (a, b) => a.boardCreatedAt.compareTo(b.boardCreatedAt);
      case 'created_desc':
        return (a, b) => b.boardCreatedAt.compareTo(a.boardCreatedAt);
      case 'modified_asc':
        return (a, b) => a.boardLastModifiedAt.compareTo(b.boardLastModifiedAt);
      case 'modified_desc':
      default:
        return (a, b) => b.boardLastModifiedAt.compareTo(a.boardLastModifiedAt);
    }
  }
}
