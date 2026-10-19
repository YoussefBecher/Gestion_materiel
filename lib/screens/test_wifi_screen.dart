import 'package:flutter/material.dart';
import '../services/wifi_location_service.dart';
import '../services/zone_wifi_service.dart';

class TestWifiScreen extends StatefulWidget {
  const TestWifiScreen({super.key});

  @override
  State<TestWifiScreen> createState() => _TestWifiScreenState();
}

class _TestWifiScreenState extends State<TestWifiScreen> {
  final WifiLocationService _wifiService = WifiLocationService();
  final ZoneWifiService _zoneService = ZoneWifiService();

  String _resultText = 'Aucun test lancé pour le moment.';
  bool _isLoading = false;

  Future<void> _testerLocalisation() async {
    setState(() {
      _isLoading = true;
      _resultText = 'Lecture du SSID en cours...';
    });

    final ssidResult = await _wifiService.getCurrentSsid();

    if (ssidResult.erreur != null) {
      setState(() {
        _isLoading = false;
        _resultText = 'Erreur SSID :\n${ssidResult.erreur}';
      });
      return;
    }

    setState(() {
      _resultText =
      'SSID détecté : ${ssidResult.ssid}\nRecherche de la zone...';
    });

    try {
      final zone = await _zoneService.trouverZoneParSsid(ssidResult.ssid!);

      setState(() {
        _isLoading = false;
        if (zone == null) {
          _resultText =
          'SSID détecté : ${ssidResult.ssid}\n\nAucune zone enregistrée pour ce réseau dans Firestore.';
        } else {
          _resultText =
          'SSID : ${zone.ssid}\nBâtiment : ${zone.batiment}\nÉtage : ${zone.etage}\nZone : ${zone.zone}';
        }
      });
    } on ZoneWifiException catch (e) {
      setState(() {
        _isLoading = false;
        _resultText =
        'SSID détecté : ${ssidResult.ssid}\n\nErreur lors de la recherche de zone :\n${e.message}\n\nVérifie ta connexion et réessaie.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _resultText =
        'SSID détecté : ${ssidResult.ssid}\n\nUne erreur inattendue est survenue : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Localisation Wi-Fi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _resultText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _testerLocalisation,
                child: const Text('Tester la localisation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}