import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/basededados.dart';

class CertificadoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CertificadoPage({super.key, required this.userData});

  @override
  State<CertificadoPage> createState() => _CertificadoPageState();
}

class _CertificadoPageState extends State<CertificadoPage> {
  final Basededados _dbLocal = Basededados();
  Future<Map<String, dynamic>?>? _certificadoFuture;

  @override
  void initState() {
    super.initState();
    _certificadoFuture = _carregarDadosCertificadoLocal();
  }

  // REESCRITA OFFLINE-FIRST: Procura os metadados do certificado diretamente nas tabelas locais do SQFlite
  Future<Map<String, dynamic>?> _carregarDadosCertificadoLocal() async {
    try {
      final int userId = widget.userData['id_utilizador'] ?? 0;
      
      // Realiza uma consulta combinando os dados do utilizador com as tabelas do ecossistema local[cite: 12]
      final db = await _dbLocal.database;
      
      final List<Map<String, dynamic>> resultado = await db.rawQuery('''
        SELECT 
          u.nome_completo AS nome,
          c.progresso_nivel AS nivel,
          bm.nome_badge AS badge,
          ch.data_entrada_historico AS data,
          ch.id_candidatura_historico AS codigo
        FROM utilizador u
        INNER JOIN consultor c ON u.id_utilizador = c.id_utilizador
        LEFT JOIN candidatura_pedido cp ON c.id_utilizador = cp.id_utilizador
        LEFT JOIN badge_modelo bm ON cp.id_badge_modelo = bm.id_badge_modelo
        LEFT JOIN candidatura_tm ctm ON cp.id_candidatura_pedido = ctm.id_candidatura_pedido
        LEFT JOIN candidatura_sll csll ON ctm.id_candidatura_tm = csll.id_candidatura_tm
        LEFT JOIN candidatura_historico ch ON csll.id_candidatura_sll = ch.id_candidatura_sll
        WHERE u.id_utilizador = ? AND ch.estado_final = 'APROVADO'
        LIMIT 1
      ''', [userId]);

      if (resultado.isNotEmpty) {
        return resultado.first;
      }
    } catch (e) {
      print("Erro ao ler certificado local: $e");
    }
    return null;
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [                 
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "SOFTINSA",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF39639C),
                      ),
                    ),
                  ),
                  const Spacer(),
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
                ],
              ),
            ),

            // ================= CONTEÚDO DINÂMICO LOCAL =================
            Expanded(
              child: FutureBuilder<Map<String, dynamic>?>(
                future: _certificadoFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                  }

                  if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.info_outline, size: 60, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              "Certificado não disponível localmente ou ainda não foi aprovado pela equipa Softinsa.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final dados = snapshot.data!;
                  
                  // Tratamento seguro da data armazenada como TEXT no SQLite
                  String dataFormatada = "Data pendente";
                  if (dados['data'] != null) {
                    final DateTime? dataParsed = DateTime.tryParse(dados['data'].toString());
                    if (dataParsed != null) {
                      dataFormatada = DateFormat("d 'de' MMMM 'de' yyyy").format(dataParsed);
                    }
                  }

                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Text(
                            "Certificado de Competências", 
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),
                          const Icon(Icons.workspace_premium, size: 80, color: Color(0xFF4470AF)),
                          
                          const SizedBox(height: 40),
                          const Text("Certificamos que:", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          Text(
                            dados['nome'] ?? widget.userData['nome_completo'] ?? "Utilizador", 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4470AF)),
                          ),
                          const Text("Consultor Softinsa", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          
                          const SizedBox(height: 30),
                          const Text("Concluiu com sucesso o badge:", style: TextStyle(fontSize: 16)),
                          const SizedBox(height: 10),
                          Text(
                            "${dados['badge'] ?? 'Formação Base'} – ${dados['nivel'] ?? 'Nível A'}", 
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),

                          const SizedBox(height: 40),
                          Divider(color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("Data de emissão: $dataFormatada", style: const TextStyle(fontSize: 13)),
                          Text("Código Único Softinsa: CERT-${dados['codigo'] ?? '000'}", style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          
                          const SizedBox(height: 40),
                          
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
                                  print("A gerar PDF do certificado...");
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildActionButton(Icons.table_view, "Gerar EXCEL", Colors.green, () {
                                  print("A gerar listagem Excel...");
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
        const Icon(Icons.edit_note, size: 40, color: Colors.grey),
        Container(width: 120, height: 1, color: Colors.black45),
        const SizedBox(height: 6),
        Text(cargo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: Colors.grey.shade300),
        elevation: 0,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: color),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}