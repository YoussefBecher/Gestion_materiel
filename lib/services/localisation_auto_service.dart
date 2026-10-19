import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'wifi_location_service.dart';
import 'zone_wifi_service.dart';

/// ===============================================================
/// LOCALISATION AUTOMATIQUE PAR WI-FI
/// ===============================================================
///
/// Fonctionnement :
///
/// Téléphone
///    ↓
/// Wi-Fi actuel
///    ↓
/// SSID / BSSID
///    ↓
/// Collection Firestore "zones_wifi"
///    ↓
/// Zone correspondante
///    ↓
/// Matériel affecté à l'employé connecté
///    ↓
/// localisationInterieure
///    ↓
/// historique
///    ↓
/// LiveTrackingScreen / PlanEtageScreen
///
/// IMPORTANT :
/// Cette méthode identifie la zone à partir du Wi-Fi auquel
/// le téléphone est actuellement connecté.
/// Elle ne fait PAS de triangulation avec plusieurs bornes Wi-Fi.
///
/// Les positionX / positionY doivent être comprises entre 0 et 1.
/// ===============================================================

class LocalisationAutoService {
  // ===============================================================
  // SERVICES
  // ===============================================================

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final WifiLocationService _wifiService;
  final ZoneWifiService _zoneService;

  // ===============================================================
  // ABONNEMENT WI-FI
  // ===============================================================

  StreamSubscription<WifiLocationResult>? _wifiSubscription;

  // ===============================================================
  // ÉTAT DU SERVICE
  // ===============================================================

  bool _localisationActive = false;
  bool _traitementEnCours = false;

  // ===============================================================
  // DERNIÈRES INFORMATIONS WI-FI
  // ===============================================================

  String? _dernierSsid;
  String? _dernierBssid;
  DateTime? _derniereDetection;

  // ===============================================================
  // MÉMOIRES INTERNES
  // ===============================================================

  final Map<String, DateTime>
  _dernierHistoriqueParMateriel =
  <String, DateTime>{};

  final Map<String, String>
  _derniereZoneParMateriel =
  <String, String>{};

  // ===============================================================
  // CONFIGURATION
  // ===============================================================

  /// Temps minimum entre deux traitements automatiques.
  final Duration _intervalleDetection =
  const Duration(seconds: 8);

  /// Seuil de déplacement.
  ///
  /// Les coordonnées étant normalisées entre 0 et 1,
  /// 0.03 représente environ 3 % de la dimension du plan.
  final double _seuilDeplacement = 0.03;

  // ===============================================================
  // CONSTRUCTEUR
  // ===============================================================

  LocalisationAutoService({
    required WifiLocationService wifiService,
    required ZoneWifiService zoneService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _wifiService = wifiService,
        _zoneService = zoneService,
        _firestore =
            firestore ?? FirebaseFirestore.instance,
        _auth =
            auth ?? FirebaseAuth.instance;

  // ===============================================================
  // GETTERS
  // ===============================================================

  /// Localisation automatique active ou non.
  bool get localisationActive =>
      _localisationActive;

  /// Dernier SSID détecté.
  String? get dernierSsid =>
      _dernierSsid;

  /// Dernier BSSID détecté.
  String? get dernierBssid =>
      _dernierBssid;

  /// Date de la dernière détection réussie.
  DateTime? get derniereDetection =>
      _derniereDetection;

  // ===============================================================
  // DÉMARRER LA LOCALISATION AUTOMATIQUE
  // ===============================================================

  Future<void>
  demarrerLocalisationAutomatique() async {
    // Éviter plusieurs démarrages.
    if (_localisationActive) {
      return;
    }

    _localisationActive = true;

    // Annuler une ancienne écoute si elle existe.
    await _wifiSubscription?.cancel();
    _wifiSubscription = null;

    // Écouter les changements Wi-Fi.
    _wifiSubscription =
        _wifiService.wifiStream.listen(
              (WifiLocationResult resultat) async {
            await _traiterResultatWifi(
              resultat,
            );
          },
          onError: (Object erreur) {
            // On ne coupe pas automatiquement le service.
            // Une prochaine détection pourra fonctionner.
          },
        );

    // Démarrer le scan périodique du service Wi-Fi.
    _wifiService.startScanning();

    // Première détection immédiate.
    await detecterEtMettreAJour();
  }

  // ===============================================================
  // ARRÊTER LA LOCALISATION AUTOMATIQUE
  // ===============================================================

  Future<void>
  arreterLocalisationAutomatique() async {
    _localisationActive = false;

    await _wifiSubscription?.cancel();
    _wifiSubscription = null;

    _wifiService.stopScanning();
  }

  // ===============================================================
  // TRAITER UN RÉSULTAT WI-FI
  // ===============================================================

  Future<void> _traiterResultatWifi(
      WifiLocationResult resultat,
      ) async {
    if (!_localisationActive) {
      return;
    }

    if (!resultat.isSuccess) {
      return;
    }

    final String? ssid =
    _normaliserSsid(
      resultat.ssid,
    );

    final String? bssid =
    _normaliserBssid(
      resultat.bssid,
    );

    // Aucun SSID exploitable.
    if (ssid == null) {
      return;
    }

    // Mise à jour des informations affichées
    // dans LiveTrackingScreen.
    _dernierSsid = ssid;
    _dernierBssid = bssid;

    final DateTime maintenant =
    DateTime.now();

    // Limitation des traitements.
    if (_derniereDetection != null &&
        maintenant.difference(
          _derniereDetection!,
        ) <
            _intervalleDetection) {
      return;
    }

    try {
      await _executerLocalisation(
        ssid: ssid,
        bssid: bssid,
      );

      _derniereDetection =
          maintenant;
    } catch (_) {
      // Ne pas interrompre le suivi automatique.
    }
  }

  // ===============================================================
  // DÉTECTION MANUELLE
  // ===============================================================

  Future<void>
  detecterEtMettreAJour() async {
    if (_traitementEnCours) {
      return;
    }

    try {
      final WifiLocationResult resultat =
      await _wifiService.getCurrentWifi();

      if (!resultat.isSuccess) {
        return;
      }

      final String? ssid =
      _normaliserSsid(
        resultat.ssid,
      );

      final String? bssid =
      _normaliserBssid(
        resultat.bssid,
      );

      if (ssid == null) {
        return;
      }

      // Mise à jour immédiate.
      _dernierSsid = ssid;
      _dernierBssid = bssid;

      await _executerLocalisation(
        ssid: ssid,
        bssid: bssid,
      );

      _derniereDetection =
          DateTime.now();
    } catch (_) {
      // Ne pas faire planter l'application.
    }
  }

  // ===============================================================
  // EXÉCUTER LA LOCALISATION
  // ===============================================================

  Future<void> _executerLocalisation({
    required String ssid,
    String? bssid,
  }) async {
    if (_traitementEnCours) {
      return;
    }

    _traitementEnCours = true;

    try {
      await _mettreAJourDepuisWifi(
        ssid: ssid,
        bssid: bssid,
      );
    } finally {
      _traitementEnCours = false;
    }
  }

  // ===============================================================
  // LOCALISATION À PARTIR DU WI-FI
  // ===============================================================

  Future<void> _mettreAJourDepuisWifi({
    required String ssid,
    String? bssid,
  }) async {
    // =============================================================
    // 1. UTILISATEUR CONNECTÉ
    // =============================================================

    final User? utilisateur =
        _auth.currentUser;

    if (utilisateur == null) {
      return;
    }

    // =============================================================
    // 2. TROUVER LA ZONE
    // =============================================================

    final ZoneWifi? zone =
    await _zoneService.trouverZone(
      ssid: ssid,
      bssid: bssid,
    );

    // Wi-Fi non enregistré dans zones_wifi.
    if (zone == null) {
      return;
    }

    // =============================================================
    // 3. TROUVER L'EMPLOYÉ
    // =============================================================

    final QuerySnapshot<
        Map<String, dynamic>>
    employesSnapshot =
    await _firestore
        .collection('employes')
        .where(
      'email',
      isEqualTo: utilisateur.email,
    )
        .limit(1)
        .get();

    if (employesSnapshot.docs.isEmpty) {
      return;
    }

    final DocumentSnapshot<
        Map<String, dynamic>>
    employeDoc =
        employesSnapshot.docs.first;

    final String employeId =
        employeDoc.id;

    final Map<String, dynamic>
    employeData =
        employeDoc.data() ??
            <String, dynamic>{};

    final String nomEmploye =
        _obtenirTexte(
          employeData['nom'],
        ) ??
            _obtenirTexte(
              employeData['nomComplet'],
            ) ??
            utilisateur.email ??
            'Utilisateur';

    // =============================================================
    // 4. MATÉRIELS AFFECTÉS À L'EMPLOYÉ
    // =============================================================

    final QuerySnapshot<
        Map<String, dynamic>>
    materielsSnapshot =
    await _firestore
        .collection('materiels')
        .where(
      'employeId',
      isEqualTo: employeId,
    )
        .get();

    if (materielsSnapshot.docs.isEmpty) {
      return;
    }

    // =============================================================
    // 5. BATCH FIRESTORE
    // =============================================================

    WriteBatch batch =
    _firestore.batch();

    int operations = 0;

    // =============================================================
    // 6. TRAITER CHAQUE MATÉRIEL
    // =============================================================

    for (final DocumentSnapshot<
        Map<String, dynamic>>
    materielDoc
    in materielsSnapshot.docs) {
      final Map<String, dynamic>
      materielData =
          materielDoc.data() ??
              <String, dynamic>{};

      final String materielId =
          materielDoc.id;

      final String nomMateriel =
      _obtenirNomMateriel(
        materielData,
      );

      // =========================================================
      // ANCIENNE LOCALISATION
      // =========================================================

      final Map<String, dynamic>?
      ancienneLocalisation =
      _extraireMap(
        materielData[
        'localisationInterieure'],
      );

      final double? ancienneX =
      _extraireDouble(
        ancienneLocalisation?[
        'positionX'],
      );

      final double? ancienneY =
      _extraireDouble(
        ancienneLocalisation?[
        'positionY'],
      );

      final String? ancienneZone =
      _obtenirTexte(
        ancienneLocalisation?[
        'zone'],
      );

      final String? ancienEtage =
      _obtenirTexte(
        ancienneLocalisation?[
        'etage'],
      );

      final String? ancienBatiment =
      _obtenirTexte(
        ancienneLocalisation?[
        'batiment'],
      );

      // =========================================================
      // NOUVELLE POSITION
      // =========================================================

      final double nouvelleX =
      _normaliserCoordonnee(
        zone.positionX,
      );

      final double nouvelleY =
      _normaliserCoordonnee(
        zone.positionY,
      );

      // =========================================================
      // PREMIÈRE LOCALISATION
      // =========================================================

      final bool premiereLocalisation =
          ancienneLocalisation == null ||
              ancienneX == null ||
              ancienneY == null;

      // =========================================================
      // CHANGEMENT DE ZONE
      // =========================================================

      final bool changementZone =
          ancienneZone != null &&
              ancienneZone
                  .trim()
                  .toLowerCase() !=
                  zone.zone
                      .trim()
                      .toLowerCase();

      // =========================================================
      // CHANGEMENT D'ÉTAGE
      // =========================================================

      final bool changementEtage =
          ancienEtage != null &&
              ancienEtage
                  .trim()
                  .toLowerCase() !=
                  zone.etage
                      .trim()
                      .toLowerCase();

      // =========================================================
      // CHANGEMENT DE BÂTIMENT
      // =========================================================

      final bool changementBatiment =
          ancienBatiment != null &&
              ancienBatiment
                  .trim()
                  .toLowerCase() !=
                  zone.batiment
                      .trim()
                      .toLowerCase();

      // =========================================================
      // CHANGEMENT DE POSITION
      // =========================================================

      final bool changementPosition =
          ancienneX != null &&
              ancienneY != null &&
              _distanceNormalisee(
                ancienneX,
                ancienneY,
                nouvelleX,
                nouvelleY,
              ) >=
                  _seuilDeplacement;

      // =========================================================
      // MOUVEMENT
      // =========================================================

      final bool mouvementDetecte =
          !premiereLocalisation &&
              (
                  changementZone ||
                      changementEtage ||
                      changementBatiment ||
                      changementPosition
              );

      final String statut =
      mouvementDetecte
          ? 'enMouvement'
          : 'statique';

      final Timestamp maintenant =
      Timestamp.now();

      // =========================================================
      // TRAJECTOIRE
      // =========================================================

      final TrajectoryInfo trajectoire =
      _calculerInformationsTrajectoire(
        materielId: materielId,
        ancienneLocalisation:
        ancienneLocalisation,
        nouvelleX: nouvelleX,
        nouvelleY: nouvelleY,
        mouvementDetecte:
        mouvementDetecte,
      );

      // =========================================================
      // NOUVELLE LOCALISATION
      // =========================================================

      final Map<String, dynamic>
      nouvelleLocalisation =
      <String, dynamic>{
        'id':
        '${materielId}_${maintenant.millisecondsSinceEpoch}',

        'materielId':
        materielId,

        'zoneId':
        zone.id,

        // Wi-Fi
        'ssid':
        ssid,

        'bssid':
        bssid,

        // RSSI non disponible avec
        // cette architecture.
        'rssi':
        null,

        // Zone
        'batiment':
        zone.batiment,

        'etage':
        zone.etage,

        'zone':
        zone.zone,

        // Position normalisée 0..1
        'positionX':
        nouvelleX,

        'positionY':
        nouvelleY,

        // État
        'statut':
        statut,

        'statutDeplacement':
        statut,

        // Dates
        'derniereMiseAJour':
        maintenant,

        'dateCreation':
        ancienneLocalisation?[
        'dateCreation'] ??
            maintenant,

        // Méthode
        'methode':
        'wifi',

        // Confiance
        'confiance':
        1.0,

        'precision':
        1.0,

        'precisionType':
        'zone',

        // Mouvement
        'mouvementDetecte':
        mouvementDetecte,

        'trajetActif':
        mouvementDetecte,

        // Trajectoire
        'sequence':
        trajectoire.sequence,

        'trajetId':
        trajectoire.trajetId,

        'dureeDepuisPrecedent':
        trajectoire
            .dureeDepuisPrecedent,

        'distanceDepuisPrecedent':
        trajectoire
            .distanceDepuisPrecedent,

        'direction':
        trajectoire.direction,

        'vitesse':
        trajectoire.vitesse,

        'estPointDepart':
        trajectoire.estPointDepart,

        'estPointArrivee':
        trajectoire.estPointArrivee,

        'notes':
        mouvementDetecte
            ? 'Déplacement détecté automatiquement par Wi-Fi.'
            : 'Position détectée automatiquement par Wi-Fi.',
      };

      // =========================================================
      // MISE À JOUR DU MATÉRIEL
      // =========================================================

      batch.update(
        materielDoc.reference,
        <String, dynamic>{
          'localisationInterieure':
          nouvelleLocalisation,

          'dateDerniereLocalisation':
          maintenant,
        },
      );

      operations++;

      // =========================================================
      // HISTORIQUE
      // =========================================================

      if (premiereLocalisation ||
          mouvementDetecte) {
        final DocumentReference<
            Map<String, dynamic>>
        historiqueRef =
        _firestore
            .collection(
          'historique',
        )
            .doc();

        final Map<String, dynamic>
        historiqueData =
        <String, dynamic>{
          'materielId':
          materielId,

          'materiel':
          nomMateriel,

          'utilisateur':
          nomEmploye,

          'utilisateurId':
          utilisateur.uid,

          'action':
          'Localisation',

          'date':
          maintenant,

          'dateDetection':
          maintenant,

          'details':
          premiereLocalisation
              ? 'Première localisation automatique : ${zone.zone}.'
              : 'Déplacement détecté : '
              '${ancienneZone ?? 'position précédente'} → '
              '${zone.zone}.',

          'ssid':
          ssid,

          'bssid':
          bssid,

          'positionX':
          nouvelleX,

          'positionY':
          nouvelleY,

          'batiment':
          zone.batiment,

          'etage':
          zone.etage,

          'zone':
          zone.zone,

          'statut':
          statut,

          'statutDeplacement':
          statut,

          'methode':
          'wifi',

          'confiance':
          1.0,

          'precision':
          1.0,

          'precisionType':
          'zone',

          'mouvementDetecte':
          mouvementDetecte,

          'sequence':
          trajectoire.sequence,

          'trajetId':
          trajectoire.trajetId,

          'dureeDepuisPrecedent':
          trajectoire
              .dureeDepuisPrecedent,

          'distanceDepuisPrecedent':
          trajectoire
              .distanceDepuisPrecedent,

          'direction':
          trajectoire.direction,

          'vitesse':
          trajectoire.vitesse,

          'estPointDepart':
          trajectoire.estPointDepart,

          'estPointArrivee':
          trajectoire.estPointArrivee,
        };

        batch.set(
          historiqueRef,
          historiqueData,
        );

        operations++;

        _dernierHistoriqueParMateriel[
        materielId] =
            DateTime.now();

        _derniereZoneParMateriel[
        materielId] =
            zone.zone;
      }

      // =========================================================
      // FIRESTORE LIMITE DE 500 OPÉRATIONS
      // =========================================================
      //
      // On garde une marge de sécurité.
      // Chaque matériel peut faire 1 ou 2 opérations.
      // =========================================================

      if (operations >= 400) {
        await batch.commit();

        batch =
            _firestore.batch();

        operations = 0;
      }
    }

    // =============================================================
    // COMMIT FINAL
    // =============================================================

    if (operations > 0) {
      await batch.commit();
    }
  }

  // ===============================================================
  // CALCULER LES INFORMATIONS DE TRAJECTOIRE
  // ===============================================================

  TrajectoryInfo
  _calculerInformationsTrajectoire({
    required String materielId,
    required Map<String, dynamic>?
    ancienneLocalisation,
    required double nouvelleX,
    required double nouvelleY,
    required bool mouvementDetecte,
  }) {
    // =============================================================
    // PREMIÈRE LOCALISATION
    // =============================================================

    if (ancienneLocalisation == null) {
      return TrajectoryInfo(
        sequence: 1,
        trajetId:
        _nouveauTrajetId(
          materielId,
        ),
        dureeDepuisPrecedent:
        null,
        distanceDepuisPrecedent:
        null,
        direction:
        null,
        vitesse:
        null,
        estPointDepart:
        true,
        estPointArrivee:
        false,
      );
    }

    // =============================================================
    // ANCIENNES COORDONNÉES
    // =============================================================

    final double? ancienneX =
    _extraireDouble(
      ancienneLocalisation[
      'positionX'],
    );

    final double? ancienneY =
    _extraireDouble(
      ancienneLocalisation[
      'positionY'],
    );

    final int sequencePrecedente =
        _extraireInt(
          ancienneLocalisation[
          'sequence'],
        ) ??
            0;

    String? trajetId =
    _obtenirTexte(
      ancienneLocalisation[
      'trajetId'],
    );

    // =============================================================
    // TRAJET PRÉCÉDENT TERMINÉ
    // =============================================================

    final bool ancienTrajetTermine =
        ancienneLocalisation[
        'estPointArrivee'] ==
            true;

    if (mouvementDetecte &&
        (
            trajetId == null ||
                trajetId.isEmpty ||
                ancienTrajetTermine
        )) {
      trajetId =
          _nouveauTrajetId(
            materielId,
          );
    }

    // =============================================================
    // COORDONNÉES ABSENTES
    // =============================================================

    if (ancienneX == null ||
        ancienneY == null) {
      return TrajectoryInfo(
        sequence:
        sequencePrecedente + 1,

        trajetId:
        trajetId ??
            _nouveauTrajetId(
              materielId,
            ),

        dureeDepuisPrecedent:
        null,

        distanceDepuisPrecedent:
        null,

        direction:
        null,

        vitesse:
        null,

        estPointDepart:
        true,

        estPointArrivee:
        false,
      );
    }

    // =============================================================
    // DISTANCE
    // =============================================================

    final double distance =
    _distanceNormalisee(
      ancienneX,
      ancienneY,
      nouvelleX,
      nouvelleY,
    );

    // =============================================================
    // DIRECTION
    // =============================================================

    final double? direction =
    _calculerDirection(
      ancienneX,
      ancienneY,
      nouvelleX,
      nouvelleY,
    );

    // =============================================================
    // DATE PRÉCÉDENTE
    // =============================================================

    final DateTime? ancienneDate =
    _extraireDate(
      ancienneLocalisation[
      'derniereMiseAJour'],
    );

    // =============================================================
    // DURÉE
    // =============================================================

    final int? dureeSecondes =
    ancienneDate == null
        ? null
        : DateTime.now()
        .difference(
      ancienneDate,
    )
        .inSeconds;

    // =============================================================
    // VITESSE
    // =============================================================

    double? vitesse;

    if (dureeSecondes != null &&
        dureeSecondes > 0) {
      vitesse =
          distance /
              dureeSecondes;
    }

    return TrajectoryInfo(
      sequence:
      sequencePrecedente + 1,

      trajetId:
      trajetId ??
          _nouveauTrajetId(
            materielId,
          ),

      dureeDepuisPrecedent:
      dureeSecondes,

      distanceDepuisPrecedent:
      distance,

      direction:
      direction,

      vitesse:
      vitesse,

      estPointDepart:
      false,

      estPointArrivee:
      !mouvementDetecte,
    );
  }

  // ===============================================================
  // CRÉER UN ID DE TRAJET
  // ===============================================================

  String _nouveauTrajetId(
      String materielId,
      ) {
    return 'trajet_${materielId}_'
        '${DateTime.now().millisecondsSinceEpoch}';
  }

  // ===============================================================
  // DISTANCE ENTRE DEUX POSITIONS
  // ===============================================================

  double _distanceNormalisee(
      double x1,
      double y1,
      double x2,
      double y2,
      ) {
    final double dx =
        x2 - x1;

    final double dy =
        y2 - y1;

    return math.sqrt(
      (dx * dx) +
          (dy * dy),
    );
  }

  // ===============================================================
  // CALCUL DE DIRECTION
  // ===============================================================

  double? _calculerDirection(
      double x1,
      double y1,
      double x2,
      double y2,
      ) {
    final double dx =
        x2 - x1;

    final double dy =
        y2 - y1;

    if (dx.abs() < 0.0001 &&
        dy.abs() < 0.0001) {
      return null;
    }

    double angle =
        math.atan2(
          dy,
          dx,
        ) *
            180 /
            math.pi;

    if (angle < 0) {
      angle += 360;
    }

    return angle;
  }

  // ===============================================================
  // RÉCUPÉRER LA DERNIÈRE POSITION
  // ===============================================================

  Future<LocalisationData?>
  getDernierePosition(
      String materielId,
      ) async {
    try {
      final DocumentSnapshot<
          Map<String, dynamic>>
      doc =
      await _firestore
          .collection(
        'materiels',
      )
          .doc(materielId)
          .get();

      if (!doc.exists) {
        return null;
      }

      final Map<String, dynamic>
      data =
          doc.data() ??
              <String, dynamic>{};

      final Map<String, dynamic>?
      localisation =
      _extraireMap(
        data[
        'localisationInterieure'],
      );

      if (localisation == null) {
        return null;
      }

      final double? x =
      _extraireDouble(
        localisation[
        'positionX'],
      );

      final double? y =
      _extraireDouble(
        localisation[
        'positionY'],
      );

      if (x == null || y == null) {
        return null;
      }

      return LocalisationData(
        materielId:
        materielId,

        zone:
        _obtenirTexte(
          localisation[
          'zone'],
        ) ??
            '',

        etage:
        _obtenirTexte(
          localisation[
          'etage'],
        ) ??
            '',

        batiment:
        _obtenirTexte(
          localisation[
          'batiment'],
        ) ??
            '',

        positionX:
        _normaliserCoordonnee(
          x,
        ),

        positionY:
        _normaliserCoordonnee(
          y,
        ),

        ssid:
        _obtenirTexte(
          localisation['ssid'],
        ),

        bssid:
        _obtenirTexte(
          localisation['bssid'],
        ),

        statut:
        _obtenirTexte(
          localisation[
          'statut'],
        ) ??
            'statique',

        date:
        _extraireDate(
          localisation[
          'derniereMiseAJour'],
        ) ??
            DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  // ===============================================================
  // RÉCUPÉRER L'HISTORIQUE D'UN MATÉRIEL
  // ===============================================================

  Future<List<Map<String, dynamic>>>
  getHistoriqueMateriel(
      String materielId, {
        int limite = 100,
      }) async {
    try {
      final QuerySnapshot<
          Map<String, dynamic>>
      snapshot =
      await _firestore
          .collection(
        'historique',
      )
          .where(
        'materielId',
        isEqualTo: materielId,
      )
          .limit(limite)
          .get();

      final List<
          Map<String, dynamic>>
      historique =
      snapshot.docs
          .map(
            (
            DocumentSnapshot<
                Map<String, dynamic>>
            doc,
            ) {
          final Map<String, dynamic>
          data =
              doc.data() ??
                  <String, dynamic>{};

          return <String, dynamic>{
            ...data,
            '_id': doc.id,
          };
        },
      )
          .toList();

      historique.sort(
            (
            Map<String, dynamic> a,
            Map<String, dynamic> b,
            ) {
          final DateTime dateA =
              _extraireDate(
                a['date'],
              ) ??
                  DateTime
                      .fromMillisecondsSinceEpoch(
                    0,
                  );

          final DateTime dateB =
              _extraireDate(
                b['date'],
              ) ??
                  DateTime
                      .fromMillisecondsSinceEpoch(
                    0,
                  );

          return dateA.compareTo(
            dateB,
          );
        },
      );

      return historique;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  // ===============================================================
  // NORMALISER SSID
  // ===============================================================

  String? _normaliserSsid(
      String? valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    String resultat =
    valeur.trim();

    if (resultat.isEmpty) {
      return null;
    }

    final String minuscule =
    resultat.toLowerCase();

    if (minuscule ==
        '<unknown ssid>' ||
        minuscule ==
            'unknown' ||
        minuscule ==
            'null') {
      return null;
    }

    // Certains téléphones Android
    // renvoient le SSID avec des guillemets.
    if (resultat.startsWith('"') &&
        resultat.endsWith('"') &&
        resultat.length >= 2) {
      resultat =
          resultat.substring(
            1,
            resultat.length - 1,
          );
    }

    resultat = resultat.trim();

    if (resultat.isEmpty) {
      return null;
    }

    return resultat;
  }

  // ===============================================================
  // NORMALISER BSSID
  // ===============================================================

  String? _normaliserBssid(
      String? valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    final String resultat =
    valeur
        .trim()
        .toLowerCase();

    if (resultat.isEmpty) {
      return null;
    }

    if (resultat ==
        '<unknown bssid>' ||
        resultat ==
            'unknown' ||
        resultat ==
            'null' ||
        resultat ==
            '02:00:00:00:00:00') {
      return null;
    }

    return resultat;
  }

  // ===============================================================
  // OBTENIR TEXTE
  // ===============================================================

  String? _obtenirTexte(
      dynamic valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    final String texte =
    valeur.toString().trim();

    if (texte.isEmpty) {
      return null;
    }

    return texte;
  }

  // ===============================================================
  // EXTRAIRE DOUBLE
  // ===============================================================

  double? _extraireDouble(
      dynamic valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is num) {
      return valeur.toDouble();
    }

    return double.tryParse(
      valeur.toString(),
    );
  }

  // ===============================================================
  // EXTRAIRE INT
  // ===============================================================

  int? _extraireInt(
      dynamic valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is int) {
      return valeur;
    }

    if (valeur is num) {
      return valeur.toInt();
    }

    return int.tryParse(
      valeur.toString(),
    );
  }

  // ===============================================================
  // EXTRAIRE DATE
  // ===============================================================

  DateTime? _extraireDate(
      dynamic valeur,
      ) {
    if (valeur == null) {
      return null;
    }

    if (valeur is Timestamp) {
      return valeur.toDate();
    }

    if (valeur is DateTime) {
      return valeur;
    }

    if (valeur is int) {
      return DateTime
          .fromMillisecondsSinceEpoch(
        valeur,
      );
    }

    if (valeur is String) {
      return DateTime.tryParse(
        valeur,
      );
    }

    return null;
  }

  // ===============================================================
  // EXTRAIRE MAP
  // ===============================================================

  Map<String, dynamic>? _extraireMap(
      dynamic valeur,
      ) {
    if (valeur ==
        null) {
      return null;
    }

    if (valeur
    is Map<String, dynamic>) {
      return valeur;
    }

    if (valeur is Map) {
      return Map<String, dynamic>
          .from(
        valeur,
      );
    }

    return null;
  }

  // ===============================================================
  // OBTENIR NOM MATÉRIEL
  // ===============================================================

  String _obtenirNomMateriel(
      Map<String, dynamic> data,
      ) {
    final String? nom =
    _obtenirTexte(
      data['nom'],
    );

    if (nom != null) {
      return nom;
    }

    final String? marque =
    _obtenirTexte(
      data['marque'],
    );

    final String? type =
    _obtenirTexte(
      data['type'],
    );

    if (marque != null &&
        type != null) {
      return '$marque — $type';
    }

    if (type != null) {
      return type;
    }

    final String? reference =
    _obtenirTexte(
      data['reference'],
    );

    if (reference != null) {
      return reference;
    }

    final String? numeroSerie =
    _obtenirTexte(
      data['numeroSerie'],
    );

    if (numeroSerie != null) {
      return numeroSerie;
    }

    return 'Matériel';
  }

  // ===============================================================
  // NORMALISER COORDONNÉE
  // ===============================================================
  //
  // Les coordonnées du plan sont normalisées :
  //
  // 0.0 = début
  // 0.5 = milieu
  // 1.0 = fin
  //
  // Cela permet à PlanEtageScreen de faire :
  //
  // x = positionX * largeur
  // y = positionY * hauteur
  // ===============================================================

  double _normaliserCoordonnee(
      double valeur,
      ) {
    if (valeur.isNaN ||
        valeur.isInfinite) {
      return 0.0;
    }

    return valeur.clamp(
      0.0,
      1.0,
    );
  }

  // ===============================================================
  // DISPOSE
  // ===============================================================

  Future<void> dispose() async {
    await arreterLocalisationAutomatique();

    _dernierHistoriqueParMateriel
        .clear();

    _derniereZoneParMateriel
        .clear();

    _dernierSsid = null;
    _dernierBssid = null;
    _derniereDetection = null;
  }
}

// ===============================================================
// INFORMATIONS DE TRAJECTOIRE
// ===============================================================

class TrajectoryInfo {
  final int sequence;

  final String trajetId;

  final int?
  dureeDepuisPrecedent;

  final double?
  distanceDepuisPrecedent;

  final double? direction;

  final double? vitesse;

  final bool estPointDepart;

  final bool estPointArrivee;

  const TrajectoryInfo({
    required this.sequence,
    required this.trajetId,
    required this.dureeDepuisPrecedent,
    required this.distanceDepuisPrecedent,
    required this.direction,
    required this.vitesse,
    required this.estPointDepart,
    required this.estPointArrivee,
  });
}

// ===============================================================
// DONNÉES DE LOCALISATION
// ===============================================================

class LocalisationData {
  final String materielId;

  final String zone;

  final String etage;

  final String batiment;

  final double positionX;

  final double positionY;

  final String? ssid;

  final String? bssid;

  final String statut;

  final DateTime date;

  const LocalisationData({
    required this.materielId,
    required this.zone,
    required this.etage,
    required this.batiment,
    required this.positionX,
    required this.positionY,
    required this.ssid,
    required this.bssid,
    required this.statut,
    required this.date,
  });

  bool get estEnMouvement =>
      statut == 'enMouvement';

  bool get estStatique =>
      statut == 'statique';

  bool get estHorsLigne =>
      statut == 'horsLigne';
}

// ===============================================================
// PROVIDER RIVERPOD
// ===============================================================

final localisationAutoServiceProvider =
Provider<LocalisationAutoService>(
      (ref) {
    final WifiLocationService
    wifiService =
    ref.watch(
      wifiLocationServiceProvider,
    );

    final ZoneWifiService
    zoneService =
    ref.watch(
      zoneWifiServiceProvider,
    );

    final LocalisationAutoService
    service =
    LocalisationAutoService(
      wifiService: wifiService,
      zoneService: zoneService,
    );

    // Nettoyage automatique lorsque
    // le provider est détruit.
    ref.onDispose(() {
      unawaited(
        service.dispose(),
      );
    });

    return service;
  },
);