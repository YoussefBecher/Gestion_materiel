import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../materiel/ajouter_materiel_screen.dart';
import '../materiel/liste_materiels_screen.dart';
import '../materiel/scanner_screen.dart';
import '../materiel/localisation_temps_reel_screen.dart';
import '../stats/statistiques_screen.dart';
import '../admin/historique_screen.dart';
import '../employes/employes_list_screen.dart';

// ===============================================================
// COULEURS DE L'APPLICATION
// ===============================================================

class AppColors {
  static const primary = Color(0xFF003087);
  static const primaryLight = Color(0xFF1C5EC9);
  static const background = Color(0xFFF3F5F9);

  static const sectionMateriel = Color(0xFF1565C0);
  static const sectionRH = Color(0xFF6A1B9A);
  static const sectionSuivi = Color(0xFF00796B);

  static const statOk = Color(0xFF6FE29A);
  static const statUsage = Color(0xFFFFC26F);
  static const statPanne = Color(0xFFFF8A80);
}

// ===============================================================
// COLLECTIONS FIRESTORE
// ===============================================================

class FirestoreCollections {
  static const materiels = 'materiels';
}

// ===============================================================
// ÉTATS DU MATÉRIEL
// ===============================================================

enum EtatMateriel {
  disponible('Disponible'),
  enUtilisation('En utilisation'),
  enPanne('En panne');

  final String label;

  const EtatMateriel(this.label);

  static EtatMateriel? fromLabel(String? label) {
    for (final etat in EtatMateriel.values) {
      if (etat.label == label) {
        return etat;
      }
    }

    return null;
  }
}

// ===============================================================
// HOME SCREEN
// ===============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  // =============================================================
  // BUILD
  // =============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ---------------------------------------------------------
      // APP BAR
      // ---------------------------------------------------------

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,

        titleSpacing: 16,

        title: Row(
          children: [
            Image.asset(
              'assets/logo_biat.png',
              height: 30,
              errorBuilder: (
                  context,
                  error,
                  stackTrace,
                  ) {
                return const Icon(
                  Icons.account_balance_rounded,
                  size: 26,
                );
              },
            ),

            const SizedBox(width: 10),

            const Text(
              'Gestion Matériel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
            ),
            tooltip: 'Déconnexion',
            onPressed: () => _deconnexion(context),
          ),
        ],
      ),

      // ---------------------------------------------------------
      // CORPS
      // ---------------------------------------------------------

      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // =====================================================
            // EN-TÊTE DU DASHBOARD
            // =====================================================

            _buildDashboardHeader(),

            // =====================================================
            // SECTIONS
            // =====================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                20,
                16,
                24,
              ),

              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  // ------------------------------------------------
                  // GESTION DU MATÉRIEL
                  // ------------------------------------------------

                  _buildSection(
                    title: 'Gestion du matériel',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.sectionMateriel,

                    items: [

                      _ActionItem(
                        'Liste des matériels',
                        Icons.list_alt_rounded,
                            () {
                          _navigate(
                            const ListeMaterielsScreen(),
                          );
                        },
                      ),

                      _ActionItem(
                        'Scanner QR Code',
                        Icons.qr_code_scanner_rounded,
                            () {
                          _navigate(
                            const ScannerScreen(),
                          );
                        },
                      ),

                      _ActionItem(
                        'Ajouter un matériel',
                        Icons.add_box_rounded,
                            () {
                          _navigate(
                            const AjouterMaterielScreen(),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // RESSOURCES HUMAINES
                  // ------------------------------------------------

                  _buildSection(
                    title: 'Ressources humaines',
                    icon: Icons.badge_rounded,
                    color: AppColors.sectionRH,

                    items: [

                      _ActionItem(
                        'Gestion Employés',
                        Icons.people_rounded,
                            () {
                          _navigate(
                            const EmployesListScreen(),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ------------------------------------------------
                  // SUIVI ET ANALYSE
                  // ------------------------------------------------

                  _buildSection(
                    title: 'Suivi & Analyse',
                    icon: Icons.insights_rounded,
                    color: AppColors.sectionSuivi,

                    items: [

                      _ActionItem(
                        'Localisation en temps réel',
                        Icons.wifi_tethering_rounded,
                            () {
                          _navigate(
                            const LocalisationTempsReelScreen(),
                          );
                        },
                      ),

                      _ActionItem(
                        'Statistiques',
                        Icons.bar_chart_rounded,
                            () {
                          _navigate(
                            const StatistiquesScreen(),
                          );
                        },
                      ),

                      _ActionItem(
                        'Historique',
                        Icons.history_rounded,
                            () {
                          _navigate(
                            const HistoriqueScreen(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // NAVIGATION
  // ===============================================================

  void _navigate(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  // ===============================================================
  // DÉCONNEXION
  // ===============================================================

  Future<void> _deconnexion(
      BuildContext context,
      ) async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de la déconnexion : $e',
          ),
        ),
      );
    }
  }

  // ===============================================================
  // HEADER DASHBOARD
  // ===============================================================

  Widget _buildDashboardHeader() {
    return Container(
      width: double.infinity,

      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryLight,
          ],

          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),

      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        28,
      ),

      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          const Text(
            'Tableau de bord',

            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Vue d\'ensemble du parc matériel',

            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
            ),
          ),

          const SizedBox(height: 18),

          // =====================================================
          // STATISTIQUES FIRESTORE
          // =====================================================

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore
                .instance
                .collection(
              FirestoreCollections.materiels,
            )
                .snapshots(),

            builder: (
                context,
                snapshot,
                ) {

              // -------------------------------------------------
              // CHARGEMENT
              // -------------------------------------------------

              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const SizedBox(
                  height: 78,

                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,

                      child:
                      CircularProgressIndicator(
                        strokeWidth: 2.2,

                        valueColor:
                        AlwaysStoppedAnimation(
                          Colors.white70,
                        ),
                      ),
                    ),
                  ),
                );
              }

              // -------------------------------------------------
              // ERREUR
              // -------------------------------------------------

              if (snapshot.hasError) {
                return Container(
                  padding:
                  const EdgeInsets.all(12),

                  decoration:
                  BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha: 0.08,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),

                  child: const Row(
                    children: [

                      Icon(
                        Icons
                            .error_outline_rounded,
                        color:
                        AppColors.statPanne,
                        size: 18,
                      ),

                      SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Impossible de charger les statistiques',

                          style: TextStyle(
                            color:
                            Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // -------------------------------------------------
              // CALCUL DES STATISTIQUES
              // -------------------------------------------------

              int total = 0;
              int disponible = 0;
              int enUtilisation = 0;
              int enPanne = 0;

              if (snapshot.hasData) {
                final docs =
                    snapshot.data!.docs;

                total = docs.length;

                for (final doc in docs) {
                  final data =
                  doc.data()
                  as Map<String, dynamic>?;

                  final etat =
                  EtatMateriel.fromLabel(
                    data?['etat'] as String?,
                  );

                  switch (etat) {
                    case EtatMateriel.disponible:
                      disponible++;
                      break;

                    case EtatMateriel.enUtilisation:
                      enUtilisation++;
                      break;

                    case EtatMateriel.enPanne:
                      enPanne++;
                      break;

                    case null:
                      break;
                  }
                }
              }

              // -------------------------------------------------
              // CARTES
              // -------------------------------------------------

              return Row(
                children: [

                  _buildStatCard(
                    'Total',
                    total,
                    Icons.computer_rounded,
                    Colors.white,
                  ),

                  const SizedBox(width: 10),

                  _buildStatCard(
                    'Disponibles',
                    disponible,
                    Icons.check_circle_rounded,
                    AppColors.statOk,
                  ),

                  const SizedBox(width: 10),

                  _buildStatCard(
                    'En usage',
                    enUtilisation,
                    Icons.person_rounded,
                    AppColors.statUsage,
                  ),

                  const SizedBox(width: 10),

                  _buildStatCard(
                    'En panne',
                    enPanne,
                    Icons.warning_rounded,
                    AppColors.statPanne,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // CARTE STATISTIQUE
  // ===============================================================

  Widget _buildStatCard(
      String label,
      int value,
      IconData icon,
      Color accentColor,
      ) {
    return Expanded(
      child: Container(
        padding:
        const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),

        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: 0.08,
          ),

          borderRadius:
          BorderRadius.circular(14),

          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.12,
            ),
          ),
        ),

        child: Column(
          children: [

            Icon(
              icon,
              color: accentColor,
              size: 20,
            ),

            const SizedBox(height: 6),

            Text(
              '$value',

              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              textAlign: TextAlign.center,

              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // SECTION
  // ===============================================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<_ActionItem> items,
  }) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [

        // ---------------------------------------------------------
        // TITRE
        // ---------------------------------------------------------

        Row(
          children: [

            Container(
              padding:
              const EdgeInsets.all(7),

              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.1,
                ),

                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),

              child: Icon(
                icon,
                color: color,
                size: 17,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              title,

              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ---------------------------------------------------------
        // LISTE DES ACTIONS
        // ---------------------------------------------------------

        Container(
          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius:
            BorderRadius.circular(
              14,
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.04,
                ),

                blurRadius: 10,

                offset:
                const Offset(0, 3),
              ),
            ],
          ),

          child: Column(
            children: items
                .asMap()
                .entries
                .map(
                  (entry) {

                final index =
                    entry.key;

                final item =
                    entry.value;

                final isLast =
                    index ==
                        items.length - 1;

                return Column(
                  children: [

                    _buildActionTile(
                      item,
                      color,
                    ),

                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 56,
                        color:
                        Colors.grey.shade100,
                      ),
                  ],
                );
              },
            )
                .toList(),
          ),
        ),
      ],
    );
  }

  // ===============================================================
  // ACTION TILE
  // ===============================================================

  Widget _buildActionTile(
      _ActionItem item,
      Color accentColor,
      ) {
    return Semantics(
      button: true,
      label: item.title,

      child: InkWell(
        borderRadius:
        BorderRadius.circular(14),

        onTap: item.onTap,

        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),

          child: Row(
            children: [

              // ---------------------------------------------------
              // ICÔNE
              // ---------------------------------------------------

              Container(
                padding:
                const EdgeInsets.all(8),

                decoration:
                BoxDecoration(
                  color:
                  accentColor.withValues(
                    alpha: 0.08,
                  ),

                  borderRadius:
                  BorderRadius.circular(
                    9,
                  ),
                ),

                child: Icon(
                  item.icon,
                  color: accentColor,
                  size: 19,
                ),
              ),

              const SizedBox(width: 13),

              // ---------------------------------------------------
              // TITRE
              // ---------------------------------------------------

              Expanded(
                child: Text(
                  item.title,

                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ),

              // ---------------------------------------------------
              // FLÈCHE
              // ---------------------------------------------------

              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===============================================================
// MODÈLE ACTION
// ===============================================================

class _ActionItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _ActionItem(
      this.title,
      this.icon,
      this.onTap,
      );
}