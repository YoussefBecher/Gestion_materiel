import 'package:flutter/material.dart';
import '../services/wifi_location_service.dart';

class TestBssidScreen extends StatefulWidget {
  const TestBssidScreen({super.key});

  @override
  State<TestBssidScreen> createState() => _TestBssidScreenState();
}

class _TestBssidScreenState extends State<TestBssidScreen> {
  final WifiLocationService _wifiService = WifiLocationService();
  String _resultText = 'Aucun test lancé pour le moment.';
  bool _isLoading = false;

  Future<void> _testerBssid() async {
    setState(() {
      _isLoading = true;
      _resultText = 'Lecture en cours...';
    });

    final resultat = await _wifiService.testerBssid();

    setState(() {
      _isLoading = false;
      _resultText = resultat;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test BSSID Wi-Fi')),
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
                onPressed: _testerBssid,
                child: const Text('Tester la lecture du BSSID'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}