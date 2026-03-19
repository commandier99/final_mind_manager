import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/memory_model.dart';

class MemoryService {
  // Kept as `pokes` for backward compatibility with existing Firestore data.
  final CollectionReference _memoryCollection = FirebaseFirestore.instance
      .collection('pokes');

  Future<String> createMemoryEntry(MemoryModel memory) async {
    final ref = _memoryCollection.doc();
    final payload = memory.toMap();
    payload['memoryId'] = ref.id;
    payload['pokeId'] = ref.id;
    payload['threadId'] = (memory.threadId ?? '').trim().isEmpty
        ? ref.id
        : memory.threadId!.trim();
    payload['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await ref.set(payload);
    return ref.id;
  }

  Stream<List<MemoryModel>> streamCreatedByUser(String userId) {
    return _memoryCollection
        .where('createdByUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MemoryModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }

  Stream<List<MemoryModel>> streamReceivedByUser(String userId) {
    return _memoryCollection
        .where('recipientUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MemoryModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }
}
