import 'package:flutter/foundation.dart';
import '../models/subtask_model.dart';
import '../services/subtask_services.dart';

class SubtaskProvider with ChangeNotifier {
  final SubtaskService _subtaskService = SubtaskService();

  Stream<List<Subtask>> streamSubtasksByTaskId(String taskId) {
    return _subtaskService.streamSubtasksByTaskId(taskId);
  }

  Stream<List<Subtask>> streamActiveSubtasksByTaskId(String taskId) {
    return _subtaskService.streamActiveSubtasksByTaskId(taskId);
  }

  Stream<List<Subtask>> streamDeletedSubtasks() {
    return _subtaskService.streamDeletedSubtasks();
  }

  Future<void> addSubtask({
    required String subtaskTaskId,
    required String subtaskBoardId,
    String? subtaskTitle,
  }) async {
    try {
      await _subtaskService.addSubtask(
        subtaskTaskId: subtaskTaskId,
        subtaskBoardId: subtaskBoardId,
        subtaskTitle: subtaskTitle,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error adding subtask: $e");
      }
    }
  }

  Future<void> toggleSubtaskDoneStatus(Subtask subtask) async {
    try {
      await _subtaskService.toggleSubtaskDoneStatus(subtask);
    } catch (e) {
      if (kDebugMode) {
        print("Error toggling subtask: $e");
      }
    }
  }

  Future<void> softDeleteSubtask(Subtask subtask) async {
    try {
      await _subtaskService.softDeleteSubtask(subtask);
    } catch (e) {
      if (kDebugMode) {
        print("Error soft deleting subtask: $e");
      }
    }
  }

  Future<void> restoreSubtask(Subtask subtask) async {
    try {
      await _subtaskService.restoreSubtask(subtask);
    } catch (e) {
      if (kDebugMode) {
        print("Error restoring subtask: $e");
      }
    }
  }

  Future<void> deleteSubtask(String subtaskId) async {
    try {
      await _subtaskService.deleteSubtask(subtaskId);
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting subtask: $e");
      }
    }
  }

  Future<void> updateSubtask(String subtaskId, Subtask updatedSubtask) async {
    try {
      await _subtaskService.updateSubtask(subtaskId, updatedSubtask);
    } catch (e) {
      if (kDebugMode) {
        print("Error updating subtask: $e");
      }
    }
  }

  Future<Subtask?> getSubtaskById(String subtaskId) async {
    try {
      return await _subtaskService.getSubtaskById(subtaskId);
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching subtask by ID: $e");
      }
      return null;
    }
  }
}
