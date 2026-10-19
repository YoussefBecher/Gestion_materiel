import 'dart:ui' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    // Demander la permission d'envoyer des notifications (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
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

  Future<void> verifierRetours() async {
    try {
      // Vérifier si un utilisateur est connecté avant d'accéder à Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // Pas connecté → on ne fait rien

      final now = DateTime.now();
      final docs = await FirebaseFirestore.instance
          .collection('materiels')
          .where('etat', isEqualTo: 'En utilisation')
          .get();

      int id = 0;
      for (var doc in docs.docs) {
        final data = doc.data();
        final dateRetour = data['dateRetour'] as Timestamp?;
        final marque = (data['marque'] ?? '').toString();
        final type = (data['type'] ?? 'Matériel').toString();
        final nom = marque.isNotEmpty ? '$marque — $type' : type;
        final responsable = data['responsable'] ?? '';

        if (dateRetour != null) {
          final retour = dateRetour.toDate();
          final diff = retour.difference(now).inDays;

          if (diff == 1) {
            await showNotification(
              id: id++,
              title: '⚠️ Retour prévu demain',
              body: '$nom doit être rendu demain par $responsable',
            );
          } else if (diff == 0) {
            await showNotification(
              id: id++,
              title: '🔴 Retour aujourd\'hui',
              body: '$nom doit être rendu aujourd\'hui par $responsable',
            );
          } else if (diff < 0) {
            await showNotification(
              id: id++,
              title: '❌ Retour en retard',
              body:
              '$nom aurait dû être rendu il y a ${diff.abs()} jour(s) par $responsable',
            );
          }
        }
      }
    } catch (e) {
      // Ignorer silencieusement les erreurs de permission
      print('verifierRetours ignoré: $e');
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