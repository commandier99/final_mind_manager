import 'package:flutter/foundation.dart';
import '../models/plans_model.dart';
import '../services/plan_service.dart';

class PlanProvider extends ChangeNotifier {
  final PlanService _planService;

  Plan? _activePlan;
  List<Plan> _userPlans = [];
  List<Plan> _sharedPlans = [];
  bool _isLoading = false;
  String? _error;

  PlanProvider({PlanService? planService})
      : _planService = planService ?? PlanService();

  // ============ Getters ============

  Plan? get activePlan => _activePlan;
  String? get activePlanId => _activePlan?.planId;
  bool get hasActivePlan => _activePlan != null;
  List<Plan> get userPlans => _userPlans;
  List<Plan> get sharedPlans => _sharedPlans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ============ Loading and Initialization ============

  /// Load all plans for a user (owned + shared)
  Future<void> loadUserPlans(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load owned plans
      final owned = await _planService.getUserPlans(userId);
      // Load shared plans
      final shared = await _planService.getSharedPlansForUser(userId);

      _userPlans = owned;
      _sharedPlans = shared;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Stream user plans (real-time updates)
  Stream<List<Plan>> streamUserPlans(String userId) {
    return _planService.streamUserPlans(userId);
  }

  // ============ Plan Creation ============

  /// Create a new plan
  Future<Plan?> createPlan({
    required String userId,
    required String userName,
    required String title,
    required String description,
    String technique = 'custom',
    int estimatedDurationMinutes = 0,
    int plannedFocusIntervals = 0,
    int focusIntervalMinutes = 25,
    int breakMinutes = 5,
    DateTime? deadline,
    DateTime? scheduledFor,
    List<String> taskIds = const [],
  }) async {
    try {
      final plan = await _planService.createPlan(
        userId: userId,
        userName: userName,
        title: title,
        description: description,
        technique: technique,
        estimatedDurationMinutes: estimatedDurationMinutes,
        plannedFocusIntervals: plannedFocusIntervals,
        focusIntervalMinutes: focusIntervalMinutes,
        breakMinutes: breakMinutes,
        deadline: deadline,
        scheduledFor: scheduledFor,
        taskIds: taskIds,
      );

      _userPlans = [..._userPlans, plan];
      _error = null;
      notifyListeners();
      return plan;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ============ Plan Activation & Execution ============

  /// Activate a plan to work on it
  Future<bool> activatePlan(String planId) async {
    try {
      final plan = await _planService.getPlan(planId);
      if (plan == null) throw Exception('Plan not found');

      await _planService.activatePlan(planId);
      _activePlan = plan.copyWith(planStatus: 'active');
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Pause the active plan
  Future<bool> pauseActivePlan() async {
    if (_activePlan == null) return false;

    try {
      await _planService.pausePlan(_activePlan!.planId);
      _activePlan = _activePlan!.copyWith(planStatus: 'paused');
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Resume the paused plan
  Future<bool> resumeActivePlan() async {
    if (_activePlan == null) return false;

    try {
      await _planService.resumePlan(_activePlan!.planId);
      _activePlan = _activePlan!.copyWith(planStatus: 'active');
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Complete the active plan
  Future<bool> completeActivePlan() async {
    if (_activePlan == null) return false;

    try {
      await _planService.completePlan(_activePlan!.planId);
      _activePlan = _activePlan!.copyWith(planStatus: 'completed');
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear the active plan
  void clearActivePlan() {
    _activePlan = null;
    notifyListeners();
  }

  // ============ Task Management ============

  /// Add a task to the active plan
  Future<bool> addTaskToActivePlan(String taskId) async {
    if (_activePlan == null) return false;

    try {
      await _planService.addTaskToPlan(_activePlan!.planId, taskId);
      final updatedTasks = [..._activePlan!.taskIds, taskId];
      final updatedOrder = {..._activePlan!.taskOrder, taskId: updatedTasks.length - 1};

      _activePlan = _activePlan!.copyWith(
        taskIds: updatedTasks,
        taskOrder: updatedOrder,
        totalTasks: updatedTasks.length,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Remove a task from the active plan
  Future<bool> removeTaskFromActivePlan(String taskId) async {
    if (_activePlan == null) return false;

    try {
      await _planService.removeTaskFromPlan(_activePlan!.planId, taskId);
      final updatedTasks = _activePlan!.taskIds.where((id) => id != taskId).toList();
      final updatedOrder = {..._activePlan!.taskOrder};
      updatedOrder.remove(taskId);

      for (int i = 0; i < updatedTasks.length; i++) {
        updatedOrder[updatedTasks[i]] = i;
      }

      _activePlan = _activePlan!.copyWith(
        taskIds: updatedTasks,
        taskOrder: updatedOrder,
        totalTasks: updatedTasks.length,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reorder tasks in the active plan
  Future<bool> reorderTasksInActivePlan(List<String> taskIds) async {
    if (_activePlan == null) return false;

    try {
      await _planService.reorderTasksInPlan(_activePlan!.planId, taskIds);
      final taskOrder = <String, int>{};
      for (int i = 0; i < taskIds.length; i++) {
        taskOrder[taskIds[i]] = i;
      }

      _activePlan = _activePlan!.copyWith(
        taskIds: taskIds,
        taskOrder: taskOrder,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Focus Session Integration ============

  /// Link a completed focus session to the active plan
  Future<bool> linkFocusSessionToActivePlan({
    required String focusSessionId,
    required int minutesSpent,
    required double productivityScore,
  }) async {
    if (_activePlan == null) return false;

    try {
      await _planService.addFocusSessionToPlan(
        planId: _activePlan!.planId,
        focusSessionId: focusSessionId,
        minutesSpent: minutesSpent,
        productivityScore: productivityScore,
      );

      final newCompletedSessions = _activePlan!.actualFocusSessionsCompleted + 1;
      final newTotalMinutes = _activePlan!.actualFocusMinutesSpent + minutesSpent;

      final totalScorePoints =
          (_activePlan!.averageProductivityScore * _activePlan!.actualFocusSessionsCompleted) +
              productivityScore;
      final newAverageScore = totalScorePoints / newCompletedSessions;

      final updatedFocusSessions = [..._activePlan!.focusSessionIds, focusSessionId];

      _activePlan = _activePlan!.copyWith(
        focusSessionIds: updatedFocusSessions,
        actualFocusSessionsCompleted: newCompletedSessions,
        actualFocusMinutesSpent: newTotalMinutes,
        averageProductivityScore: newAverageScore,
      );
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Plan Updates ============

  /// Update an existing plan
  Future<bool> updatePlan(Plan plan) async {
    try {
      await _planService.updatePlan(plan);

      // Update in user plans list if it exists
      final index = _userPlans.indexWhere((p) => p.planId == plan.planId);
      if (index != -1) {
        _userPlans[index] = plan;
      }

      // Update active plan if it's the one being modified
      if (_activePlan?.planId == plan.planId) {
        _activePlan = plan;
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete a plan (soft delete)
  Future<bool> deletePlan(String planId) async {
    try {
      await _planService.deletePlan(planId);

      _userPlans.removeWhere((p) => p.planId == planId);

      if (_activePlan?.planId == planId) {
        _activePlan = null;
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Collaboration ============

  /// Share a plan with other users
  Future<bool> sharePlan(
    String planId,
    List<String> userIds,
    Map<String, String> userNames,
  ) async {
    try {
      await _planService.sharePlanWithUsers(planId, userIds, userNames);

      final planIndex = _userPlans.indexWhere((p) => p.planId == planId);
      if (planIndex != -1) {
        _userPlans[planIndex] = _userPlans[planIndex].copyWith(
          planIsShared: true,
          sharedWithUserIds: userIds,
          sharedUserNames: userNames,
        );
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ============ Templates ============

  /// Create a template from an existing plan
  Future<bool> createPlanTemplate(String planId, String templateName) async {
    try {
      final plan = _userPlans.firstWhere((p) => p.planId == planId);
      await _planService.createPlanTemplate(plan, templateName);

      final index = _userPlans.indexWhere((p) => p.planId == planId);
      if (index != -1) {
        _userPlans[index] = _userPlans[index].copyWith(
          planIsTemplate: true,
          planTemplateName: templateName,
        );
      }

      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load all available templates
  Future<List<Plan>> loadTemplates() async {
    try {
      final templates = await _planService.getTemplates();
      _error = null;
      return templates;
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Duplicate a template as a new plan
  Future<Plan?> duplicateTemplate({
    required String templateId,
    required String userId,
    required String userName,
    required String newTitle,
  }) async {
    try {
      final newPlan = await _planService.duplicateTemplateAsPlan(
        templateId: templateId,
        userId: userId,
        userName: userName,
        newTitle: newTitle,
      );

      _userPlans = [..._userPlans, newPlan];
      _error = null;
      notifyListeners();
      return newPlan;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
}
