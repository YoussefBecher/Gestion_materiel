import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AjouterMaterielScreen extends StatefulWidget {
  final String? numeroSerieInitial;
  const AjouterMaterielScreen({super.key, this.numeroSerieInitial});

  @override
  State<AjouterMaterielScreen> createState() => _AjouterMaterielScreenState();
}

class _AjouterMaterielScreenState extends State<AjouterMaterielScreen> {
  final _marqueController = TextEditingController();
  final _numeroSerieController = TextEditingController();
  final _departementController = TextEditingController();
  final _bureauController = TextEditingController();
  final _typeAutreController = TextEditingController();

  String _type = 'Ordinateur';
  String _etat = 'Disponible';
  bool _isLoading = false;
  DateTime? _datePrise;
  DateTime? _dateRetour;

  String? _employeId;
  String? _employeNom;
  String? _employeMatricule;

  final List<String> _types = [
    'Ordinateur', 'Imprimante', 'Téléphone', 'Serveur', 'Switch', 'Autre'
  ];

  final List<String> _etats = [
    'Disponible', 'En utilisation', 'En panne', 'En maintenance'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.numeroSerieInitial != null) {
      _numeroSerieController.text = widget.numeroSerieInitial!;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPrise) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isPrise) {
          _datePrise = picked;
        } else {
          _dateRetour = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Sélectionner une date';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String get _nomAffichage {
    final marque = _marqueController.text.trim();
    if (marque.isNotEmpty) return '$marque — $_type';
    return _type;
  }

  // ⚠️ Sélection d'employé — je n'ai pas vu le mécanisme exact de ton app.
  // Ceci ouvre un choix simple depuis Firestore. Si tu avais un écran/dialogue
  // spécial pour choisir l'employé, dis-le-moi et je corrigerai cette fonction.
  Future<void> _choisirEmploye() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('employes')
        .orderBy('nom')
        .get();

    if (!mounted) return;

    final selection = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: snapshot.docs.map((doc) {
          final data = doc.data();
          final nom = '${data['nom'] ?? ''} ${data['prenom'] ?? ''}';
          return ListTile(
            title: Text(nom),
            subtitle: Text(data['matricule'] ?? ''),
            onTap: () => Navigator.pop(ctx, {
              'id': doc.id,
              'nom': nom,
              'matricule': data['matricule'] ?? '',
            }),
          );
        }).toList(),
      ),
    );

    if (selection != null) {
      setState(() {
        _employeId = selection['id'];
        _employeNom = selection['nom'];
        _employeMatricule = selection['matricule'];
      });
    }
  }

  Future<void> _sauvegarder() async {
    final typeFinal = _type == 'Autre'
        ? _typeAutreController.text.trim()
        : _type;

    if (_type == 'Autre' && typeFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez préciser le type de matériel.')),
      );
      return;
    }

    if (_numeroSerieController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez remplir le numéro de série.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = await FirebaseFirestore.instance.collection('materiels').add({
        'marque': _marqueController.text.trim(),
        'type': typeFinal,
        'numeroSerie': _numeroSerieController.text.trim(),
        'etat': _etat,
        'agence': 'Siège BIAT',
        'departement': _departementController.text.trim(),
        'bureau': _bureauController.text.trim(),
        'responsable': _employeNom ?? '',
        'employeId': _employeId ?? '',
        'employeMatricule': _employeMatricule ?? '',
        'datePrise': _datePrise != null ? Timestamp.fromDate(_datePrise!) : null,
        'dateRetour': _dateRetour != null ? Timestamp.fromDate(_dateRetour!) : null,
        'dateAjout': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('historique').add({
        'action': 'Ajout',
        'materielId': docRef.id,
        'materiel': _nomAffichage,
        'utilisateur': 'admin@gestion.com',
        'date': FieldValue.serverTimestamp(),
        'details': 'Type: $typeFinal | N°série: ${_numeroSerieController.text.trim()}',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matériel ajouté avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'ajout.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: const Text('Ajouter un matériel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.numeroSerieInitial != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'QR Code scanné : ${widget.numeroSerieInitial}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            _buildCard('Informations générales', [
              _buildTextField(_marqueController, 'Marque', Icons.branding_watermark),
              const SizedBox(height: 12),
              _buildDropdown('Type', _type, _types,
                      (val) => setState(() => _type = val!)),
              if (_type == 'Autre') ...[
                const SizedBox(height: 12),
                _buildTextField(_typeAutreController, 'Précisez le type', Icons.edit),
              ],
              const SizedBox(height: 12),
              _buildTextField(_numeroSerieController, 'Numéro de série', Icons.tag),
              const SizedBox(height: 12),
              _buildDropdown('État', _etat, _etats,
                      (val) => setState(() => _etat = val!)),
            ]),
            const SizedBox(height: 16),
            _buildCard('Localisation — Siège BIAT', [
              _buildTextField(_departementController, 'Département', Icons.apartment),
              const SizedBox(height: 12),
              _buildTextField(_bureauController, 'Bureau', Icons.room),
            ]),
            const SizedBox(height: 16),
            _buildCard('Période d\'utilisation', [
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de prise',
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF003087)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(_formatDate(_datePrise)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _selectDate(context, false),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de retour prévue',
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF003087)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(_formatDate(_dateRetour)),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildCard('Employé responsable', [
              InkWell(
                onTap: _choisirEmploye,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Sélectionner un employé',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF003087)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(_employeNom ?? 'Sélectionner un employé'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sauvegarder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003087),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Ajouter le matériel',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF003087)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}