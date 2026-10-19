import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/materiel/localisation_temps_reel_screen.dart';
import 'services/notification_service.dart';

/// Point d'entrée unique pour signaler une erreur (log local pour
/// l'instant). Centraliser ici permet de brancher plus tard un vrai
/// outil de monitoring (Crashlytics, Sentry...) en ne modifiant que
/// cette fonction, sans toucher au reste du fichier.
void _signalerErreur(String message, Object error, StackTrace? stack) {
  developer.log(message, name: 'main', error: error, stackTrace: stack);
  // Exemple d'intégration future :
  // FirebaseCrashlytics.instance.recordError(error, stack, reason: message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture toute erreur Flutter non interceptée ailleurs (erreurs de
  // rendu, exceptions dans les callbacks de widgets...) pour qu'elle
  // soit au moins loggée au lieu de disparaître silencieusement.
  FlutterError.onError = (FlutterErrorDetails details) {
    _signalerErreur(
      'Erreur Flutter non interceptée',
      details.exception,
      details.stack,
    );
  };

  // Idem pour les erreurs async/plateforme hors du cycle de rendu
  // Flutter (ex : erreurs dans des Future non attendus).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _signalerErreur('Erreur non interceptée (PlatformDispatcher)', error, stack);
    return true;
  };

  runApp(const MyApp());
}

/// Initialise Firebase puis les notifications. Isolée dans une fonction
/// à part pour pouvoir être rappelée depuis le bouton "Réessayer" sans
/// jamais retoucher à runApp() ni à main().
Future<void> _initFirebaseEtNotifications() async {
  // Firebase reste indispensable avant d'afficher le contenu réel :
  // l'écran de connexion (StreamBuilder sur authStateChanges) en dépend
  // directement. Un timeout évite de rester bloqué indéfiniment si le
  // réseau est très lent plutôt que franchement en échec.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ).timeout(const Duration(seconds: 10));

  // Les notifications ne sont pas nécessaires pour afficher le premier
  // écran : on les initialise après Firebase, sans bloquer l'affichage
  // si elles échouent — un échec de notifications ne doit pas empêcher
  // l'utilisateur d'utiliser l'app.
  if (!kIsWeb) {
    unawaited(
      NotificationService().init().then((_) {
        NotificationService().verifierRetours();
      }).catchError((Object e, StackTrace stack) {
        _signalerErreur('Échec de l\'initialisation des notifications', e, stack);
      }),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static const double _largeurMaxContenu = 700;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFirebaseEtNotifications();
  }

  void _reessayer() {
    setState(() {
      _initFuture = _initFirebaseEtNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Matériel',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003087)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(maxWidth: MyApp._largeurMaxContenu),
              child: child,
            ),
          ),
        );
      },
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            _signalerErreur(
              'Échec de l\'initialisation Firebase',
              snapshot.error!,
              snapshot.stackTrace,
            );
            return _ErreurDemarrageScreen(
              erreur: snapshot.error,
              onReessayer: _reessayer,
            );
          }
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}

/// Écran de secours affiché quand Firebase n'a pas pu s'initialiser
/// (pas de réseau, config invalide, quota dépassé, timeout...).
class _ErreurDemarrageScreen extends StatefulWidget {
  const _ErreurDemarrageScreen({
    required this.onReessayer,
    this.erreur,
  });

  final Object? erreur;
  final VoidCallback onReessayer;

  @override
  State<_ErreurDemarrageScreen> createState() =>
      _ErreurDemarrageScreenState();
}

class _ErreurDemarrageScreenState extends State<_ErreurDemarrageScreen> {
  bool _enCoursDeReessai = false;

  String get _message {
    if (widget.erreur is TimeoutException) {
      return 'La connexion prend trop de temps. Vérifiez votre réseau.';
    }
    return 'Impossible de se connecter au service.';
  }

  void _onPressed() {
    if (_enCoursDeReessai) return;
    setState(() => _enCoursDeReessai = true);
    widget.onReessayer();
    // Le nouveau FutureBuilder reconstruit cet écran (ou le remplace)
    // dès que _initFuture change ; on borne juste l'anti-spam du
    // bouton le temps que la reconstruction ait lieu.
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _enCoursDeReessai = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vérifiez votre connexion internet puis réessayez.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _enCoursDeReessai ? null : _onPressed,
                child: _enCoursDeReessai
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}