import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'screens/login.dart';
import 'screens/pagina_principal.dart';
import 'screens/Perfil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';

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

  runApp(const MyApp());
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
      return jsonDecode(userString);
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
        '/home': (context) => HomePage(userData: {}),
        '/perfil': (context) => const PerfilPage(userData: {}),

        //'/perfil': (context) => const ProfilePage(),
        //'/definicoes': (context) => const SettingsPage(),
      },
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLogin(),
        builder: (context, snapshot) {

          // loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // se tem utilizador → entra direto
          if (snapshot.hasData) {
            //return HomePage(userData: snapshot.data!);
          }

          // senão → login
          return const LoginPage();
        },
      ),
    );
  }
}