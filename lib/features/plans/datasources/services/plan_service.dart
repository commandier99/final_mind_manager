import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/plans_model.dart';

class PlanService {
  final FirebaseFirestore _firestore;

  PlanService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _plansCollection = 'plans';

  // ============ CRUD Operations ============

  /// Create a new plan
  Future<Plan> createPlan({
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
      final docRef = _firestore.collection(_plansCollection).doc();
      final now = DateTime.now();

      final plan = Plan(
        planId: docRef.id,
        planOwnerId: userId,
        planOwnerName: userName,
        planTitle: title,
        planDescription: description,
        planCreatedAt: now,
        planTechnique: technique,
        planDeadline: deadline,
        planScheduledFor: scheduledFor,
        taskIds: taskIds,
        totalTasks: taskIds.length,
      );

      await docRef.set(plan.toMap());
      return plan;
    } catch (e) {
      throw Exception('Error creating plan: $e');
    }
  }

  /// Get a specific plan by ID
  Future<Plan?> getPlan(String planId) async {
    try {
      final doc = await _firestore.collection(_plansCollection).doc(planId).get();
      if (doc.exists) {
        return Plan.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Error fetching plan: $e');
    }
  }

  /// Get all non-deleted plans for a user
  Future<List<Plan>> getUserPlans(String userId) async {
    try {
      final query = await _firestore
          .collection(_plansCollection)
          .where('planOwnerId', isEqualTo: userId)
          .where('planIsDeleted', isEqualTo: false)
          .orderBy('planCreatedAt', descending: true)
          .get();

      return query.docs
          .map((doc) => Plan.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching user plans: $e');
    }
  }

  /// Stream all non-deleted plans for a user (real-time)
  Stream<List<Plan>> streamUserPlans(String userId) {
    try {
      return _firestore
          .collection(_plansCollection)
          .where('planOwnerId', isEqualTo: userId)
          .where('planIsDeleted', isEqualTo: false)
          .orderBy('planCreatedAt', descending: true)
          .snapshots()
          .map((query) => query.docs
              .map((doc) => Plan.fromMap(doc.data(), doc.id))
              .toList());
    } catch (e) {
      throw Exception('Error streaming user plans: $e');
    }
  }

  /// Get all templates available
  Future<List<Plan>> getTemplates() async {
    try {
      final query = await _firestore
          .collection(_plansCollection)
          .where('planIsTemplate', isEqualTo: true)
          .orderBy('planCreatedAt', descending: true)
          .get();

      return query.docs
          .map((doc) => Plan.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Error fetching templates: $e');
    }
  }

  /// Update plan details
  Future<void> updatePlan(Plan plan) async {
    try {
      await _firestore
          .collection(_plansCollection)
          .doc(plan.planId)
          .update(plan.toMap());
    } catch (e) {
      throw Exception('Error updating plan: $e');
    }
  }

  /// Soft delete a plan (mark as deleted but keep in DB)
  Future<void> deletePlan(String planId) async {
    try {
      await _firestore.collection(_plansCollection).doc(planId).update({
        'planIsDeleted': true,
        'planDeletedAt': Timestamp.now(),
      });
    } catch (e) {
      throw Exception('Error deleting plan: $e');
    }
  }

  // ============ Task Management ============

  /// Add a task to a plan
  Future<void> addTaskToPlan(String planId, String taskId) async {
    try {
      final planDoc = await _firestore.collection(_plansCollection).doc(planId).get();
      if (!planDoc.exists) throw Exception('Plan not found');

      final plan = Plan.fromMap(planDoc.data() as Map<String, dynamic>, planDoc.id);

      if (plan.taskIds.contains(taskId)) {
        return; // Task already in plan
      }

      final updatedTaskIds = [...plan.taskIds, taskId];
      final updatedTaskOrder = {...plan.taskOrder, taskId: updatedTaskIds.length - 1};

      await _firestore.collection(_plansCollection).doc(planId).update({
        'taskIds': updatedTaskIds,
        'taskOrder': updatedTaskOrder,
        'totalTasks': updatedTaskIds.length,
      });
    } catch (e) {
      throw Exception('Error adding task to plan: $e');
    }
  }

  /// Remove a task from a plan
  Future<void> removeTaskFromPlan(String planId, String taskId) async {
    try {
      final planDoc = await _firestore.collection(_plansCollection).doc(planId).get();
      if (!planDoc.exists) throw Exception('Plan not found');

      final plan = Plan.fromMap(planDoc.data() as Map<String, dynamic>, planDoc.id);

      final updatedTaskIds = plan.taskIds.where((id) => id != taskId).toList();
      final updatedTaskOrder = {...plan.taskOrder};
      updatedTaskOrder.remove(taskId);

      // Recalculate order indices
      for (int i = 0; i < updatedTaskIds.length; i++) {
        updatedTaskOrder[updatedTaskIds[i]] = i;
      }

      await _firestore.collection(_plansCollection).doc(planId).update({
        'taskIds': updatedTaskIds,
        'taskOrder': updatedTaskOrder,
        'totalTasks': updatedTaskIds.length,
      });
    } catch (e) {
      throw Exception('Error removing task from plan: $e');
    }
  }

  /// Reorder tasks in a plan
  Future<void> reorderTasksInPlan(String planId, List<String> taskIds) async {
    try {
      final taskOrder = <String, int>{};
      for (int i = 0; i < taskIds.length; i++) {
        taskOrder[taskIds[i]] = i;
      }

      await _firestore.collection(_plansCollection).doc(planId).update({
        'taskIds': taskIds,
        'taskOrder': taskOrder,
      });
    } catch (e) {
      throw Exception('Error reordering tasks: $e');
    }
  }

  /// Mark a task as completed within the plan
  Future<void> markTaskCompletedInPlan(String planId) async {
    try {
      final planDoc = await _firestore.collection(_plansCollection).doc(planId).get();
      if (!planDoc.exists) throw Exception('Plan not found');

      final plan = Plan.fromMap(planDoc.data() as Map<String, dynamic>, planDoc.id);

      final newCompletedCount = (plan.completedTasks + 1).clamp(0, plan.totalTasks);

      await _firestore.collection(_plansCollection).doc(planId).update({
        'completedTasks': newCompletedCount,
      });
    } catch (e) {
      throw Exception('Error updating task completion in plan: $e');
    }
  }

  /// Get plans shared with a specific user
  Future<List<Plan>> getSharedPlansForUser(String userId) async {
    // No sharing functionality - return empty list
    return [];
  }
}
