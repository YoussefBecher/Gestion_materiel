import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/materiel.dart';
import 'ajouter_materiel_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _scanned = false;

  Future<void> _enregistrerScan(Materiel materiel) async {
    await FirebaseFirestore.instance.collection('historique').add({
      'action': 'Scan',
      'materielId': materiel
          .id, // 👈 ajouté : sans ça, le tap "modifier" et l'appui long "supprimer" ne trouvent jamais le matériel
      'materiel': materiel.displayName,
      'utilisateur': 'admin@gestion.com',
      'date': FieldValue.serverTimestamp(),
      'details': 'N°série: ${materiel.numeroSerie}',
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final barcode = capture.barcodes.first;
    if (barcode.rawValue == null) return;

    setState(() => _scanned = true);
    cameraController.stop();

    final valeurScannee = barcode.rawValue!;

    final query = await FirebaseFirestore.instance
        .collection('materiels')
        .where('numeroSerie', isEqualTo: valeurScannee)
        .get();

    if (!mounted) return;

    if (query.docs.isNotEmpty) {
      final doc = query.docs.first;
      final materiel = Materiel.fromFirestore(doc);

      await _enregistrerScan(materiel);

      Map<String, dynamic>? employeData;
      final employeId = doc.data()['employeId'];
      if (employeId != null && employeId.toString().isNotEmpty) {
        final employeDoc = await FirebaseFirestore.instance
            .collection('employes')
            .doc(employeId)
            .get();
        if (employeDoc.exists) {
          employeData = employeDoc.data();
        }
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.qr_code, color: Color(0xFF003087)),
              const SizedBox(width: 8),
              const Text(
                'Matériel trouvé',
                style: TextStyle(color: Color(0xFF003087)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF003087).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF003087).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💻 Matériel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003087),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow(
                      'Marque',
                      materiel.marque.isEmpty ? '-' : materiel.marque,
                    ),
                    _infoRow('Type', materiel.type),
                    _infoRow('N° Série', materiel.numeroSerie),
                    _infoRow('État', materiel.etat),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '👤 Employé responsable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (employeData != null) ...[
                      _infoRow(
                        'Nom',
                        '${employeData['nom']} ${employeData['prenom']}',
                      ),
                      _infoRow('Matricule', employeData['matricule'] ?? '-'),
                      _infoRow('Poste', employeData['poste'] ?? '-'),
                      _infoRow(
                        'Département',
                        employeData['departement'] ?? '-',
                      ),
                    ] else
                      const Text(
                        'Aucun employé assigné',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _scanned = false);
                cameraController.start();
              },
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              AjouterMaterielScreen(numeroSerieInitial: valeurScannee),
        ),
      ).then((_) {
        setState(() => _scanned = false);
        cameraController.start();
      });
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: const Text('Scanner QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: cameraController, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Pointez la caméra vers le QR Code',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}