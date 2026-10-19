// lib/services/zone_wifi_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================
// MODÈLE ZONE WI-FI
// ============================================================

class ZoneWifi {
  final String id;
  final String ssid;
  final String bssid;
  final String batiment;
  final String etage;
  final String zone;

  // Position sur le plan visuel
  final double positionX;
  final double positionY;

  // SSID supplémentaires pouvant correspondre à la zone
  final List<String> ssidsAlternatifs;

  ZoneWifi({
    required this.id,
    required this.ssid,
    required this.bssid,
    required this.batiment,
    required this.etage,
    required this.zone,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.ssidsAlternatifs = const [],
  });

  // ============================================================
  // FIRESTORE → OBJET
  // ============================================================

  factory ZoneWifi.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ZoneWifi(
      id: doc.id,

      ssid: (data['ssid'] ?? '')
          .toString()
          .trim(),

      bssid: (data['bssid'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),

      batiment: (data['batiment'] ?? '')
          .toString()
          .trim(),

      etage: (data['etage'] ?? '')
          .toString()
          .trim(),

      zone: (data['zone'] ?? '')
          .toString()
          .trim(),

      positionX:
      (data['positionX'] as num?)?.toDouble() ?? 0.0,

      positionY:
      (data['positionY'] as num?)?.toDouble() ?? 0.0,

      ssidsAlternatifs:
      List<String>.from(
        data['ssidsAlternatifs'] ?? [],
      ),
    );
  }

  // ============================================================
  // OBJET → FIRESTORE
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'ssid': ssid,
      'bssid': bssid,
      'batiment': batiment,
      'etage': etage,
      'zone': zone,
      'positionX': positionX,
      'positionY': positionY,
      'ssidsAlternatifs': ssidsAlternatifs,
    };
  }

  // ============================================================
  // VÉRIFIER LE SSID
  // ============================================================

  bool correspondSSID(String ssidRecherche) {
    final ssidNettoye = ssidRecherche.trim();

    if (ssid == ssidNettoye) {
      return true;
    }

    return ssidsAlternatifs.contains(ssidNettoye);
  }

  @override
  String toString() {
    return 'ZoneWifi('
        'id: $id, '
        'ssid: $ssid, '
        'bssid: $bssid, '
        'batiment: $batiment, '
        'etage: $etage, '
        'zone: $zone, '
        'positionX: $positionX, '
        'positionY: $positionY'
        ')';
  }
}

// ============================================================
// EXCEPTION
// ============================================================

class ZoneWifiException implements Exception {
  final String message;

  ZoneWifiException(this.message);

  @override
  String toString() => message;
}

// ============================================================
// SERVICE ZONE WI-FI
// ============================================================

class ZoneWifiService {
  final CollectionReference<Map<String, dynamic>> _zonesRef =
  FirebaseFirestore.instance.collection('zones_wifi');

  // ============================================================
  // RECHERCHE PAR BSSID
  // ============================================================

  Future<ZoneWifi?> trouverZoneParBssid(
      String bssid,
      ) async {
    final bssidNettoye =
    bssid.trim().toLowerCase();

    if (bssidNettoye.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _zonesRef
          .where(
        'bssid',
        isEqualTo: bssidNettoye,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ZoneWifi.fromFirestore(
        snapshot.docs.first,
      );
    } catch (e) {
      throw ZoneWifiException(
        'Impossible de rechercher la zone par BSSID : $e',
      );
    }
  }

  // ============================================================
  // RECHERCHE PAR SSID
  // ============================================================

  Future<ZoneWifi?> trouverZoneParSsid(
      String ssid,
      ) async {
    final ssidNettoye = ssid.trim();

    if (ssidNettoye.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _zonesRef
          .where(
        'ssid',
        isEqualTo: ssidNettoye,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ZoneWifi.fromFirestore(
        snapshot.docs.first,
      );
    } catch (e) {
      throw ZoneWifiException(
        'Impossible de rechercher la zone par SSID : $e',
      );
    }
  }

  // ============================================================
  // RECHERCHE PAR SSID ALTERNATIF
  // ============================================================

  Future<ZoneWifi?> trouverZoneParSsidAlternatif(
      String ssid,
      ) async {
    final ssidNettoye = ssid.trim();

    if (ssidNettoye.isEmpty) {
      return null;
    }

    try {
      final snapshot = await _zonesRef
          .where(
        'ssidsAlternatifs',
        arrayContains: ssidNettoye,
      )
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return ZoneWifi.fromFirestore(
        snapshot.docs.first,
      );
    } catch (e) {
      throw ZoneWifiException(
        'Impossible de rechercher la zone par SSID alternatif : $e',
      );
    }
  }

  // ============================================================
  // RECHERCHE INTELLIGENTE
  //
  // Priorité :
  // 1. BSSID
  // 2. SSID
  // 3. SSID alternatif
  // ============================================================

  Future<ZoneWifi?> trouverZone({
    String? ssid,
    String? bssid,
  }) async {
    // ----------------------------------------------------------
    // 1. BSSID
    // ----------------------------------------------------------

    if (bssid != null &&
        bssid.trim().isNotEmpty) {
      final zoneParBssid =
      await trouverZoneParBssid(bssid);

      if (zoneParBssid != null) {
        return zoneParBssid;
      }
    }

    // ----------------------------------------------------------
    // 2. SSID
    // ----------------------------------------------------------

    if (ssid != null &&
        ssid.trim().isNotEmpty) {
      final zoneParSsid =
      await trouverZoneParSsid(ssid);

      if (zoneParSsid != null) {
        return zoneParSsid;
      }
    }

    // ----------------------------------------------------------
    // 3. SSID ALTERNATIF
    // ----------------------------------------------------------

    if (ssid != null &&
        ssid.trim().isNotEmpty) {
      final zoneParSsidAlternatif =
      await trouverZoneParSsidAlternatif(ssid);

      if (zoneParSsidAlternatif != null) {
        return zoneParSsidAlternatif;
      }
    }

    return null;
  }

  // ============================================================
  // RÉCUPÉRER TOUTES LES ZONES EN TEMPS RÉEL
  // ============================================================

  Stream<List<ZoneWifi>> getAllZones() {
    return _zonesRef.snapshots().map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) => ZoneWifi.fromFirestore(doc),
        )
            .toList();
      },
    );
  }

  // ============================================================
  // RÉCUPÉRER LES ZONES D'UN ÉTAGE
  // ============================================================

  Stream<List<ZoneWifi>> getZonesByFloor(
      String etage,
      ) {
    return _zonesRef
        .where(
      'etage',
      isEqualTo: etage,
    )
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) => ZoneWifi.fromFirestore(doc),
        )
            .toList();
      },
    );
  }

  // ============================================================
  // RÉCUPÉRER LES ZONES D'UN BÂTIMENT
  // ============================================================

  Stream<List<ZoneWifi>> getZonesByBuilding(
      String batiment,
      ) {
    return _zonesRef
        .where(
      'batiment',
      isEqualTo: batiment,
    )
        .snapshots()
        .map(
          (snapshot) {
        return snapshot.docs
            .map(
              (doc) => ZoneWifi.fromFirestore(doc),
        )
            .toList();
      },
    );
  }

  // ============================================================
  // AJOUTER UNE ZONE
  // ============================================================

  Future<void> addZone(
      ZoneWifi zone,
      ) async {
    try {
      await _zonesRef.add(
        zone.toMap(),
      );
    } catch (e) {
      throw ZoneWifiException(
        'Impossible d\'ajouter la zone : $e',
      );
    }
  }

  // ============================================================
  // MODIFIER UNE ZONE
  // ============================================================

  Future<void> updateZone(
      String id,
      ZoneWifi zone,
      ) async {
    try {
      await _zonesRef
          .doc(id)
          .update(zone.toMap());
    } catch (e) {
      throw ZoneWifiException(
        'Impossible de mettre à jour la zone : $e',
      );
    }
  }

  // ============================================================
  // SUPPRIMER UNE ZONE
  // ============================================================

  Future<void> deleteZone(
      String id,
      ) async {
    try {
      await _zonesRef
          .doc(id)
          .delete();
    } catch (e) {
      throw ZoneWifiException(
        'Impossible de supprimer la zone : $e',
      );
    }
  }

  // ============================================================
  // VÉRIFIER SI UN BSSID EXISTE
  // ============================================================

  Future<bool> zoneExiste(
      String bssid,
      ) async {
    try {
      final bssidNettoye =
      bssid.trim().toLowerCase();

      final snapshot = await _zonesRef
          .where(
        'bssid',
        isEqualTo: bssidNettoye,
      )
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================
// RIVERPOD PROVIDER
// ============================================================

final zoneWifiServiceProvider =
Provider<ZoneWifiService>((ref) {
  return ZoneWifiService();
});