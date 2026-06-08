import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Pacotes de infraestrutura e Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';

// Imports exatos do teu ecossistema de ficheiros
import 'database/basededados.dart';
import 'providers/utilizador_provider.dart';
import 'screens/login.dart';
import 'screens/pagina_principal.dart'; // Onde reside a tua classe HomePage
import 'screens/Perfil.dart';           // Onde reside o teu widget Perfil

// Handler obrigatório fora de qualquer classe para processar notificações em segundo plano
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  print("Notificação em background recebida: ${message.notification?.title}");
}

void main() async {
  // 1. Garante a inicialização das amarrações nativas do Flutter antes de ler dados assíncronos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa o Firebase com as definições de plataforma do teu ecossistema
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Configurações explícitas de recolha e consentimento do Analytics
  await FirebaseAnalytics.instance.setConsent(
    analyticsStorageConsentGranted: true,
    adStorageConsentGranted: true,
  );
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

  // 4. Dispara o evento de teste inicial exigido para validação no painel
  await FirebaseAnalytics.instance.logEvent(
    name: 'app_iniciada_teste',
    parameters: {'origem': 'main'},
  );
  print("✅ Analytics ativo e evento app_iniciada_teste enviado");

  // 5. Configura o escutador de notificações em Background/Terminated
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 6. Inicializa a base de dados local SQFlite (Gera as tabelas locais)
  await Basededados().database;

  runApp(
    // 7. Injeta o Provider global no topo do projeto para suportar o Offline-First
    ChangeNotifierProvider(
      create: (_) => UtilizadorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Instanciação estática do Analytics e do respetivo observador de navegação
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver observer = FirebaseAnalyticsObserver(analytics: analytics);

  // Valida se existem credenciais de sessão trancadas em disco
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
      title: 'Softinsa Gamification',
      navigatorObservers: [observer], // Acopla o observador do Firebase
      
      // As tuas tabelas de caminhos diretos (Named Routes) mantidas intactas
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => HomePage(userData: const {}),
        '/perfil': (context) => const PerfilPage(userData: {}),
      },
      
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLogin(),
        builder: (context, snapshot) {
          // Enquanto valida o estado da sessão no arranque da aplicação
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  color: Colors.blueAccent,
                ),
              ),
            );
          }

          // Se o utilizador já tiver uma sessão válida guardada localmente
          if (snapshot.hasData && snapshot.data != null) {
            final userData = snapshot.data!;
            final int userId = userData['id_utilizador'] ?? 0;

            // Alimenta e acorda o Provider para ler o SQFlite e disparar o Sync assíncrono da API
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<UtilizadorProvider>(context, listen: false)
                  .inicializarDados(userId);
            });

            // Abre o teu widget real passando o mapa de dados estruturado do utilizador
            return HomePage(userData: userData);
          }

          // Caso contrário (primeira abertura ou pós-logout) -> Redireciona para o Login
          return const LoginPage();
        },
      ),
    );
  }
}