// ============================================================================
// login.dart
//
// Ecrã responsável pela autenticação do utilizador.
//
// Responsabilidades principais:
// - Recolher e validar email e password;
// - Tentar o login online através de ApiService;
// - Inicializar Firebase Messaging e Analytics depois do login;
// - Guardar token e utilizador no SharedPreferences;
// - Guardar uma cópia da conta no SQLite;
// - Permitir autenticação offline quando a API não está disponível;
// - Navegar para a HomePage após autenticação.
//
// Fluxo: API primeiro -> SQLite como fallback.
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// Adicionado para controlo do estado local
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central do SQFlite para login offline
import 'register.dart';
import 'pagina_principal.dart';
import '../services/notification_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Widget público utilizado nas rotas da aplicação.
// Como não possui estado próprio, apenas devolve o widget LogPage.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  // =========================================================================
  // BUILD
  // Constrói a interface. É executado novamente sempre que setState é chamado.
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return const LogPage();
  }
}

// StatefulWidget porque o ecrã precisa de alterar o indicador de
// carregamento, a visibilidade da password e o conteúdo dos campos.
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  _LogPageState createState() => _LogPageState();
}

// Objeto que guarda o estado mutável do formulário.
class _LogPageState extends State<LogPage> {
  // true: password escondida; false: password visível.
  bool _obscureText = true;

  // Controla o spinner e impede pedidos repetidos.
  bool _isLoading = false;

  // Controllers usados para ler o conteúdo dos TextFields.
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  // Serviços de API e base de dados utilizados por este ecrã.
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Chave mestra do SQLite

  // =========================================================================
  // DISPOSE
  // Liberta os controllers quando o ecrã é destruído.
  // =========================================================================
  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  // =========================================================================
  // FAZER LOGIN
  //
  // 1. Normaliza e valida os dados introduzidos;
  // 2. Ativa o estado de carregamento;
  // 3. Tenta autenticação online;
  // 4. Guarda sessão, cache e token FCM quando tem sucesso;
  // 5. Se a API falhar, tenta validar a conta no SQLite.
  // =========================================================================
  Future<void> _fazerLogin() async {
    // Remove espaços e converte o email para minúsculas para que
    // a comparação online e offline utilize sempre o mesmo formato.
    final String emailInput = _emailController.text
      .trim()
      .replaceAll(' ', '')
      .toLowerCase();
    final String passwordInput = _passController.text;

    // Impede o envio de um pedido com campos vazios.
    if (emailInput.isEmpty || passwordInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha o email e a password!")),
      );
      return;
    }

    // setState reconstrói o ecrã e mostra o indicador de carregamento.
    setState(() => _isLoading = true);

    try {
      // 1. TENTA AUTENTICAÇÃO ONLINE MESTRA (Via API HTTP)
      // Aguarda a resposta do endpoint /auth/login.
      final response = await _apiService.login(emailInput, passwordInput);

      // Depois de um await, confirma que o ecrã continua montado
      // antes de usar context ou setState.
      if (!mounted) return;

      // LOGIN COM SUCESSO NA REDE
      if (response['success'] == true) {
        // Cria uma cópia tipada do objeto do utilizador devolvido pela API.
        final Map<String, dynamic> user =
        Map<String, dynamic>.from(response['user']);

        // Token JWT usado nos pedidos protegidos seguintes.
        final String tokenRecebido = response['token']?.toString() ?? '';

        // Converte o ID para int sem lançar exceção.
        final int? idUtilizador = int.tryParse(
          user['id_utilizador']?.toString() ?? '',
        );

        if (idUtilizador == null) {
          throw Exception('ID do utilizador inválido.');
        }

        // Uniformiza o tipo do ID no resto da aplicação.
        user['id_utilizador'] = idUtilizador;
        
        // 🛡️ CORREÇÃO: Bloco isolado para serviços adicionais (Firebase / Notificações)
        // O Firebase é um serviço secundário: uma falha aqui não deve
        // impedir que o utilizador entre na aplicação.
        String? tokenFcm;
        try {
          // Pede permissão e obtém o token FCM deste dispositivo.
          tokenFcm = await NotificationService().iniciarNotificacoes();
          
          // Regista no Analytics o método utilizado para o login.
          await FirebaseAnalytics.instance.logLogin(loginMethod: 'email_password');
          await FirebaseAnalytics.instance.logEvent(
            name: 'teste_debugview_login',
            parameters: {'origem': 'login_page'},
          );
          print("✅ Evento Analytics enviado com sucesso");

          // Só atualiza o backend quando existe um token válido.
          if (tokenFcm != null) {
            await _apiService.atualizarFcmToken(
              idUtilizador: idUtilizador,
              fcmToken: tokenFcm,
            );
          }
        } catch (firebaseError) {
          // Se o Firebase falhar, apenas avisamos na consola e deixamos o login avançar!
          debugPrint("⚠️ Erro secundário ignorado (Firebase/Notificações): $firebaseError");
        }

        // MIRRORING: Guarda e atualiza a cache na tabela local do SQLite para acessos offline futuros
        // Guarda os dados necessários para permitir login offline futuro.
        await _dbLocal.salvarRegisto('utilizador', {
          'id_utilizador': idUtilizador,
          'nome_completo': user['nome_completo'] ?? '',
          'email': user['email'] ?? emailInput,
          'contacto': user['contacto']?.toString() ?? '',
          'password': passwordInput,
        });

        // SharedPreferences mantém a sessão mesmo depois de fechar a app.
        final prefs = await SharedPreferences.getInstance();
        // Guarda o JWT e o utilizador serializado em JSON.
        await prefs.setString('token', tokenRecebido);
        await prefs.setString('user', jsonEncode(user));

        setState(() => _isLoading = false);

        // Substitui o Login pela Home, impedindo que o botão voltar
        // regresse ao formulário de autenticação.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(userData: user)),
        );
        return;
      }

      // EMAIL DO CONSULTOR RETIDO EM VERIFICAÇÃO PENDENTE
      // Trata separadamente uma conta que ainda não confirmou o email.
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
      // Este catch agora SÓ vai ser chamado se a API HTTP falhar mesmo (falta de net, erro 500, etc)
      debugPrint("API Indisponível de facto. A tentar cache local... ($e)");

      // 2. FALLBACK OFFLINE-FIRST: Procura a conta localmente nas tabelas do SQLite
      // Fallback offline: lê todas as contas guardadas no SQLite.
      final localUsers = await _dbLocal.listarTabela('utilizador');
      
      // Procura pelo email; se não encontrar, devolve um Map vazio.
      final contaLocalEncontrada = localUsers.firstWhere(
        (u) => u['email']?.toString().toLowerCase() == emailInput.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (contaLocalEncontrada.isNotEmpty) {
        // Valida a password contra a cópia local.
        if (contaLocalEncontrada['password'] == passwordInput) {
          
          // Cria o objeto esperado pela HomePage em modo offline.
          final Map<String, dynamic> userOffline = {
            'id_utilizador': contaLocalEncontrada['id_utilizador'],
            'nome_completo': contaLocalEncontrada['nome_completo'],
            'email': contaLocalEncontrada['email'],
            'contacto': contaLocalEncontrada['contacto'],
            'offline_mode': true
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text("Password incorreta para o modo local."),
            ),
          );
          return;
        }
      }

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
                            "Entrar",
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
                              labelText: "Palavra-passe",
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
                            // null desativa o botão enquanto o pedido decorre.
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