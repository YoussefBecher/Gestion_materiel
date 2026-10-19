import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: const Text('Statistiques'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('materiels').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('Aucune donnée disponible',
                  style: TextStyle(color: Colors.grey)),
            );
          }

          final docs = snapshot.data!.docs;
          final total = docs.length;

          // Stats par état
          final disponible = docs.where((d) => d['etat'] == 'Disponible').length;
          final enUtilisation = docs.where((d) => d['etat'] == 'En utilisation').length;
          final enPanne = docs.where((d) => d['etat'] == 'En panne').length;
          final enMaintenance = docs.where((d) => d['etat'] == 'En maintenance').length;

          // Stats par type
          final Map<String, int> parType = {};
          for (final doc in docs) {
            final type = doc['type'] ?? 'Autre';
            parType[type] = (parType[type] ?? 0) + 1;
          }

          // Stats par agence
          final Map<String, int> parAgence = {};
          for (final doc in docs) {
            final agence = doc['agence'] ?? 'Non défini';
            if (agence.isNotEmpty) {
              parAgence[agence] = (parAgence[agence] ?? 0) + 1;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Résumé général
                _buildSectionTitle('Résumé général'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('Total', total.toString(), Icons.computer, Colors.blue),
                    const SizedBox(width: 12),
                    _buildStatCard('Disponibles', disponible.toString(), Icons.check_circle, Colors.green),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatCard('En utilisation', enUtilisation.toString(), Icons.person, Colors.orange),
                    const SizedBox(width: 12),
                    _buildStatCard('En panne', enPanne.toString(), Icons.warning, Colors.red),
                  ],
                ),
                if (enMaintenance > 0) ...[
                  const SizedBox(height: 12),
                  _buildStatCard('En maintenance', enMaintenance.toString(), Icons.build, Colors.purple),
                ],

                const SizedBox(height: 24),

                // Statistiques par état (barres)
                _buildSectionTitle('Répartition par état'),
                const SizedBox(height: 12),
                _buildCard([
                  _buildBar('Disponible', disponible, total, Colors.green),
                  const SizedBox(height: 12),
                  _buildBar('En utilisation', enUtilisation, total, Colors.orange),
                  const SizedBox(height: 12),
                  _buildBar('En panne', enPanne, total, Colors.red),
                  if (enMaintenance > 0) ...[
                    const SizedBox(height: 12),
                    _buildBar('En maintenance', enMaintenance, total, Colors.purple),
                  ],
                ]),

                const SizedBox(height: 24),

                // Statistiques par type
                _buildSectionTitle('Répartition par type'),
                const SizedBox(height: 12),
                _buildCard(
                  parType.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildBar(e.key, e.value, total, const Color(0xFF003087)),
                  )).toList(),
                ),

                const SizedBox(height: 24),

                // Statistiques par agence
                if (parAgence.isNotEmpty) ...[
                  _buildSectionTitle('Répartition par agence'),
                  const SizedBox(height: 12),
                  _buildCard(
                    parAgence.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildBar(e.key, e.value, total, Colors.teal),
                    )).toList(),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildBar(String label, int value, int total, Color color) {
    final percent = total == 0 ? 0.0 : value / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text('$value / $total',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}