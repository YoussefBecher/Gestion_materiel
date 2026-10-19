import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/localisation_auto_service.dart';

/// Nom de la collection Firestore.
const String _materielsCollection = 'materiels';

class LiveTrackingScreen extends ConsumerStatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  ConsumerState<LiveTrackingScreen> createState() =>
      _LiveTrackingScreenState();
}

class _LiveTrackingScreenState
    extends ConsumerState<LiveTrackingScreen> {
  bool _demarrageEnCours = true;
  String? _erreurLocalisation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _demarrerLocalisation();
    });
  }

  // ===============================================================
  // DÉMARRAGE LOCALISATION
  // ===============================================================

  Future<void> _demarrerLocalisation() async {
    try {
      final service =
      ref.read(localisationAutoServiceProvider);

      if (!service.localisationActive) {
        await service.demarrerLocalisationAutomatique();
      }

      if (!mounted) return;

      setState(() {
        _demarrageEnCours = false;
        _erreurLocalisation = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _demarrageEnCours = false;
        _erreurLocalisation =
        'Impossible de démarrer la localisation Wi-Fi.';
      });
    }
  }

  // ===============================================================
  // DÉTECTION FORCÉE
  // ===============================================================

  Future<void> _forcerDetection() async {
    try {
      final service =
      ref.read(localisationAutoServiceProvider);

      await service.detecterEtMettreAJour();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Détection Wi-Fi effectuée.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erreur pendant la détection Wi-Fi.',
          ),
        ),
      );
    }
  }

  // ===============================================================
  // COULEUR ÉTAT DU MATÉRIEL
  // ===============================================================

  Color _statusColor(String? etat) {
    switch (etat) {
      case 'En panne':
        return Colors.red;

      case 'En utilisation':
        return Colors.orange;

      case 'Disponible':
        return Colors.green;

      case 'En maintenance':
        return Colors.purple;

      default:
        return Colors.blueGrey;
    }
  }

  // ===============================================================
  // FORMAT DATE
  // ===============================================================

  String _formatDate(dynamic timestamp) {
    if (timestamp == null ||
        timestamp is! Timestamp) {
      return '-';
    }

    return DateFormat(
      'dd/MM/yyyy à HH:mm',
    ).format(
      timestamp.toDate(),
    );
  }

  // ===============================================================
  // FRAÎCHEUR
  // ===============================================================

  ({
  String label,
  Color color,
  }) _freshness(dynamic timestamp) {
    if (timestamp == null ||
        timestamp is! Timestamp) {
      return (
      label: 'Date inconnue',
      color: Colors.grey,
      );
    }

    final DateTime date =
    timestamp.toDate();

    final Duration diff =
    DateTime.now().difference(date);

    if (diff.isNegative) {
      return (
      label: 'À jour',
      color: Colors.green,
      );
    }

    if (diff.inMinutes < 30) {
      return (
      label: 'À jour',
      color: Colors.green,
      );
    }

    if (diff.inHours < 24) {
      final int h =
      diff.inHours < 1
          ? diff.inMinutes
          : diff.inHours;

      final String unite =
      diff.inHours < 1
          ? 'min'
          : 'h';

      return (
      label: 'Il y a $h $unite',
      color: Colors.orange,
      );
    }

    return (
    label: 'Obsolète • il y a ${diff.inDays} j',
    color: Colors.red,
    );
  }

  // ===============================================================
  // TRI ÉTAGE
  // ===============================================================

  int _etageOrdre(String etage) {
    final Match? match =
    RegExp(r'\d+').firstMatch(etage);

    if (match == null) {
      final String valeur =
      etage.toLowerCase();

      if (valeur.contains('rdc')) {
        return -1;
      }

      return 999;
    }

    return int.tryParse(
      match.group(0)!,
    ) ??
        999;
  }

  // ===============================================================
  // NOM AFFICHAGE
  // ===============================================================

  ({
  String label,
  bool manquant,
  }) _nomAffichage(
      String? marque,
      String? type,
      ) {
    final String m =
        marque?.trim() ?? '';

    final String t =
        type?.trim() ?? '';

    if (m.isEmpty && t.isEmpty) {
      return (
      label: 'Nom non renseigné',
      manquant: true,
      );
    }

    if (m.isEmpty) {
      return (
      label: t,
      manquant: false,
      );
    }

    if (t.isEmpty) {
      return (
      label: m,
      manquant: false,
      );
    }

    return (
    label: '$m — $t',
    manquant: false,
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final service =
    ref.watch(
      localisationAutoServiceProvider,
    );

    return Scaffold(
      backgroundColor:
      const Color(0xFFF0F4F8),

      appBar: AppBar(
        backgroundColor:
        const Color(0xFF003087),
        foregroundColor: Colors.white,

        title: const Text(
          'Localisation intérieure',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip:
            'Forcer une détection',
            onPressed:
            _demarrageEnCours
                ? null
                : _forcerDetection,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          _buildStatutLocalisation(
            service,
          ),

          if (_erreurLocalisation != null)
            _buildErreurLocalisation(),

          Expanded(
            child:
            _buildListeLocalisation(),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // BARRE STATUT LOCALISATION
  // ===============================================================

  Widget _buildStatutLocalisation(
      LocalisationAutoService service,
      ) {
    final bool active =
        service.localisationActive;

    final String ssid =
        service.dernierSsid ?? '-';

    final String bssid =
        service.dernierBssid ?? '-';

    final String derniereDetection =
    service.derniereDetection == null
        ? 'Aucune détection'
        : DateFormat(
      'HH:mm:ss',
    ).format(
      service.derniereDetection!,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        12,
        12,
        12,
        4,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                active
                    ? Icons.wifi
                    : Icons.wifi_off,
                color: active
                    ? Colors.green
                    : Colors.orange,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  active
                      ? 'Localisation Wi-Fi active'
                      : 'Localisation Wi-Fi inactive',
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    color: active
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                  ),
                ),
              ),

              if (_demarrageEnCours)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),

          if (active) ...[
            const SizedBox(height: 8),

            Text(
              'SSID : $ssid',
              style: const TextStyle(
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              'BSSID : $bssid',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              'Dernière détection : $derniereDetection',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===============================================================
  // ERREUR
  // ===============================================================

  Widget _buildErreurLocalisation() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _erreurLocalisation!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // LISTE
  // ===============================================================

  Widget _buildListeLocalisation() {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore
          .instance
          .collection(
        _materielsCollection,
      )
          .snapshots(),

      builder: (
          context,
          snapshot,
          ) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child:
            CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _buildErreurListe();
        }

        final docs =
            snapshot.data?.docs ?? [];

        final List<
            QueryDocumentSnapshot<
                Map<String, dynamic>>>
        avecLocalisation = [];

        for (final doc in docs) {
          final Map<String, dynamic>
          data = doc.data();

          final dynamic rawLoc =
          data[
          'localisationInterieure'];

          final Map<String, dynamic>?
          loc = _extraireMap(rawLoc);

          if (loc != null &&
              (loc['zone'] ?? '')
                  .toString()
                  .trim()
                  .isNotEmpty) {
            avecLocalisation.add(doc);
          }
        }

        if (avecLocalisation.isEmpty) {
          return _buildAucuneLocalisation();
        }

        final Map<
            String,
            List<
                QueryDocumentSnapshot<
                    Map<String, dynamic>>>>
        parEtage = {};

        for (final doc
        in avecLocalisation) {
          final Map<String, dynamic>
          data = doc.data();

          final Map<String, dynamic>
          loc =
              _extraireMap(
                data[
                'localisationInterieure'],
              ) ??
                  <String, dynamic>{};

          final String etage =
          (loc['etage'] ??
              'Étage inconnu')
              .toString();

          parEtage
              .putIfAbsent(
            etage,
                () => [],
          )
              .add(doc);
        }

        final List<String> etages =
        parEtage.keys.toList()
          ..sort(
                (a, b) =>
                _etageOrdre(a)
                    .compareTo(
                  _etageOrdre(b),
                ),
          );

        return ListView.builder(
          padding:
          const EdgeInsets.only(
            bottom: 16,
          ),
          itemCount: etages.length,
          itemBuilder: (
              context,
              index,
              ) {
            final String etage =
            etages[index];

            final materiels =
            parEtage[etage]!;

            return Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Container(
                  width:
                  double.infinity,
                  color:
                  const Color(
                    0xFF003087,
                  ),
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    '$etage  •  ${materiels.length} équipement${materiels.length > 1 ? 's' : ''}',
                    style:
                    const TextStyle(
                      color: Colors.white,
                      fontWeight:
                      FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),

                ...materiels.map(
                  _buildCarteMateriel,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===============================================================
  // ERREUR LISTE
  // ===============================================================

  Widget _buildErreurListe() {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons
                  .error_outline_rounded,
              size: 56,
              color:
              Colors.red.shade300,
            ),

            const SizedBox(
              height: 16,
            ),

            const Text(
              'Impossible de charger les localisations.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Vérifie ta connexion internet et réessaie.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color:
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // AUCUNE LOCALISATION
  // ===============================================================

  Widget _buildAucuneLocalisation() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding:
              const EdgeInsets.all(24),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_find,
                    size: 64,
                    color:
                    Colors.grey.shade400,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  Text(
                    'Aucun équipement localisé pour le moment.',
                    textAlign:
                    TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Container(
          padding:
          const EdgeInsets.all(14),
          color:
          Colors.orange.shade50,
          child: const Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange,
              ),

              SizedBox(width: 8),

              Expanded(
                child: Text(
                  'La localisation se met à jour automatiquement lorsque le téléphone est connecté à un Wi-Fi configuré dans zones_wifi.',
                  style:
                  TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // CARTE MATÉRIEL
  // ===============================================================

  Widget _buildCarteMateriel(
      QueryDocumentSnapshot<
          Map<String, dynamic>> doc,
      ) {
    final Map<String, dynamic>
    data = doc.data();

    final Map<String, dynamic>
    loc =
        _extraireMap(
          data[
          'localisationInterieure'],
        ) ??
            <String, dynamic>{};

    final String marque =
        data['marque']
            ?.toString() ??
            '-';

    final String type =
        data['type']
            ?.toString() ??
            '-';

    final nomInfo =
    _nomAffichage(
      data['marque']?.toString(),
      data['type']?.toString(),
    );

    final String nom =
        nomInfo.label;

    final bool nomManquant =
        nomInfo.manquant;

    final String? etat =
    data['etat']?.toString();

    final String bureau =
        data['bureau']
            ?.toString() ??
            '-';

    final String departement =
        data['departement']
            ?.toString() ??
            '-';

    final String responsable =
        data['responsable']
            ?.toString() ??
            '-';

    final String zone =
        loc['zone']
            ?.toString() ??
            '-';

    final String batiment =
        loc['batiment']
            ?.toString() ??
            '-';

    final String etage =
        loc['etage']
            ?.toString() ??
            '-';

    final String ssid =
        loc['ssid']
            ?.toString() ??
            '-';

    final String bssid =
        loc['bssid']
            ?.toString() ??
            '-';

    final double? positionX =
    _extraireDouble(
      loc['positionX'],
    );

    final double? positionY =
    _extraireDouble(
      loc['positionY'],
    );

    final bool mouvement =
        loc['mouvementDetecte'] ==
            true ||
            loc['statut'] ==
                'enMouvement';

    final dynamic rawTimestamp =
    loc['derniereMiseAJour'];

    final String derniereMaj =
    _formatDate(
      rawTimestamp,
    );

    final fraicheur =
    _freshness(
      rawTimestamp,
    );

    final Color color =
    _statusColor(etat);

    return Card(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      elevation: 1,
      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),

        leading: CircleAvatar(
          backgroundColor:
          color.withValues(
            alpha: 0.15,
          ),
          child: Icon(
            mouvement
                ? Icons
                .directions_walk
                : Icons.location_pin,
            color: color,
          ),
        ),

        title: Row(
          children: [
            Flexible(
              child: Text(
                nom,
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  fontStyle:
                  nomManquant
                      ? FontStyle.italic
                      : FontStyle.normal,
                  color:
                  nomManquant
                      ? Colors
                      .grey
                      .shade600
                      : Colors.black,
                ),
              ),
            ),

            if (mouvement) ...[
              const SizedBox(width: 6),

              Icon(
                Icons
                    .directions_walk,
                size: 16,
                color:
                Colors.orange.shade700,
              ),
            ],
          ],
        ),

        subtitle: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              '$zone  •  $batiment  •  $etage',
            ),

            const SizedBox(height: 3),

            Row(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color:
                  fraicheur.color,
                ),

                const SizedBox(
                  width: 4,
                ),

                Text(
                  fraicheur.label,
                  style: TextStyle(
                    fontSize: 11,
                    color:
                    fraicheur.color,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),

            if (positionX != null &&
                positionY != null)
              Text(
                'Position : ${(positionX * 100).toStringAsFixed(1)}% × ${(positionY * 100).toStringAsFixed(1)}%',
                style:
                const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
          ],
        ),

        isThreeLine: true,

        trailing: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration:
          BoxDecoration(
            color:
            color.withValues(
              alpha: 0.1,
            ),
            borderRadius:
            BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: color,
            ),
          ),
          child: Text(
            mouvement
                ? 'En mouvement'
                : (etat ?? '-'),
            style: TextStyle(
              color: mouvement
                  ? Colors.orange
                  : color,
              fontSize: 11,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),

        onTap: () =>
            _showInfoLocalisation(
              context,
              nom: nom,
              nomManquant:
              nomManquant,
              etat: etat,
              marque: marque,
              type: type,
              bureau: bureau,
              departement:
              departement,
              responsable:
              responsable,
              zone: zone,
              batiment: batiment,
              etage: etage,
              ssid: ssid,
              bssid: bssid,
              positionX: positionX,
              positionY: positionY,
              mouvement: mouvement,
              derniereMaj:
              derniereMaj,
              fraicheur:
              fraicheur,
            ),
      ),
    );
  }

  // ===============================================================
  // DÉTAILS
  // ===============================================================

  void _showInfoLocalisation(
      BuildContext context, {
        required String nom,
        bool nomManquant = false,
        String? etat,
        String? marque,
        String? type,
        String? bureau,
        String? departement,
        String? responsable,
        String? zone,
        String? batiment,
        String? etage,
        String? ssid,
        String? bssid,
        double? positionX,
        double? positionY,
        bool mouvement = false,
        String? derniereMaj,
        ({
        String label,
        Color color,
        })? fraicheur,
      }) {
    final Color color =
    _statusColor(etat);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape:
      const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) =>
          DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (
                context,
                scrollController,
                ) =>
                SingleChildScrollView(
                  controller:
                  scrollController,
                  padding:
                  const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .grey.shade300,
                            borderRadius:
                            BorderRadius.circular(
                              2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              nom,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight.bold,
                                fontStyle:
                                nomManquant
                                    ? FontStyle
                                    .italic
                                    : FontStyle
                                    .normal,
                                color:
                                nomManquant
                                    ? Colors
                                    .grey
                                    .shade600
                                    : Colors.black,
                              ),
                            ),
                          ),

                          if (mouvement)
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Colors
                                    .orange
                                    .withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  20,
                                ),
                              ),
                              child:
                              const Text(
                                'En mouvement',
                                style: TextStyle(
                                  color:
                                  Colors.orange,
                                  fontWeight:
                                  FontWeight
                                      .w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      const Divider(),

                      const SizedBox(
                        height: 8,
                      ),

                      _infoTile(
                        Icons
                            .branding_watermark,
                        'Marque',
                        marque ?? '-',
                      ),

                      _infoTile(
                        Icons.category,
                        'Type',
                        type ?? '-',
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Divider(),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Localisation intérieure (Wi-Fi)',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          Color(0xFF003087),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _infoTile(
                        Icons.apartment,
                        'Bâtiment',
                        batiment ?? '-',
                      ),

                      _infoTile(
                        Icons.layers,
                        'Étage',
                        etage ?? '-',
                      ),

                      _infoTile(
                        Icons.room,
                        'Zone',
                        zone ?? '-',
                      ),

                      _infoTile(
                        Icons.wifi,
                        'SSID',
                        ssid ?? '-',
                      ),

                      _infoTile(
                        Icons.router,
                        'BSSID',
                        bssid ?? '-',
                      ),

                      if (positionX != null &&
                          positionY != null) ...[
                        _infoTile(
                          Icons
                              .my_location,
                          'Position',
                          '${(positionX * 100).toStringAsFixed(1)}% × ${(positionY * 100).toStringAsFixed(1)}%',
                        ),
                      ],

                      _infoTile(
                        Icons.access_time,
                        'Dernière mise à jour',
                        derniereMaj ?? '-',
                      ),

                      if (fraicheur != null)
                        Padding(
                          padding:
                          const EdgeInsets
                              .only(
                            top: 4,
                            left: 28,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color:
                                fraicheur.color,
                              ),
                              const SizedBox(
                                width: 6,
                              ),
                              Text(
                                fraicheur.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                  fraicheur.color,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Divider(),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Affectation',
                        style: TextStyle(
                          fontWeight:
                          FontWeight.bold,
                          color:
                          Color(0xFF003087),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      _infoTile(
                        Icons.apartment,
                        'Département',
                        departement ?? '-',
                      ),

                      _infoTile(
                        Icons.room,
                        'Bureau',
                        bureau ?? '-',
                      ),

                      _infoTile(
                        Icons.person,
                        'Responsable',
                        responsable ?? '-',
                      ),

                      const SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  // ===============================================================
  // INFO TILE
  // ===============================================================

  Widget _infoTile(
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding:
      const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color:
            const Color(0xFF003087),
          ),

          const SizedBox(
            width: 10,
          ),

          Text(
            '$label : ',
            style:
            const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
              const TextStyle(
                fontWeight:
                FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // EXTRAIRE MAP
  // ===============================================================

  Map<String, dynamic>? _extraireMap(
      dynamic value,
      ) {
    if (value
    is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>
          .from(value);
    }

    return null;
  }

  // ===============================================================
  // EXTRAIRE DOUBLE
  // ===============================================================

  double? _extraireDouble(
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

  // ===============================================================
  // DISPOSE
  // ===============================================================

  @override
  void dispose() {
    final service = ref.read(localisationAutoServiceProvider);
    service.arreterLocalisationAutomatique();

    super.dispose();
  }
}