import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login.dart';

class AreaRegisterPage extends StatefulWidget {
  final String nome;
  final String email;
  final String password;
  final bool aceitouTermos;

  const AreaRegisterPage({
    super.key,
    required this.nome,
    required this.email,
    required this.password,
    required this.aceitouTermos,
  });

  @override
  _AreaRegPageState createState() => _AreaRegPageState();
}

class _AreaRegPageState extends State<AreaRegisterPage> {
  final ApiService _apiService = ApiService();

  int? _selectedAreaId;
  List<Map<String, dynamic>> _areas = [];
  bool _isLoading = true;
  bool _aGravar = false;

  @override
  void initState() {
    super.initState();
    _carregarAreas();
  }

  Future<void> _carregarAreas() async {
    try {
      print("A carregar áreas de forma Offline-First...");
      
      // Invoca o método adaptado que descarrega da API ou recorre à cache local do SQFlite
      final lista = await _apiService.getAreas();

      setState(() {
        _areas = lista;
        _isLoading = false;
      });
    } catch (e) {
      print("ERRO ao ler áreas no registo: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _finalizarRegisto() async {
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma área!")),
      );
      return;
    }

    setState(() => _aGravar = true);

    // O registo físico continua a requerer rede (PostgreSQL)
    final sucesso = await _apiService.register(
      nome: widget.nome,
      email: widget.email,
      password: widget.password,
      aceitarTermos: widget.aceitouTermos,
      idArea: _selectedAreaId!,
    );

    setState(() => _aGravar = false);

    if (!mounted) return;

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Conta criada! Verifique o seu e-mail para ativar a conta."),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro ao efetuar registo. Verifique a sua ligação."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : Column(
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

                  // CONTEÚDO
                  Expanded(
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
                            children: [
                              const Text(
                                "Área",
                                style: TextStyle(
                                  color: Color(0xFF6993BE),
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text("Escolha a sua área de atuação"),
                              const SizedBox(height: 30),

                              // DROPDOWN SINCRONIZADO
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: "Selecione a Área",
                                  prefixIcon: Icon(Icons.list_alt_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                value: _selectedAreaId,
                                // AJUSTE: Mapeia dinamicamente usando os campos do teu pgAdmin (ID_AREAS / NOME_AREA)
                                items: _areas.map((area) {
                                  final int id = area['id_areas'] ?? area['id'] ?? 0;
                                  final String nome = area['nome_area'] ?? area['nome'] ?? 'Sem Nome';
                                  
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: Text(nome),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => _selectedAreaId = value),
                              ),
                              const SizedBox(height: 30),

                              // BOTÃO SUBMETER
                              ElevatedButton(
                                onPressed: _aGravar ? null : _finalizarRegisto,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _aGravar
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text("Concluir registo"),
                                          SizedBox(width: 6),
                                          Icon(Icons.check),
                                        ],
                                      ),
                              ),
                              TextButton(
                                onPressed: _aGravar ? null : () => Navigator.pop(context),
                                child: const Text("Voltar"),
                              ),
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