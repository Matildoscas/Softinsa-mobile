import 'package:flutter/material.dart'; // Importa a biblioteca principal do Flutter
//import 'login.dart'; 
import 'certificado.dart';
//import 'database_service.dart';

void main() {
  runApp(MyApp()); // Inicializa a app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: CertificadoPage(userData: {}), // Define a página de login
    );
  }
}