import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeFormScreen extends StatefulWidget {
  final DocumentSnapshot? employe;
  const EmployeFormScreen({super.key, this.employe});

  @override
  State<EmployeFormScreen> createState() => _EmployeFormScreenState();
}

class _EmployeFormScreenState extends State<EmployeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _departementController = TextEditingController();
  final _posteController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.employe != null) {
      final data = widget.employe!.data() as Map<String, dynamic>;
      _nomController.text = data['nom'] ?? '';
      _prenomController.text = data['prenom'] ?? '';
      _matriculeController.text = data['matricule'] ?? '';
      _departementController.text = data['departement'] ?? '';
      _posteController.text = data['poste'] ?? '';
      _telephoneController.text = data['telephone'] ?? '';
      _emailController.text = data['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _matriculeController.dispose();
    _departementController.dispose();
    _posteController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sauvegarder() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      'nom': _nomController.text.trim(),
      'prenom': _prenomController.text.trim(),
      'matricule': _matriculeController.text.trim(),
      'departement': _departementController.text.trim(),
      'poste': _posteController.text.trim(),
      'telephone': _telephoneController.text.trim(),
      'email': _emailController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      if (widget.employe == null) {
        // Créer
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('employes').add(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employé ajouté avec succès !'),
              backgroundColor: Color(0xFF2ECC71),
            ),
          );
        }
      } else {
        // Modifier
        await FirebaseFirestore.instance
            .collection('employes')
            .doc(widget.employe!.id)
            .update(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Employé modifié avec succès !'),
              backgroundColor: Color(0xFF3498DB),
            ),
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Widget _buildField(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text, bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF003087), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: required
            ? (v) => (v == null || v.isEmpty) ? 'Champ obligatoire' : null
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employe != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        title: Text(
          isEdit ? 'Modifier employé' : 'Ajouter un employé',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // En-tête
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF003087), Color(0xFF0055B3)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? 'Modifier les informations' : 'Nouvel employé BIAT',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              _buildField('Nom', _nomController),
              _buildField('Prénom', _prenomController),
              _buildField('Matricule', _matriculeController),
              _buildField('Département', _departementController),
              _buildField('Poste', _posteController),
              _buildField('Téléphone', _telephoneController,
                  type: TextInputType.phone),
              _buildField('Email', _emailController,
                  type: TextInputType.emailAddress),

              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sauvegarder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003087),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    isEdit ? 'Enregistrer les modifications' : 'Ajouter l\'employé',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}