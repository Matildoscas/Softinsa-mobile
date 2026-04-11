import 'package:flutter/material.dart';
import 'register.dart';
import 'database_service.dart';
import 'pagina_inicial.dart';

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

  // ✅ CONTROLLERS + DB SERVICE
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [

            // HEADER
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
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),

                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          const Text(
                            "Login",
                            style: TextStyle(
                              color: Color.fromARGB(255, 105, 147, 190),
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const Text("Faça login na sua conta"),

                          const SizedBox(height: 20),

                          // ✅ EMAIL FIELD COM CONTROLLER
                          TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 15),

                          // ✅ PASSWORD FIELD COM CONTROLLER
                          TextField(
                            controller: _passController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelText: "Password",
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_off
                                      : Icons.visibility,
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

                          const SizedBox(height: 10),

                          const SizedBox(height: 10),

                          // ✅ BOTÃO LOGIN COM DB
                          ElevatedButton(
                            onPressed: () async {
                              final userDados =
                                  await _dbService.loginUtilizador(
                                _emailController.text,
                                _passController.text,
                              );

                              if (userDados != null) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        HomePage(userData: userDados),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        "Email ou Password incorretos!"),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 5,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 105, vertical: 14),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Entrar"),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),

                          const SizedBox(height: 80),

                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const RegisterPage()),
                              );
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("Ainda não tem conta? "),
                                Text(
                                  "Registar",
                                  style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold),
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