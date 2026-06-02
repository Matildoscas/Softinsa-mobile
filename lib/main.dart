import 'package:flutter/material.dart'; // Importa a biblioteca principal do Flutter
import 'package:popover/popover.dart'; // Importamos o pacote
import 'Perfil.dart';

void main() {
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