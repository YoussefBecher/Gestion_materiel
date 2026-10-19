import 'package:cloud_firestore/cloud_firestore.dart';
import 'employe.dart';

class EmployeService {
  final CollectionReference _collection =
  FirebaseFirestore.instance.collection('employes');

  Stream<List<Employe>> streamEmployes() {
    return _collection
        .orderBy('nom')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Employe.fromFirestore(d)).toList());
  }

  Future<void> ajouterEmploye(Employe employe) {
    return _collection.add(employe.toMap());
  }

  Future<void> modifierEmploye(String id, Employe employe) {
    return _collection.doc(id).update(employe.toMap());
  }

  Future<void> supprimerEmploye(String id) {
    return _collection.doc(id).delete();
  }

  Future<Employe?> getEmploye(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Employe.fromFirestore(doc);
  }
}