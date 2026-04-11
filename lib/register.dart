import 'package:flutter/material.dart';
import 'login.dart';
import 'database_service.dart';
import 'area_register.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscureText = true;
  bool _aceitouTermos = false;

  // ADICIONA ESTES CONTROLLERS
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _confirmPassController = TextEditingController();

  // Função para processar o clique
  Future<void> _fazerRegisto() async {
    if (_nomeController.text.isEmpty || _emailController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preencha os campos obrigatórios!")));
       return;
    }
    if (_passController.text != _confirmPassController.text) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("As passwords não coincidem!")));
       return;
    }
    if (!_aceitouTermos) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Deve aceitar os termos!")));
       return;
    }

    DatabaseService db = DatabaseService();
    final int? userId = await db.registrarUtilizador(
    nome: _nomeController.text,
    email: _emailController.text,
    password: _passController.text,
    aceitouTermos: _aceitouTermos,
  );

  if (userId != null) { // Se o ID não for nulo, o registo correu bem
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registado com sucesso!"))
    );
    
    // Navega para a página de áreas passando o userId (como a tua AreaRegisterPage exige)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AreaRegisterPage(userId: userId),
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Erro ao registar. Email já existe?"))
    );
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [

            // ================= HEADER =================
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              width: double.infinity, // Garante que o container ocupe a largura toda
              child: Center(
                child: Image.asset(
                  'lib/img/logo.png', // Caminho para o teu arquivo de logótipo
                  height: 70, // Ajusta a altura conforme necessário para caber bem
                  fit: BoxFit.contain, // Garante que a imagem se ajuste ao espaço sem distorcer
                ),
              ),
            ),

            // ================= CONTEÚDO PRINCIPAL =================
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),

                      // LOGIN
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          Center(
                            child: Text(
                              "Registar",
                              style: TextStyle(
                                color: Color.fromARGB(255, 105, 147, 190),
                                fontSize: 50,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Text(
                            "Crie a sua conta",
                            style: TextStyle(
                              fontSize: 15,
                            ),
                          ),

                          SizedBox(height: 20),

                          TextField(
                            controller: _nomeController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle( color: Color.fromARGB(255, 0, 0, 0),),
                              labelText: "Nome Completo",
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 15),

                          TextField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelStyle: TextStyle( color: Color.fromARGB(255, 0, 0, 0),),
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 15), //Espaço entre Elementos

                          TextField(
                            controller: _passController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelStyle: TextStyle( color: Color.fromARGB(255, 0, 0, 0),),
                              labelText: "Password",
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    // O setState avisa ao Flutter para redesenhar o widget
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 15), //Espaço entre Elementos

                          TextField(
                            controller: _confirmPassController,
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              labelStyle: TextStyle( color: Color.fromARGB(255, 0, 0, 0),),
                              labelText: "Confirme a Password",
                              prefixIcon: Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureText ? Icons.visibility_off : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    // O setState avisa ao Flutter para redesenhar o widget
                                    setState(() {
                                      _obscureText = !_obscureText;
                                    });
                                  },
                                ),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 4),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min, // Garante que não ocupe a largura toda
                              children: [
                                Checkbox(
                                  value: _aceitouTermos,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _aceitouTermos = value ?? false;
                                    });
                                  },
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Lógica para abrir os Termos de Serviço
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size(0, 0),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    "Aceito os Termos de Serviço",
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 4), //Espaço entre Elementos

                          ElevatedButton(
                            onPressed: _fazerRegisto,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 5,
                              padding: EdgeInsets.symmetric(horizontal: 97, vertical: 14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min, // Faz o botão envolver o conteúdo
                              children: [
                                Text("Registar"),
                                SizedBox(width: 4), // Cria um espaço entre o texto e a seta
                                Icon(Icons.arrow_forward), // A seta à frente
                              ],
                            ),
                          ),

                          SizedBox(height: 80),

                          Align(
                            alignment: Alignment.center,
                            child: TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const LoginPage()),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero, // Remove o padding padrão do TextButton
                                minimumSize: Size(0, 0), // Permite que o botão seja tão pequeno quanto o conteúdo
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduz a área de toque ao mínimo
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min, // Importante para não esticar o botão
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
                                      fontWeight: FontWeight.bold, // Destaque extra para o link
                                    ),
                                  ),
                                ],
                              ),
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