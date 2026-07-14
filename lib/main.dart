// ============================================================
// main.dart
// Ponto de entrada da aplicação móvel Softinsa Badges.
// Responsabilidades:
//   - Inicializar o Firebase (Analytics + Messaging)
//   - Registar o handler de notificações em background
//   - Injetar o estado global (UtilizadorProvider) no topo da app
//   - Decidir se o utilizador vai para Login ou direto para a Home
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'providers/utilizador_provider.dart';
import 'screens/login.dart';
import 'screens/pagina_principal.dart';
import 'screens/Perfil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'screens/ativacao_admin.dart';


// ============================================================
// HANDLER DE NOTIFICAÇÕES EM BACKGROUND
// Esta função tem de ser declarada fora de qualquer classe e
// ao nível global, porque o Firebase a invoca num isolate
// separado quando a app está fechada ou em segundo plano.
// ============================================================
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Garante que o Firebase está inicializado neste isolate secundário,
  // pois o main() pode ainda não ter corrido neste contexto.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  // Regista no terminal o título da notificação recebida em background.
  print("Notificação em background: ${message.notification?.title}");
}


// ============================================================
// PONTO DE ENTRADA PRINCIPAL
// O 'async' é necessário porque várias inicializações são
// operações assíncronas (Firebase, Analytics, SharedPreferences).
// ============================================================
void main() async {
  // Garante que os bindings internos do Flutter (motor gráfico,
  // plugins de plataforma) estão prontos antes de qualquer
  // chamada assíncrona. Obrigatório quando se usa 'await' antes do runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Firebase com as opções da plataforma atual
  // (Android, iOS, Web, etc.), lidas do firebase_options.dart.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configura o consentimento de recolha de dados para o Analytics.
  // Necessário para conformidade com o GDPR — indica que o utilizador
  // aceitou a recolha de dados analíticos e de publicidade.
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

  print("✅ Analytics ativo e evento app_iniciada_teste enviado");

  // Regista o handler que será chamado quando chegarem notificações
  // push enquanto a app está fechada ou em background.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Arranca a aplicação Flutter.
  // O ChangeNotifierProvider envolve toda a árvore de widgets,
  // tornando o UtilizadorProvider acessível em qualquer ecrã
  // via Provider.of<UtilizadorProvider>(context) ou Consumer<>.
  runApp(
    ChangeNotifierProvider(
      create: (_) => UtilizadorProvider(), // Cria uma única instância global do provider
      child: const MyApp(),
    ),
  );
}


// ============================================================
// WIDGET RAIZ DA APLICAÇÃO
// StatelessWidget porque a sua configuração não muda após
// a construção — o estado dinâmico é gerido pelo Provider.
// ============================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Instância partilhada do Analytics para uso em toda a app.
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  // Observer que regista automaticamente as mudanças de ecrã
  // (navegação entre páginas) no Firebase Analytics.
  static FirebaseAnalyticsObserver observer =
      FirebaseAnalyticsObserver(analytics: analytics);


  // ============================================================
  // VERIFICAÇÃO DE SESSÃO PERSISTIDA
  // Verifica se existe uma sessão guardada localmente do último
  // login, para evitar que o utilizador precise de fazer login
  // sempre que abre a app.
  // ============================================================
  Future<Map<String, dynamic>?> _checkLogin() async {
    // SharedPreferences é o armazenamento chave-valor persistente
    // do dispositivo (equivalente ao localStorage no browser).
    final prefs = await SharedPreferences.getInstance();

    // Tenta recuperar o token JWT e os dados do utilizador
    // guardados no último login bem-sucedido.
    final token = prefs.getString('token');
    final userString = prefs.getString('user');

    // Só considera sessão válida se ambos existirem.
    if (token != null && userString != null) {
      try {
        // Desserializa a string JSON de volta para um Map Dart.
        return jsonDecode(userString) as Map<String, dynamic>;
      } catch (_) {
        // Se o JSON estiver corrompido, ignora e força novo login.
        return null;
      }
    }
    // Sem sessão guardada — o utilizador terá de fazer login.
    return null;
  }


  // ============================================================
  // CONSTRUÇÃO DA ÁRVORE DE WIDGETS DA APP
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Remove o banner vermelho de "DEBUG" no canto superior direito.
      debugShowCheckedModeBanner: false,

      // Injeta o observer do Analytics para registar automaticamente
      // cada navegação entre ecrãs.
      navigatorObservers: [observer],

      // Rotas nomeadas — permitem navegação via Navigator.pushNamed('/login').
      routes: {
        '/login': (context) => const LoginPage(),
        '/home':  (context) => HomePage(userData: const {}),
        '/perfil': (context) => const PerfilPage(userData: {}),
        '/ativacao-admin': (context) => const AtivacaoAdminPage(),
      },

      // FutureBuilder: constrói o ecrã inicial de forma assíncrona,
      // aguardando o resultado de _checkLogin().
      home: FutureBuilder<Map<String, dynamic>?>(
        future: _checkLogin(),
        builder: (context, snapshot) {

          // Enquanto o SharedPreferences ainda está a carregar,
          // mostra um indicador de progresso no centro do ecrã.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF4470AF)),
              ),
            );
          }

          // Sessão válida encontrada → entra diretamente no Dashboard
          // sem precisar de mostrar o ecrã de login.
          if (snapshot.hasData && snapshot.data != null) {
            return HomePage(userData: snapshot.data!);
          }

          // Sem sessão guardada ou sessão inválida → mostra o Login.
          return const LoginPage();
        },
      ),
    );
  }
}
