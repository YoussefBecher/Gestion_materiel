import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/materiel.dart';

/// Centralise TOUS les accès Firestore liés aux matériels.
/// Les écrans n'appellent plus jamais FirebaseFirestore directement.
class MaterielService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('materiels');

  /// Flux temps réel de tous les matériels, déjà convertis en objets Materiel.
  Stream<List<Materiel>> streamMateriels() {
    return _collection
        .orderBy('dateAjout', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Materiel.fromFirestore(d)).toList());
  }

  Future<void> ajouterMateriel(Materiel materiel) {
    return _collection.add(materiel.toMap());
  }

  Future<void> modifierMateriel(String id, Materiel materiel) {
    return _collection.doc(id).update(materiel.toMap());
  }

  Future<void> supprimerMateriel(String id) {
    return _collection.doc(id).delete();
  }

  Future<Materiel?> getMateriel(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Materiel.fromFirestore(doc);
  }

  /// Met à jour uniquement la position GPS d'un matériel,
  /// sans toucher aux autres champs (nom, type, état...).
  Future<void> mettreAJourPosition(String id, GeoPoint position) {
    return _collection.doc(id).update({'position': position});
  }
}