import 'package:flutter/material.dart';
import 'database_service.dart'; // Garante que o import está correto
import 'main.dart';

class AreaRegisterPage extends StatefulWidget {
  final int userId; // Recebemos o ID do utilizador vindo do registo

  const AreaRegisterPage({super.key, required this.userId});

  @override
  _AreaRegPageState createState() => _AreaRegPageState();
}

class _AreaRegPageState extends State<AreaRegisterPage> {
  final DatabaseService _dbService = DatabaseService();
  int? selectedAreaId; // Guardamos o ID da área, não o nome
  List<Map<String, dynamic>> areas = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarAreas();
  }

  // Vai buscar as áreas à base de dados
  Future<void> _carregarAreas() async {
    try {
      final lista = await _dbService.obterAreas();
      setState(() {
        areas = lista;
        isLoading = false;
      });
    } catch (e) {
      print("Erro ao carregar áreas: $e");
    }
  }

  // Função para salvar a escolha e avançar
  Future<void> _finalizarRegisto() async {
    print("A atualizar user ${widget.userId} para a área $selectedAreaId");
    if (selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, selecione uma área!")),
      );
      return;
    }

    setState(() => isLoading = true);

    final sucesso = await _dbService.atualizarAreaUtilizador(widget.userId, selectedAreaId!);

    if (sucesso) {
      print("Sucesso! Área definida na BD.");
      
      // VERIFICA ESTA LINHA:
      // pushReplacement faz com que o utilizador não consiga voltar atrás para o registo
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MyApp()), // Substitui MainApp pelo nome da tua classe no main.dart
        );
      }
    } else {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erro ao salvar área. Tente novamente.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : Column(
          children: [
            // ================= HEADER =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              width: double.infinity,
              child: Center(
                child: Image.asset('lib/img/logo.png', height: 70, fit: BoxFit.contain),
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        const Text("Áreas", style: TextStyle(color: Color(0xFF6993BE), fontSize: 40, fontWeight: FontWeight.bold)),
                        const Text("Escolha a sua área de atuação"),
                        const SizedBox(height: 30),

                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: "Selecione a Área",
                            prefixIcon: Icon(Icons.list_alt_outlined),
                            border: OutlineInputBorder(),
                          ),
                          initialValue: selectedAreaId,
                          items: areas.map((area) {
                            return DropdownMenuItem<int>(
                              value: area['id'] as int,
                              child: Text(area['nome'].toString()),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => selectedAreaId = value),
                        ),

                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: _finalizarRegisto,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [Text("Avançar"), Icon(Icons.arrow_forward)],
                          ),
                        ),
                        
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancelar"),
                        )
                      ],
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