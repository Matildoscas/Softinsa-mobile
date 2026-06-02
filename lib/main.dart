import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'screens/login.dart';
import 'screens/pagina_principal.dart';
import 'screens/Perfil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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