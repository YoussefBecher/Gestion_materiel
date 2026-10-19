// lib/services/wifi_location_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// ============================================================
// MODÈLE DE RÉSULTAT
// ============================================================

class WifiLocationResult {
  final String? ssid;
  final String? bssid;
  final String? erreur;

  const WifiLocationResult({
    this.ssid,
    this.bssid,
    this.erreur,
  });

  bool get isSuccess =>
      erreur == null &&
          ssid != null &&
          ssid!.trim().isNotEmpty;

  @override
  String toString() {
    return 'WifiLocationResult('
        'ssid: $ssid, '
        'bssid: $bssid, '
        'erreur: $erreur'
        ')';
  }
}

// ============================================================
// SERVICE WI-FI
// ============================================================

class WifiLocationService {
  final NetworkInfo _networkInfo = NetworkInfo();

  static const Duration _timeout = Duration(seconds: 5);

  /// Intervalle entre deux détections.
  static const Duration _scanInterval =
  Duration(seconds: 10);

  Timer? _scanTimer;

  final StreamController<WifiLocationResult>
  _wifiController =
  StreamController<WifiLocationResult>.broadcast();

  bool _scanInProgress = false;
  bool _disposed = false;

  WifiLocationResult? _lastResult;

  // ============================================================
  // STREAM WI-FI
  // ============================================================

  Stream<WifiLocationResult> get wifiStream =>
      _wifiController.stream;

  // ============================================================
  // DERNIER RÉSULTAT
  // ============================================================

  WifiLocationResult? get lastResult => _lastResult;

  // ============================================================
  // DÉMARRAGE DU SCAN AUTOMATIQUE
  // ============================================================

  void startScanning() {
    if (_disposed) {
      return;
    }

    // Empêche de créer plusieurs timers.
    if (_scanTimer != null) {
      return;
    }

    debugPrint(
      '📡 Scan Wi-Fi automatique démarré '
          '(toutes les 10 secondes)',
    );

    // ----------------------------------------------------------
    // Premier scan immédiat
    // ----------------------------------------------------------

    _performScan();

    // ----------------------------------------------------------
    // Scan périodique
    // ----------------------------------------------------------

    _scanTimer = Timer.periodic(
      _scanInterval,
          (_) {
        _performScan();
      },
    );
  }

  // ============================================================
  // ARRÊT DU SCAN
  // ============================================================

  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;

    debugPrint('📡 Scan Wi-Fi automatique arrêté');
  }

  // ============================================================
  // SCAN INTERNE SÉCURISÉ
  // ============================================================

  Future<void> _performScan() async {
    if (_disposed) {
      return;
    }

    // Évite deux scans simultanés.
    if (_scanInProgress) {
      debugPrint(
        '⏳ Scan Wi-Fi précédent encore en cours.',
      );
      return;
    }

    _scanInProgress = true;

    try {
      final result = await getCurrentWifi();

      if (_disposed || _wifiController.isClosed) {
        return;
      }

      _lastResult = result;

      _wifiController.add(result);

      // --------------------------------------------------------
      // Logs de diagnostic
      // --------------------------------------------------------

      if (result.erreur != null) {
        debugPrint(
          '❌ Wi-Fi : ${result.erreur}',
        );
      } else {
        debugPrint(
          '📡 Wi-Fi détecté : '
              'SSID=${result.ssid}, '
              'BSSID=${result.bssid}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Erreur pendant le scan Wi-Fi : $e',
      );
    } finally {
      _scanInProgress = false;
    }
  }

  // ============================================================
  // FORCER UNE DÉTECTION IMMÉDIATE
  // ============================================================

  Future<WifiLocationResult> forceScan() async {
    if (_disposed) {
      return const WifiLocationResult(
        erreur: 'Le service Wi-Fi est arrêté.',
      );
    }

    // Si un scan est déjà en cours, on effectue quand même
    // une lecture directe pour retourner un résultat fiable.
    final result = await getCurrentWifi();

    if (!_disposed && !_wifiController.isClosed) {
      _lastResult = result;
      _wifiController.add(result);
    }

    return result;
  }

  // ============================================================
  // DÉTECTION PRINCIPALE
  // ============================================================

  /// Détecte le réseau Wi-Fi actuellement utilisé :
  ///
  /// - SSID
  /// - BSSID
  ///
  /// Le BSSID permet ensuite d'associer le téléphone
  /// à un point d'accès Wi-Fi enregistré dans Firestore.
  Future<WifiLocationResult> getCurrentWifi() async {
    try {
      // ----------------------------------------------------------
      // 1. Vérification plateforme
      // ----------------------------------------------------------

      if (kIsWeb) {
        return const WifiLocationResult(
          erreur:
          'La détection SSID/BSSID Wi-Fi n’est pas '
              'disponible sur le Web.',
        );
      }

      // ----------------------------------------------------------
      // 2. Vérification permission localisation
      // ----------------------------------------------------------

      PermissionStatus status =
      await Permission.location.status;

      if (status.isDenied) {
        status =
        await Permission.location.request();
      }

      if (status.isPermanentlyDenied) {
        return const WifiLocationResult(
          erreur:
          'Permission de localisation refusée définitivement. '
              'Va dans Paramètres > Applications > '
              'ton application > Autorisations et active '
              'la localisation.',
        );
      }

      if (!status.isGranted) {
        return const WifiLocationResult(
          erreur:
          'La permission de localisation est nécessaire '
              'pour détecter le réseau Wi-Fi.',
        );
      }

      // ----------------------------------------------------------
      // 3. Récupération du SSID
      // ----------------------------------------------------------

      final rawSsid = await _networkInfo
          .getWifiName()
          .timeout(_timeout);

      final ssid = _nettoyerSsid(rawSsid);

      if (ssid == null) {
        return const WifiLocationResult(
          erreur:
          'SSID vide ou inconnu. Vérifie que le Wi-Fi '
              'et la localisation du téléphone sont activés.',
        );
      }

      // ----------------------------------------------------------
      // 4. Récupération du BSSID
      // ----------------------------------------------------------

      String? bssid;

      try {
        final rawBssid = await _networkInfo
            .getWifiBSSID()
            .timeout(_timeout);

        bssid = _nettoyerBssid(rawBssid);
      } catch (e) {
        // Le BSSID peut être inaccessible sur certains appareils.
        debugPrint(
          '⚠️ BSSID indisponible : $e',
        );

        bssid = null;
      }

      // ----------------------------------------------------------
      // 5. Résultat
      // ----------------------------------------------------------

      return WifiLocationResult(
        ssid: ssid,
        bssid: bssid,
      );
    } on TimeoutException {
      return const WifiLocationResult(
        erreur:
        'Délai dépassé lors de la détection du Wi-Fi.',
      );
    } on Exception catch (e) {
      return WifiLocationResult(
        erreur:
        'Impossible de lire le réseau Wi-Fi : $e',
      );
    }
  }

  // ============================================================
  // COMPATIBILITÉ ANCIEN CODE
  // ============================================================

  /// Conservée pour ne pas casser les anciens fichiers
  /// qui utilisent getCurrentSsid().
  Future<WifiLocationResult> getCurrentSsid() async {
    return await getCurrentWifi();
  }

  // ============================================================
  // NETTOYAGE SSID
  // ============================================================

  String? _nettoyerSsid(String? value) {
    if (value == null) {
      return null;
    }

    var ssid = value.trim();

    // Certains appareils retournent le SSID entre guillemets.
    ssid = ssid.replaceAll('"', '').trim();

    if (ssid.isEmpty) {
      return null;
    }

    if (ssid.toLowerCase() == '<unknown ssid>') {
      return null;
    }

    if (ssid.toLowerCase() == 'unknown ssid') {
      return null;
    }

    return ssid;
  }

  // ============================================================
  // NETTOYAGE BSSID
  // ============================================================

  String? _nettoyerBssid(String? value) {
    if (value == null) {
      return null;
    }

    final bssid = value.trim().toLowerCase();

    if (bssid.isEmpty) {
      return null;
    }

    // Adresse fictive retournée par Android
    // dans certaines situations.
    if (bssid == '02:00:00:00:00:00') {
      return null;
    }

    return bssid;
  }

  // ============================================================
  // DIAGNOSTIC BSSID
  // ============================================================

  Future<String> testerBssid() async {
    final result = await getCurrentWifi();

    if (result.erreur != null) {
      return 'ARRÊT : ${result.erreur}';
    }

    if (result.bssid == null) {
      return 'SSID détecté : ${result.ssid}\n'
          'BSSID indisponible sur cet appareil.';
    }

    return 'SSID : ${result.ssid}\n'
        'BSSID : ${result.bssid}';
  }

  // ============================================================
  // DÉTECTION D'UN CHANGEMENT
  // ============================================================

  bool hasChanged(WifiLocationResult result) {
    if (_lastResult == null) {
      return true;
    }

    final ancienSsid = _lastResult!.ssid;
    final ancienBssid = _lastResult!.bssid;

    final nouveauSsid = result.ssid;
    final nouveauBssid = result.bssid;

    return ancienSsid != nouveauSsid ||
        ancienBssid != nouveauBssid;
  }

  // ============================================================
  // LIBÉRATION DES RESSOURCES
  // ============================================================

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    stopScanning();

    if (!_wifiController.isClosed) {
      _wifiController.close();
    }

    debugPrint(
      '📡 WifiLocationService supprimé.',
    );
  }
}

// ============================================================
// RIVERPOD : SERVICE
// ============================================================

final wifiLocationServiceProvider =
Provider<WifiLocationService>((ref) {
  final service = WifiLocationService();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// ============================================================
// RIVERPOD : SSID ACTUEL
// ============================================================

final currentSsidProvider =
FutureProvider<String?>((ref) async {
  final service =
  ref.watch(wifiLocationServiceProvider);

  final result =
  await service.getCurrentWifi();

  if (result.erreur != null) {
    debugPrint(
      '❌ Erreur SSID : ${result.erreur}',
    );

    return null;
  }

  return result.ssid;
});

// ============================================================
// RIVERPOD : BSSID ACTUEL
// ============================================================

final currentBssidProvider =
FutureProvider<String?>((ref) async {
  final service =
  ref.watch(wifiLocationServiceProvider);

  final result =
  await service.getCurrentWifi();

  if (result.erreur != null) {
    debugPrint(
      '❌ Erreur BSSID : ${result.erreur}',
    );

    return null;
  }

  return result.bssid;
});

// ============================================================
// RIVERPOD : ÉTAT WI-FI
// ============================================================

final wifiStateProvider =
FutureProvider<WifiState>((ref) async {
  final service =
  ref.watch(wifiLocationServiceProvider);

  final result =
  await service.getCurrentWifi();

  final permission =
  await Permission.location.status;

  return WifiState(
    isConnected: result.isSuccess,
    ssid: result.ssid,
    bssid: result.bssid,
    permissionGranted: permission.isGranted,
    error: result.erreur,
  );
});

// ============================================================
// RIVERPOD : STREAM WI-FI AUTOMATIQUE
// ============================================================

final wifiStreamProvider =
StreamProvider<WifiLocationResult>((ref) {
  final service =
  ref.watch(wifiLocationServiceProvider);

  // Démarre automatiquement le scan toutes les 10 secondes.
  service.startScanning();

  // Le provider s'occupe de libérer le service.
  ref.onDispose(() {
    service.dispose();
  });

  return service.wifiStream;
});

// ============================================================
// MODÈLE D'ÉTAT WI-FI
// ============================================================

class WifiState {
  final bool isConnected;
  final String? ssid;
  final String? bssid;
  final bool permissionGranted;
  final String? error;

  const WifiState({
    required this.isConnected,
    this.ssid,
    this.bssid,
    required this.permissionGranted,
    this.error,
  });

  bool get hasError => error != null;

  // ============================================================
  // COULEUR
  // ============================================================

  Color get couleur {
    if (error != null) {
      return Colors.red;
    }

    if (isConnected) {
      return Colors.green;
    }

    return Colors.grey;
  }

  // ============================================================
  // ICÔNE
  // ============================================================

  IconData get icone {
    if (error != null) {
      return Icons.error;
    }

    if (isConnected) {
      return Icons.wifi;
    }

    return Icons.wifi_off;
  }

  // ============================================================
  // LABEL
  // ============================================================

  String get label {
    if (error != null) {
      return 'Erreur';
    }

    if (isConnected) {
      return ssid ?? 'Connecté';
    }

    return 'Déconnecté';
  }

  // ============================================================
  // TEXTE BSSID
  // ============================================================

  String get bssidLabel {
    if (bssid == null || bssid!.isEmpty) {
      return 'BSSID indisponible';
    }

    return bssid!;
  }

  @override
  String toString() {
    return 'WifiState('
        'isConnected: $isConnected, '
        'ssid: $ssid, '
        'bssid: $bssid, '
        'permissionGranted: $permissionGranted, '
        'error: $error'
        ')';
  }
}