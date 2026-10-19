import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../materiel/modifier_materiel_screen.dart';
import '../../models/materiel.dart';

class HistoriqueScreen extends StatefulWidget {
  const HistoriqueScreen({super.key});

  @override
  State<HistoriqueScreen> createState() => _HistoriqueScreenState();
}

class _HistoriqueScreenState extends State<HistoriqueScreen> {
  String _filtreAction = 'Tous';
  String _recherche = '';
  late final Stream<QuerySnapshot> _historiqueStream;

  @override
  void initState() {
    super.initState();
    _historiqueStream = FirebaseFirestore.instance
        .collection('historique')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> _supprimerTout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer tout l\'historique ?'),
        content: const Text(
          'Cette action est irréversible. Toutes les entrées de l\'historique seront définitivement supprimées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tout supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snapshot = await FirebaseFirestore.instance.collection('historique').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Historique entièrement supprimé.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _ouvrirMateriel(BuildContext context, String? materielId) async {
    if (materielId == null || materielId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce matériel est introuvable (ancienne entrée sans lien).'),
        ),
      );
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('materiels').doc(materielId).get();
    if (!doc.exists) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce matériel a été supprimé depuis.')),
        );
      }
      return;
    }

    final materiel = Materiel.fromFirestore(doc);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ModifierMaterielScreen(materiel: materiel)),
      );
    }
  }

  Future<void> _supprimerUneEntree(BuildContext context, DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette entrée ?'),
        content: const Text('Cette entrée d\'historique sera définitivement supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrée supprimée.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _couleurAction(String action) {
    switch (action) {
      case 'Ajout':
        return Colors.green;
      case 'Modification':
        return Colors.orange;
      case 'Suppression':
        return Colors.red;
      case 'Scan':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _iconeAction(String action) {
    switch (action) {
      case 'Ajout':
        return Icons.add_circle;
      case 'Modification':
        return Icons.edit;
      case 'Suppression':
        return Icons.delete;
      case 'Scan':
        return Icons.qr_code_scanner;
      default:
        return Icons.info;
    }
  }

  Widget _buildHeaderStat(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final selected = _filtreAction == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filtreAction = label),
        selectedColor: const Color(0xFF003087).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF003087),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF003087) : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Historique des mouvements',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Tout supprimer',
            onPressed: _supprimerTout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _historiqueStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF003087)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Aucun historique disponible',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }

          final allDocs = snapshot.data!.docs;

          final totalAjout = allDocs.where((d) => d['action'] == 'Ajout').length;
          final totalModif = allDocs.where((d) => d['action'] == 'Modification').length;
          final totalSuppr = allDocs.where((d) => d['action'] == 'Suppression').length;
          final totalScan = allDocs.where((d) => d['action'] == 'Scan').length;

          var docs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final materiel = (data['materiel'] ?? '').toString().toLowerCase();
            final action = data['action'] ?? '';

            final matchAction = _filtreAction == 'Tous' || action == _filtreAction;
            final matchRecherche = _recherche.isEmpty || materiel.contains(_recherche.toLowerCase());

            return matchAction && matchRecherche;
          }).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF003087), Color(0xFF0052CC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Column(
                    children: [
                      Text('${allDocs.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                      const Text('actions enregistrées',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildHeaderStat('Ajouts', totalAjout, Colors.greenAccent),
                          _buildHeaderStat('Modifs', totalModif, Colors.orangeAccent),
                          _buildHeaderStat('Supprs', totalSuppr, Colors.redAccent),
                          _buildHeaderStat('Scans', totalScan, Colors.purpleAccent),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (v) => setState(() => _recherche = v),
                        decoration: InputDecoration(
                          hintText: 'Rechercher un matériel...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF003087)),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tous'),
                        _buildFilterChip('Ajout'),
                        _buildFilterChip('Modification'),
                        _buildFilterChip('Suppression'),
                        _buildFilterChip('Scan'),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${docs.length} résultat(s)',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text('Appui long pour supprimer',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (docs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('Aucun résultat trouvé',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final action = data['action'] ?? '';
                      final materiel = data['materiel'] ?? '';
                      final utilisateur = data['utilisateur'] ?? '';
                      final details = data['details'] ?? '';
                      final materielId = data['materielId'] as String?;
                      final timestamp = data['date'] as Timestamp?;
                      final date = timestamp != null
                          ? '${timestamp.toDate().day.toString().padLeft(2, '0')}/${timestamp.toDate().month.toString().padLeft(2, '0')}/${timestamp.toDate().year} ${timestamp.toDate().hour.toString().padLeft(2, '0')}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                          : '';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border(left: BorderSide(color: _couleurAction(action), width: 4)),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _ouvrirMateriel(context, materielId),
                          onLongPress: () => _supprimerUneEntree(context, doc),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: _couleurAction(action).withValues(alpha: 0.15),
                                  child: Icon(_iconeAction(action), color: _couleurAction(action), size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _couleurAction(action).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: _couleurAction(action).withValues(alpha: 0.4)),
                                            ),
                                            child: Text(action,
                                                style: TextStyle(
                                                    color: _couleurAction(action),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold)),
                                          ),
                                          Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(materiel,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 13, color: Colors.grey.shade500),
                                          const SizedBox(width: 4),
                                          Text(utilisateur,
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                      if (details.toString().isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(details,
                                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}