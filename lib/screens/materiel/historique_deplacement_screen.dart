import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/materiel.dart';

/// Affiche la chronologie des déplacements d'un matériel : chaque fois
/// que sa zone Wi-Fi détectée a changé (entrées `action: 'Localisation'`
/// dans `historique`, créées par LocalisationAutoService ou l'agent PC),
/// on affiche "d'où → vers où, quand".
class HistoriqueDeplacementScreen extends StatelessWidget {
  final Materiel materiel;
  const HistoriqueDeplacementScreen({super.key, required this.materiel});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} à ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Trajet — ${materiel.displayName}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('historique')
            .where('materielId', isEqualTo: materiel.id)
            .where('action', isEqualTo: 'Localisation')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF003087)));
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur : ${snapshot.error}\n\nSi l\'erreur mentionne un index manquant, '
                      'clique sur le lien fourni par Firestore pour le créer automatiquement.',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final entrees = snapshot.data?.docs ?? [];

          if (entrees.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_outlined, size: 70, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Aucun déplacement détecté pour ce matériel.',
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text('L\'historique apparaîtra dès que sa zone Wi-Fi changera.',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entrees.length,
            itemBuilder: (context, index) {
              final data = entrees[index].data() as Map<String, dynamic>;
              final details = (data['details'] ?? '').toString();
              final date = data['date'] as Timestamp?;
              final estLeplusRecent = index == 0;

              return _buildEtapeTrajet(
                details: details,
                date: _formatDate(date),
                estLeplusRecent: estLeplusRecent,
                estDernier: index == entrees.length - 1,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEtapeTrajet({
    required String details,
    required String date,
    required bool estLeplusRecent,
    required bool estDernier,
  }) {
    final couleur = estLeplusRecent ? Colors.green : const Color(0xFF003087);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne de temps verticale (point + trait)
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: couleur,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: couleur.withValues(alpha: 0.3), blurRadius: 4)],
                ),
              ),
              if (!estDernier)
                Expanded(
                  child: Container(width: 2, color: Colors.grey.shade300),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Carte de l'étape
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: estLeplusRecent ? Border.all(color: Colors.green.shade200) : null,
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (estLeplusRecent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Position actuelle',
                          style: TextStyle(color: Colors.green, fontSize: 10.5, fontWeight: FontWeight.bold)),
                    ),
                  Text(details.isEmpty ? 'Localisation mise à jour' : details,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(date, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}