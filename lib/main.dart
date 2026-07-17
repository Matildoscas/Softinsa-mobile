// ============================================================
// main.dart
// Ponto de entrada da aplicação móvel Softinsa Badges.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

import 'screens/login.dart';
import 'screens/pagina_principal.dart';
import 'screens/Perfil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'screens/ativacao_admin.dart';
import 'services/deep_link_service.dart';
import 'services/api_service.dart' as api_service;
import 'services/offline_sync_service.dart';

// ============================================================
// NAVIGATOR GLOBAL
// Tem de estar fora do main para ser usado no MaterialApp
// e também no DeepLinkService.
// ============================================================
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

// ============================================================
// HANDLER DE NOTIFICAÇÕES EM BACKGROUND
// ============================================================
Future<void> _firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  print(
    "Notificação em background: "
    "${message.notification?.title}",
  );
}

// ============================================================
// MAIN
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefsAnalytics =
      await SharedPreferences.getInstance();

  final analyticsAceite =
      prefsAnalytics.getBool('rgpd_analytics_aceite') ??
          false;

  await FirebaseAnalytics.instance.setConsent(
    analyticsStorageConsentGranted: analyticsAceite,
    adStorageConsentGranted: false,
  );

  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
    analyticsAceite,
  );

  if (analyticsAceite) {
    await FirebaseAnalytics.instance.logEvent(
      name: 'app_iniciada',
      parameters: {
        'origem': 'main',
      },
    );
  }

  print(
    analyticsAceite
        ? "✅ Analytics ativo com consentimento do utilizador"
        : "ℹ️ Analytics desativado sem consentimento",
  );

  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );

  runApp(
    const ProviderScope(
      child: const MyApp(),
    ),
  );

  /*
  * Inicializa os deep links depois de a árvore da app
  * já existir. Assim o navigatorKey já tem contexto.
  */
  WidgetsBinding.instance.addPostFrameCallback(
    (_) async {
      await DeepLinkService.instance.inicializar(
        navigatorKey: navigatorKey,
      );
    },
  );
}

// ============================================================
// WIDGET RAIZ
// ============================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static FirebaseAnalytics analytics =
      FirebaseAnalytics.instance;

  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(
    analytics: analytics,
  );

  Future<Map<String, dynamic>?> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final authToken = prefs.getString('token');
    final userString = prefs.getString('user');

    if (
      authToken != null &&
      authToken.trim().isNotEmpty &&
      userString != null &&
      userString.trim().isNotEmpty
    ) {
      try {
        /*
        * Muito importante:
        * repõe o token global do ApiService quando a app
        * abre com sessão guardada.
        *
        * Sem isto, a app entra na Home mas depois as rotas
        * protegidas aparecem como "Token indisponível".
        */
        api_service.token = authToken.trim();

        final userData = jsonDecode(userString)
            as Map<String, dynamic>;

        final idUtilizador = int.tryParse(
          userData['id_utilizador']?.toString() ?? '',
        );

        if (idUtilizador != null && idUtilizador > 0) {
          unawaited(
            OfflineSyncService().sincronizarPendenciasUtilizador(
              idUtilizador,
            ),
          );
        }

        return userData;
      } catch (e) {
        print(
          'Erro ao recuperar sessão guardada: $e',
        );

        return null;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      navigatorObservers: [
        observer,
      ],
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(
              userData: const {},
            ),
        '/perfil': (context) => const PerfilPage(
              userData: {},
            ),
        '/ativacao-admin': (context) =>
            const AtivacaoAdminPage(),
      },
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          if (
            snapshot.connectionState ==
            ConnectionState.waiting
          ) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4470AF),
                ),
              ),
            );
          }

          if (
            snapshot.hasData &&
            snapshot.data != null
          ) {
            return HomePage(
              userData: snapshot.data!,
            );
          }

          return const LoginPage();
        },
      ),
    );
  }
}