import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Statut de déplacement d'un matériel.
enum StatutDeplacement {
  statique('Statique', Icons.location_on, Colors.green),
  enMouvement('En mouvement', Icons.directions_run, Colors.orange),
  horsLigne('Hors ligne', Icons.signal_wifi_off, Colors.red);

  final String label;
  final IconData icon;
  final Color color;

  const StatutDeplacement(this.label, this.icon, this.color);

  static StatutDeplacement fromString(String value) {
    return StatutDeplacement.values.firstWhere(
          (e) => e.name == value,
      orElse: () => StatutDeplacement.horsLigne,
    );
  }
}

/// Méthode de détection de la localisation.
enum MethodeDetection {
  wifi('Wi-Fi', Icons.wifi),
  ble('Bluetooth', Icons.bluetooth),
  gps('GPS', Icons.gps_fixed),
  manuelle('Manuelle', Icons.edit_location),
  inconnue('Inconnue', Icons.location_off);

  final String label;
  final IconData icon;

  const MethodeDetection(this.label, this.icon);

  static MethodeDetection fromString(String value) {
    return MethodeDetection.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MethodeDetection.inconnue,
    );
  }
}

/// Modèle représentant la localisation intérieure d'un matériel.
/// Supporte le suivi de trajet et les déplacements visuels.
class LocalisationInterieure {
  // ============================================================
  // IDENTIFIANTS
  // ============================================================
  final String? id;
  final String? materielId;
  final String? zoneId;

  // ============================================================
  // INFORMATIONS WI-FI
  // ============================================================
  final String ssid;
  final String? bssid;
  final int? rssi;

  // ============================================================
  // INFORMATIONS SPATIALES
  // ============================================================
  final String batiment;
  final String etage;
  final String zone;
  final double positionX;
  final double positionY;

  // ============================================================
  // STATUT ET TEMPOREL
  // ============================================================
  final StatutDeplacement statut;
  final DateTime derniereMiseAJour;
  final DateTime? dateCreation;

  // ============================================================
  // INFORMATIONS DE TRAJET
  // ============================================================
  final int? sequence;
  final String? trajetId;
  final int? dureeDepuisPrecedent;
  final double? distanceDepuisPrecedent;
  final double? direction;
  final double? vitesse;
  final bool? estPointDepart;
  final bool? estPointArrivee;

  // ============================================================
  // MÉTADONNÉES DE QUALITÉ
  // ============================================================
  final MethodeDetection methode;
  final double? confiance;
  final double? precision;
  final String? notes;

  // ============================================================
  // CONSTRUCTEUR PRINCIPAL
  // ============================================================
  LocalisationInterieure({
    this.id,
    this.materielId,
    this.zoneId,
    required this.ssid,
    this.bssid,
    this.rssi,
    required this.batiment,
    required this.etage,
    required this.zone,
    required this.positionX,
    required this.positionY,
    this.statut = StatutDeplacement.statique,
    DateTime? derniereMiseAJour,
    this.dateCreation,
    this.sequence,
    this.trajetId,
    this.dureeDepuisPrecedent,
    this.distanceDepuisPrecedent,
    this.direction,
    this.vitesse,
    this.estPointDepart,
    this.estPointArrivee,
    this.methode = MethodeDetection.wifi,
    this.confiance,
    this.precision,
    this.notes,
  }) : derniereMiseAJour = derniereMiseAJour ?? DateTime.now();

  // ============================================================
  // FACTORY: depuis Firestore
  // ============================================================
  factory LocalisationInterieure.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LocalisationInterieure(
      id: doc.id,
      materielId: data['materielId'] as String?,
      zoneId: data['zoneId'] as String?,
      ssid: data['ssid'] ?? '',
      bssid: data['bssid'] as String?,
      rssi: (data['rssi'] as num?)?.toInt(),
      batiment: data['batiment'] ?? '',
      etage: data['etage'] ?? '',
      zone: data['zone'] ?? '',
      positionX: (data['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (data['positionY'] as num?)?.toDouble() ?? 0.0,
      statut: StatutDeplacement.fromString(data['statut'] ?? 'horsLigne'),
      derniereMiseAJour: (data['derniereMiseAJour'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateCreation: (data['dateCreation'] as Timestamp?)?.toDate(),
      sequence: data['sequence'] as int?,
      trajetId: data['trajetId'] as String?,
      dureeDepuisPrecedent: data['dureeDepuisPrecedent'] as int?,
      distanceDepuisPrecedent: (data['distanceDepuisPrecedent'] as num?)?.toDouble(),
      direction: (data['direction'] as num?)?.toDouble(),
      vitesse: (data['vitesse'] as num?)?.toDouble(),
      estPointDepart: data['estPointDepart'] as bool?,
      estPointArrivee: data['estPointArrivee'] as bool?,
      methode: MethodeDetection.fromString(data['methode'] ?? 'inconnue'),
      confiance: (data['confiance'] as num?)?.toDouble(),
      precision: (data['precision'] as num?)?.toDouble(),
      notes: data['notes'] as String?,
    );
  }

  factory LocalisationInterieure.fromMap(Map<String, dynamic> map) {
    return LocalisationInterieure(
      id: map['id'] as String?,
      materielId: map['materielId'] as String?,
      zoneId: map['zoneId'] as String?,
      ssid: map['ssid'] ?? '',
      bssid: map['bssid'] as String?,
      rssi: (map['rssi'] as num?)?.toInt(),
      batiment: map['batiment'] ?? '',
      etage: map['etage'] ?? '',
      zone: map['zone'] ?? '',
      positionX: (map['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (map['positionY'] as num?)?.toDouble() ?? 0.0,
      statut: StatutDeplacement.fromString(map['statut'] ?? 'horsLigne'),
      derniereMiseAJour: map['derniereMiseAJour'] != null
          ? (map['derniereMiseAJour'] as Timestamp).toDate()
          : DateTime.now(),
      dateCreation: map['dateCreation'] != null
          ? (map['dateCreation'] as Timestamp).toDate()
          : null,
      sequence: map['sequence'] as int?,
      trajetId: map['trajetId'] as String?,
      dureeDepuisPrecedent: map['dureeDepuisPrecedent'] as int?,
      distanceDepuisPrecedent: (map['distanceDepuisPrecedent'] as num?)?.toDouble(),
      direction: (map['direction'] as num?)?.toDouble(),
      vitesse: (map['vitesse'] as num?)?.toDouble(),
      estPointDepart: map['estPointDepart'] as bool?,
      estPointArrivee: map['estPointArrivee'] as bool?,
      methode: MethodeDetection.fromString(map['methode'] ?? 'inconnue'),
      confiance: (map['confiance'] as num?)?.toDouble(),
      precision: (map['precision'] as num?)?.toDouble(),
      notes: map['notes'] as String?,
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (materielId != null) 'materielId': materielId,
      if (zoneId != null) 'zoneId': zoneId,
      'ssid': ssid,
      if (bssid != null) 'bssid': bssid,
      if (rssi != null) 'rssi': rssi,
      'batiment': batiment,
      'etage': etage,
      'zone': zone,
      'positionX': positionX,
      'positionY': positionY,
      'statut': statut.name,
      'derniereMiseAJour': Timestamp.fromDate(derniereMiseAJour),
      if (dateCreation != null) 'dateCreation': Timestamp.fromDate(dateCreation!),
      if (sequence != null) 'sequence': sequence,
      if (trajetId != null) 'trajetId': trajetId,
      if (dureeDepuisPrecedent != null) 'dureeDepuisPrecedent': dureeDepuisPrecedent,
      if (distanceDepuisPrecedent != null) 'distanceDepuisPrecedent': distanceDepuisPrecedent,
      if (direction != null) 'direction': direction,
      if (vitesse != null) 'vitesse': vitesse,
      if (estPointDepart != null) 'estPointDepart': estPointDepart,
      if (estPointArrivee != null) 'estPointArrivee': estPointArrivee,
      'methode': methode.name,
      if (confiance != null) 'confiance': confiance,
      if (precision != null) 'precision': precision,
      if (notes != null) 'notes': notes,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================
  LocalisationInterieure copyWith({
    String? id,
    String? materielId,
    String? zoneId,
    String? ssid,
    String? bssid,
    int? rssi,
    String? batiment,
    String? etage,
    String? zone,
    double? positionX,
    double? positionY,
    StatutDeplacement? statut,
    DateTime? derniereMiseAJour,
    DateTime? dateCreation,
    int? sequence,
    String? trajetId,
    int? dureeDepuisPrecedent,
    double? distanceDepuisPrecedent,
    double? direction,
    double? vitesse,
    bool? estPointDepart,
    bool? estPointArrivee,
    MethodeDetection? methode,
    double? confiance,
    double? precision,
    String? notes,
  }) {
    return LocalisationInterieure(
      id: id ?? this.id,
      materielId: materielId ?? this.materielId,
      zoneId: zoneId ?? this.zoneId,
      ssid: ssid ?? this.ssid,
      bssid: bssid ?? this.bssid,
      rssi: rssi ?? this.rssi,
      batiment: batiment ?? this.batiment,
      etage: etage ?? this.etage,
      zone: zone ?? this.zone,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      statut: statut ?? this.statut,
      derniereMiseAJour: derniereMiseAJour ?? this.derniereMiseAJour,
      dateCreation: dateCreation ?? this.dateCreation,
      sequence: sequence ?? this.sequence,
      trajetId: trajetId ?? this.trajetId,
      dureeDepuisPrecedent: dureeDepuisPrecedent ?? this.dureeDepuisPrecedent,
      distanceDepuisPrecedent: distanceDepuisPrecedent ?? this.distanceDepuisPrecedent,
      direction: direction ?? this.direction,
      vitesse: vitesse ?? this.vitesse,
      estPointDepart: estPointDepart ?? this.estPointDepart,
      estPointArrivee: estPointArrivee ?? this.estPointArrivee,
      methode: methode ?? this.methode,
      confiance: confiance ?? this.confiance,
      precision: precision ?? this.precision,
      notes: notes ?? this.notes,
    );
  }

  // ============================================================
  // VALIDATION
  // ============================================================
  bool get isValid {
    return ssid.isNotEmpty &&
        batiment.isNotEmpty &&
        etage.isNotEmpty &&
        zone.isNotEmpty &&
        positionX >= 0 && positionX <= 1 &&
        positionY >= 0 && positionY <= 1;
  }

  bool get estRecente {
    return DateTime.now().difference(derniereMiseAJour).inMinutes < 2;
  }

  bool get estFiable {
    return confiance != null && confiance! >= 0.7;
  }

  bool get estPrecise {
    return precision != null && precision! <= 10.0;
  }

  // ============================================================
  // INFORMATIONS DE TRAJET
  // ============================================================
  bool get estDansTrajet => trajetId != null && trajetId!.isNotEmpty;
  bool get estDepart => estPointDepart == true;
  bool get estArrivee => estPointArrivee == true;

  String get dureeFormatee {
    if (dureeDepuisPrecedent == null) return 'N/A';
    final duree = dureeDepuisPrecedent!;
    if (duree < 60) return '${duree}s';
    if (duree < 3600) return '${duree ~/ 60}m ${duree % 60}s';
    return '${duree ~/ 3600}h ${(duree % 3600) ~/ 60}m';
  }

  String get distanceFormatee {
    if (distanceDepuisPrecedent == null) return 'N/A';
    final dist = distanceDepuisPrecedent!;
    if (dist < 1000) return '${dist.toStringAsFixed(0)}m';
    return '${(dist / 1000).toStringAsFixed(1)}km';
  }

  String get vitesseFormatee {
    if (vitesse == null) return 'N/A';
    final v = vitesse!;
    if (v < 1) return '${(v * 3.6).toStringAsFixed(1)} km/h';
    return '${v.toStringAsFixed(1)} m/s';
  }

  String get directionTexte {
    if (direction == null) return 'N/A';
    final d = direction!;
    if (d >= 337.5 || d < 22.5) return 'Nord ↑';
    if (d >= 22.5 && d < 67.5) return 'Nord-Est ↗';
    if (d >= 67.5 && d < 112.5) return 'Est →';
    if (d >= 112.5 && d < 157.5) return 'Sud-Est ↘';
    if (d >= 157.5 && d < 202.5) return 'Sud ↓';
    if (d >= 202.5 && d < 247.5) return 'Sud-Ouest ↙';
    if (d >= 247.5 && d < 292.5) return 'Ouest ←';
    return 'Nord-Ouest ↖';
  }

  // ============================================================
  // AFFICHAGE
  // ============================================================
  Color get couleurStatut => statut.color;
  IconData get iconeStatut => statut.icon;
  Color get couleurConfiance {
    if (confiance == null) return Colors.grey;
    if (confiance! >= 0.8) return Colors.green;
    if (confiance! >= 0.5) return Colors.orange;
    return Colors.red;
  }

  IconData get iconeMethode => methode.icon;

  String get timeAgo {
    final diff = DateTime.now().difference(derniereMiseAJour);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
    return 'il y a ${diff.inDays}j';
  }

  String get formattedLocation => '$zone ($etage) - $ssid';

  String get detailedLocation {
    final parts = <String>[];
    parts.add(zone);
    if (batiment.isNotEmpty) parts.add(batiment);
    parts.add('Étage $etage');
    if (confiance != null) {
      parts.add('${(confiance! * 100).toInt()}% fiable');
    }
    parts.add(statut.label);
    if (estDansTrajet) {
      if (estDepart) parts.add('🚀 Départ');
      if (estArrivee) parts.add('🏁 Arrivée');
      if (sequence != null) parts.add('Étape ${sequence! + 1}');
    }
    return parts.join(' · ');
  }

  @override
  String toString() {
    return 'LocalisationInterieure('
        'id: $id, '
        'materiel: $materielId, '
        'zone: $zone, '
        'ssid: $ssid, '
        'statut: ${statut.name}, '
        'sequence: ${sequence ?? "N/A"}, '
        'trajet: ${trajetId ?? "N/A"}'
        ')';
  }
}

// ============================================================
// COMPATIBILITÉ
// ============================================================
extension LocalisationInterieureCompat on LocalisationInterieure {
  LocalisationInterieure updateWith({
    String? ssid,
    String? batiment,
    String? etage,
    String? zone,
    double? positionX,
    double? positionY,
    String? bssid,
    int? rssi,
    StatutDeplacement? statut,
  }) {
    return copyWith(
      ssid: ssid,
      batiment: batiment,
      etage: etage,
      zone: zone,
      positionX: positionX,
      positionY: positionY,
      bssid: bssid,
      rssi: rssi,
      statut: statut ?? this.statut,
      derniereMiseAJour: DateTime.now(),
    );
  }

  LocalisationInterieure updateStatut() {
    if (!isValid) {
      return copyWith(statut: StatutDeplacement.horsLigne);
    }
    if (!estRecente) {
      return copyWith(statut: StatutDeplacement.horsLigne);
    }
    if (rssi != null && rssi! < -80) {
      return copyWith(statut: StatutDeplacement.enMouvement);
    }
    return copyWith(statut: StatutDeplacement.statique);
  }

  LocalisationInterieure withTrajetInfo({
    required int sequence,
    required String trajetId,
    int? dureeDepuisPrecedent,
    double? distanceDepuisPrecedent,
    double? direction,
    double? vitesse,
    bool? estPointDepart,
    bool? estPointArrivee,
  }) {
    return copyWith(
      sequence: sequence,
      trajetId: trajetId,
      dureeDepuisPrecedent: dureeDepuisPrecedent,
      distanceDepuisPrecedent: distanceDepuisPrecedent,
      direction: direction,
      vitesse: vitesse,
      estPointDepart: estPointDepart,
      estPointArrivee: estPointArrivee,
    );
  }
}