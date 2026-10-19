import 'package:cloud_firestore/cloud_firestore.dart';
import 'localisation_interieure.dart'; // Import de la classe LocalisationInterieure

/// Modèle représentant un matériel, avec lecture sécurisée depuis Firestore.
/// Plus jamais de crash si un champ manque : chaque champ a une valeur par défaut.
class Materiel {
  final String id;
  final String type;
  final String numeroSerie;
  final String etat;
  final String departement;
  final String responsable;
  final String agence;
  final String bureau;
  final String marque;
  final DateTime? dateAjout;
  final DateTime? dateRetour;
  final GeoPoint? position;
  final LocalisationInterieure? localisationInterieure;

  Materiel({
    required this.id,
    required this.type,
    required this.numeroSerie,
    required this.etat,
    required this.departement,
    required this.responsable,
    required this.agence,
    required this.bureau,
    required this.marque,
    this.dateAjout,
    this.dateRetour,
    this.position,
    this.localisationInterieure,
  });

  /// Nom d'affichage généré automatiquement (remplace l'ancien champ "nom").
  /// Exemple : "Dell — Ordinateur"
  String get displayName {
    if (marque.isNotEmpty && type.isNotEmpty) return '$marque — $type';
    if (marque.isNotEmpty) return marque;
    if (type.isNotEmpty) return type;
    return 'Matériel sans nom';
  }

  /// Construit un Materiel depuis un DocumentSnapshot Firestore.
  /// Utilise TOUJOURS des valeurs par défaut : aucun champ manquant ne peut planter.
  factory Materiel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final localisationRaw = data['localisationInterieure'] as Map<String, dynamic>?;
    return Materiel(
      id: doc.id,
      type: (data['type'] ?? 'Inconnu').toString(),
      numeroSerie: (data['numeroSerie'] ?? '').toString(),
      etat: (data['etat'] ?? 'Disponible').toString(),
      departement: (data['departement'] ?? '').toString(),
      responsable: (data['responsable'] ?? '').toString(),
      agence: (data['agence'] ?? '').toString(),
      bureau: (data['bureau'] ?? '').toString(),
      marque: (data['marque'] ?? '').toString(),
      dateAjout: (data['dateAjout'] as Timestamp?)?.toDate(),
      dateRetour: (data['dateRetour'] as Timestamp?)?.toDate(),
      position: data['position'] as GeoPoint?,
      localisationInterieure: localisationRaw != null
          ? LocalisationInterieure.fromMap(localisationRaw)
          : null,
    );
  }

  /// Convertit le Materiel en Map pour l'écrire dans Firestore.
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'numeroSerie': numeroSerie,
      'etat': etat,
      'departement': departement,
      'responsable': responsable,
      'agence': agence,
      'bureau': bureau,
      'marque': marque,
      'dateAjout': dateAjout != null
          ? Timestamp.fromDate(dateAjout!)
          : FieldValue.serverTimestamp(),
      if (dateRetour != null) 'dateRetour': Timestamp.fromDate(dateRetour!),
      if (position != null) 'position': position,
      // localisationInterieure n'est jamais écrit ici : c'est
      // LocalisationAutoService qui le gère exclusivement, pour éviter
      // qu'une modification manuelle n'écrase une détection Wi-Fi récente.
    };
  }

  bool get estEnRetard {
    if (dateRetour == null) return false;
    return etat == 'En utilisation' && dateRetour!.isBefore(DateTime.now());
  }

  Materiel copyWith({
    String? type,
    String? numeroSerie,
    String? etat,
    String? departement,
    String? responsable,
    String? agence,
    String? bureau,
    String? marque,
    DateTime? dateAjout,
    DateTime? dateRetour,
    GeoPoint? position,
    LocalisationInterieure? localisationInterieure,
  }) {
    return Materiel(
      id: id,
      type: type ?? this.type,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      etat: etat ?? this.etat,
      departement: departement ?? this.departement,
      responsable: responsable ?? this.responsable,
      agence: agence ?? this.agence,
      bureau: bureau ?? this.bureau,
      marque: marque ?? this.marque,
      dateAjout: dateAjout ?? this.dateAjout,
      dateRetour: dateRetour ?? this.dateRetour,
      position: position ?? this.position,
      localisationInterieure: localisationInterieure ?? this.localisationInterieure,
    );
  }
}