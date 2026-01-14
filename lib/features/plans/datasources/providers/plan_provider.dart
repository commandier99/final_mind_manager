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
}
