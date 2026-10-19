import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/materiel.dart';
import '../../services/materiel_service.dart';
import 'ajouter_materiel_screen.dart';
import 'modifier_materiel_screen.dart';

class ListeMaterielsScreen extends StatefulWidget {
  const ListeMaterielsScreen({super.key});

  @override
  State<ListeMaterielsScreen> createState() => _ListeMaterielsScreenState();
}

class _ListeMaterielsScreenState extends State<ListeMaterielsScreen> {
  final _service = MaterielService();
  String _recherche = '';
  String _filtreEtat = 'Tous';
  String _filtreType = 'Tous';

  final List<String> _etats = ['Tous', 'Disponible', 'En utilisation', 'En panne', 'En maintenance'];
  final List<String> _types = ['Tous', 'Ordinateur', 'Imprimante', 'Téléphone', 'Serveur', 'Switch', 'Autre'];

  Widget _buildSearchAndFilters() {
    return Container(
      color: const Color(0xFF003087),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filtreEtat,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _etats.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _filtreEtat = val!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filtreType,
                  dropdownColor: Colors.white,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: _types.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) => setState(() => _filtreType = val!),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
        ],
      ),
    );
  }

  Color _couleurEtat(String etat) {
    switch (etat) {
      case 'Disponible':
        return Colors.green;
      case 'En utilisation':
        return Colors.orange;
      case 'En panne':
        return Colors.red;
      case 'En maintenance':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12.5)),
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
    );
  }

  Widget _buildMaterielCard(BuildContext context, Materiel materiel) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(materiel.displayName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _couleurEtat(materiel.etat).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _couleurEtat(materiel.etat).withValues(alpha: 0.4)),
                  ),
                  child: Text(materiel.etat,
                      style: TextStyle(color: _couleurEtat(materiel.etat), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('N°série: ${materiel.numeroSerie}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (materiel.responsable.isNotEmpty)
              Text('Responsable: ${materiel.responsable}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.qr_code,
                  label: 'QR',
                  color: Colors.blueGrey,
                  onTap: () => _showQrDialog(context, materiel),
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Modifier',
                  color: const Color(0xFF3498DB),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ModifierMaterielScreen(materiel: materiel)),
                  ),
                ),
                _buildActionButton(
                  icon: Icons.delete,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () => _confirmerSuppression(context, materiel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context, Materiel materiel) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(materiel.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: materiel.id, version: QrVersions.auto, size: 200),
            const SizedBox(height: 8),
            Text('ID: ${materiel.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Future<void> _supprimerTousLesMateriels() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer TOUT le matériel ?'),
        content: const Text(
          'Cette action supprimera définitivement tous les équipements enregistrés. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tout supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final snapshot = await FirebaseFirestore.instance.collection('materiels').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    await FirebaseFirestore.instance.collection('historique').add({
      'action': 'Suppression',
      'materiel': 'Tous les équipements',
      'utilisateur': 'admin@gestion.com',
      'date': FieldValue.serverTimestamp(),
      'details': 'Suppression totale du parc matériel',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tous les matériels ont été supprimés.'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmerSuppression(BuildContext context, Materiel materiel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous supprimer "${materiel.displayName}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _service.supprimerMateriel(materiel.id);

      await FirebaseFirestore.instance.collection('historique').add({
        'action': 'Suppression',
        'materielId': materiel.id,
        'materiel': materiel.displayName,
        'utilisateur': 'admin@gestion.com',
        'date': FieldValue.serverTimestamp(),
        'details': 'N°série: ${materiel.numeroSerie}',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matériel supprimé !'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Liste des matériels', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AjouterMaterielScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Tout supprimer',
            onPressed: _supprimerTousLesMateriels,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: StreamBuilder<List<Materiel>>(
              stream: _service.streamMateriels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF003087)));
                }

                final tous = snapshot.data ?? [];

                if (tous.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.computer_outlined,
                    message: 'Aucun matériel enregistré',
                  );
                }

                final filtres = tous.where((m) {
                  final recherche = _recherche.toLowerCase();
                  final matchRecherche = recherche.isEmpty ||
                      m.displayName.toLowerCase().contains(recherche) ||
                      m.numeroSerie.toLowerCase().contains(recherche) ||
                      m.responsable.toLowerCase().contains(recherche);

                  final matchEtat = _filtreEtat == 'Tous' || m.etat == _filtreEtat;
                  final matchType = _filtreType == 'Tous' || m.type == _filtreType;

                  return matchRecherche && matchEtat && matchType;
                }).toList();

                if (filtres.isEmpty) {
                  return _buildEmptyState(
                    icon: Icons.search_off_rounded,
                    message: 'Aucun résultat trouvé',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtres.length,
                  itemBuilder: (context, index) => _buildMaterielCard(context, filtres[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}