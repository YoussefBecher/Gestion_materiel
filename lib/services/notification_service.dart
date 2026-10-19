import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );
    await _notifications.initialize(settings);

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImplementation?.requestNotificationsPermission();
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'gestion_materiel',
      'Gestion Matériel BIAT',
      channelDescription: 'Notifications de gestion du matériel',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF003087),
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );
    await _notifications.show(id, title, body, details);
  }

  // ─── Anti-duplication des notifications ─────────────────────
  // Empêche qu'une même alerte (ex: "retard" pour un matériel donné)
  // soit réaffichée plusieurs fois LE MÊME JOUR. La date fait partie de
  // la clé : ainsi, si le retard continue le lendemain, ou si le matériel
  // repasse par un nouveau cycle (rendu puis re-prêté puis de nouveau en
  // retard), l'alerte revient naturellement — pas de blocage permanent.

  String get _cleJourActuel {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Vérifie si cette notification précise a déjà été envoyée aujourd'hui.
  Future<bool> _dejaNotifie(String cle) async {
    final prefs = await SharedPreferences.getInstance();
    final envoyees = prefs.getStringList('notifications_envoyees') ?? [];
    return envoyees.contains(cle);
  }

  /// Marque cette notification comme envoyée pour aujourd'hui.
  Future<void> _marquerCommeNotifie(String cle) async {
    final prefs = await SharedPreferences.getInstance();
    final envoyees = prefs.getStringList('notifications_envoyees') ?? [];
    envoyees.add(cle);
    await prefs.setStringList('notifications_envoyees', envoyees);
  }

  /// Supprime les clés des jours précédents, pour que la liste ne grossisse
  /// pas indéfiniment sur le téléphone au fil des semaines/mois.
  Future<void> _purgerAnciennesCles() async {
    final prefs = await SharedPreferences.getInstance();
    final envoyees = prefs.getStringList('notifications_envoyees') ?? [];
    final aujourdHui = _cleJourActuel;
    final conservees = envoyees.where((c) => c.endsWith(aujourdHui)).toList();
    await prefs.setStringList('notifications_envoyees', conservees);
  }

  Future<void> verifierRetours() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _purgerAnciennesCles();

      final now = DateTime.now();
      final aujourdHui = _cleJourActuel;
      final docs = await FirebaseFirestore.instance
          .collection('materiels')
          .where('etat', isEqualTo: 'En utilisation')
          .get();

      int id = 0;
      for (var doc in docs.docs) {
        final data = doc.data();
        final dateRetour = data['dateRetour'] as Timestamp?;
        final nom = data['nom'] ?? 'Matériel';
        final responsable = data['responsable'] ?? '';

        if (dateRetour != null) {
          final retour = dateRetour.toDate();
          final diff = retour.difference(now).inDays;

          // Clé unique par matériel, par type d'alerte ET par jour :
          // - "demain"/"en retard" ne spamment pas plusieurs fois le même jour
          // - mais reviennent bien le jour suivant tant que ce n'est pas réglé
          // - et un nouveau cycle (rendu → re-prêté → de nouveau en retard,
          //   à une date différente) déclenche à nouveau l'alerte normalement
          String? cle;
          String? titre;
          String? corps;

          if (diff == 1) {
            cle = '${doc.id}_demain_$aujourdHui';
            titre = '⚠️ Retour prévu demain';
            corps = '$nom doit être rendu demain par $responsable';
          } else if (diff == 0) {
            cle = '${doc.id}_aujourdhui_$aujourdHui';
            titre = '🔴 Retour aujourd\'hui';
            corps = '$nom doit être rendu aujourd\'hui par $responsable';
          } else if (diff < 0) {
            cle = '${doc.id}_retard_$aujourdHui';
            titre = '❌ Retour en retard';
            corps =
            '$nom aurait dû être rendu il y a ${diff.abs()} jour(s) par $responsable';
          }

          if (cle != null && !(await _dejaNotifie(cle))) {
            await showNotification(id: id++, title: titre!, body: corps!);
            await _marquerCommeNotifie(cle);
          }
        }
      }
    } catch (e) {
      // Erreur silencieusement ignorée (ex: hors ligne, permissions temporaires)
    }
  }

  Future<void> notifierPanne(String nomMateriel, String bureau) async {
    await showNotification(
      id: 999,
      title: '🔴 Matériel en panne',
      body: '$nomMateriel est en panne - $bureau',
    );
  }
}