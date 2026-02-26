import 'package:cloud_firestore/cloud_firestore.dart';

class TaskAppealService {
  final FirebaseFirestore _firestore;

  TaskAppealService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _appealsRef(String taskId) {
    return _firestore.collection('tasks').doc(taskId).collection('appeals');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAppeals(String taskId) {
    return _appealsRef(
      taskId,
    ).orderBy('createdAt', descending: true).snapshots();
  }

  Stream<bool> hasUserAppealed(String taskId, String userId) {
    return _appealsRef(taskId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.isNotEmpty);
  }

  Future<void> submitAppeal({
    required String taskId,
    required String userId,
    required String appealText,
  }) async {
    await _appealsRef(taskId).add({
      'userId': userId,
      'appealText': appealText,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> removeUserAppeals({
    required String taskId,
    required String userId,
  }) async {
    final query = await _appealsRef(taskId)
        .where('userId', isEqualTo: userId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteAppeal({
    required String taskId,
    required String appealDocId,
  }) async {
    await _appealsRef(taskId).doc(appealDocId).delete();
  }
}
