import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/materiel.dart';
import '../../models/localisation_interieure.dart';
import '../../services/localisation_auto_service.dart';

class LocalisationDashboardScreen
    extends ConsumerStatefulWidget {
  const LocalisationDashboardScreen({
    super.key,
  });

  @override
  ConsumerState<
      LocalisationDashboardScreen> createState() =>
      _LocalisationDashboardScreenState();
}

class _LocalisationDashboardScreenState
    extends ConsumerState<
        LocalisationDashboardScreen> {
  static const double _planWidth = 900;
  static const double _planHeight = 620;

  String? _materielSelectionneId;

// ============================================================
// PLAN ÉTAGE 2
// ============================================================

  static const List<_Salle> _sallesEtage2 = [
    _Salle(
      'Bureau 204',
      30,
      40,
      145,
      90,
    ),
    _Salle(
      'Couloir',
      185,
      65,
      145,
      42,
    ),
    _Salle(
      'Salle R2',
      345,
      40,
      150,
      90,
    ),
    _Salle(
      'Bureau 209',
      510,
      40,
      145,
      90,
    ),
    _Salle(
      'Bureau 243',
      30,
      165,
      125,
      82,
    ),
    _Salle(
      'Espace Ouvert 244A',
      165,
      145,
      165,
      110,
    ),
    _Salle(
      'Cage escalier A',
      345,
      150,
      70,
      90,
    ),
    _Salle(
      'Bureau 245',
      430,
      155,
      115,
      82,
    ),
    _Salle(
      'Archive 260A',
      560,
      155,
      120,
      82,
    ),
    _Salle(
      'Salle Réunion 251',
      700,
      150,
      150,
      100,
    ),
    _Salle(
      'Bureau 252',
      30,
      275,
      125,
      82,
    ),
    _Salle(
      'Bureau 242',
      165,
      275,
      125,
      82,
    ),
    _Salle(
      'Bureau 220',
      305,
      275,
      115,
      82,
    ),
    _Salle(
      'Bureau 221',
      435,
      275,
      115,
      82,
    ),
    _Salle(
      'Sanitaires',
      565,
      275,
      90,
      82,
    ),
    _Salle(
      'Salle Réunion 215',
      670,
      275,
      180,
      82,
    ),
    _Salle(
      'Bureau 213A',
      30,
      380,
      120,
      82,
    ),
    _Salle(
      'Bureau 207',
      165,
      380,
      120,
      82,
    ),
    _Salle(
      'Bureau 223',
      300,
      380,
      115,
      82,
    ),
    _Salle(
      'Bureau 222',
      430,
      380,
      115,
      82,
    ),
    _Salle(
      'Bureau 217',
      560,
      380,
      115,
      82,
    ),
    _Salle(
      'Bureau 216',
      690,
      380,
      160,
      82,
    ),
    _Salle(
      'Cage escalier B',
      30,
      490,
      70,
      82,
    ),
    _Salle(
      'Bureau 212',
      115,
      490,
      115,
      82,
    ),
    _Salle(
      'Bureau 211',
      245,
      490,
      115,
      82,
    ),
    _Salle(
      'Bureau 208',
      375,
      490,
      115,
      82,
    ),
    _Salle(
      'Bureau 206',
      505,
      490,
      115,
      82,
    ),
  ];

// ============================================================
// BUILD
// ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Localisation intérieure',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),
      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('materiels')
            .snapshots(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snapshot.error}',
              ),
            );
          }

          final List<Materiel> materiels =
              snapshot.data?.docs
                  .map(
                    (doc) =>
                    Materiel.fromFirestore(
                      doc,
                    ),
              )
                  .toList() ??
                  [];

          final List<Materiel>
          materielsLocalises =
          materiels.where(
                (materiel) {
              final localisation =
                  materiel.localisationInterieure;

              return localisation != null &&
                  localisation.zone.isNotEmpty;
            },
          ).toList();

          final int total =
              materiels.length;

          final int localises =
              materielsLocalises.length;

          final int enMouvement =
              materielsLocalises.where(
                    (materiel) =>
                materiel.localisationInterieure!
                    .statut ==
                    StatutDeplacement
                        .enMouvement,
              ).length;

          final int zonesOccupees =
              materielsLocalises
                  .map(
                    (materiel) =>
                materiel
                    .localisationInterieure!
                    .zone,
              )
                  .where(
                    (zone) =>
                zone.isNotEmpty,
              )
                  .toSet()
                  .length;

          final Materiel? selection =
          _materielSelectionneId == null
              ? null
              : _findMateriel(
            materiels,
            _materielSelectionneId!,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 18),

                _buildStatistics(
                  total: total,
                  localises: localises,
                  enMouvement:
                  enMouvement,
                  zonesOccupees:
                  zonesOccupees,
                ),

                const SizedBox(height: 20),

                _buildMainCard(
                  context,
                  materielsLocalises,
                  selection,
                ),

                const SizedBox(height: 20),

                if (selection != null)
                  _buildTrajectoryDetails(
                    selection,
                  ),

                const SizedBox(height: 20),

                _buildEquipmentList(
                  materielsLocalises,
                ),
              ],
            ),
          );
        },
      ),
    );

  }

// ============================================================
// HEADER
// ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(14),
            color: Colors.blue.withOpacity(
              0.10,
            ),
          ),
          child: const Icon(
            Icons.location_on,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                'Suivi des équipements',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Visualisation Wi-Fi en temps réel et trajectoire des matériels',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

// ============================================================
// STATISTIQUES
// ============================================================

  Widget _buildStatistics({
    required int total,
    required int localises,
    required int enMouvement,
    required int zonesOccupees,
  }) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _statCard(
          'Matériels',
          total.toString(),
          Icons.inventory_2_outlined,
        ),
        _statCard(
          'Localisés',
          localises.toString(),
          Icons.location_on_outlined,
        ),
        _statCard(
          'En mouvement',
          enMouvement.toString(),
          Icons.directions_run,
        ),
        _statCard(
          'Zones occupées',
          zonesOccupees.toString(),
          Icons.map_outlined,
        ),
      ],
    );
  }

  Widget _statCard(
      String title,
      String value,
      IconData icon,
      ) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 25,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

// ============================================================
// CARTE PRINCIPALE
// ============================================================

  Widget _buildMainCard(
      BuildContext context,
      List<Materiel> materiels,
      Materiel? selection,
      ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.map,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan intérieur',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Étage 2',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selection != null)
                  _locationBadge(
                    selection
                        .localisationInterieure!
                        .statut,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                height: 620,
                color:
                const Color(0xFFF0F2F5),
                child: InteractiveViewer(
                  minScale: 0.55,
                  maxScale: 2.5,
                  boundaryMargin:
                  const EdgeInsets.all(
                    80,
                  ),
                  child: SizedBox(
                    width: _planWidth,
                    height: _planHeight,
                    child: CustomPaint(
                      painter:
                      _PlanPainter(
                        salles:
                        _sallesEtage2,
                      ),
                      child: Stack(
                        children: [
                          ...materiels.map(
                                (materiel) {
                              return _buildMarker(
                                materiel,
                                materiel.id ==
                                    _materielSelectionneId,
                              );
                            },
                          ),
                          if (selection != null)
                            _buildTrajectory(
                              selection,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            _buildLegend(),
          ],
        ),
      ),
    );

  }

// ============================================================
// MARKER
// ============================================================

  Widget _buildMarker(
      Materiel materiel,
      bool selected,
      ) {
    final localisation =
        materiel.localisationInterieure;

    if (localisation == null) {
      return const SizedBox.shrink();
    }

    final double x =
    _normaliserPosition(
      localisation.positionX,
      _planWidth,
    );

    final double y =
    _normaliserPosition(
      localisation.positionY,
      _planHeight,
    );

    final bool mouvement =
        localisation.statut ==
            StatutDeplacement
                .enMouvement;

    return Positioned(
      left: x - 18,
      top: y - 18,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _materielSelectionneId =
                materiel.id;
          });
        },
        child: AnimatedContainer(
          duration:
          const Duration(
            milliseconds: 250,
          ),
          width: selected ? 38 : 32,
          height: selected ? 38 : 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected
                ? Colors.blue
                : mouvement
                ? Colors.orange
                : Colors.green,
            boxShadow: [
              if (selected ||
                  mouvement)
                BoxShadow(
                  blurRadius: 12,
                  spreadRadius: 3,
                  color: (selected
                      ? Colors.blue
                      : Colors.orange)
                      .withOpacity(
                    0.25,
                  ),
                ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
          ),
          child: Icon(
            _iconForMateriel(
              materiel,
            ),
            size: selected ? 20 : 17,
            color: Colors.white,
          ),
        ),
      ),
    );

  }

// ============================================================
// TRAJECTOIRE
// ============================================================

  Widget _buildTrajectory(
      Materiel materiel,
      ) {
    return FutureBuilder<
        List<Map<String, dynamic>>>(
      future:
      _getTrajectory(materiel.id),
      builder: (
          context,
          snapshot,
          ) {
        if (!snapshot.hasData ||
            snapshot.data!.length < 2) {
          return const SizedBox.shrink();
        }

        final points =
        _extractPoints(
          snapshot.data!,
        );

        if (points.length < 2) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter:
              _TrajectoryPainter(
                points: points,
              ),
            ),
          ),
        );
      },
    );

  }

  Future<List<Map<String, dynamic>>>
  _getTrajectory(
      String materielId,
      ) async {
    final snapshot =
    await FirebaseFirestore.instance
        .collection('historique')
        .where(
      'materielId',
      isEqualTo: materielId,
    )
        .get();

    final List<Map<String, dynamic>>
    data = snapshot.docs
        .map(
          (doc) => {
        ...doc.data(),
        'id': doc.id,
      },
    )
        .where(
          (item) =>
      item['action'] ==
          'Localisation' ||
          item['positionX'] != null,
    )
        .toList();

    data.sort(
          (a, b) {
        final DateTime? dateA =
        _dateFromValue(
          a['dateDetection'] ??
              a['date'],
        );

        final DateTime? dateB =
        _dateFromValue(
          b['dateDetection'] ??
              b['date'],
        );

        if (dateA == null ||
            dateB == null) {
          return 0;
        }

        return dateA.compareTo(dateB);
      },
    );

    return data;

  }

  List<Offset> _extractPoints(
      List<Map<String, dynamic>> data,
      ) {
    final List<Offset> points = [];

    Offset? dernier;

    for (final item in data) {
      final double? x =
      _toDouble(item['positionX']);

      final double? y =
      _toDouble(item['positionY']);

      if (x == null || y == null) {
        continue;
      }

      final Offset point = Offset(
        _normaliserPosition(
          x,
          _planWidth,
        ),
        _normaliserPosition(
          y,
          _planHeight,
        ),
      );

      if (dernier != null &&
          (point - dernier).distance <
              2) {
        continue;
      }

      points.add(point);
      dernier = point;
    }

    return points;

  }

// ============================================================
// DÉTAILS DU TRAJET
// ============================================================

  Widget _buildTrajectoryDetails(
      Materiel materiel,
      ) {
    final localisation =
    materiel.localisationInterieure!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Trajectoire sélectionnée',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),
              Text(
                localisation.zone,
                style: const TextStyle(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ],
          ),

          const Divider(
            height: 28,
          ),

          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              _detailItem(
                'Zone actuelle',
                localisation.zone,
                Icons.location_on,
              ),
              _detailItem(
                'Étage',
                localisation.etage,
                Icons.layers,
              ),
              _detailItem(
                'Bâtiment',
                localisation.batiment,
                Icons.business,
              ),
              _detailItem(
                'Méthode',
                'Wi-Fi',
                Icons.wifi,
              ),
              _detailItem(
                'Confiance',
                '${((localisation.confiance ?? 1) * 100).toInt()} %',
                Icons.verified,
              ),
              _detailItem(
                'Dernière détection',
                _formatDate(
                  localisation
                      .derniereMiseAJour,
                ),
                Icons.access_time,
              ),
            ],
          ),
        ],
      ),
    );

  }

  Widget _detailItem(
      String title,
      String value,
      IconData icon,
      ) {
    return SizedBox(
      width: 190,
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// ============================================================
// LISTE MATÉRIELS
// ============================================================

  Widget _buildEquipmentList(
      List<Materiel> materiels,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.devices),
              SizedBox(width: 10),
              Text(
                'Matériels localisés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (materiels.isEmpty)
            const Padding(
              padding:
              EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Aucun matériel localisé.',
                ),
              ),
            )
          else
            ...materiels.map(
                  (materiel) =>
                  _buildEquipmentTile(
                    materiel,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTile(
      Materiel materiel,
      ) {
    final localisation =
    materiel.localisationInterieure!;

    final bool selected =
        materiel.id ==
            _materielSelectionneId;

    final bool mouvement =
        localisation.statut ==
            StatutDeplacement
                .enMouvement;

    return Card(
      elevation: 0,
      color: selected
          ? Colors.blue.withOpacity(
        0.06,
      )
          : Colors.transparent,
      child: ListTile(
        onTap: () {
          setState(() {
            _materielSelectionneId =
                materiel.id;
          });
        },
        leading: CircleAvatar(
          backgroundColor: mouvement
              ? Colors.orange
              .withOpacity(
            0.12,
          )
              : Colors.green
              .withOpacity(
            0.12,
          ),
          child: Icon(
            mouvement
                ? Icons.directions_run
                : Icons.location_on,
            color: mouvement
                ? Colors.orange
                : Colors.green,
          ),
        ),
        title: Text(
          materiel.displayName,
          style: const TextStyle(
            fontWeight:
            FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${localisation.zone} · ${localisation.batiment} · ${localisation.etage}',
        ),
        trailing: _locationBadge(
          localisation.statut,
        ),
      ),
    );

  }

// ============================================================
// LÉGENDE
// ============================================================

  Widget _buildLegend() {
    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        _legendItem(
          Colors.green,
          'Position statique',
        ),
        _legendItem(
          Colors.orange,
          'En mouvement',
        ),
        _legendItem(
          Colors.blue,
          'Matériel sélectionné',
        ),
        _legendItem(
          Colors.black54,
          'Trajectoire',
        ),
      ],
    );
  }

  Widget _legendItem(
      Color color,
      String text,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration:
          BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(text),
      ],
    );
  }

  Widget _locationBadge(
      StatutDeplacement statut,
      ) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
        statut.color.withOpacity(
          0.10,
        ),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        statut.label,
        style: TextStyle(
          color: statut.color,
          fontWeight:
          FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

// ============================================================
// UTILITAIRES
// ============================================================

  Materiel? _findMateriel(
      List<Materiel> materiels,
      String id,
      ) {
    for (final materiel in materiels) {
      if (materiel.id == id) {
        return materiel;
      }
    }

    return null;

  }

  IconData _iconForMateriel(
      Materiel materiel,
      ) {
    final String type =
    materiel.type.toLowerCase();

    if (type.contains('ordinateur') ||
        type.contains('pc')) {
      return Icons.computer;
    }

    if (type.contains('imprim')) {
      return Icons.print;
    }

    if (type.contains('serveur')) {
      return Icons.dns;
    }

    if (type.contains('switch')) {
      return Icons.hub;
    }

    if (type.contains('telephone') ||
        type.contains('téléphone')) {
      return Icons.phone_android;
    }

    return Icons.devices;

  }

  double _normaliserPosition(
      double valeur,
      double dimension,
      ) {
    if (valeur >= 0 &&
        valeur <= 1) {
      return valeur * dimension;
    }

    return valeur.clamp(
      0,
      dimension,
    );

  }

  double? _toDouble(
      dynamic value,
      ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );

  }

  DateTime? _dateFromValue(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(
        value,
      );
    }

    return null;

  }

  String _formatDate(
      DateTime date,
      ) {
    final String h =
    date.hour
        .toString()
        .padLeft(2, '0');

    final String m =
    date.minute
        .toString()
        .padLeft(2, '0');

    final String s =
    date.second
        .toString()
        .padLeft(2, '0');

    return '$h:$m:$s';

  }
}

// ============================================================
// MODÈLE SALLE
// ============================================================

class _Salle {
  final String nom;
  final double x;
  final double y;
  final double width;
  final double height;

  const _Salle(
      this.nom,
      this.x,
      this.y,
      this.width,
      this.height,
      );
}

// ============================================================
// PAINTER PLAN
// ============================================================

class _PlanPainter
    extends CustomPainter {
  final List<_Salle> salles;

  const _PlanPainter({
    required this.salles,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final Paint fond =
    Paint()
      ..style =
          PaintingStyle.fill;

    final Paint contour =
    Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 1.2;

    fond.color =
    const Color(0xFFF8F9FB);

    canvas.drawRect(
      Offset.zero &
      size,
      fond,
    );

    for (final salle in salles) {
      final Rect rect =
      Rect.fromLTWH(
        salle.x,
        salle.y,
        salle.width,
        salle.height,
      );

      fond.color =
      const Color(0xFFFFFFFF);

      contour.color =
      const Color(0xFFCBD1D8);

      canvas.drawRect(
        rect,
        fond,
      );

      canvas.drawRect(
        rect,
        contour,
      );

      final TextPainter text =
      TextPainter(
        text: TextSpan(
          text: salle.nom,
          style: const TextStyle(
            fontSize: 10,
            color: Color(
              0xFF5E6670,
            ),
            fontWeight:
            FontWeight.w600,
          ),
        ),
        textDirection:
        TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      );

      text.layout(
        maxWidth:
        salle.width - 12,
      );

      text.paint(
        canvas,
        Offset(
          salle.x + 6,
          salle.y +
              (salle.height -
                  text.height) /
                  2,
        ),
      );
    }

  }

  @override
  bool shouldRepaint(
      covariant _PlanPainter oldDelegate,
      ) {
    return false;
  }
}

// ============================================================
// PAINTER TRAJECTOIRE
// ============================================================

class _TrajectoryPainter
    extends CustomPainter {
  final List<Offset> points;

  const _TrajectoryPainter({
    required this.points,
  });

  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    if (points.length < 2) {
      return;
    }

    final Paint ligne =
    Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap =
          StrokeCap.round
      ..strokeJoin =
          StrokeJoin.round;

    final Paint ligneFine =
    Paint()
      ..style =
          PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap =
          StrokeCap.round;

    final Path path =
    Path()
      ..moveTo(
        points.first.dx,
        points.first.dy,
      );

    for (int i = 1;
    i < points.length;
    i++) {
      path.lineTo(
        points[i].dx,
        points[i].dy,
      );
    }

    ligne.color =
        Colors.blue.withOpacity(
          0.18,
        );

    canvas.drawPath(
      path,
      ligne,
    );

    ligneFine.color =
        Colors.blue;

    canvas.drawPath(
      path,
      ligneFine,
    );

// ----------------------------------------------------------
// Points intermédiaires
// ----------------------------------------------------------

    final Paint pointPaint =
    Paint()
      ..style =
          PaintingStyle.fill;

    for (int i = 1;
    i < points.length - 1;
    i++) {
      pointPaint.color =
          Colors.orange;

      canvas.drawCircle(
        points[i],
        6,
        pointPaint,
      );

      pointPaint.color =
          Colors.white;

      canvas.drawCircle(
        points[i],
        2.5,
        pointPaint,
      );
    }

// ----------------------------------------------------------
// Départ
// ----------------------------------------------------------

    pointPaint.color =
        Colors.green;

    canvas.drawCircle(
      points.first,
      9,
      pointPaint,
    );

    pointPaint.color =
        Colors.white;

    canvas.drawCircle(
      points.first,
      4,
      pointPaint,
    );

// ----------------------------------------------------------
// Position actuelle
// ----------------------------------------------------------

    pointPaint.color =
        Colors.blue;

    canvas.drawCircle(
      points.last,
      11,
      pointPaint,
    );

    pointPaint.color =
        Colors.white;

    canvas.drawCircle(
      points.last,
      5,
      pointPaint,
    );

// ----------------------------------------------------------
// Flèches
// ----------------------------------------------------------

    for (int i = 0;
    i < points.length - 1;
    i++) {
      _drawArrow(
        canvas,
        points[i],
        points[i + 1],
      );
    }

  }

  void _drawArrow(
      Canvas canvas,
      Offset start,
      Offset end,
      ) {
    final Offset vector =
        end - start;

    final double length =
        vector.distance;

    if (length < 18) {
      return;
    }

    final Offset direction =
        vector / length;

    final Offset center =
        start +
            vector * 0.65;

    final Offset perpendicular =
    Offset(
      -direction.dy,
      direction.dx,
    );

    const double arrowLength =
    9;

    const double arrowWidth =
    5;

    final Offset tip =
        center +
            direction *
                arrowLength;

    final Offset left =
        center -
            direction *
                arrowLength +
            perpendicular *
                arrowWidth;

    final Offset right =
        center -
            direction *
                arrowLength -
            perpendicular *
                arrowWidth;

    final Path arrow =
    Path()
      ..moveTo(
        tip.dx,
        tip.dy,
      )
      ..lineTo(
        left.dx,
        left.dy,
      )
      ..lineTo(
        right.dx,
        right.dy,
      )
      ..close();

    final Paint paint =
    Paint()
      ..style =
          PaintingStyle.fill
      ..color =
          Colors.blue;

    canvas.drawPath(
      arrow,
      paint,
    );

  }

  @override
  bool shouldRepaint(
      covariant _TrajectoryPainter
      oldDelegate,
      ) {
    if (oldDelegate.points.length !=
        points.length) {
      return true;
    }

    for (int i = 0;
    i < points.length;
    i++) {
      if (oldDelegate.points[i] !=
          points[i]) {
        return true;
      }
    }

    return false;

  }
}