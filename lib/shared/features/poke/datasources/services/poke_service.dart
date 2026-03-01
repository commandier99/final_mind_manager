import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/poke_model.dart';

class PokeService {
  final CollectionReference _pokes = FirebaseFirestore.instance.collection(
    'pokes',
  );

  Future<String> createPoke(PokeModel poke) async {
    final ref = _pokes.doc();
    final payload = poke.toMap();
    payload['pokeId'] = ref.id;
    await ref.set(payload);
    return ref.id;
  }

  Stream<List<PokeModel>> streamCreatedByUser(String userId) {
    return _pokes
        .where('createdByUserId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => PokeModel.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ),
              )
              .toList(),
        );
  }
}

