import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Imports exatos do teu ecossistema de ficheiros
import 'database/basededados.dart';
import 'providers/utilizador_provider.dart';
import 'screens/login.dart';
import 'screens/pagina_principal.dart'; // Importa o teu ficheiro onde está o HomePage

void main() async {
  // 1. Garante a inicialização das amarrações nativas do Flutter antes de ler dados assíncronos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa a base de dados local SQFlite e gera as 21 tabelas espelhadas do pgAdmin
  await Basededados().database;

  runApp(
    // 3. Injeta o Provider no topo do projeto para que todos os sub-ecrãs consigam ler o SQLite
    ChangeNotifierProvider(
      create: (_) => UtilizadorProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Verifica se o Token e os dados do Consultor já existem no disco persistente (Shared Preferences)
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

            // CORREÇÃO: Abre o teu widget real passando o mapa de dados estruturado do utilizador
            return HomePage(userData: userData);
          }

          // Caso contrário (primeira abertura ou pós-logout) -> Redireciona para o Login
          return const LoginPage();
        },
      ),
    );
  }
}