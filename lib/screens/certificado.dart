/*
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';

class CertificadoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CertificadoPage({super.key, required this.userData});

  @override
  State<CertificadoPage> createState() => _CertificadoPageState();
}

class _CertificadoPageState extends State<CertificadoPage> {
  final DatabaseService _dbService = DatabaseService();
  Future<Map<String, dynamic>?>? _certificadoFuture;

  @override
  void initState() {
    super.initState();
    _certificadoFuture = _dbService.obterDadosCertificado(
      widget.userData['id_badge_atrib'] ?? 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER (Sempre Visível) =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [                 
                  // Logo
                  Image.asset('lib/img/logo.png', height: 30, fit: BoxFit.contain),
                  
                  const Spacer(), // Empurra os ícones para a direita
                  
                  Row(
                    children: const [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF4470AF),
                        child: Icon(Icons.notifications, color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(0xFF4470AF),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),

            // ================= CONTEÚDO DINÂMICO =================
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _certificadoFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Caso dê erro ou não existam dados
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.info_outline, size: 60, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              "Certificado não disponível ou ainda não aprovado.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final dados = snapshot.data!;
                  // Formatação da data (Garante que 'data' não é nulo no seu DB)
                  final dataFormatada = dados['data'] != null 
                      ? DateFormat('d \'de\' MMMM \'de\' yyyy', 'pt_BR').format(dados['data'])
                      : "Data pendente";

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Text("Certificado de Competências", 
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Image.asset('lib/img/logo.png', height: 40),
                          
                          const SizedBox(height: 40),
                          const Text("Certificamos que:", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          Text(dados['nome'] ?? "Utilizador", 
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4470AF))),
                          Text("${dados['cargo'] ?? ''}", style: const TextStyle(fontSize: 14)),
                          
                          const SizedBox(height: 30),
                          const Text("Concluiu com sucesso o badge:", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          Text("${dados['badge'] ?? 'Badge'} – Nível ${dados['nivel'] ?? 'I'}", 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),

                          const SizedBox(height: 40),
                          Text("Data de emissão: $dataFormatada"),
                          Text("Código único de Verificação: ${dados['codigo'] ?? '---'}"),
                          
                          const SizedBox(height: 50),
                          
                          // ÁREA DE ASSINATURAS
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildAssinatura("Service Line Leader"),
                              _buildAssinatura("Talent Manager"),
                            ],
                          ),

                          const SizedBox(height: 40),

                          // BOTÕES DE AÇÃO EM LINHA
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(Icons.picture_as_pdf, "Gerar PDF", Colors.red, () {
                                  print("A gerar PDF...");
                                }),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildActionButton(Icons.table_view, "Gerar EXCEL", Colors.green, () {
                                  print("A gerar Excel...");
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssinatura(String cargo) {
    return Column(
      children: [
        const Icon(Icons.edit_note, size: 50, color: Colors.grey),
        Container(width: 120, height: 1, color: Colors.black),
        const SizedBox(height: 4),
        Text(cargo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        elevation: 2,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: color),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
*/