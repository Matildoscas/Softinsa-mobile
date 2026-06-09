import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central do SQFlite para login offline
import 'register.dart';
import 'pagina_principal.dart';
import '../services/notification_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LogPage();
  }
}

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  _LogPageState createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  bool _obscureText = true;
  bool _isLoading = false; // Flag para feedback de processamento na UI

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Chave mestra do SQLite

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    final String emailInput = _emailController.text.trim();
    final String passwordInput = _passController.text;

    if (emailInput.isEmpty || passwordInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha o email e a password!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. TENTA AUTENTICAÇÃO ONLINE MESTRA (Via API HTTP)
      final response = await _apiService.login(emailInput, passwordInput);

      if (!mounted) return;

      // LOGIN COM SUCESSO NA REDE
      if (response['success'] == true) {
        final user = response['user'];
        final token = response['token'];
        
        // Inicialização de serviços em background de notificações push
        final tokenFcm = await NotificationService().iniciarNotificacoes();

        await FirebaseAnalytics.instance.logLogin(loginMethod: 'email_password');
        try {
          await FirebaseAnalytics.instance.logEvent(
            name: 'teste_debugview_login',
            parameters: {'origem': 'login_page'},
          );
          print("✅ Evento Analytics enviado: teste_debugview_login");
        } catch (e) {
          print("❌ Erro Analytics: $e");
        }

        if (tokenFcm != null) {
          await _apiService.atualizarFcmToken(
            idUtilizador: user['id_utilizador'],
            fcmToken: tokenFcm,
          );
        }

        // MIRRORING: Guarda e atualiza a cache na tabela local do SQLite para acessos offline futuros
        await _dbLocal.salvarRegisto('utilizador', {
          'id_utilizador': int.tryParse(user['id_utilizador'].toString()) ?? 0,
          'nome_completo': user['nome_completo'] ?? '',
          'email': user['email'] ?? emailInput,
          'contacto': user['contacto']?.toString() ?? '',
          'password': passwordInput, // Guardada localmente de forma defensiva para match offline
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('user', jsonEncode(user));

        setState(() => _isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userData: user)),
        );
        return;
      }

      // EMAIL DO CONSULTOR RETIDO EM VERIFICAÇÃO PENDENTE
      if (response['emailNaoVerificado'] == true) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text("Confirme o seu email antes de iniciar sessão."),
          ),
        );
        return;
      }

      // ERRO DE CREDENCIAIS (Servidor respondeu rejeitando)
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Email ou password incorretos!")),
      );

    } catch (e) {
      debugPrint("API Indisponível. Iniciando verificação de credenciais em cache local... ($e)");

      // 2. FALLBACK OFFLINE-FIRST: Procura a conta localmente nas tabelas do SQLite
      final localUsers = await _dbLocal.listarTabela('utilizador');
      
      // Procura se existe algum registo na BD local com o mesmo email introduzido
      final contaLocalEncontrada = localUsers.firstWhere(
        (u) => u['email']?.toString().toLowerCase() == emailInput.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (contaLocalEncontrada.isNotEmpty) {
        // Validação estrita da última password em cache local
        if (contaLocalEncontrada['password'] == passwordInput) {
          
          final Map<String, dynamic> userOffline = {
            'id_utilizador': contaLocalEncontrada['id_utilizador'],
            'nome_completo': contaLocalEncontrada['nome_completo'],
            'email': contaLocalEncontrada['email'],
            'contacto': contaLocalEncontrada['contacto'],
            'offline_mode': true // Adicionado sinalizador útil para as restantes UIs
          };

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user', jsonEncode(userOffline));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.blueGrey,
              content: Text("Iniciou sessão em Modo Offline (Cache Local ativa)."),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage(userData: userOffline)),
          );
          return;
        } else {
          // Utilizador existe localmente mas errou a password guardada em cache
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("Password incorreta para o modo local."),
            ),
          );
          return;
        }
      }

      // Nenhuma conta encontrada em cache e sem internet para verificar junto da API
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("Sem ligação ao servidor e sem credenciais guardadas localmente."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color azulFocado = Color(0xFF4470AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // FIXED HEADER APP LOGO
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              width: double.infinity,
              child: Center(
                child: Image.asset(
                  'lib/img/logo.png',
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Login",
                            style: TextStyle(
                              color: azulFocado,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text("Faça login na sua conta", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),

                          // Campo Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Color(0xFFF7F7F7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Campo Password
                          TextField(
                            controller: _passController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF7F7F7),
                              border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Botão de Submissão reativo ao estado de Loading
                          ElevatedButton(
                            onPressed: _isLoading ? null : _fazerLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulFocado,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text("Entrar", style: TextStyle(fontWeight: FontWeight.bold)),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward, size: 18),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 40),

                          // Botão de Redirecionamento para Registo
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterPage()),
                              );
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Ainda não tem conta? ",
                                  style: TextStyle(color: Color.fromARGB(255, 113, 125, 144), fontSize: 13),
                                ),
                                Text(
                                  "Registar",
                                  style: TextStyle(color: azulFocado, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}