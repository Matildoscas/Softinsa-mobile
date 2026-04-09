import 'package:flutter/material.dart';

bool _obscureText = true; // Esconde a password por padrão

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: HomePage(), // Define a página inicial
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "SOFTINSA",
                    style: TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF39639C),
                    ),
                  ),
                ],
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

                          Text(
                            "Login",
                            style: TextStyle(
                              color: Color.fromARGB(255, 105, 147, 190),
                              fontSize: 50,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            "Faça login na sua conta",
                            style: TextStyle(
                              fontSize: 15,
                            ),
                          ),

                          SizedBox(height: 20),

                          TextField(
                            decoration: InputDecoration(
                              labelStyle: TextStyle( color: Color.fromARGB(255, 0, 0, 0),),
                              labelText: "Email",
                              prefixIcon: Icon(Icons.email_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),

                          SizedBox(height: 15),

                          TextField(
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

                          SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor:Colors.blueAccent,
                              foregroundColor: Colors.white,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),

                              ),
                              elevation: 5,
                              padding: EdgeInsets.symmetric(horizontal:30, vertical:15),
                            ),
                            child: Text("Entrar"),
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