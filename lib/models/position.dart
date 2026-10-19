// lib/models/position.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Position {
  final String materielId;
  final String zoneId;
  final DateTime timestamp;
  final String? ssid;

  Position({
    required this.materielId,
    required this.zoneId,
    required this.timestamp,
    this.ssid,
  });

  /// Crée une instance de [Position] à partir des données Firestore.
  /// Gère les cas où `timestamp` est null ou invalide.
  factory Position.fromFirestore(Map<String, dynamic> data) {
    return Position(
      materielId: data['materielId'] ?? '',
      zoneId: data['zoneId'] ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(), // Valeur par défaut si timestamp est null
      ssid: data['ssid'],
    );
  }

  /// Convertit une [Position] en Map pour Firestore.
  /// Utilise `Timestamp` pour `timestamp` pour une meilleure compatibilité.
  Map<String, dynamic> toFirestore() {
    return {
      'materielId': materielId,
      'zoneId': zoneId,
      'timestamp': Timestamp.fromDate(timestamp),
      'ssid': ssid,
    };
  }
}