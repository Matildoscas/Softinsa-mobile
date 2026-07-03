// ============================================================================
// register.dart
//
// Primeiro passo do processo de registo.
//
// Responsabilidades principais:
// - Recolher nome, email e password;
// - Confirmar a password;
// - Exigir a aceitação dos Termos de Serviço;
// - Validar todos os campos;
// - Abrir o texto dos Termos num AlertDialog;
// - Passar os dados válidos para AreaRegisterPage.
//
// Este ecrã ainda não cria a conta. O POST final ocorre em area_register.dart.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Import adicionado
import '../providers/utilizador_provider.dart'; // Import adicionado
import 'login.dart';
import 'area_register.dart';

// StatefulWidget porque o formulário altera a visibilidade da password,
// o valor da checkbox e o conteúdo dos campos.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

// Estado mutável do primeiro passo do registo.
class _RegisterPageState extends State<RegisterPage> {
  // Controla se as passwords ficam escondidas.
  bool _obscureText = true;

  // Guarda o estado da checkbox dos Termos de Serviço.
  bool _aceitouTermos = false;

  // Controllers usados para ler os quatro campos do formulário.
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // =========================================================================
  // INITSTATE
  // Executado uma única vez quando o ecrã é criado.
  // =========================================================================
  @override
  void initState() {
    super.initState();
    // CORREÇÃO CRÍTICA: Manda carregar as áreas da API imediatamente em background
    // enquanto o utilizador digita os dados de registo!
    // Agenda a chamada para depois do primeiro frame, quando o context
    // já pode consultar o Provider de forma segura.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // listen: false porque apenas executa uma ação e este ecrã
      // não precisa reconstruir quando o Provider mudar.
      Provider.of<UtilizadorProvider>(context, listen: false).inicializarDados(0);
    });
  }

  // =========================================================================
  // DISPOSE
  // Liberta os controllers quando o formulário deixa de existir.
  // =========================================================================
  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // =========================================================================
  // AVANÇAR PARA A ÁREA
  //
  // Valida campos obrigatórios, formato do email, tamanho da password,
  // confirmação da password e aceitação dos termos. Só depois navega
  // para o segundo passo do registo.
  // =========================================================================
  void _avancarParaArea() {
    // Lê os valores atuais dos TextFields.
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text;
    final confirmPassword = _confirmPassController.text;

    // Validação dos campos obrigatórios.
    if (nome.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Preencha todos os campos obrigatórios!")),
      );
      return;
    }

    // Expressão regular simples para verificar a estrutura do email.
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Email inválido!")),
      );
      return;
    }

    // Regra mínima de segurança definida para a password.
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A password deve ter pelo menos 6 caracteres!")),
      );
      return;
    }

    // Impede avançar quando as duas passwords são diferentes.
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As passwords não coincidem!")),
      );
      return;
    }

    // O consentimento é obrigatório para continuar o registo.
    if (!_aceitouTermos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Deve aceitar os Termos de Serviço!")),
      );
      return;
    }

    // Envia os dados já validados para o segundo passo.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AreaRegisterPage(
          nome: nome,
          email: email,
          password: password,
          aceitouTermos: _aceitouTermos,
        ),
      ),
    );
  }

  // =========================================================================
  // ABRIR TERMOS DE SERVIÇO
  // Mostra uma janela modal sem apagar o conteúdo do formulário.
  // =========================================================================
  void _abrirTermosServico() {
    // showDialog coloca um AlertDialog por cima do ecrã atual.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Termos de Serviço", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            "Ao registar-se na plataforma Softinsa Badges, concorda que os seus dados de progresso, "
            "submissões de evidências e conquistas profissionais sejam armazenados para fins de "
            "gestão de competências e emissão de certificados internos.\n\n"
            "A cache local do dispositivo guardará informações para permitir a utilização "
            "da aplicação em modo offline de forma fluida.",
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar", style: TextStyle(color: Color(0xFF4470AF), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD
  // Constrói o formulário e é repetido quando setState altera o estado.
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    const Color azulSoftinsa = Color(0xFF4470AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
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
                            "Registar",
                            style: TextStyle(
                              color: azulSoftinsa,
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text("Crie a sua conta", style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              labelText: "Nome Completo",
                              prefixIcon: Icon(Icons.person_outline),
                              filled: true,
                              fillColor: Color(0xFFF7F7F7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "E-mail",
                              prefixIcon: Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Color(0xFFF7F7F7),
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                            ),
                          ),
                          const SizedBox(height: 14),
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
                          const SizedBox(height: 14),
                          TextField(
                            controller: _confirmPassController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: "Confirme a Password",
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
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _aceitouTermos,
                                  activeColor: azulSoftinsa,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _aceitouTermos = value ?? false;
                                    });
                                  },
                                ),
                                TextButton(
                                  onPressed: _abrirTermosServico,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    "Aceito os Termos de Serviço",
                                    style: TextStyle(
                                      color: azulSoftinsa,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            // Executa as validações antes de avançar.
                            onPressed: _avancarParaArea,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulSoftinsa,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Seguinte", style: TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const LoginPage()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Já tens conta? ",
                                  style: TextStyle(color: Color.fromARGB(255, 113, 125, 144), fontSize: 13),
                                ),
                                Text(
                                  "Login",
                                  style: TextStyle(color: azulSoftinsa, fontSize: 13, fontWeight: FontWeight.bold),
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