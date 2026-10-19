import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/materiel.dart';
import '../../models/localisation_interieure.dart';
import '../../services/materiel_service.dart';
import '../../utils/etat_utils.dart';

/// Définition graphique d'une zone du plan.
class _ZoneDef {
  final String titre;
  final String bureau;
  final double left;
  final double top;
  final double width;
  final double height;

  const _ZoneDef(
      this.titre,
      this.bureau,
      this.left,
      this.top,
      this.width,
      this.height,
      );
}

/// Point d'un trajet provenant de Firestore.
class _PointTrajet {
  final double x;
  final double y;
  final DateTime? date;
  final String zone;
  final String etage;
  final String details;

  const _PointTrajet({
    required this.x,
    required this.y,
    this.date,
    this.zone = '',
    this.etage = '',
    this.details = '',
  });
}

/// Plan d'étage avec localisation Wi-Fi et trajectoire.
class PlanEtageScreen extends StatefulWidget {
  final int etage;
  final String titreEtage;

  const PlanEtageScreen({
    super.key,
    this.etage = 2,
    this.titreEtage = '2ème étage',
  });

  @override
  State<PlanEtageScreen> createState() => _PlanEtageScreenState();
}

class _PlanEtageScreenState extends State<PlanEtageScreen> {
  static const double _planWidth = 800;
  static const double _planHeight = 600;

  final MaterielService _materielService = MaterielService();

  String? _materielSelectionneId;

  // ============================================================
  // ZONES ÉTAGE 2
  // ============================================================

  static const List<_ZoneDef> _zonesEtage2 = [
    _ZoneDef('Bureau 243', '243', 20, 20, 110, 130),
    _ZoneDef('Espace Ouvert 244A', '244A', 140, 20, 140, 130),
    _ZoneDef('Cage escalier A', 'Cage esc. A', 290, 20, 60, 130),
    _ZoneDef('Bureau 245', '245', 360, 20, 90, 130),
    _ZoneDef('Archive 260A', '260A', 460, 20, 90, 130),
    _ZoneDef('Salle Réunion 251', '251', 560, 20, 130, 130),
    _ZoneDef('Bureau 252', '252', 700, 20, 90, 130),

    _ZoneDef('Bureau 242', '242', 20, 170, 110, 100),
    _ZoneDef('Bureau 220', '220', 20, 290, 110, 100),
    _ZoneDef('Bureau 221', '221', 20, 400, 110, 100),

    _ZoneDef('Sanitaires', 'Sanitaires', 140, 290, 90, 100),
    _ZoneDef('Salle Réunion 215', '215', 240, 290, 170, 210),

    _ZoneDef('Bureau 213A', '213A', 420, 290, 90, 100),
    _ZoneDef('Bureau 209', '209', 520, 290, 90, 100),
    _ZoneDef('Bureau 207', '207', 620, 290, 90, 100),

    _ZoneDef('Cage escalier B', 'Cage esc. B', 700, 290, 90, 210),

    _ZoneDef('Bureau 223', '223', 20, 500, 80, 90),
    _ZoneDef('Bureau 222', '222', 110, 500, 80, 90),
    _ZoneDef('Bureau 217', '217', 200, 500, 80, 90),
    _ZoneDef('Bureau 216', '216', 290, 500, 80, 90),
    _ZoneDef('Bureau 212', '212', 380, 500, 80, 90),
    _ZoneDef('Bureau 211', '211', 470, 500, 80, 90),
    _ZoneDef('Bureau 208', '208', 560, 500, 80, 90),
    _ZoneDef('Bureau 206', '206', 650, 500, 80, 90),
  ];

  // ============================================================
  // ZONES ÉTAGE 1
  // ============================================================

  static const List<_ZoneDef> _zonesEtage1 = [
    _ZoneDef('Bureau 101', '101', 20, 20, 180, 120),
    _ZoneDef('Bureau 102', '102', 220, 20, 180, 120),
    _ZoneDef('Bureau 103', '103', 420, 20, 180, 120),
    _ZoneDef('Bureau 104', '104', 20, 180, 180, 120),
    _ZoneDef('Open Space IT', 'Open Space IT', 220, 180, 380, 120),
    _ZoneDef('Salle de réunion', 'Salle de réunion', 20, 340, 380, 150),
    _ZoneDef('Salle serveur', 'Salle serveur', 420, 340, 180, 150),
  ];

  // ============================================================
  // ZONES RDC
  // ============================================================

  static const List<_ZoneDef> _zonesRDC = [
    _ZoneDef('Accueil', 'Accueil', 20, 20, 180, 120),
    _ZoneDef('Salle d\'attente', 'Salle d\'attente', 220, 20, 380, 120),
    _ZoneDef('Bureau 001', '001', 420, 20, 180, 120),
  ];

  List<_ZoneDef> get _zones {
    switch (widget.etage) {
      case 0:
        return _zonesRDC;
      case 1:
        return _zonesEtage1;
      case 2:
        return _zonesEtage2;
      default:
        return _zonesEtage2;
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.map_rounded, size: 21),
            const SizedBox(width: 9),
            Text(
              'Localisation — ${widget.titreEtage}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildLegende(),
          Expanded(
            child: StreamBuilder<List<Materiel>>(
              stream: _materielService.streamMateriels(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFF003087),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chargement de la localisation...',
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _buildErreur(snapshot.error);
                }

                final materiels = snapshot.data ?? [];

                return _buildContenu(
                  context,
                  materiels,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTENU
  // ============================================================

  Widget _buildContenu(
      BuildContext context,
      List<Materiel> tousLesMateriels,
      ) {
    final materielsEtage = tousLesMateriels.where((materiel) {
      final localisation = materiel.localisationInterieure;

      if (localisation == null) {
        return false;
      }

      if (localisation.zone.trim().isEmpty) {
        return false;
      }

      return _memeEtage(localisation.etage);
    }).toList();

    Materiel? materielSelectionne;

    for (final materiel in materielsEtage) {
      if (materiel.id == _materielSelectionneId) {
        materielSelectionne = materiel;
        break;
      }
    }

    return Column(
      children: [
        _buildBarreEtat(
          tousLesMateriels.length,
          materielsEtage.length,
          materielSelectionne,
        ),
        Expanded(
          child: _buildPlan(
            context,
            materielsEtage,
            materielSelectionne,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BARRE D'ÉTAT
  // ============================================================

  Widget _buildBarreEtat(
      int total,
      int localises,
      Materiel? materielSelectionne,
      ) {
    final bool enMouvement = materielSelectionne != null &&
        _estEnMouvement(materielSelectionne);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _statutItem(
            Icons.inventory_2_outlined,
            '$localises localisé(s)',
          ),
          _statutItem(
            Icons.devices_other,
            '$total matériel(s)',
          ),
          if (materielSelectionne != null)
            _statutItem(
              Icons.touch_app_outlined,
              materielSelectionne.displayName,
            ),
          if (enMouvement)
            _statutItem(
              Icons.directions_walk,
              'En déplacement',
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _statutItem(
      IconData icon,
      String texte, {
        Color color = const Color(0xFF003087),
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          texte,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PLAN
  // ============================================================

  Widget _buildPlan(
      BuildContext context,
      List<Materiel> materiels,
      Materiel? materielSelectionne,
      ) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(100),
      child: SizedBox(
        width: _planWidth,
        height: _planHeight,
        child: Stack(
          children: [
            Container(
              width: _planWidth,
              height: _planHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 3),
                    color: Colors.black12,
                  ),
                ],
              ),
            ),

            _buildGrid(),

            for (final zone in _zones)
              Positioned(
                left: zone.left,
                top: zone.top,
                child: _buildZone(
                  context,
                  zone,
                  materiels,
                ),
              ),

            if (materielSelectionne != null)
              _buildTrajet(materielSelectionne),

            for (final materiel in materiels)
              _buildMaterielMarker(
                context,
                materiel,
                selected:
                materiel.id == _materielSelectionneId,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GRILLE
  // ============================================================

  Widget _buildGrid() {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GridPainter(),
        ),
      ),
    );
  }

  // ============================================================
  // TRAJET
  // ============================================================

  Widget _buildTrajet(Materiel materiel) {
    final localisation = materiel.localisationInterieure;

    if (localisation == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<_PointTrajet>>(
      stream: _streamTrajet(materiel.id),
      builder: (context, snapshot) {
        final historique = snapshot.data ?? [];

        final points = <_PointTrajet>[
          ...historique,
        ];

        final pointActuel = _PointTrajet(
          x: localisation.positionX.clamp(0.0, 1.0),
          y: localisation.positionY.clamp(0.0, 1.0),
          date: localisation.derniereMiseAJour,
          zone: localisation.zone,
          etage: localisation.etage,
        );

        if (points.isEmpty ||
            !_memePosition(points.last, pointActuel)) {
          points.add(pointActuel);
        }

        final pointsDistincts = _supprimerDoublons(points);

        if (pointsDistincts.length < 2) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _TrajetPainter(
                points: pointsDistincts,
                width: _planWidth,
                height: _planHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HISTORIQUE TRAJET
  // ============================================================

  Stream<List<_PointTrajet>> _streamTrajet(
      String materielId,
      ) {
    return FirebaseFirestore.instance
        .collection('historique')
        .where(
      'materielId',
      isEqualTo: materielId,
    )
        .limit(100)
        .snapshots()
        .map((snapshot) {
      final points = <_PointTrajet>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final position = _extrairePosition(data);

        if (position == null) {
          continue;
        }

        final String etage =
        _extraireEtage(data);

        // Important :
        // On ne dessine que les points appartenant
        // à l'étage actuellement affiché.
        if (!_memeEtageHistorique(etage)) {
          continue;
        }

        final date = _extraireDate(data);

        final zone =
            data['zone']?.toString() ??
                data['zoneName']?.toString() ??
                '';

        final details =
            data['details']?.toString() ?? '';

        points.add(
          _PointTrajet(
            x: position.dx,
            y: position.dy,
            date: date,
            zone: zone,
            etage: etage,
            details: details,
          ),
        );
      }

      points.sort((a, b) {
        if (a.date == null && b.date == null) {
          return 0;
        }

        if (a.date == null) {
          return -1;
        }

        if (b.date == null) {
          return 1;
        }

        return a.date!.compareTo(b.date!);
      });

      return _supprimerDoublons(points);
    });
  }

  List<_PointTrajet> _supprimerDoublons(
      List<_PointTrajet> points,
      ) {
    if (points.isEmpty) {
      return [];
    }

    final resultat = <_PointTrajet>[
      points.first,
    ];

    for (int i = 1; i < points.length; i++) {
      if (!_memePosition(resultat.last, points[i])) {
        resultat.add(points[i]);
      }
    }

    return resultat;
  }

  bool _memePosition(
      _PointTrajet a,
      _PointTrajet b,
      ) {
    const tolerance = 0.0001;

    return (a.x - b.x).abs() < tolerance &&
        (a.y - b.y).abs() < tolerance;
  }

  String _extraireEtage(
      Map<String, dynamic> data,
      ) {
    dynamic value = data['etage'];

    if (value == null) {
      final localisation =
      data['localisationInterieure'];

      if (localisation is Map) {
        value = localisation['etage'];
      }
    }

    return value?.toString() ?? '';
  }

  bool _memeEtageHistorique(String valeur) {
    final v = valeur.trim().toLowerCase();

    if (v.isEmpty) {
      return false;
    }

    if (widget.etage == 0) {
      return v == '0' ||
          v == 'rdc' ||
          v.contains('rez');
    }

    if (widget.etage == 1) {
      return v == '1' ||
          v == '1er' ||
          v.contains('étage 1') ||
          v.contains('etage 1');
    }

    if (widget.etage == 2) {
      return v == '2' ||
          v == '2ème' ||
          v == '2eme' ||
          v.contains('étage 2') ||
          v.contains('etage 2');
    }

    return v == widget.etage.toString();
  }

  Offset? _extrairePosition(
      Map<String, dynamic> data,
      ) {
    dynamic x = data['positionX'];
    dynamic y = data['positionY'];

    if (x == null || y == null) {
      x = data['x'];
      y = data['y'];
    }

    if (x == null || y == null) {
      final localisation =
      data['localisationInterieure'];

      if (localisation is Map) {
        x = localisation['positionX'] ??
            localisation['x'];

        y = localisation['positionY'] ??
            localisation['y'];
      }
    }

    final double? dx = _toDouble(x);
    final double? dy = _toDouble(y);

    if (dx == null || dy == null) {
      return null;
    }

    if (dx < 0 ||
        dx > 1 ||
        dy < 0 ||
        dy > 1) {
      return null;
    }

    return Offset(dx, dy);
  }

  DateTime? _extraireDate(
      Map<String, dynamic> data,
      ) {
    final dynamic value =
        data['date'] ??
            data['timestamp'] ??
            data['createdAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // MARQUEUR
  // ============================================================

  Widget _buildMaterielMarker(
      BuildContext context,
      Materiel materiel, {
        bool selected = false,
      }) {
    final localisation =
        materiel.localisationInterieure;

    if (localisation == null) {
      return const SizedBox.shrink();
    }

    if (!_memeEtage(localisation.etage)) {
      return const SizedBox.shrink();
    }

    final double x =
        localisation.positionX.clamp(0.0, 1.0) *
            _planWidth;

    final double y =
        localisation.positionY.clamp(0.0, 1.0) *
            _planHeight;

    final Color couleur =
    EtatUtils.couleur(materiel.etat);

    final bool enDeplacement =
        localisation.statut ==
            StatutDeplacement.enMouvement;

    final bool estHorsLigne =
        localisation.statut ==
            StatutDeplacement.horsLigne;

    return Positioned(
      left: x - 20,
      top: y - 20,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_materielSelectionneId ==
                materiel.id) {
              _materielSelectionneId = null;
            } else {
              _materielSelectionneId =
                  materiel.id;
            }
          });
        },
        onLongPress: () {
          _afficherMateriel(
            context,
            materiel,
          );
        },
        child: Tooltip(
          message:
          '${materiel.displayName}\n'
              '${localisation.zone}',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration:
                    const Duration(
                      milliseconds: 250,
                    ),
                    width:
                    selected ? 42 : 36,
                    height:
                    selected ? 42 : 36,
                    decoration: BoxDecoration(
                      color: couleur,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width:
                        selected ? 4 : 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius:
                          selected ? 14 : 6,
                          spreadRadius:
                          selected ? 3 : 0,
                          offset:
                          const Offset(0, 3),
                          color:
                          couleur.withValues(
                            alpha:
                            selected
                                ? 0.35
                                : 0.20,
                          ),
                        ),
                      ],
                    ),
                    child: Icon(
                      _iconeMateriel(
                        materiel.type,
                      ),
                      color: Colors.white,
                      size:
                      selected ? 21 : 19,
                    ),
                  ),

                  if (enDeplacement)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration:
                        const BoxDecoration(
                          color:
                          Colors.orange,
                          shape:
                          BoxShape.circle,
                        ),
                        child:
                        const Icon(
                          Icons
                              .directions_walk,
                          color:
                          Colors.white,
                          size: 10,
                        ),
                      ),
                    ),

                  if (estHorsLigne)
                    Positioned(
                      right: -5,
                      bottom: -3,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration:
                        const BoxDecoration(
                          color: Colors.red,
                          shape:
                          BoxShape.circle,
                        ),
                        child:
                        const Icon(
                          Icons.wifi_off,
                          color:
                          Colors.white,
                          size: 9,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 3),

              Container(
                constraints:
                const BoxConstraints(
                  maxWidth: 120,
                ),
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(
                    0xFF003087,
                  )
                      : Colors.white,
                  borderRadius:
                  BorderRadius.circular(5),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 4,
                      color: Colors.black12,
                    ),
                  ],
                ),
                child: Text(
                  materiel.displayName,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                    FontWeight.w700,
                    color: selected
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ZONE
  // ============================================================

  Widget _buildZone(
      BuildContext context,
      _ZoneDef zone,
      List<Materiel> materiels,
      ) {
    final materielsZone =
    materiels.where((m) {
      final localisation =
          m.localisationInterieure;

      if (localisation == null) {
        return false;
      }

      final valeur =
      localisation.zone.trim();

      return valeur == zone.bureau ||
          valeur == zone.titre;
    }).toList();

    return GestureDetector(
      onTap: () {
        _afficherDetailsZone(
          context,
          zone.titre,
          materielsZone,
        );
      },
      child: Container(
        width: zone.width,
        height: zone.height,
        decoration: BoxDecoration(
          color:
          _couleurZone(materielsZone),
          border: Border.all(
            color: Colors.grey.shade500,
            width: 1.5,
          ),
          borderRadius:
          BorderRadius.circular(6),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                zone.titre,
                textAlign:
                TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
              if (materielsZone.isNotEmpty) ...[
                const SizedBox(height: 5),
                Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    Colors.black.withValues(
                      alpha: 0.06,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: Text(
                    '${materielsZone.length} matériel(s)',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                      Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILTRE ÉTAGE
  // ============================================================

  bool _memeEtage(String valeur) {
    final String v =
    valeur.trim().toLowerCase();

    if (widget.etage == 0) {
      return v == '0' ||
          v == 'rdc' ||
          v.contains('rez');
    }

    if (widget.etage == 1) {
      return v == '1' ||
          v == '1er' ||
          v.contains('étage 1') ||
          v.contains('etage 1');
    }

    if (widget.etage == 2) {
      return v == '2' ||
          v == '2ème' ||
          v == '2eme' ||
          v.contains('étage 2') ||
          v.contains('etage 2');
    }

    return v == widget.etage.toString();
  }

  // ============================================================
  // STATUT
  // ============================================================

  bool _estEnMouvement(
      Materiel materiel,
      ) {
    final localisation =
        materiel.localisationInterieure;

    if (localisation == null) {
      return false;
    }

    return localisation.statut ==
        StatutDeplacement.enMouvement;
  }

  // ============================================================
  // COULEUR ZONE
  // ============================================================

  Color _couleurZone(
      List<Materiel> materiels,
      ) {
    if (materiels.isEmpty) {
      return Colors.white;
    }

    const ordre = [
      'En panne',
      'En maintenance',
      'En utilisation',
      'Disponible',
    ];

    for (final etat in ordre) {
      if (materiels.any(
            (m) => m.etat == etat,
      )) {
        return EtatUtils.couleur(etat)
            .withValues(alpha: 0.13);
      }
    }

    return Colors.blue.shade50;
  }

  // ============================================================
  // LÉGENDE
  // ============================================================

  Widget _buildLegende() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Wrap(
        spacing: 17,
        runSpacing: 8,
        children: [
          _legendeItem(
            Colors.grey,
            'Disponible',
          ),
          _legendeItem(
            Colors.orange,
            'En utilisation',
          ),
          _legendeItem(
            Colors.red,
            'En panne',
          ),
          _legendeItem(
            Colors.blue,
            'En maintenance',
          ),
          _legendeItem(
            Colors.orange.shade700,
            'Déplacement',
            icone:
            Icons.directions_walk,
          ),
          _legendeItem(
            Colors.blue.shade700,
            'Trajet',
            icone: Icons.route,
          ),
        ],
      ),
    );
  }

  Widget _legendeItem(
      Color color,
      String label, {
        IconData? icone,
      }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: icone != null
              ? Icon(
            icone,
            color: Colors.white,
            size: 10,
          )
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color:
            Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ICÔNE MATÉRIEL
  // ============================================================

  IconData _iconeMateriel(
      String type,
      ) {
    final t = type.toLowerCase();

    if (t.contains('ordinateur') ||
        t.contains('pc') ||
        t.contains('laptop')) {
      return Icons.laptop_mac;
    }

    if (t.contains('imprim')) {
      return Icons.print;
    }

    if (t.contains('serveur')) {
      return Icons.dns;
    }

    if (t.contains('switch') ||
        t.contains('réseau') ||
        t.contains('reseau')) {
      return Icons.hub;
    }

    if (t.contains('téléphone') ||
        t.contains('telephone') ||
        t.contains('mobile')) {
      return Icons.smartphone;
    }

    return Icons.devices;
  }

  // ============================================================
  // DÉTAILS ZONE
  // ============================================================

  void _afficherDetailsZone(
      BuildContext context,
      String titre,
      List<Materiel> materiels,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.location_on,
                color:
                Color(0xFF003087),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(titre),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: materiels.isEmpty
                ? Padding(
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 20,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .inbox_outlined,
                    size: 40,
                    color: Colors
                        .grey.shade400,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    'Aucun matériel localisé dans cette zone.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      color: Colors
                          .grey.shade600,
                    ),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: materiels
                    .map(
                  _materielCard,
                )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
              const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _materielCard(
      Materiel materiel,
      ) {
    final color =
    EtatUtils.couleur(
      materiel.etat,
    );

    final localisation =
        materiel.localisationInterieure;

    return InkWell(
      onTap: () {
        Navigator.pop(context);

        setState(() {
          _materielSelectionneId =
              materiel.id;
        });
      },
      borderRadius:
      BorderRadius.circular(10),
      child: Container(
        margin:
        const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
        const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius:
          BorderRadius.circular(10),
          border: Border(
            left: BorderSide(
              color: color,
              width: 3,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              EtatUtils.icone(
                materiel.etat,
              ),
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    materiel.displayName,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'N° série : ${materiel.numeroSerie}',
                    style:
                    const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                  if (localisation !=
                      null)
                    Text(
                      'Zone : ${localisation.zone}',
                      style:
                      const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    materiel.etat,
                    style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight:
                      FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DÉTAILS MATÉRIEL
  // ============================================================

  void _afficherMateriel(
      BuildContext context,
      Materiel materiel,
      ) {
    final localisation =
        materiel.localisationInterieure;

    if (localisation == null) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final enMouvement =
            localisation.statut ==
                StatutDeplacement
                    .enMouvement;

        return AlertDialog(
          shape:
          RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.gps_fixed,
                color:
                Color(0xFF003087),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  materiel.displayName,
                ),
              ),
            ],
          ),
          content:
          SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _infoLine(
                  Icons.location_on,
                  'Zone',
                  localisation.zone,
                ),
                if (localisation
                    .batiment
                    .isNotEmpty)
                  _infoLine(
                    Icons.business,
                    'Bâtiment',
                    localisation.batiment,
                  ),
                _infoLine(
                  Icons.layers,
                  'Étage',
                  localisation.etage,
                ),
                _infoLine(
                  Icons.wifi,
                  'SSID',
                  localisation.ssid,
                ),
                if (localisation.bssid !=
                    null &&
                    localisation
                        .bssid!
                        .isNotEmpty)
                  _infoLine(
                    Icons.router,
                    'BSSID',
                    localisation.bssid!,
                  ),
                if (localisation.rssi !=
                    null)
                  _infoLine(
                    Icons
                        .signal_cellular_alt,
                    'RSSI',
                    '${localisation.rssi} dBm',
                  ),
                _infoLine(
                  Icons.my_location,
                  'Position X',
                  '${(localisation.positionX * 100).toStringAsFixed(1)} %',
                ),
                _infoLine(
                  Icons.my_location,
                  'Position Y',
                  '${(localisation.positionY * 100).toStringAsFixed(1)} %',
                ),
                _infoLine(
                  enMouvement
                      ? Icons
                      .directions_walk
                      : Icons.location_on,
                  'Statut',
                  enMouvement
                      ? 'Déplacement détecté'
                      : localisation
                      .statut
                      .label,
                ),
                _infoLine(
                  Icons.access_time,
                  'Dernière détection',
                  _formatDate(
                    localisation
                        .derniereMiseAJour,
                  ),
                ),
                if (localisation
                    .confiance !=
                    null)
                  _infoLine(
                    Icons.verified,
                    'Confiance',
                    '${(localisation.confiance! * 100).toStringAsFixed(0)} %',
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
              const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoLine(
      IconData icon,
      String label,
      String value,
      ) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF003087),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                const TextStyle(
                  color:
                  Colors.black87,
                  fontSize: 13,
                ),
                children: [
                  TextSpan(
                    text: '$label : ',
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: value,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERREUR
  // ============================================================

  Widget _buildErreur(
      Object? error,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color:
              Colors.red.shade300,
              size: 50,
            ),
            const SizedBox(height: 12),
            const Text(
              'Erreur de chargement du plan',
              style:
              TextStyle(
                fontWeight:
                FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error?.toString() ??
                  'Erreur inconnue',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OUTILS
  // ============================================================

  double? _toDouble(
      dynamic value,
      ) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  String _formatDate(
      DateTime date,
      ) {
    final d = date.day
        .toString()
        .padLeft(2, '0');

    final m = date.month
        .toString()
        .padLeft(2, '0');

    final y = date.year.toString();

    final h = date.hour
        .toString()
        .padLeft(2, '0');

    final min = date.minute
        .toString()
        .padLeft(2, '0');

    final sec = date.second
        .toString()
        .padLeft(2, '0');

    return '$d/$m/$y $h:$min:$sec';
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ============================================================
// PAINTER GRILLE
// ============================================================

class _GridPainter
    extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final paint = Paint()
      ..color =
      Colors.grey.withValues(
        alpha: 0.08,
      )
      ..strokeWidth = 1;

    const step = 40.0;

    for (
    double x = 0;
    x <= size.width;
    x += step
    ) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (
    double y = 0;
    y <= size.height;
    y += step
    ) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) {
    return false;
  }
}

// ============================================================
// PAINTER TRAJET
// ============================================================

class _TrajetPainter
    extends CustomPainter {
  final List<_PointTrajet> points;
  final double width;
  final double height;

  const _TrajetPainter({
    required this.points,
    required this.width,
    required this.height,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    if (points.length < 2) {
      return;
    }

    final path = Path();

    for (
    int i = 0;
    i < points.length;
    i++
    ) {
      final point = points[i];

      final offset = Offset(
        point.x.clamp(0.0, 1.0) *
            width,
        point.y.clamp(0.0, 1.0) *
            height,
      );

      if (i == 0) {
        path.moveTo(
          offset.dx,
          offset.dy,
        );
      } else {
        path.lineTo(
          offset.dx,
          offset.dy,
        );
      }
    }

    // Ombre du trajet.
    final shadowPaint = Paint()
      ..color =
      Colors.blue.withValues(
        alpha: 0.12,
      )
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round;

    canvas.drawPath(
      path,
      shadowPaint,
    );

    // Ligne principale.
    final linePaint = Paint()
      ..color =
      const Color(0xFF1976D2)
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round;

    canvas.drawPath(
      path,
      linePaint,
    );

    // Points intermédiaires.
    for (
    int i = 0;
    i < points.length - 1;
    i++
    ) {
      final point = points[i];

      final offset = Offset(
        point.x.clamp(0.0, 1.0) *
            width,
        point.y.clamp(0.0, 1.0) *
            height,
      );

      final pointPaint = Paint()
        ..color = Colors.white
        ..style =
            PaintingStyle.fill;

      canvas.drawCircle(
        offset,
        5,
        pointPaint,
      );

      final borderPaint = Paint()
        ..color =
        const Color(0xFF1976D2)
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawCircle(
        offset,
        5,
        borderPaint,
      );
    }

    // Point de départ.
    final depart = points.first;

    final departOffset = Offset(
      depart.x.clamp(0.0, 1.0) *
          width,
      depart.y.clamp(0.0, 1.0) *
          height,
    );

    final departPaint = Paint()
      ..color = Colors.green
      ..style =
          PaintingStyle.fill;

    canvas.drawCircle(
      departOffset,
      8,
      departPaint,
    );

    final departBorder = Paint()
      ..color = Colors.white
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      departOffset,
      8,
      departBorder,
    );

    // Point d'arrivée / position actuelle.
    final arrivee = points.last;

    final arriveeOffset = Offset(
      arrivee.x.clamp(0.0, 1.0) *
          width,
      arrivee.y.clamp(0.0, 1.0) *
          height,
    );

    final arriveePaint = Paint()
      ..color =
      const Color(0xFF003087)
      ..style =
          PaintingStyle.fill;

    canvas.drawCircle(
      arriveeOffset,
      10,
      arriveePaint,
    );

    final arriveeBorder = Paint()
      ..color = Colors.white
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(
      arriveeOffset,
      10,
      arriveeBorder,
    );

    // Flèches de direction.
    for (
    int i = 0;
    i < points.length - 1;
    i++
    ) {
      final a = points[i];
      final b = points[i + 1];

      final start = Offset(
        a.x.clamp(0.0, 1.0) *
            width,
        a.y.clamp(0.0, 1.0) *
            height,
      );

      final end = Offset(
        b.x.clamp(0.0, 1.0) *
            width,
        b.y.clamp(0.0, 1.0) *
            height,
      );

      final middle = Offset(
        (start.dx + end.dx) / 2,
        (start.dy + end.dy) / 2,
      );

      _drawArrow(
        canvas,
        middle,
        start,
        end,
      );
    }
  }

  void _drawArrow(
      Canvas canvas,
      Offset middle,
      Offset start,
      Offset end,
      ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;

    final distance =
    math.sqrt(
      dx * dx + dy * dy,
    );

    if (distance < 1) {
      return;
    }

    final ux = dx / distance;
    final uy = dy / distance;

    const arrowSize = 7.0;

    final p1 = Offset(
      middle.dx -
          ux * arrowSize -
          uy * arrowSize * 0.6,
      middle.dy -
          uy * arrowSize +
          ux * arrowSize * 0.6,
    );

    final p2 = Offset(
      middle.dx -
          ux * arrowSize +
          uy * arrowSize * 0.6,
      middle.dy -
          uy * arrowSize -
          ux * arrowSize * 0.6,
    );

    final paint = Paint()
      ..color =
      const Color(0xFF1976D2)
      ..style =
          PaintingStyle.fill;

    final path = Path()
      ..moveTo(
        middle.dx,
        middle.dy,
      )
      ..lineTo(
        p1.dx,
        p1.dy,
      )
      ..lineTo(
        p2.dx,
        p2.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      paint,
    );
  }

  @override
  bool shouldRepaint(
      covariant _TrajetPainter oldDelegate,
      ) {
    return oldDelegate.points !=
        points ||
        oldDelegate.width != width ||
        oldDelegate.height != height;
  }
}