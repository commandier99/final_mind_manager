import 'package:flutter/foundation.dart';
import '../models/step_model.dart';
import '../services/step_services.dart';

class StepProvider with ChangeNotifier {
  final StepService _stepService = StepService();

  Stream<List<TaskStep>> streamStepsByTaskId(String taskId) {
    return _stepService.streamStepsByTaskId(taskId);
  }

  Stream<List<TaskStep>> streamActiveStepsByTaskId(String taskId) {
    return _stepService.streamActiveStepsByTaskId(taskId);
  }

  Stream<List<TaskStep>> streamDeletedSteps() {
    return _stepService.streamDeletedSteps();
  }

  Future<void> addStep({
    required String stepTaskId,
    required String stepBoardId,
    String? stepTitle,
    String? stepDescription,
    bool initialDone = false,
  }) async {
    try {
      await _stepService.addStep(
        stepTaskId: stepTaskId,
        stepBoardId: stepBoardId,
        stepTitle: stepTitle,
        stepDescription: stepDescription,
        initialDone: initialDone,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error adding step: $e");
      }
    }
  }

  Future<void> toggleStepDoneStatus(TaskStep step) async {
    try {
      await _stepService.toggleStepDoneStatus(step);
    } catch (e) {
      if (kDebugMode) {
        print("Error toggling step: $e");
      }
    }
  }

  Future<void> softDeleteStep(TaskStep step) async {
    try {
      await _stepService.softDeleteStep(step);
    } catch (e) {
      if (kDebugMode) {
        print("Error soft deleting step: $e");
      }
    }
  }

  Future<void> restoreStep(TaskStep step) async {
    try {
      await _stepService.restoreStep(step);
    } catch (e) {
      if (kDebugMode) {
        print("Error restoring step: $e");
      }
    }
  }

  Future<void> deleteStep(String stepId) async {
    try {
      await _stepService.deleteStep(stepId);
    } catch (e) {
      if (kDebugMode) {
        print("Error deleting step: $e");
      }
    }
  }

  Future<void> updateStep(String stepId, TaskStep updatedStep) async {
    try {
      await _stepService.updateStep(stepId, updatedStep);
    } catch (e) {
      if (kDebugMode) {
        print("Error updating step: $e");
      }
    }
  }

  Future<TaskStep?> getStepById(String stepId) async {
    try {
      return await _stepService.getStepById(stepId);
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching step by ID: $e");
      }
      return null;
    }
  }

  Future<void> swapStepOrder(TaskStep first, TaskStep second) async {
    try {
      await _stepService.swapStepOrder(first, second);
    } catch (e) {
      if (kDebugMode) {
        print("Error reordering steps: $e");
      }
    }
  }

  Future<void> reorderSteps(
    String taskId,
    List<TaskStep> orderedSteps,
  ) async {
    try {
      await _stepService.reorderSteps(taskId, orderedSteps);
    } catch (e) {
      if (kDebugMode) {
        print("Error reordering steps list: $e");
      }
    }
  }

  Future<TaskStep?> getLatestActiveStepForTask(String taskId) async {
    try {
      return await _stepService.getLatestActiveStepForTask(taskId);
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching latest active step: $e");
      }
      return null;
    }
  }

  Future<bool> hasActiveStepsForTask(String taskId) async {
    try {
      return await _stepService.hasActiveStepsForTask(taskId);
    } catch (e) {
      if (kDebugMode) {
        print("Error checking active steps: $e");
      }
      return false;
    }
  }
}


