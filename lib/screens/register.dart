import 'package:flutter/material.dart';
import 'login.dart';
import 'area_register.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscureText = true;
  bool _aceitouTermos = false;

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  // Validação local dos dados antes de avançar para a escolha da Área
  void _avancarParaArea() {
    final nome = _nomeController.text.trim();
    final email = _emailController.text.trim();
    final password = _passController.text;
    final confirmPassword = _confirmPassController.text;

    if (nome.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Preencha todos os campos obrigatórios!"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("As palavras-passe não coincidem!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!_aceitouTermos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Deve aceitar os Termos e Condições para continuar."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // Avança para a AreaRegisterPage levando os dados validados em pipeline
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER COM LOGÓTIPO FIXED
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

            // FORMULÁRIO DE REGISTO
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Registar",
                            style: TextStyle(
                              color: Color(0xFF6993BE),
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text("Crie a sua conta para aceder à plataforma"),
                          const SizedBox(height: 30),

                          // INPUT NOME
                          TextField(
                            controller: _nomeController,
                            decoration: const InputDecoration(
                              labelText: "Nome Completo",
                              prefixIcon: Icon(Icons.person_outline),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // INPUT EMAIL
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "E-mail",
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // INPUT PASSWORD
                          TextField(
                            controller: _passController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: "Palavra-passe",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscureText = !_obscureText;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // INPUT CONFIRM PASSWORD
                          TextField(
                            controller: _confirmPassController,
                            obscureText: _obscureText,
                            decoration: const InputDecoration(
                              labelText: "Confirmar Palavra-passe",
                              prefixIcon: Icon(Icons.lock_clock_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // CHECKBOX TERMOS
                          Row(
                            children: [
                              Checkbox(
                                value: _aceitouTermos,
                                onChanged: (value) {
                                  setState(() {
                                    _aceitouTermos = value ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  "Aceito os Termos e Condições",
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // BOTÃO SEGUINTE
                          ElevatedButton(
                            onPressed: _avancarParaArea,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Seguinte"),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // LINK RETORNAR AO LOGIN
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Já tens conta? ",
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 113, 125, 144),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  "Login",
                                  style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
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