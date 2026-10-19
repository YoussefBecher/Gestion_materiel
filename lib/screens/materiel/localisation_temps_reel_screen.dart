import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/localisation_interieure.dart';
import '../../models/materiel.dart';
import '../../services/localisation_auto_service.dart';
import '../../services/wifi_location_service.dart';
import 'historique_deplacement_screen.dart';

const double _planWidth = 1100;
const double _planHeight = 680;

class LocalisationTempsReelScreen extends ConsumerStatefulWidget {
  const LocalisationTempsReelScreen({super.key});

  @override
  ConsumerState<LocalisationTempsReelScreen> createState() =>
      _LocalisationTempsReelScreenState();
}

class _LocalisationTempsReelScreenState
    extends ConsumerState<LocalisationTempsReelScreen> {
  int _etageSelectionne = 2;
  String? _materielSelectionneId;
  bool _afficherTrajet = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _demarrerLocalisation();
    });
  }

  Future<void> _demarrerLocalisation() async {
    try {
      final service = ref.read(localisationAutoServiceProvider);

      if (!service.localisationActive) {
        await service.demarrerLocalisationAutomatique();
      }
    } catch (e) {
      debugPrint('Erreur démarrage localisation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // wifiStateProvider renvoie un AsyncValue<WifiState> (chargement,
    // erreur ou donnée). On extrait la valeur ; elle est null tant que
    // la donnée n'est pas disponible ou en cas d'erreur.
    final wifiStateAsync = ref.watch(wifiStateProvider);
    final WifiState? wifiState = wifiStateAsync.valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172033),
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.location_searching,
                color: Color(0xFF1769E0),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Localisation en temps réel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Suivi du matériel par Wi-Fi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF758195),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          _WifiStatusBadge(wifiState: wifiState),
          const SizedBox(width: 18),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('materiels')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErreurView(
              message: 'Impossible de charger les matériels.',
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final materiels = snapshot.data!.docs
              .map((doc) {
            try {
              return Materiel.fromFirestore(doc);
            } catch (_) {
              return null;
            }
          })
              .whereType<Materiel>()
              .toList();

          return _buildContent(
            context,
            materiels,
            wifiState,
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context,
      List<Materiel> materiels,
      WifiState? wifiState,
      ) {
    final localises = materiels.where((m) {
      final localisation = m.localisationInterieure;
      return localisation != null &&
          localisation.batiment.trim().isNotEmpty &&
          localisation.etage.trim().isNotEmpty;
    }).toList();

    final materielsEtage = localises.where((m) {
      final localisation = m.localisationInterieure!;
      return _normaliserEtage(localisation.etage) == _etageSelectionne;
    }).toList();

    Materiel? materielSelectionne;

    if (_materielSelectionneId != null) {
      for (final materiel in materiels) {
        if (materiel.id == _materielSelectionneId) {
          materielSelectionne = materiel;
          break;
        }
      }
    }

    return Column(
      children: [
        _buildTopStats(materiels, localises, wifiState),
        _buildToolbar(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth >= 1000;

              if (horizontal) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 9, 18),
                        child: _buildPlanCard(
                          materielsEtage,
                          materielSelectionne,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 340,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(9, 0, 18, 18),
                        child: _buildDetailsPanel(
                          materielSelectionne,
                          materielsEtage,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  children: [
                    SizedBox(
                      height: 520,
                      child: _buildPlanCard(
                        materielsEtage,
                        materielSelectionne,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailsPanel(
                      materielSelectionne,
                      materielsEtage,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopStats(
      List<Materiel> materiels,
      List<Materiel> localises,
      WifiState? wifiState,
      ) {
    final enMouvement = localises.where((m) {
      return m.localisationInterieure?.statut ==
          StatutDeplacement.enMouvement;
    }).length;

    final statiques = localises.where((m) {
      return m.localisationInterieure?.statut ==
          StatutDeplacement.statique;
    }).length;

    final wifiConnecte = wifiState?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      color: Colors.white,
      child: Row(
        children: [
          _StatCard(
            icon: Icons.inventory_2_outlined,
            title: 'Matériel',
            value: '${materiels.length}',
            subtitle: 'total',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.location_on_outlined,
            title: 'Localisés',
            value: '${localises.length}',
            subtitle: 'par Wi-Fi',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.directions_run,
            title: 'En mouvement',
            value: '$enMouvement',
            subtitle: 'détectés',
          ),
          const SizedBox(width: 10),
          _StatCard(
            icon: Icons.pause_circle_outline,
            title: 'Statiques',
            value: '$statiques',
            subtitle: 'immobiles',
          ),
          const Spacer(),
          _LiveIndicator(
            active: wifiConnecte,
            label: wifiConnecte
                ? 'SURVEILLANCE ACTIVE'
                : 'WI-FI NON DISPONIBLE',
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.layers_outlined,
            size: 20,
            color: Color(0xFF526174),
          ),
          const SizedBox(width: 8),
          const Text(
            'Étage',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(width: 10),
          _buildFloorButton(0),
          _buildFloorButton(1),
          _buildFloorButton(2),
          _buildFloorButton(3),
          _buildFloorButton(4),
          const SizedBox(width: 20),
          Container(
            height: 28,
            width: 1,
            color: const Color(0xFFE1E5EB),
          ),
          const SizedBox(width: 18),
          const Icon(
            Icons.route_outlined,
            size: 19,
            color: Color(0xFF526174),
          ),
          const SizedBox(width: 7),
          const Text(
            'Trajet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: _afficherTrajet,
            onChanged: (value) {
              setState(() {
                _afficherTrajet = value;
              });
            },
          ),
          const Spacer(),
          Text(
            'Mise à jour automatique',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorButton(int floor) {
    final selected = floor == _etageSelectionne;

    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _etageSelectionne = floor;
            _materielSelectionneId = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1769E0)
                : const Color(0xFFF3F5F8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Étage $floor',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : const Color(0xFF526174),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(
      List<Materiel> materiels,
      Materiel? materielSelectionne,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E6ED)),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 4),
            color: Colors.black.withOpacity(0.035),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPlanHeader(materiels.length),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              child: InteractiveViewer(
                minScale: 0.55,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(100),
                child: SizedBox(
                  width: _planWidth,
                  height: _planHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: FloorPlanPainter(
                            etage: _etageSelectionne,
                          ),
                        ),
                      ),
                      if (_afficherTrajet &&
                          materielSelectionne != null)
                        Positioned.fill(
                          child: _TrajectoryLayer(
                            materiel: materielSelectionne,
                            etage: _etageSelectionne,
                          ),
                        ),
                      ...materiels.map(
                            (materiel) => _buildMarker(materiel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 13),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8EBF0)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.map_outlined,
            size: 21,
            color: Color(0xFF1769E0),
          ),
          const SizedBox(width: 9),
          Text(
            'Plan intérieur — Étage $_etageSelectionne',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1D2939),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F4F8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count matériel${count > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
          ),
          const Spacer(),
          _LegendDot(
            color: const Color(0xFF12B76A),
            label: 'Statique',
          ),
          const SizedBox(width: 14),
          _LegendDot(
            color: const Color(0xFFF79009),
            label: 'Mouvement',
          ),
          const SizedBox(width: 14),
          _LegendDot(
            color: const Color(0xFFF04438),
            label: 'Hors ligne',
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Materiel materiel) {
    final localisation = materiel.localisationInterieure;

    if (localisation == null) {
      return const SizedBox.shrink();
    }

    final position = _positionPourMateriel(materiel);

    final selected = materiel.id == _materielSelectionneId;

    return Positioned(
      left: position.dx - 25,
      top: position.dy - 25,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _materielSelectionneId = materiel.id;
          });
        },
        child: _MaterialMarker(
          materiel: materiel,
          selected: selected,
        ),
      ),
    );
  }

  Offset _positionPourMateriel(Materiel materiel) {
    final localisation = materiel.localisationInterieure!;

    double x = localisation.positionX;
    double y = localisation.positionY;

    if (x > 1 || y > 1) {
      x = x / _planWidth;
      y = y / _planHeight;
    }

    if (x == 0 && y == 0) {
      final fallback = _positionSelonZone(localisation.zone);
      if (fallback != null) {
        return fallback;
      }
    }

    return Offset(
      x.clamp(0.04, 0.96) * _planWidth,
      y.clamp(0.06, 0.94) * _planHeight,
    );
  }

  Offset? _positionSelonZone(String zone) {
    final normalized = zone.toLowerCase().trim();

    final positions = <String, Offset>{
      'bureau 204': const Offset(145, 120),
      'bureau 207': const Offset(430, 145),
      'bureau 208': const Offset(540, 145),
      'bureau 209': const Offset(650, 145),
      'bureau 211': const Offset(850, 145),
      'bureau 212': const Offset(955, 145),
      'bureau 213a': const Offset(430, 300),
      'bureau 216': const Offset(735, 300),
      'bureau 217': const Offset(850, 300),
      'bureau 220': const Offset(180, 460),
      'bureau 221': const Offset(290, 460),
      'bureau 222': const Offset(730, 460),
      'bureau 223': const Offset(850, 460),
      'bureau 242': const Offset(140, 570),
      'bureau 243': const Offset(280, 570),
      'bureau 245': const Offset(510, 570),
      'bureau 252': const Offset(850, 570),
      'salle r2': const Offset(600, 110),
      'salle réunion 251': const Offset(735, 570),
      'salle réunion 215': const Offset(600, 460),
      'couloir': const Offset(540, 340),
      'archive 260a': const Offset(1000, 570),
    };

    return positions[normalized];
  }

  Widget _buildDetailsPanel(
      Materiel? materiel,
      List<Materiel> materielsEtage,
      ) {
    if (materiel == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E6ED)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  color: Color(0xFF1769E0),
                ),
                SizedBox(width: 10),
                Text(
                  'Détails du matériel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 52,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sélectionnez un matériel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Cliquez sur un marqueur du plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final localisation = materiel.localisationInterieure!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E6ED)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF1769E0),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Détails du matériel',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () {
                    setState(() {
                      _materielSelectionneId = null;
                    });
                  },
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildMaterialIdentity(materiel),
            const SizedBox(height: 18),
            _buildSectionTitle('LOCALISATION'),
            const SizedBox(height: 9),
            _InfoRow(
              icon: Icons.business_outlined,
              label: 'Bâtiment',
              value: localisation.batiment,
            ),
            _InfoRow(
              icon: Icons.layers_outlined,
              label: 'Étage',
              value: localisation.etage,
            ),
            _InfoRow(
              icon: Icons.room_outlined,
              label: 'Zone',
              value: localisation.zone,
            ),
            const SizedBox(height: 15),
            _buildSectionTitle('DÉTECTION'),
            const SizedBox(height: 9),
            _InfoRow(
              icon: Icons.wifi,
              label: 'SSID',
              value: localisation.ssid,
            ),
            _InfoRow(
              icon: Icons.router_outlined,
              label: 'BSSID',
              value: localisation.bssid ?? 'Non disponible',
            ),
            _InfoRow(
              icon: Icons.signal_cellular_alt,
              label: 'RSSI',
              value: localisation.rssi != null
                  ? '${localisation.rssi} dBm'
                  : 'Non disponible',
            ),
            const SizedBox(height: 15),
            _buildSectionTitle('ÉTAT'),
            const SizedBox(height: 9),
            _StatusCard(localisation: localisation),
            const SizedBox(height: 15),
            _buildSectionTitle('DERNIÈRE MISE À JOUR'),
            const SizedBox(height: 9),
            _InfoRow(
              icon: Icons.access_time,
              label: 'Heure',
              value: _formatDate(localisation.derniereMiseAJour),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoriqueDeplacementScreen(
                            materiel: materiel,
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.route_outlined),
                label: const Text('Voir l’historique du trajet'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769E0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialIdentity(Materiel materiel) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.devices_other,
              color: Color(0xFF1769E0),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  materiel.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  materiel.type,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.7,
        fontWeight: FontWeight.w800,
        color: Color(0xFF98A2B3),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(d.day)}/${two(d.month)}/${d.year} '
        '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
  }

  int _normaliserEtage(String etage) {
    final value = etage.toLowerCase().trim();

    if (value.contains('rdc') || value == '0') return 0;
    if (value.contains('1')) return 1;
    if (value.contains('2')) return 2;
    if (value.contains('3')) return 3;
    if (value.contains('4')) return 4;

    return int.tryParse(value) ?? 2;
  }
}

class _TrajectoryLayer extends StatelessWidget {
  final Materiel materiel;
  final int etage;

  const _TrajectoryLayer({
    required this.materiel,
    required this.etage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('historique')
          .where(
        'materielId',
        isEqualTo: materiel.id,
      )
          .limit(200)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final points = <Offset>[];

        for (final doc in snapshot.data!.docs) {
          final data = doc.data();

          final action = data['action']?.toString();

          if (action != null &&
              action.isNotEmpty &&
              action.toLowerCase() != 'localisation') {
            continue;
          }

          final localisation = _extractLocalisation(data);

          if (localisation == null) continue;

          final historyFloor = _extractString(
            localisation,
            ['etage', 'floor'],
          );

          if (historyFloor != null &&
              _normaliserEtage(historyFloor) != etage) {
            continue;
          }

          final x = _extractDouble(
            localisation,
            ['positionX', 'x'],
          );

          final y = _extractDouble(
            localisation,
            ['positionY', 'y'],
          );

          if (x == null || y == null) continue;

          points.add(
            Offset(
              _normalizeCoordinate(x) * _planWidth,
              _normalizeCoordinate(y) * _planHeight,
            ),
          );
        }

        if (points.length < 2) {
          return const SizedBox.shrink();
        }

        return CustomPaint(
          painter: TrajectoryPainter(points: points),
          size: const Size(_planWidth, _planHeight),
        );
      },
    );
  }

  Map<String, dynamic>? _extractLocalisation(
      Map<String, dynamic> data,
      ) {
    final candidates = [
      data['localisationInterieure'],
      data['localisation'],
      data['details'],
    ];

    for (final candidate in candidates) {
      if (candidate is Map) {
        return Map<String, dynamic>.from(candidate);
      }
    }

    return data;
  }

  double? _extractDouble(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = data[key];

      if (value is num) {
        return value.toDouble();
      }

      if (value is String) {
        return double.tryParse(value);
      }
    }

    return null;
  }

  String? _extractString(
      Map<String, dynamic> data,
      List<String> keys,
      ) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return null;
  }

  double _normalizeCoordinate(double value) {
    if (value > 1) {
      if (value <= _planWidth) {
        return value / _planWidth;
      }

      if (value <= _planHeight) {
        return value / _planHeight;
      }
    }

    return value.clamp(0.0, 1.0);
  }

  int _normaliserEtage(String etage) {
    final value = etage.toLowerCase().trim();

    if (value.contains('rdc') || value == '0') return 0;
    if (value.contains('1')) return 1;
    if (value.contains('2')) return 2;
    if (value.contains('3')) return 3;
    if (value.contains('4')) return 4;

    return int.tryParse(value) ?? 2;
  }
}

class TrajectoryPainter extends CustomPainter {
  final List<Offset> points;

  TrajectoryPainter({
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final linePaint = Paint()
      ..color = const Color(0xFF1769E0)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = const Color(0x401769E0)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length - 1; i++) {
      _drawArrow(
        canvas,
        points[i],
        points[i + 1],
      );
    }

    final startPaint = Paint()
      ..color = const Color(0xFF12B76A)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.first, 9, startPaint);

    final currentPaint = Paint()
      ..color = const Color(0xFFF04438)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 10, currentPaint);

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(points.last, 4, innerPaint);
  }

  void _drawArrow(
      Canvas canvas,
      Offset from,
      Offset to,
      ) {
    final distance = (to - from).distance;

    if (distance < 20) return;

    final direction = (to - from) / distance;
    final center = Offset(
      from.dx + (to.dx - from.dx) * 0.65,
      from.dy + (to.dy - from.dy) * 0.65,
    );

    final perpendicular = Offset(
      -direction.dy,
      direction.dx,
    );

    final tip = center + direction * 9;
    final left = center - direction * 6 + perpendicular * 6;
    final right = center - direction * 6 - perpendicular * 6;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF1769E0)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant TrajectoryPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class FloorPlanPainter extends CustomPainter {
  final int etage;

  FloorPlanPainter({
    required this.etage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Offset.zero & size,
      background,
    );

    _drawGrid(canvas, size);

    if (etage == 2) {
      _drawEtageDeux(canvas, size);
    } else {
      _drawGenericFloor(canvas, size);
    }

    _drawCompass(canvas);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFEFF2F6)
      ..strokeWidth = 1;

    const grid = 40.0;

    for (double x = 0; x <= size.width; x += grid) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    for (double y = 0; y <= size.height; y += grid) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawEtageDeux(Canvas canvas, Size size) {
    final rooms = <_Room>[
      _Room(
        'Bureau 204',
        Rect.fromLTWH(45, 55, 180, 125),
        _RoomType.office,
      ),
      _Room(
        'Salle R2',
        Rect.fromLTWH(240, 55, 160, 125),
        _RoomType.meeting,
      ),
      _Room(
        'Bureau 207',
        Rect.fromLTWH(420, 55, 95, 125),
        _RoomType.office,
      ),
      _Room(
        'Bureau 208',
        Rect.fromLTWH(530, 55, 95, 125),
        _RoomType.office,
      ),
      _Room(
        'Bureau 209',
        Rect.fromLTWH(640, 55, 110, 125),
        _RoomType.office,
      ),
      _Room(
        'Bureau 211',
        Rect.fromLTWH(780, 55, 100, 125),
        _RoomType.office,
      ),
      _Room(
        'Bureau 212',
        Rect.fromLTWH(895, 55, 145, 125),
        _RoomType.office,
      ),
      _Room(
        'Bureau 213A',
        Rect.fromLTWH(420, 225, 110, 105),
        _RoomType.office,
      ),
      _Room(
        'Couloir',
        Rect.fromLTWH(80, 215, 960, 95),
        _RoomType.corridor,
      ),
      _Room(
        'Bureau 216',
        Rect.fromLTWH(650, 345, 105, 110),
        _RoomType.office,
      ),
      _Room(
        'Bureau 217',
        Rect.fromLTWH(775, 345, 105, 110),
        _RoomType.office,
      ),
      _Room(
        'Bureau 220',
        Rect.fromLTWH(45, 365, 115, 115),
        _RoomType.office,
      ),
      _Room(
        'Bureau 221',
        Rect.fromLTWH(180, 365, 115, 115),
        _RoomType.office,
      ),
      _Room(
        'Salle Réunion 215',
        Rect.fromLTWH(320, 345, 175, 135),
        _RoomType.meeting,
      ),
      _Room(
        'Bureau 222',
        Rect.fromLTWH(520, 500, 105, 115),
        _RoomType.office,
      ),
      _Room(
        'Bureau 223',
        Rect.fromLTWH(650, 500, 105, 115),
        _RoomType.office,
      ),
      _Room(
        'Bureau 242',
        Rect.fromLTWH(45, 505, 105, 110),
        _RoomType.office,
      ),
      _Room(
        'Bureau 243',
        Rect.fromLTWH(175, 505, 120, 110),
        _RoomType.office,
      ),
      _Room(
        'Bureau 245',
        Rect.fromLTWH(320, 505, 125, 110),
        _RoomType.office,
      ),
      _Room(
        'Salle Réunion 251',
        Rect.fromLTWH(465, 500, 165, 115),
        _RoomType.meeting,
      ),
      _Room(
        'Bureau 252',
        Rect.fromLTWH(780, 500, 120, 115),
        _RoomType.office,
      ),
      _Room(
        'Archive 260A',
        Rect.fromLTWH(920, 500, 120, 115),
        _RoomType.storage,
      ),
    ];

    for (final room in rooms) {
      _drawRoom(canvas, room);
    }

    _drawStairs(
      canvas,
      const Rect.fromLTWH(955, 220, 75, 90),
      'A',
    );

    _drawStairs(
      canvas,
      const Rect.fromLTWH(45, 225, 75, 80),
      'B',
    );

    _drawTitle(
      canvas,
      'PLAN INTÉRIEUR — ÉTAGE 2',
      const Offset(45, 22),
    );
  }

  void _drawGenericFloor(Canvas canvas, Size size) {
    final rows = 3;
    final columns = 6;

    final marginX = 50.0;
    final marginY = 90.0;
    final roomWidth = 145.0;
    final roomHeight = 130.0;
    final gapX = 25.0;
    final gapY = 35.0;

    for (int row = 0; row < rows; row++) {
      for (int column = 0; column < columns; column++) {
        final x = marginX + column * (roomWidth + gapX);
        final y = marginY + row * (roomHeight + gapY);

        if (x + roomWidth > size.width - 25) continue;
        if (y + roomHeight > size.height - 25) continue;

        _drawRoom(
          canvas,
          _Room(
            'Zone ${row * columns + column + 1}',
            Rect.fromLTWH(
              x,
              y,
              roomWidth,
              roomHeight,
            ),
            _RoomType.office,
          ),
        );
      }
    }

    _drawTitle(
      canvas,
      'PLAN INTÉRIEUR — ÉTAGE $etage',
      const Offset(50, 40),
    );
  }

  void _drawRoom(
      Canvas canvas,
      _Room room,
      ) {
    Color fill;
    Color border;

    switch (room.type) {
      case _RoomType.office:
        fill = const Color(0xFFFFFFFF);
        border = const Color(0xFFC8D0DA);
        break;
      case _RoomType.meeting:
        fill = const Color(0xFFF0F6FF);
        border = const Color(0xFF9DBBE8);
        break;
      case _RoomType.corridor:
        fill = const Color(0xFFF2F4F7);
        border = const Color(0xFFD5DAE1);
        break;
      case _RoomType.storage:
        fill = const Color(0xFFFFF8ED);
        border = const Color(0xFFE6C68A);
        break;
    }

    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rounded = RRect.fromRectAndRadius(
      room.rect,
      const Radius.circular(5),
    );

    canvas.drawRRect(rounded, fillPaint);
    canvas.drawRRect(rounded, borderPaint);

    _drawCenteredText(
      canvas,
      room.name,
      room.rect.center,
      fontSize: room.name.length > 16 ? 9 : 10,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF667085),
    );
  }

  void _drawStairs(
      Canvas canvas,
      Rect rect,
      String label,
      ) {
    final paint = Paint()
      ..color = const Color(0xFFE3E7EC)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = const Color(0xFF98A2B3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRect(rect, paint);
    canvas.drawRect(rect, border);

    for (double y = rect.top + 10;
    y < rect.bottom - 5;
    y += 10) {
      canvas.drawLine(
        Offset(rect.left + 7, y),
        Offset(rect.right - 7, y),
        border,
      );
    }

    _drawCenteredText(
      canvas,
      'Escalier $label',
      rect.center,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF667085),
    );
  }

  void _drawTitle(
      Canvas canvas,
      String text,
      Offset position,
      ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF344054),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    painter.layout();
    painter.paint(canvas, position);
  }

  void _drawCompass(Canvas canvas) {
    const center = Offset(1010, 35);

    final paint = Paint()
      ..color = const Color(0xFF667085)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 18, paint);

    final north = Path()
      ..moveTo(center.dx, center.dy - 13)
      ..lineTo(center.dx - 5, center.dy + 3)
      ..lineTo(center.dx, center.dy)
      ..lineTo(center.dx + 5, center.dy + 3)
      ..close();

    canvas.drawPath(
      north,
      Paint()
        ..color = const Color(0xFF1769E0)
        ..style = PaintingStyle.fill,
    );

    _drawCenteredText(
      canvas,
      'N',
      Offset(center.dx, center.dy - 27),
      fontSize: 9,
      fontWeight: FontWeight.w800,
      color: const Color(0xFF344054),
    );
  }

  void _drawCenteredText(
      Canvas canvas,
      String text,
      Offset center, {
        required double fontSize,
        required FontWeight fontWeight,
        required Color color,
      }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 2,
      ellipsis: '…',
    );

    painter.layout(maxWidth: 130);

    painter.paint(
      canvas,
      Offset(
        center.dx - painter.width / 2,
        center.dy - painter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant FloorPlanPainter oldDelegate) {
    return oldDelegate.etage != etage;
  }
}

enum _RoomType {
  office,
  meeting,
  corridor,
  storage,
}

class _Room {
  final String name;
  final Rect rect;
  final _RoomType type;

  const _Room(
      this.name,
      this.rect,
      this.type,
      );
}

class _MaterialMarker extends StatefulWidget {
  final Materiel materiel;
  final bool selected;

  const _MaterialMarker({
    required this.materiel,
    required this.selected,
  });

  @override
  State<_MaterialMarker> createState() => _MaterialMarkerState();
}

class _MaterialMarkerState extends State<_MaterialMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (_isMoving) {
      _controller.repeat();
    }
  }

  bool get _isMoving {
    return widget.materiel.localisationInterieure?.statut ==
        StatutDeplacement.enMouvement;
  }

  @override
  void didUpdateWidget(covariant _MaterialMarker oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isMoving && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!_isMoving && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _statusColor() {
    final status =
        widget.materiel.localisationInterieure?.statut;

    switch (status) {
      case StatutDeplacement.enMouvement:
        return const Color(0xFFF79009);
      case StatutDeplacement.horsLigne:
        return const Color(0xFFF04438);
      case StatutDeplacement.statique:
      default:
        return const Color(0xFF12B76A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return SizedBox(
      width: 50,
      height: 50,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = _isMoving
              ? 1 + math.sin(_controller.value * math.pi * 2) * 0.15
              : 1.0;

          return Stack(
            alignment: Alignment.center,
            children: [
              if (_isMoving)
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withOpacity(0.25),
                        width: 5,
                      ),
                    ),
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: widget.selected ? 38 : 32,
                height: widget.selected ? 38 : 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: widget.selected ? 4 : 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.35),
                      blurRadius: widget.selected ? 14 : 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.devices,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WifiStatusBadge extends StatelessWidget {
  final WifiState? wifiState;

  const _WifiStatusBadge({
    required this.wifiState,
  });

  @override
  Widget build(BuildContext context) {
    final connected = wifiState?.isConnected ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: connected
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFFF3F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: connected
              ? const Color(0xFFA6F4C5)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.wifi : Icons.wifi_off,
            size: 17,
            color: connected
                ? const Color(0xFF039855)
                : const Color(0xFFD92D20),
          ),
          const SizedBox(width: 7),
          Text(
            connected
                ? (wifiState?.ssid ?? 'Wi-Fi connecté')
                : 'Wi-Fi indisponible',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: connected
                  ? const Color(0xFF027A48)
                  : const Color(0xFFB42318),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFE8ECF1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: const Color(0xFF1769E0),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF98A2B3),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  final bool active;
  final String label;

  const _LiveIndicator({
    required this.active,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF12B76A)
                : const Color(0xFFF04438),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: active
                ? const Color(0xFF027A48)
                : const Color(0xFFB42318),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF667085),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 17,
            color: const Color(0xFF98A2B3),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF667085),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final LocalisationInterieure localisation;

  const _StatusCard({
    required this.localisation,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String label;

    switch (localisation.statut) {
      case StatutDeplacement.enMouvement:
        color = const Color(0xFFF79009);
        icon = Icons.directions_run;
        label = 'En mouvement';
        break;

      case StatutDeplacement.horsLigne:
        color = const Color(0xFFF04438);
        icon = Icons.signal_wifi_off;
        label = 'Hors ligne';
        break;

      case StatutDeplacement.statique:
        color = const Color(0xFF12B76A);
        icon = Icons.location_on;
        label = 'Statique';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: color,
          ),
          const SizedBox(width: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          if (localisation.methode ==
              MethodeDetection.wifi)
            const Icon(
              Icons.wifi,
              size: 16,
              color: Color(0xFF667085),
            ),
        ],
      ),
    );
  }
}

class _ErreurView extends StatelessWidget {
  final String message;

  const _ErreurView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(0xFFD92D20),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}