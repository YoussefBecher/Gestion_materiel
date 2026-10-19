// lib/models/zone_wifi.dart
/// Modèle représentant une zone Wi-Fi calibrée (SSID → bâtiment/étage/zone).
/// Utilisé par ZoneWifiService pour retrouver la zone correspondant
/// au SSID actuellement détecté par WifiLocationService.
class ZoneWifi {
  final String ssid;
  final String batiment;
  final String etage;
  final String zone;

  ZoneWifi({
    required this.ssid,
    required this.batiment,
    required this.etage,
    required this.zone,
  });

  factory ZoneWifi.fromFirestore(Map<String, dynamic> data) {
    return ZoneWifi(
      ssid: (data['ssid'] ?? '').toString(),
      batiment: (data['batiment'] ?? '').toString(),
      etage: (data['etage'] ?? '').toString(),
      zone: (data['zone'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ssid': ssid,
      'batiment': batiment,
      'etage': etage,
      'zone': zone,
    };
  }

  @override
  String toString() => 'ZoneWifi(ssid: $ssid, batiment: $batiment, etage: $etage, zone: $zone)';
}