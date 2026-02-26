import 'mind_set_modes.dart';

class MindSetModePolicy {
  final String runtimeMode;

  const MindSetModePolicy(this.runtimeMode);

  factory MindSetModePolicy.fromMode(String mode) {
    return MindSetModePolicy(MindSetModes.resolveRuntimeMode(mode));
  }

  bool get isChecklist => runtimeMode == MindSetModes.checklist;
  bool get isPomodoro => runtimeMode == MindSetModes.pomodoro;
  bool get isEatTheFrog => runtimeMode == MindSetModes.eatTheFrog;

  bool get hidesSessionTimer => isPomodoro;

  bool allowsPauseWhileFocused() {
    return isChecklist;
  }

  bool allowsSwitchWhileFocused() {
    return isChecklist || isPomodoro;
  }

  bool doneAllowedOnTask({required bool isFocused}) {
    if (isChecklist) return isFocused;
    if (isEatTheFrog) return isFocused;
    if (isPomodoro) return isFocused;
    return isFocused;
  }

  bool taskVisible({
    required bool hasFocusedTask,
    required bool isTaskFocused,
  }) {
    return true;
  }

  bool canFocusTask({
    required bool isSessionActive,
    required bool hasFocusedTask,
    required bool isTaskFocused,
  }) {
    if (!isSessionActive) return false;
    if (isTaskFocused) return false;
    if (!hasFocusedTask) return true;
    return allowsSwitchWhileFocused();
  }

  bool canPauseTask({
    required bool isSessionActive,
    required bool isTaskFocused,
  }) {
    if (!isSessionActive || !isTaskFocused) return false;
    return allowsPauseWhileFocused();
  }
}
