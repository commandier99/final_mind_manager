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
    await _stepService.addStep(
      stepTaskId: stepTaskId,
      stepBoardId: stepBoardId,
      stepTitle: stepTitle,
      stepDescription: stepDescription,
      initialDone: initialDone,
    );
  }

  Future<void> duplicateStep(TaskStep step) async {
    await addStep(
      stepTaskId: step.parentTaskId,
      stepBoardId: step.stepBoardId ?? '',
      stepTitle: _duplicateTitle(step.stepTitle),
      stepDescription: step.stepDescription,
      initialDone: false,
    );
  }

  String _duplicateTitle(String title) {
    const copySuffix = ' (Copy)';
    return title.endsWith(copySuffix) ? title : '$title$copySuffix';
  }

  Future<void> toggleStepDoneStatus(TaskStep step) async {
    try {
      await _stepService.toggleStepDoneStatus(step);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error toggling step: $e");
      }
    }
  }

  Future<void> softDeleteStep(TaskStep step) async {
    try {
      await _stepService.softDeleteStep(step);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error soft deleting step: $e");
      }
    }
  }

  Future<void> restoreStep(TaskStep step) async {
    try {
      await _stepService.restoreStep(step);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error restoring step: $e");
      }
    }
  }

  Future<void> deleteStep(String stepId) async {
    try {
      await _stepService.deleteStep(stepId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error deleting step: $e");
      }
    }
  }

  Future<void> updateStep(String stepId, TaskStep updatedStep) async {
    try {
      await _stepService.updateStep(stepId, updatedStep);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error updating step: $e");
      }
    }
  }

  Future<TaskStep?> getStepById(String stepId) async {
    try {
      return await _stepService.getStepById(stepId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching step by ID: $e");
      }
      return null;
    }
  }

  Future<void> swapStepOrder(TaskStep first, TaskStep second) async {
    try {
      await _stepService.swapStepOrder(first, second);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error reordering steps: $e");
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
        debugPrint("Error reordering steps list: $e");
      }
    }
  }

  Future<TaskStep?> getLatestActiveStepForTask(String taskId) async {
    try {
      return await _stepService.getLatestActiveStepForTask(taskId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error fetching latest active step: $e");
      }
      return null;
    }
  }

  Future<bool> hasActiveStepsForTask(String taskId) async {
    try {
      return await _stepService.hasActiveStepsForTask(taskId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Error checking active steps: $e");
      }
      return false;
    }
  }
}


