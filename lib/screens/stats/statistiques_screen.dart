import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/materiel.dart';
import '../../services/materiel_service.dart';
import '../../utils/etat_utils.dart';

class StatistiquesScreen extends StatelessWidget {
  const StatistiquesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF003087),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Tableau de bord analytique',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: StreamBuilder<List<Materiel>>(
        stream: MaterielService().streamMateriels(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF003087)));
          }

          final materiels = snapshot.data ?? [];

          if (materiels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 84, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('Aucune donnée disponible',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                ],
              ),
            );
          }

          final total = materiels.length;
          final parEtat = <String, List<Materiel>>{};
          for (final e in EtatUtils.tousLesEtats) {
            parEtat[e] = materiels.where((m) => m.etat == e).toList();
          }
          final disponible = parEtat['Disponible']!.length;
          final enUtilisation = parEtat['En utilisation']!.length;
          final enPanne = parEtat['En panne']!.length;
          final enMaintenance = parEtat['En maintenance']!.length;

          final parType = <String, int>{};
          for (final m in materiels) {
            parType[m.type] = (parType[m.type] ?? 0) + 1;
          }

          final parAgence = <String, int>{};
          for (final m in materiels) {
            if (m.agence.isNotEmpty) {
              parAgence[m.agence] = (parAgence[m.agence] ?? 0) + 1;
            }
          }

          final enCours = parEtat['En utilisation']!;
          final now = DateTime.now();
          final retardes = enCours.where((m) => m.estEnRetard).toList();
          final demain = enCours.where((m) {
            if (m.dateRetour == null) return false;
            final diff = m.dateRetour!.difference(now).inDays;
            return diff == 0 || diff == 1;
          }).toList();
          final semaine = enCours.where((m) {
            if (m.dateRetour == null) return false;
            final diff = m.dateRetour!.difference(now).inDays;
            return diff > 1 && diff <= 7;
          }).toList();

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(total, disponible, enUtilisation, enPanne, enMaintenance),
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        _buildRepartitionCard(disponible, enUtilisation, enPanne, enMaintenance, total),
                        const SizedBox(height: 14),
                        _buildDisponibiliteCard(disponible, enUtilisation, enPanne, enMaintenance, total),
                        const SizedBox(height: 14),
                        _buildPredictionCard(retardes, demain, semaine),
                        const SizedBox(height: 14),
                        _buildTendanceCard(enPanne, total),
                        if (parType.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildRepartitionListeCard(
                            title: 'Matériels par type',
                            icon: Icons.category_rounded,
                            data: parType,
                            total: total,
                            color: const Color(0xFF003087),
                          ),
                        ],
                        if (parAgence.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _buildRepartitionListeCard(
                            title: 'Répartition par agence',
                            icon: Icons.business_rounded,
                            data: parAgence,
                            total: total,
                            color: const Color(0xFF009688),
                            suffixLabel: 'matériels',
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header dégradé avec chiffres clés ─────────────────────
  Widget _buildHeader(int total, int disponible, int enUtilisation, int enPanne, int enMaintenance) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF003087), Color(0xFF1C5EC9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(
              '${value.round()}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 58, fontWeight: FontWeight.w800, height: 1),
            ),
          ),
          const SizedBox(height: 4),
          const Text('matériels enregistrés',
              style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.2)),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _headerStat('Disponibles', disponible, const Color(0xFF6FE29A)),
              _headerStat('Utilisation', enUtilisation, const Color(0xFFFFC26F)),
              _headerStat('En panne', enPanne, const Color(0xFFFF8A80)),
              _headerStat('Maintenance', enMaintenance, const Color(0xFFCE93D8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  // ─── Card wrapper commun ─────────────────────────────────────
  Widget _card({required String title, required IconData icon, required Widget child, Color? accent}) {
    final color = accent ?? const Color(0xFF003087);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
// ─── Répartition par état (donut) ────────────────────────────
  Widget _buildRepartitionCard(int disponible, int enUtilisation, int enPanne, int enMaintenance, int total) {
    return _card(
      title: 'Répartition par état',
      icon: Icons.donut_large_rounded,
      child: Column(
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 58,
                    sections: [
                      if (disponible > 0) _pieSection(disponible, total, EtatUtils.couleur('Disponible')),
                      if (enUtilisation > 0) _pieSection(enUtilisation, total, EtatUtils.couleur('En utilisation')),
                      if (enPanne > 0) _pieSection(enPanne, total, EtatUtils.couleur('En panne')),
                      if (enMaintenance > 0) _pieSection(enMaintenance, total, EtatUtils.couleur('En maintenance')),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF003087))),
                    const Text('Total', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 22,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _legend('Disponible', disponible, EtatUtils.couleur('Disponible')),
              _legend('Utilisation', enUtilisation, EtatUtils.couleur('En utilisation')),
              _legend('En panne', enPanne, EtatUtils.couleur('En panne')),
              _legend('Maintenance', enMaintenance, EtatUtils.couleur('En maintenance')),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(int value, int total, Color color) {
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: '${(value / total * 100).toStringAsFixed(0)}%',
      radius: 46,
      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  Widget _legend(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label  ', style: const TextStyle(fontSize: 12.5, color: Colors.grey)),
        Text('$value', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // ─── Taux de disponibilité ────────────────────────────────────
  Widget _buildDisponibiliteCard(int disponible, int enUtilisation, int enPanne, int enMaintenance, int total) {
    final taux = total > 0 ? disponible / total * 100 : 0.0;
    return _card(
      title: 'Taux de disponibilité',
      icon: Icons.speed_rounded,
      accent: const Color(0xFF2E7D32),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${taux.toStringAsFixed(1)}%',
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                    const Text('des matériels disponibles',
                        style: TextStyle(color: Colors.grey, fontSize: 12.5)),
                  ],
                ),
              ),
              SizedBox(
                width: 74,
                height: 74,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: total > 0 ? disponible / total : 0),
                  duration: const Duration(milliseconds: 800),
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF2E7D32),
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _progressRow('Disponibles', disponible, total, EtatUtils.couleur('Disponible')),
          _progressRow('En utilisation', enUtilisation, total, EtatUtils.couleur('En utilisation')),
          _progressRow('En panne', enPanne, total, EtatUtils.couleur('En panne')),
          _progressRow('En maintenance', enMaintenance, total, EtatUtils.couleur('En maintenance')),
        ],
      ),
    );
  }

  Widget _progressRow(String label, int value, int total, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 108, child: Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.grey))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: total > 0 ? value / total : 0,
                backgroundColor: Colors.grey.shade200,
                color: color,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 20,
            child: Text('$value',
                textAlign: TextAlign.right,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  // ─── Prédiction des retours ───────────────────────────────────
  Widget _buildPredictionCard(List<Materiel> retardes, List<Materiel> demain, List<Materiel> semaine) {
    return _card(
      title: 'Prédiction des retours',
      icon: Icons.schedule_rounded,
      accent: const Color(0xFF1565C0),
      child: Column(
        children: [
          if (retardes.isNotEmpty)
            _predictionItem('❌ En retard', '${retardes.length} matériel(s) auraient dû être rendus',
                Colors.red, retardes),
          if (demain.isNotEmpty)
            _predictionItem('⚠️ Aujourd\'hui / Demain', '${demain.length} matériel(s) à rendre très bientôt',
                Colors.orange, demain),
          if (semaine.isNotEmpty)
            _predictionItem('📅 Cette semaine', '${semaine.length} matériel(s) à rendre dans 7 jours',
                Colors.blue, semaine),
          if (retardes.isEmpty && demain.isEmpty && semaine.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Aucun retour prévu cette semaine', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _predictionItem(String title, String subtitle, Color color, List<Materiel> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${items.length}',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          ...items.map((m) {
            final dateStr = m.dateRetour != null
                ? '${m.dateRetour!.day.toString().padLeft(2, '0')}/${m.dateRetour!.month.toString().padLeft(2, '0')}/${m.dateRetour!.year}'
                : '-';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(Icons.computer_rounded, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${m.displayName} — ${m.responsable.isEmpty ? "Non assigné" : m.responsable}',
                      style: const TextStyle(fontSize: 12.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(dateStr, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Tendance des pannes ──────────────────────────────────────
  Widget _buildTendanceCard(int enPanne, int total) {
    final Color statutColor = enPanne > 1 ? Colors.red : (enPanne == 0 ? Colors.green : Colors.orange);
    final String statutTitre = enPanne == 0 ? 'Excellent !' : (enPanne == 1 ? 'Attention' : 'Critique');
    final IconData statutIcon =
        enPanne > 1 ? Icons.trending_up_rounded : (enPanne == 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded);

    return _card(
      title: 'Tendance des pannes',
      icon: Icons.insights_rounded,
      accent: statutColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statutColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(statutIcon, color: statutColor, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statutTitre,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: statutColor)),
                    Text(
                      enPanne == 0 ? 'Aucun matériel en panne' : '$enPanne matériel(s) en panne sur $total',
                      style: const TextStyle(color: Colors.grey, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: Colors.blue, size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    enPanne == 0
                        ? 'Tous les matériels fonctionnent correctement.'
                        : enPanne <= total * 0.25
                            ? 'Taux de panne acceptable. Planifier une maintenance préventive.'
                            : 'Taux de panne élevé (${(enPanne / total * 100).toStringAsFixed(0)}%). Action urgente recommandée.',
                    style: const TextStyle(color: Colors.blue, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Répartition générique (type / agence) ────────────────────
  Widget _buildRepartitionListeCard({
    required String title,
    required IconData icon,
    required Map<String, int> data,
    required int total,
    required Color color,
    String? suffixLabel,
  }) {
    return _card(
      title: title,
      icon: icon,
      accent: color,
      child: Column(
        children: data.entries.map((e) {
          final percent = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    Text(
                      suffixLabel != null
                          ? '${e.value} $suffixLabel'
                          : '${e.value} (${(percent * 100).toStringAsFixed(0)}%)',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: percent,
                    backgroundColor: Colors.grey.shade200,
                    color: color,
                    minHeight: 9,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}