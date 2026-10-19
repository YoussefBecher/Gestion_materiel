import 'package:cloud_firestore/cloud_firestore.dart';

class Employe {
  final String id;
  final String matricule;
  final String nom;
  final String prenom;
  final String email;
  final String telephone;
  final String departement;
  final String poste;
  final String agence;

  Employe({
    required this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.telephone,
    required this.departement,
    required this.poste,
    required this.agence,
  });

  String get nomComplet => '$prenom $nom';

  factory Employe.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Employe(
      id: doc.id,
      matricule: (data['matricule'] ?? '').toString(),
      nom: (data['nom'] ?? '').toString(),
      prenom: (data['prenom'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      telephone: (data['telephone'] ?? '').toString(),
      departement: (data['departement'] ?? '').toString(),
      poste: (data['poste'] ?? '').toString(),
      agence: (data['agence'] ?? 'Siège BIAT').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'telephone': telephone,
      'departement': departement,
      'poste': poste,
      'agence': agence,
    };
  }
}