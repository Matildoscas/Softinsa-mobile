import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
// Import do Provider adicionado

// Imports exatos do teu ecossistema de ficheiros
import 'providers/utilizador_provider.dart';
import 'screens/login.dart';
import 'screens/pagina_principal.dart';
import 'screens/Perfil.dart';
// Import do teu provider estrutural
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  print("Notificação em background: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAnalytics.instance.setConsent(
    analyticsStorageConsentGranted: true,
    adStorageConsentGranted: true,
  );

  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  await FirebaseAnalytics.instance.logEvent(
    name: 'app_iniciada_teste',
    parameters: {
      'origem': 'main',
    },
  );

  print("✅ Analytics ativo e evento app_iniciada_teste enviado");

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    // CORREÇÃO CRÍTICA: Injeta o provider no topo de toda a árvore de widgets da App
    ChangeNotifierProvider(
      create: (_) => UtilizadorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);

  Future<Map<String, dynamic>?> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final userString = prefs.getString('user');

    if (token != null && userString != null) {
      try {
        return jsonDecode(userString) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorObservers: [observer],
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(userData: const {}),
        '/perfil': (context) => const PerfilPage(userData: {}),
      },
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          // Estado de Carregamento inicial do SharedPreferences
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4470AF)),
              ),
            );
          }

          // CORREÇÃO LÓGICA: Se já tem sessão iniciada na cache, entra direto no Dashboard
          if (snapshot.hasData && snapshot.data != null) {
            return HomePage(userData: snapshot.data!);
          }

          // Senão tiver dados de sessão salvos -> Encaminha para o Login
          return const LoginPage();
        },
      ),
    );
  }
}