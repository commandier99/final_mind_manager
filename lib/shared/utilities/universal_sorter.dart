import 'package:flutter/material.dart';
import '../../features/tasks/datasources/models/task_model.dart';
import '../../features/boards/datasources/models/board_model.dart';

enum SortCriteria {
  // Common
  titleAsc,
  titleDesc,
  createdAsc,
  createdDesc,

  // Task-specific
  deadlineAsc,
  deadlineDesc,
  boardAsc,
  boardDesc,

  // Board-specific
  boardOwnerAsc,
  boardOwnerDesc,
}

class UniversalSorter {
  static List<T> sort<T>(List<T> items, SortCriteria criteria) {
    if (items.isEmpty) return items;

    if (items.first is Task) {
      _sortTasks(items as List<Task>, criteria);
    } else if (items.first is Board) {
      _sortBoards(items as List<Board>, criteria);
    }

    return items;
  }

  static void _sortTasks(List<Task> tasks, SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.titleAsc:
        tasks.sort((a, b) => a.taskTitle.toLowerCase().compareTo(b.taskTitle.toLowerCase()));
        break;
      case SortCriteria.titleDesc:
        tasks.sort((a, b) => b.taskTitle.toLowerCase().compareTo(a.taskTitle.toLowerCase()));
        break;
      case SortCriteria.deadlineAsc:
        tasks.sort((a, b) {
          if (a.taskDeadline == null && b.taskDeadline == null) return 0;
          if (a.taskDeadline == null) return 1;
          if (b.taskDeadline == null) return -1;
          return a.taskDeadline!.compareTo(b.taskDeadline!);
        });
        break;
      case SortCriteria.deadlineDesc:
        tasks.sort((a, b) {
          if (a.taskDeadline == null && b.taskDeadline == null) return 0;
          if (a.taskDeadline == null) return 1;
          if (b.taskDeadline == null) return -1;
          return b.taskDeadline!.compareTo(a.taskDeadline!);
        });
        break;
      case SortCriteria.createdAsc:
        tasks.sort((a, b) => a.taskCreatedAt.compareTo(b.taskCreatedAt));
        break;
      case SortCriteria.createdDesc:
        tasks.sort((a, b) => b.taskCreatedAt.compareTo(a.taskCreatedAt));
        break;
      case SortCriteria.boardAsc:
        tasks.sort((a, b) => (a.taskBoardTitle ?? '').toLowerCase().compareTo((b.taskBoardTitle ?? '').toLowerCase()));
        break;
      case SortCriteria.boardDesc:
        tasks.sort((a, b) => (b.taskBoardTitle ?? '').toLowerCase().compareTo((a.taskBoardTitle ?? '').toLowerCase()));
        break;
      default:
        break;
    }
  }

  static void _sortBoards(List<Board> boards, SortCriteria criteria) {
    switch (criteria) {
      case SortCriteria.titleAsc:
        boards.sort((a, b) => a.boardTitle.toLowerCase().compareTo(b.boardTitle.toLowerCase()));
        break;
      case SortCriteria.titleDesc:
        boards.sort((a, b) => b.boardTitle.toLowerCase().compareTo(a.boardTitle.toLowerCase()));
        break;
      case SortCriteria.createdAsc:
        boards.sort((a, b) => a.boardCreatedAt.compareTo(b.boardCreatedAt));
        break;
      case SortCriteria.createdDesc:
        boards.sort((a, b) => b.boardCreatedAt.compareTo(a.boardCreatedAt));
        break;
      case SortCriteria.boardOwnerAsc:
        boards.sort((a, b) => a.boardManagerName.toLowerCase().compareTo(b.boardManagerName.toLowerCase()));
        break;
      case SortCriteria.boardOwnerDesc:
        boards.sort((a, b) => b.boardManagerName.toLowerCase().compareTo(a.boardManagerName.toLowerCase()));
        break;
      default:
        break;
    }
  }

  /// Board-specific sort menu
  static List<PopupMenuEntry<SortCriteria>> buildBoardSortMenuItems() {
    return const [
      PopupMenuItem(value: SortCriteria.createdAsc, child: Text('Date Created (Oldest First)')),
      PopupMenuItem(value: SortCriteria.createdDesc, child: Text('Date Created (Newest First)')),
      PopupMenuItem(value: SortCriteria.titleAsc, child: Text('Title (A-Z)')),
      PopupMenuItem(value: SortCriteria.titleDesc, child: Text('Title (Z-A)')),
      PopupMenuItem(value: SortCriteria.boardOwnerAsc, child: Text('Board Owner (A-Z)')),
      PopupMenuItem(value: SortCriteria.boardOwnerDesc, child: Text('Board Owner (Z-A)')),
    ];
  }

  /// Task-specific sort menu (dynamic: hide board option in board view)
  static List<PopupMenuEntry<SortCriteria>> buildTaskSortMenuItems({bool isBoardView = false}) {
    final items = <PopupMenuEntry<SortCriteria>>[
      const PopupMenuItem(value: SortCriteria.createdAsc, child: Text('Date Created (Oldest First)')),
      const PopupMenuItem(value: SortCriteria.createdDesc, child: Text('Date Created (Newest First)')),
      const PopupMenuItem(value: SortCriteria.deadlineAsc, child: Text('Deadline (Soonest First)')),
      const PopupMenuItem(value: SortCriteria.deadlineDesc, child: Text('Deadline (Latest First)')),
      const PopupMenuItem(value: SortCriteria.titleAsc, child: Text('Title (A-Z)')),
      const PopupMenuItem(value: SortCriteria.titleDesc, child: Text('Title (Z-A)')),
    ];

    if (!isBoardView) {
      // Only show board sorting if not in a single board view
      items.addAll([
        const PopupMenuItem(value: SortCriteria.boardAsc, child: Text('Board (A-Z)')),
        const PopupMenuItem(value: SortCriteria.boardDesc, child: Text('Board (Z-A)')),
      ]);
    }

    return items;
  }
}
