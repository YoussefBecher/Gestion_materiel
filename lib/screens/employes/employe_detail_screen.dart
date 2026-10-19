import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/materiel.dart';
import '../../utils/etat_utils.dart';
import '../materiel/modifier_materiel_screen.dart';

class EmployeDetailScreen extends StatelessWidget {
  final DocumentSnapshot employe;
  const EmployeDetailScreen({super.key, required this.employe});

  @override
  Widget build(BuildContext context) {
    final data = employe.data() as Map<String, dynamic>;
    final nom = data['nom'] ?? '';
    final prenom = data['prenom'] ?? '';
    final poste = data['poste'] ?? '';
    final departement = data['departement'] ?? '';
    final matricule = data['matricule'] ?? '';
    final email = data['email'] ?? '';
    final telephone = data['telephone'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('$nom $prenom', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Carte infos employé ───────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF003087), Color(0xFF1C5EC9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          '${nom.isNotEmpty ? nom[0] : ''}${prenom.isNotEmpty ? prenom[0] : ''}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$nom $prenom',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('$poste — $departement',
                                style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  _infoRow(Icons.badge_rounded, 'Matricule', matricule),
                  _infoRow(Icons.email_rounded, 'Email', email),
                  _infoRow(Icons.phone_rounded, 'Téléphone', telephone),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Section Matériel assigné ────────────────────────
            const Text('Matériel assigné', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('materiels')
                  .where('employeId', isEqualTo: employe.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF003087))),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _emptyCard('Aucun matériel assigné à cet employé', Icons.computer_outlined);
                }

                final materiels = docs.map((d) => Materiel.fromFirestore(d)).toList();

                return Column(
                  children: materiels.map((m) => _materielCard(context, m)).toList(),
                );
              },
            ),

            const SizedBox(height: 20),

            // ─── Section Historique lié ─────────────────────────
            const Text('Historique de cet employé', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('materiels')
                  .where('employeId', isEqualTo: employe.id)
                  .snapshots(),
              builder: (context, materielSnapshot) {
                final materielIds = (materielSnapshot.data?.docs ?? []).map((d) => d.id).toSet();

                if (materielIds.isEmpty) {
                  return _emptyCard('Aucun historique pour cet employé', Icons.history);
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('historique')
                      .orderBy('date', descending: true)
                      .snapshots(),
                  builder: (context, historiqueSnapshot) {
                    if (historiqueSnapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF003087))),
                      );
                    }

                    final entries = (historiqueSnapshot.data?.docs ?? []).where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final materielId = data['materielId'] as String?;
                      return materielId != null && materielIds.contains(materielId);
                    }).toList();

                    if (entries.isEmpty) {
                      return _emptyCard('Aucun historique pour cet employé', Icons.history);
                    }

                    return Column(
                      children: entries.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return _historiqueTile(data);
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.white70),
          const SizedBox(width: 8),
          Text('$label : ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _emptyCard(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _materielCard(BuildContext context, Materiel materiel) {
    final color = EtatUtils.couleur(materiel.etat);
    final icon = EtatUtils.icone(materiel.etat);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(materiel.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('N°série: ${materiel.numeroSerie.isEmpty ? "-" : materiel.numeroSerie}',
            style: const TextStyle(fontSize: 12)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(materiel.etat, style: TextStyle(color: color, fontSize: 11)),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ModifierMaterielScreen(materiel: materiel)),
          );
        },
      ),
    );
  }

  Widget _historiqueTile(Map<String, dynamic> data) {
    final action = data['action'] ?? '';
    final materiel = data['materiel'] ?? '';
    final date = data['date'] as Timestamp?;

    final actionColors = {
      'Ajout': Colors.green,
      'Modification': Colors.orange,
      'Suppression': Colors.red,
      'Scan': Colors.purple,
    };
    final actionIcons = {
      'Ajout': Icons.add_circle,
      'Modification': Icons.edit,
      'Suppression': Icons.delete,
      'Scan': Icons.qr_code_scanner,
    };

    final color = actionColors[action] ?? Colors.blue;
    final icon = actionIcons[action] ?? Icons.info;

    String dateStr = '';
    if (date != null) {
      final d = date.toDate();
      dateStr = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$action — $materiel', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}