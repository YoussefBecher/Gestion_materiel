// lib/models/zone.dart

import 'package:cloud_firestore/cloud_firestore.dart';

/// Modèle représentant une zone sur le plan 2D.
///
/// Une zone peut représenter :
/// - un bureau ;
/// - une salle ;
/// - un espace de travail ;
/// - une autre partie d'un bâtiment.
///
/// La localisation Wi-Fi peut utiliser :
/// - un ou plusieurs SSIDs ;
/// - un ou plusieurs BSSIDs.
///
/// Le BSSID permet de distinguer plusieurs bornes physiques
/// utilisant le même SSID.
class Zone {
  // ================================================================
  // PROPRIÉTÉS
  // ================================================================

  final String id;

  /// Nom de la zone.
  /// Exemple : "Bureau 204".
  final String nom;

  /// Bâtiment.
  /// Exemple : "Bâtiment A".
  final String batiment;

  /// Étage.
  /// Exemple : "Étage 2".
  final String etage;

  /// Position X normalisée entre 0 et 1.
  final double x;

  /// Position Y normalisée entre 0 et 1.
  final double y;

  /// Largeur normalisée entre 0 et 1.
  final double width;

  /// Hauteur normalisée entre 0 et 1.
  final double height;

  /// SSIDs Wi-Fi associés à la zone.
  ///
  /// Exemple :
  /// ["BIAT_WIFI"]
  final List<String> ssidsAssocies;

  /// BSSIDs des bornes Wi-Fi associées à la zone.
  ///
  /// Exemple :
  /// ["AA:BB:CC:11:22:33"]
  final List<String> bssidsAssocies;

  /// Polygone de la zone.
  ///
  /// Chaque point est représenté par :
  /// {
  ///   "x": 0.25,
  ///   "y": 0.40
  /// }
  ///
  /// Les coordonnées sont normalisées entre 0 et 1.
  final List<Map<String, double>>? polygone;

  /// Couleur de la zone.
  ///
  /// Exemple :
  /// "#003087"
  final String? couleur;

  /// Date de création.
  final DateTime? dateCreation;

  /// ID du créateur.
  final String? createurId;

  // ================================================================
  // CONSTRUCTEUR
  // ================================================================

  const Zone({
    required this.id,
    required this.nom,
    required this.batiment,
    required this.etage,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.ssidsAssocies = const [],
    this.bssidsAssocies = const [],
    this.polygone,
    this.couleur,
    this.dateCreation,
    this.createurId,
  });

  // ================================================================
  // CONSTRUCTEUR VIDE
  // ================================================================

  const Zone.empty()
      : id = '',
        nom = '',
        batiment = '',
        etage = '',
        x = 0.0,
        y = 0.0,
        width = 0.1,
        height = 0.1,
        ssidsAssocies = const [],
        bssidsAssocies = const [],
        polygone = null,
        couleur = null,
        dateCreation = null,
        createurId = null;

  // ================================================================
  // FIRESTORE → ZONE
  // ================================================================

  /// Crée une Zone depuis un document Firestore.
  factory Zone.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();

    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    return Zone(
      id: doc.id,

      nom: _stringValue(
        data['nom'],
        defaultValue: 'Inconnu',
      ),

      batiment: _stringValue(
        data['batiment'],
        defaultValue: 'Inconnu',
      ),

      etage: _stringValue(
        data['etage'],
        defaultValue: 'Étage 1',
      ),

      x: _doubleValue(data['x']),
      y: _doubleValue(data['y']),

      width: _doubleValue(
        data['width'],
        defaultValue: 0.1,
      ),

      height: _doubleValue(
        data['height'],
        defaultValue: 0.1,
      ),

      ssidsAssocies: _stringList(
        data['ssidsAssocies'],
      ),

      bssidsAssocies: _normaliserBssids(
        _stringList(
          data['bssidsAssocies'],
        ),
      ),

      polygone: _parsePolygone(
        data['polygone'],
      ),

      couleur: data['couleur']?.toString(),

      dateCreation: _parseDate(
        data['dateCreation'],
      ),

      createurId: data['createurId']?.toString(),
    );
  }

  // ================================================================
  // MAP → ZONE
  // ================================================================

  /// Crée une Zone depuis une Map.
  ///
  /// Utile pour :
  /// - JSON ;
  /// - API ;
  /// - données locales ;
  /// - tests ;
  /// - transformations de données.
  factory Zone.fromMap(Map<String, dynamic> map) {
    return Zone(
      id: map['id']?.toString() ?? '',

      nom: _stringValue(
        map['nom'],
        defaultValue: 'Inconnu',
      ),

      batiment: _stringValue(
        map['batiment'],
        defaultValue: 'Inconnu',
      ),

      etage: _stringValue(
        map['etage'],
        defaultValue: 'Étage 1',
      ),

      x: _doubleValue(map['x']),
      y: _doubleValue(map['y']),

      width: _doubleValue(
        map['width'],
        defaultValue: 0.1,
      ),

      height: _doubleValue(
        map['height'],
        defaultValue: 0.1,
      ),

      ssidsAssocies: _stringList(
        map['ssidsAssocies'],
      ),

      bssidsAssocies: _normaliserBssids(
        _stringList(
          map['bssidsAssocies'],
        ),
      ),

      polygone: _parsePolygone(
        map['polygone'],
      ),

      couleur: map['couleur']?.toString(),

      dateCreation: _parseDate(
        map['dateCreation'],
      ),

      createurId: map['createurId']?.toString(),
    );
  }

  // ================================================================
  // ZONE → MAP
  // ================================================================

  /// Convertit la Zone en Map compatible avec Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,

      'nom': nom.trim(),
      'batiment': batiment.trim(),
      'etage': etage.trim(),

      'x': x,
      'y': y,
      'width': width,
      'height': height,

      'ssidsAssocies': ssidsAssocies
          .map(_nettoyerSsid)
          .where((ssid) => ssid.isNotEmpty)
          .toList(),

      'bssidsAssocies': bssidsAssocies
          .map(_normaliserBssid)
          .where(_bssidEstValide)
          .toList(),

      if (polygone != null)
        'polygone': polygone!
            .map(
              (point) => {
            'x': point['x'] ?? 0.0,
            'y': point['y'] ?? 0.0,
          },
        )
            .toList(),

      if (couleur != null && couleur!.trim().isNotEmpty)
        'couleur': couleur!.trim(),

      if (dateCreation != null)
        'dateCreation': Timestamp.fromDate(
          dateCreation!,
        ),

      if (createurId != null &&
          createurId!.trim().isNotEmpty)
        'createurId': createurId!.trim(),
    };
  }

  // ================================================================
  // ZONE → JSON
  // ================================================================

  /// Convertit la Zone en JSON.
  ///
  /// Alias de toMap().
  Map<String, dynamic> toJson() => toMap();

  // ================================================================
  // VALIDATION GÉNÉRALE
  // ================================================================

  /// Vérifie si la zone est valide.
  ///
  /// Conditions :
  /// - nom non vide ;
  /// - bâtiment non vide ;
  /// - étage non vide ;
  /// - coordonnées entre 0 et 1 ;
  /// - largeur/hauteur positives ;
  /// - zone située dans les limites du plan ;
  /// - polygone valide s'il existe ;
  /// - au moins un SSID ou BSSID.
  bool get estValide {
    if (nom.trim().isEmpty) {
      return false;
    }

    if (batiment.trim().isEmpty) {
      return false;
    }

    if (etage.trim().isEmpty) {
      return false;
    }

    if (!positionValide) {
      return false;
    }

    if (!_polygoneValide) {
      return false;
    }

    final hasSsid = ssidsAssocies.any(
      ssidValide,
    );

    final hasBssid = bssidsAssocies.any(
      bssidValide,
    );

    return hasSsid || hasBssid;
  }

  /// Vérifie uniquement la position et la taille.
  bool get positionValide {
    return _estEntreZeroEtUn(x) &&
        _estEntreZeroEtUn(y) &&
        width > 0 &&
        width <= 1 &&
        height > 0 &&
        height <= 1 &&
        x + width <= 1 &&
        y + height <= 1;
  }

  /// Vérifie si un SSID est valide.
  ///
  /// Un SSID est considéré valide s'il n'est pas vide
  /// après nettoyage.
  static bool ssidValide(String ssid) {
    return _nettoyerSsid(ssid).isNotEmpty;
  }

  /// Vérifie si un BSSID est valide.
  ///
  /// Format attendu :
  /// AA:BB:CC:11:22:33
  static bool bssidValide(String bssid) {
    return _bssidEstValide(
      _normaliserBssid(bssid),
    );
  }

  /// Indique si la zone n'a aucun SSID ni BSSID.
  bool get estVide {
    return ssidsAssocies.isEmpty &&
        bssidsAssocies.isEmpty;
  }

  /// Indique si la zone possède des informations Wi-Fi.
  bool get possedeWifi {
    return ssidsAssocies.isNotEmpty ||
        bssidsAssocies.isNotEmpty;
  }

  /// Nombre de SSIDs.
  int get nombreSSIDs => ssidsAssocies.length;

  /// Nombre de BSSIDs.
  int get nombreBSSIDs => bssidsAssocies.length;

  /// Premier SSID.
  String? get premierSSID {
    return ssidsAssocies.isNotEmpty
        ? ssidsAssocies.first
        : null;
  }

  /// Premier BSSID.
  String? get premierBSSID {
    return bssidsAssocies.isNotEmpty
        ? bssidsAssocies.first
        : null;
  }

  // ================================================================
  // RECHERCHE SSID / BSSID
  // ================================================================

  /// Vérifie si un SSID appartient à cette zone.
  bool contientSSID(String ssid) {
    final valeur = _nettoyerSsid(ssid);

    if (valeur.isEmpty) {
      return false;
    }

    return ssidsAssocies.any(
          (item) => _nettoyerSsid(item) == valeur,
    );
  }

  /// Vérifie si un BSSID appartient à cette zone.
  bool contientBSSID(String bssid) {
    final valeur = _normaliserBssid(bssid);

    if (!_bssidEstValide(valeur)) {
      return false;
    }

    return bssidsAssocies.any(
          (item) => _normaliserBssid(item) == valeur,
    );
  }

  /// Vérifie si cette zone correspond au SSID ou au BSSID fourni.
  bool correspondWifi({
    String? ssid,
    String? bssid,
  }) {
    if (bssid != null &&
        bssid.trim().isNotEmpty &&
        contientBSSID(bssid)) {
      return true;
    }

    if (ssid != null &&
        ssid.trim().isNotEmpty &&
        contientSSID(ssid)) {
      return true;
    }

    return false;
  }

  // ================================================================
  // GESTION DES SSIDs
  // ================================================================

  /// Ajoute un SSID.
  Zone ajouterSSID(String ssid) {
    final valeur = _nettoyerSsid(ssid);

    if (!ssidValide(valeur)) {
      return this;
    }

    if (contientSSID(valeur)) {
      return this;
    }

    final nouvelleListe =
    List<String>.from(ssidsAssocies)
      ..add(valeur);

    return copyWith(
      ssidsAssocies: nouvelleListe,
    );
  }

  /// Ajoute plusieurs SSIDs.
  Zone ajouterSSIDs(List<String> ssids) {
    final nouvelleListe =
    List<String>.from(ssidsAssocies);

    for (final ssid in ssids) {
      final valeur = _nettoyerSsid(ssid);

      if (ssidValide(valeur) &&
          !nouvelleListe.any(
                (item) =>
            _nettoyerSsid(item) == valeur,
          )) {
        nouvelleListe.add(valeur);
      }
    }

    return copyWith(
      ssidsAssocies: nouvelleListe,
    );
  }

  /// Retire un SSID.
  Zone retirerSSID(String ssid) {
    final valeur = _nettoyerSsid(ssid);

    final nouvelleListe =
    List<String>.from(ssidsAssocies)
      ..removeWhere(
            (item) =>
        _nettoyerSsid(item) == valeur,
      );

    return copyWith(
      ssidsAssocies: nouvelleListe,
    );
  }

  /// Retire plusieurs SSIDs.
  Zone retirerSSIDs(List<String> ssids) {
    final valeurs = ssids
        .map(_nettoyerSsid)
        .where((ssid) => ssid.isNotEmpty)
        .toSet();

    final nouvelleListe =
    List<String>.from(ssidsAssocies)
      ..removeWhere(
            (item) => valeurs.contains(
          _nettoyerSsid(item),
        ),
      );

    return copyWith(
      ssidsAssocies: nouvelleListe,
    );
  }

  // ================================================================
  // GESTION DES BSSIDs
  // ================================================================

  /// Ajoute un BSSID.
  Zone ajouterBSSID(String bssid) {
    final valeur = _normaliserBssid(bssid);

    if (!bssidValide(valeur)) {
      return this;
    }

    if (contientBSSID(valeur)) {
      return this;
    }

    final nouvelleListe =
    List<String>.from(bssidsAssocies)
      ..add(valeur);

    return copyWith(
      bssidsAssocies: nouvelleListe,
    );
  }

  /// Ajoute plusieurs BSSIDs.
  Zone ajouterBSSIDs(List<String> bssids) {
    final nouvelleListe =
    List<String>.from(bssidsAssocies);

    for (final bssid in bssids) {
      final valeur = _normaliserBssid(bssid);

      if (bssidValide(valeur) &&
          !nouvelleListe.any(
                (item) =>
            _normaliserBssid(item) == valeur,
          )) {
        nouvelleListe.add(valeur);
      }
    }

    return copyWith(
      bssidsAssocies: nouvelleListe,
    );
  }

  /// Retire un BSSID.
  Zone retirerBSSID(String bssid) {
    final valeur = _normaliserBssid(bssid);

    final nouvelleListe =
    List<String>.from(bssidsAssocies)
      ..removeWhere(
            (item) =>
        _normaliserBssid(item) == valeur,
      );

    return copyWith(
      bssidsAssocies: nouvelleListe,
    );
  }

  /// Retire plusieurs BSSIDs.
  Zone retirerBSSIDs(List<String> bssids) {
    final valeurs = bssids
        .map(_normaliserBssid)
        .where(bssidValide)
        .toSet();

    final nouvelleListe =
    List<String>.from(bssidsAssocies)
      ..removeWhere(
            (item) => valeurs.contains(
          _normaliserBssid(item),
        ),
      );

    return copyWith(
      bssidsAssocies: nouvelleListe,
    );
  }

  // ================================================================
  // GÉOMÉTRIE
  // ================================================================

  /// Vérifie si un point appartient à la zone.
  ///
  /// Si un polygone existe, il est utilisé.
  /// Sinon, la zone rectangulaire est utilisée.
  bool contientPoint(
      double px,
      double py,
      ) {
    if (polygone != null &&
        polygone!.length >= 3) {
      return _pointDansPolygone(px, py);
    }

    return px >= x &&
        px <= x + width &&
        py >= y &&
        py <= y + height;
  }

  /// Alias de contientPoint().
  bool estDansZone(
      double px,
      double py,
      ) {
    return contientPoint(px, py);
  }

  /// Centre de la zone.
  (double cx, double cy) get centre {
    if (polygone != null &&
        polygone!.length >= 3) {
      double cx = 0;
      double cy = 0;

      for (final point in polygone!) {
        cx += point['x'] ?? 0.0;
        cy += point['y'] ?? 0.0;
      }

      return (
      cx / polygone!.length,
      cy / polygone!.length,
      );
    }

    return (
    x + width / 2,
    y + height / 2,
    );
  }

  /// Surface de la zone.
  double get surface {
    if (polygone != null &&
        polygone!.length >= 3) {
      double area = 0;

      final n = polygone!.length;

      for (int i = 0; i < n; i++) {
        final current = polygone![i];
        final next = polygone![(i + 1) % n];

        final x1 = current['x'] ?? 0.0;
        final y1 = current['y'] ?? 0.0;

        final x2 = next['x'] ?? 0.0;
        final y2 = next['y'] ?? 0.0;

        area +=
            (x1 * y2) -
                (x2 * y1);
      }

      return area.abs() / 2;
    }

    return width * height;
  }

  // ================================================================
  // CHEVAUCHEMENT
  // ================================================================

  /// Vérifie si cette zone chevauche une autre zone.
  ///
  /// Cette méthode fonctionne pour les zones rectangulaires.
  ///
  /// Elle ne fait pas une détection géométrique précise des polygones.
  bool chevauche(Zone autre) {
    return !(
        x + width <= autre.x ||
            autre.x + autre.width <= x ||
            y + height <= autre.y ||
            autre.y + autre.height <= y
    );
  }

  // ================================================================
  // FUSION
  // ================================================================

  /// Fusionne cette zone avec une autre zone rectangulaire.
  ///
  /// La nouvelle zone correspond à la plus petite enveloppe
  /// rectangulaire contenant les deux zones.
  ///
  /// Les SSIDs et BSSIDs sont fusionnés.
  ///
  /// ⚠️ Les polygones ne sont pas fusionnés.
  Zone fusionnerAvec(Zone autre) {
    final newX = x < autre.x
        ? x
        : autre.x;

    final newY = y < autre.y
        ? y
        : autre.y;

    final maxX = (x + width) >
        (autre.x + autre.width)
        ? (x + width)
        : (autre.x + autre.width);

    final maxY = (y + height) >
        (autre.y + autre.height)
        ? (y + height)
        : (autre.y + autre.height);

    final newWidth = maxX - newX;
    final newHeight = maxY - newY;

    final newSsids = <String>{
      ...ssidsAssocies,
      ...autre.ssidsAssocies,
    }.toList();

    final newBssids = <String>{
      ...bssidsAssocies,
      ...autre.bssidsAssocies,
    }
        .map(_normaliserBssid)
        .where(bssidValide)
        .toList();

    return copyWith(
      x: newX,
      y: newY,
      width: newWidth,
      height: newHeight,
      ssidsAssocies: newSsids,
      bssidsAssocies: newBssids,

      // La fusion crée un rectangle.
      polygone: null,
    );
  }

  // ================================================================
  // COPY WITH
  // ================================================================

  /// Permet de créer une nouvelle Zone en modifiant
  /// uniquement certaines propriétés.
  ///
  /// Exemple :
  ///
  /// zone.copyWith(
  ///   nom: 'Bureau 205',
  ///   x: 0.5,
  /// );
  ///
  /// Pour supprimer une valeur nullable :
  ///
  /// zone.copyWith(
  ///   couleur: null,
  /// );
  ///
  /// Le système distingue donc :
  ///
  /// copyWith()
  ///
  /// de :
  ///
  /// copyWith(couleur: null)
  Zone copyWith({
    String? id,
    String? nom,
    String? batiment,
    String? etage,
    double? x,
    double? y,
    double? width,
    double? height,
    List<String>? ssidsAssocies,
    List<String>? bssidsAssocies,

    Object? polygone = _nonModifie,
    Object? couleur = _nonModifie,
    Object? dateCreation = _nonModifie,
    Object? createurId = _nonModifie,
  }) {
    return Zone(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      batiment: batiment ?? this.batiment,
      etage: etage ?? this.etage,

      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,

      ssidsAssocies:
      ssidsAssocies ??
          this.ssidsAssocies,

      bssidsAssocies:
      bssidsAssocies ??
          this.bssidsAssocies,

      polygone: identical(
        polygone,
        _nonModifie,
      )
          ? this.polygone
          : polygone
      as List<Map<String, double>>?,

      couleur: identical(
        couleur,
        _nonModifie,
      )
          ? this.couleur
          : couleur as String?,

      dateCreation: identical(
        dateCreation,
        _nonModifie,
      )
          ? this.dateCreation
          : dateCreation as DateTime?,

      createurId: identical(
        createurId,
        _nonModifie,
      )
          ? this.createurId
          : createurId as String?,
    );
  }

  // ================================================================
  // ÉGALITÉ
  // ================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    if (other is! Zone) {
      return false;
    }

    return other.id == id &&
        other.nom == nom &&
        other.batiment == batiment &&
        other.etage == etage &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height &&
        _listEquals(
          other.ssidsAssocies,
          ssidsAssocies,
        ) &&
        _listEquals(
          other.bssidsAssocies,
          bssidsAssocies,
        ) &&
        _polygonesEgaux(
          other.polygone,
          polygone,
        ) &&
        other.couleur == couleur &&
        other.dateCreation == dateCreation &&
        other.createurId == createurId;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      nom,
      batiment,
      etage,
      x,
      y,
      width,
      height,
      Object.hashAll(ssidsAssocies),
      Object.hashAll(bssidsAssocies),

      polygone == null
          ? null
          : Object.hashAll(
        polygone!.map(
              (point) => Object.hash(
            point['x'],
            point['y'],
          ),
        ),
      ),

      couleur,
      dateCreation,
      createurId,
    );
  }

  // ================================================================
  // DEBUG
  // ================================================================

  @override
  String toString() {
    return 'Zone('
        'id: $id, '
        'nom: $nom, '
        'batiment: $batiment, '
        'etage: $etage, '
        'position: '
        '(${x.toStringAsFixed(2)}, '
        '${y.toStringAsFixed(2)}), '
        'taille: '
        '${width.toStringAsFixed(2)}x'
        '${height.toStringAsFixed(2)}, '
        'SSIDs: $ssidsAssocies, '
        'BSSIDs: $bssidsAssocies, '
        'polygone: '
        '${polygone != null ? "${polygone!.length} points" : "null"}'
        ')';
  }

  /// Version courte.
  String toShortString() {
    return '$nom ($batiment - $etage)';
  }

  // ================================================================
  // MÉTHODES PRIVÉES
  // ================================================================

  static const Object _nonModifie = Object();

  /// Vérifie si une valeur est comprise entre 0 et 1.
  static bool _estEntreZeroEtUn(
      double valeur,
      ) {
    return valeur >= 0 &&
        valeur <= 1;
  }

  /// Conversion sécurisée vers double.
  static double _doubleValue(
      dynamic value, {
        double defaultValue = 0.0,
      }) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    ) ??
        defaultValue;
  }

  /// Conversion sécurisée vers String.
  static String _stringValue(
      dynamic value, {
        String defaultValue = '',
      }) {
    if (value == null) {
      return defaultValue;
    }

    final result = value.toString().trim();

    return result.isEmpty
        ? defaultValue
        : result;
  }

  /// Conversion sécurisée d'une liste.
  static List<String> _stringList(
      dynamic value,
      ) {
    if (value is! List) {
      return const [];
    }

    return value
        .map(
          (item) => item.toString().trim(),
    )
        .where(
          (item) => item.isNotEmpty,
    )
        .toList();
  }

  /// Nettoie un SSID.
  static String _nettoyerSsid(
      String ssid,
      ) {
    return ssid
        .replaceAll('"', '')
        .trim();
  }

  /// Normalise un BSSID.
  static String _normaliserBssid(
      String bssid,
      ) {
    return bssid
        .trim()
        .toUpperCase();
  }

  /// Normalise une liste de BSSIDs.
  static List<String> _normaliserBssids(
      List<String> bssids,
      ) {
    return bssids
        .map(_normaliserBssid)
        .where(bssidValide)
        .toSet()
        .toList();
  }

  /// Vérifie le format d'un BSSID.
  ///
  /// Exemple valide :
  /// AA:BB:CC:11:22:33
  static bool _bssidEstValide(
      String bssid,
      ) {
    final regex = RegExp(
      r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$',
      caseSensitive: false,
    );

    return regex.hasMatch(
      bssid.trim(),
    );
  }

  /// Parse un polygone provenant de Firestore ou JSON.
  static List<Map<String, double>>? _parsePolygone(
      dynamic value,
      ) {
    if (value is! List) {
      return null;
    }

    final resultat =
    <Map<String, double>>[];

    for (final point in value) {
      if (point is! Map) {
        continue;
      }

      final px = point['x'];
      final py = point['y'];

      if (px is num && py is num) {
        resultat.add({
          'x': px.toDouble(),
          'y': py.toDouble(),
        });
      }
    }

    return resultat.isEmpty
        ? null
        : resultat;
  }

  /// Parse une date.
  static DateTime? _parseDate(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  /// Vérifie le polygone.
  bool get _polygoneValide {
    if (polygone == null) {
      return true;
    }

    if (polygone!.length < 3) {
      return false;
    }

    for (final point in polygone!) {
      final px = point['x'];
      final py = point['y'];

      if (px == null || py == null) {
        return false;
      }

      if (!_estEntreZeroEtUn(px) ||
          !_estEntreZeroEtUn(py)) {
        return false;
      }
    }

    return true;
  }

  /// Algorithme Ray Casting pour déterminer
  /// si un point se trouve dans un polygone.
  bool _pointDansPolygone(
      double px,
      double py,
      ) {
    bool inside = false;

    final n = polygone!.length;

    for (
    int i = 0, j = n - 1;
    i < n;
    j = i++
    ) {
      final xi =
          polygone![i]['x'] ?? 0.0;
      final yi =
          polygone![i]['y'] ?? 0.0;

      final xj =
          polygone![j]['x'] ?? 0.0;
      final yj =
          polygone![j]['y'] ?? 0.0;

      if ((yi > py) != (yj > py)) {
        final intersectionX =
            (xj - xi) *
                (py - yi) /
                (yj - yi) +
                xi;

        if (px < intersectionX) {
          inside = !inside;
        }
      }
    }

    return inside;
  }

  /// Compare deux listes.
  static bool _listEquals<T>(
      List<T> a,
      List<T> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }

  /// Compare deux polygones.
  static bool _polygonesEgaux(
      List<Map<String, double>>? a,
      List<Map<String, double>>? b,
      ) {
    if (identical(a, b)) {
      return true;
    }

    if (a == null || b == null) {
      return false;
    }

    if (a.length != b.length) {
      return false;
    }

    for (int i = 0; i < a.length; i++) {
      final ax = a[i]['x'];
      final ay = a[i]['y'];

      final bx = b[i]['x'];
      final by = b[i]['y'];

      if (ax != bx || ay != by) {
        return false;
      }
    }

    return true;
  }
}