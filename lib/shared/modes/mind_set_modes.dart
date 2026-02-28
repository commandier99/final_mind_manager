class MindSetModes {
  static const String checklist = 'Checklist';
  static const String pomodoro = 'Pomodoro';
  static const String eatTheFrog = 'Eat the Frog';
  static const String flowStyleList = 'list';
  static const String flowStyleShuffle = 'shuffle';

  static const List<String> values = [checklist, pomodoro, eatTheFrog];

  // Modes currently wired to runtime behavior in session streams.
  static const List<String> implementedRuntimeModes = [
    checklist,
    pomodoro,
    eatTheFrog,
  ];

  static bool isImplementedRuntimeMode(String mode) {
    return implementedRuntimeModes.contains(mode);
  }

  // Fallback for runtime execution so sessions always behave predictably.
  static String resolveRuntimeMode(String mode) {
    if (isImplementedRuntimeMode(mode)) {
      return mode;
    }
    return checklist;
  }

  static String normalizeFlowStyle(
    String? style, {
    String fallback = flowStyleList,
  }) {
    switch ((style ?? '').trim().toLowerCase()) {
      case 'shuffle':
      case 'flow':
        return flowStyleShuffle;
      case 'list':
        return flowStyleList;
      default:
        return fallback;
    }
  }
}
