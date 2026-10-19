import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/materiel.dart';
import '../../services/materiel_service.dart';

class ModifierMaterielScreen extends StatefulWidget {
  final Materiel materiel;

  const ModifierMaterielScreen({
    super.key,
    required this.materiel,
  });

  @override
  State<ModifierMaterielScreen> createState() => _ModifierMaterielScreenState();
}

class _ModifierMaterielScreenState extends State<ModifierMaterielScreen> {
  final _service = MaterielService();

  late TextEditingController _marqueController;
  late TextEditingController _numeroSerieController;
  late TextEditingController _departementController;
  late TextEditingController _bureauController;
  late TextEditingController _responsableController;
  late TextEditingController _typeAutreController;

  late String _type;
  late String _etat;
  bool _isLoading = false;
  bool _isLoadingPosition = false;
  GeoPoint? _position;

  final List<String> _types = [
    'Ordinateur', 'Imprimante', 'Téléphone', 'Serveur', 'Switch', 'Autre'
  ];

  final List<String> _etats = [
    'Disponible', 'En utilisation', 'En panne', 'En maintenance'
  ];

  @override
  void initState() {
    super.initState();
    final m = widget.materiel;
    _marqueController = TextEditingController(text: m.marque);
    _numeroSerieController = TextEditingController(text: m.numeroSerie);
    _departementController = TextEditingController(text: m.departement);
    _bureauController = TextEditingController(text: m.bureau);
    _responsableController = TextEditingController(text: m.responsable);
    _typeAutreController = TextEditingController();

    // Si le type existant n'est pas dans la liste prédéfinie,
    // on bascule sur "Autre" et on pré-remplit le champ personnalisé.
    if (_types.contains(m.type)) {
      _type = m.type;
    } else {
      _type = 'Autre';
      _typeAutreController.text = m.type;
    }

    _etat = _etats.contains(m.etat) ? m.etat : 'Disponible';
    _position = m.position;
  }

  Future<void> _mettreAJourPosition() async {
    setState(() => _isLoadingPosition = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez activer la localisation sur votre téléphone.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permission de localisation refusée.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission de localisation refusée définitivement. Activez-la dans les paramètres.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final geoPoint = GeoPoint(position.latitude, position.longitude);

      await FirebaseFirestore.instance
          .collection('materiels')
          .doc(widget.materiel.id)
          .update({'position': geoPoint});

      setState(() => _position = geoPoint);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Position mise à jour avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de localisation : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPosition = false);
    }
  }

  Future<void> _sauvegarder() async {
    if (_numeroSerieController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir le numéro de série.')),
      );
      return;
    }

    // Si "Autre" est sélectionné, le champ personnalisé devient le vrai type.
    final typeFinal = _type == 'Autre'
        ? _typeAutreController.text.trim()
        : _type;

    if (_type == 'Autre' && typeFinal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez préciser le type de matériel.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final materielModifie = widget.materiel.copyWith(
        type: typeFinal,
        numeroSerie: _numeroSerieController.text.trim(),
        etat: _etat,
        departement: _departementController.text.trim(),
        bureau: _bureauController.text.trim(),
        responsable: _responsableController.text.trim(),
        marque: _marqueController.text.trim(),
        position: _position,
      );

      await _service.modifierMateriel(widget.materiel.id, materielModifie);

      await FirebaseFirestore.instance.collection('historique').add({
        'action': 'Modification',
        'materiel': materielModifie.displayName,
        'utilisateur': 'admin@gestion.com',
        'date': FieldValue.serverTimestamp(),
        'details': 'N°série: ${materielModifie.numeroSerie}',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matériel modifié avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la modification : $e')),
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
        title: const Text('Modifier le matériel'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard('Informations générales', [
              _buildTextField(_marqueController, 'Marque', Icons.branding_watermark),
              const SizedBox(height: 12),
              _buildDropdown('Type', _type, _types, (val) {
                setState(() => _type = val!);
              }),
              if (_type == 'Autre') ...[
                const SizedBox(height: 12),
                _buildTextField(_typeAutreController, 'Précisez le type', Icons.edit),
              ],
              const SizedBox(height: 12),
              _buildTextField(_numeroSerieController, 'Numéro de série', Icons.tag),
              const SizedBox(height: 12),
              _buildDropdown('État', _etat, _etats, (val) => setState(() => _etat = val!)),
            ]),
            const SizedBox(height: 16),
            _buildCard('Localisation — Siège BIAT', [
              _buildTextField(_departementController, 'Département', Icons.apartment),
              const SizedBox(height: 12),
              _buildTextField(_bureauController, 'Bureau', Icons.room),
              const SizedBox(height: 12),
              _buildTextField(_responsableController, 'Responsable', Icons.person),
            ]),
            const SizedBox(height: 16),
            _buildCard('Position GPS', [
              if (_position != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Position actuelle : ${_position!.latitude.toStringAsFixed(5)}, ${_position!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Aucune position enregistrée',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoadingPosition ? null : _mettreAJourPosition,
                  icon: _isLoadingPosition
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.location_on),
                  label: Text(_isLoadingPosition
                      ? 'Localisation en cours...'
                      : 'Mettre à jour la position'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF003087),
                    side: const BorderSide(color: Color(0xFF003087)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Enregistrer les modifications',
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
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003087))),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon) {
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

  Widget _buildDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
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