import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'employe_form_screen.dart';
import 'employe_detail_screen.dart';

class EmployesListScreen extends StatefulWidget {
  const EmployesListScreen({super.key});

  @override
  State<EmployesListScreen> createState() => _EmployesListScreenState();
}

class _EmployesListScreenState extends State<EmployesListScreen> {
  String _recherche = '';

  Future<void> _supprimer(DocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cet employé ?'),
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
      await FirebaseFirestore.instance
          .collection('employes')
          .doc(doc.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Employé supprimé'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: const Text('Employés',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeFormScreen()),
        ),
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: const Color(0xFF003087),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un employé...',
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
          ),

          // Liste
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('employes')
                  .orderBy('nom')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF003087)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucun employé trouvé',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nom = (data['nom'] ?? '').toLowerCase();
                  final prenom = (data['prenom'] ?? '').toLowerCase();
                  final matricule = (data['matricule'] ?? '').toLowerCase();
                  final departement = (data['departement'] ?? '').toLowerCase();
                  return nom.contains(_recherche) ||
                      prenom.contains(_recherche) ||
                      matricule.contains(_recherche) ||
                      departement.contains(_recherche);
                }).toList();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final nom = data['nom'] ?? '';
                    final prenom = data['prenom'] ?? '';
                    final poste = data['poste'] ?? '';
                    final departement = data['departement'] ?? '';
                    final matricule = data['matricule'] ?? '';
                    final email = data['email'] ?? '';
                    final telephone = data['telephone'] ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmployeDetailScreen(employe: docs[index]),
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          backgroundColor:
                          const Color(0xFF003087).withValues(alpha: 0.1),
                          radius: 28,
                          child: Text(
                            '${nom.isNotEmpty ? nom[0] : ''}${prenom.isNotEmpty ? prenom[0] : ''}',
                            style: const TextStyle(
                              color: Color(0xFF003087),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        title: Text(
                          '$nom $prenom',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('📋 $poste — $departement',
                                style: const TextStyle(fontSize: 12)),
                            Text('🪪 $matricule',
                                style: const TextStyle(fontSize: 12)),
                            Text('📧 $email',
                                style: const TextStyle(fontSize: 12)),
                            Text('📞 $telephone',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Modifier
                            IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Color(0xFF3498DB)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EmployeFormScreen(
                                      employe: docs[index]),
                                ),
                              ),
                            ),
                            // Supprimer
                            IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Color(0xFFE74C3C)),
                              onPressed: () => _supprimer(docs[index]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}