import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para salvar evidências offline
import 'informacoes_badge.dart';

class SubmeterBadge extends StatefulWidget {
  final int userId;
  final int badgeId;

  const SubmeterBadge({
    super.key,
    required this.userId,
    required this.badgeId,
  });

  @override
  State<SubmeterBadge> createState() => _SubmeterBadgeState();
}

class _SubmeterBadgeState extends State<SubmeterBadge> {
  static const Color _azul = Color(0xFF4470AF);

  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância local SQLite

  Map<String, dynamic>? badge;
  bool isLoading = true;

  final TextEditingController _descricaoController = TextEditingController();
  PlatformFile? _ficheiro;
  bool _submetido = false;

  @override
  void initState() {
    super.initState();
    _carregarBadge();
    _descricaoController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _carregarBadge() async {
    List<Map<String, dynamic>> todos = [];
    
    try {
      todos = await _apiService.getTodosBadges();
    } catch (e) {
      debugPrint("Modo Offline Ativo ao carregar badge para submissão: $e");
      
      final localModelos = await _dbLocal.listarTabela('badge_modelo');
      todos = localModelos.map((e) => {
        'id': e['id_badge_modelo'],
        'nome': e['nome_badge'],
        'descricao': e['descricao_badge_modelo'],
        'pontos': e['pontos'],
        'id_nivel': e['id_nivel']
      }).toList();
    }

    final encontrado = todos.firstWhere(
      (b) => (int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? '').toString()) ?? -1) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    if (mounted) {
      setState(() {
        badge = encontrado.isNotEmpty ? encontrado : null;
        isLoading = false;
      });
    }
  }

  int get _charCount => _descricaoController.text.length;
  bool get _descricaoValida => _charCount >= 500;
  bool get _podeSubmeter => _descricaoValida && _ficheiro != null;

  Future<void> _escolherFicheiro() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
        withData: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final sizeInMB = file.size / (1024 * 1024);

      if (sizeInMB > 10) {
        _mostrarErro("O ficheiro não pode ultrapassar 10MB.");
        return;
      }

      setState(() => _ficheiro = file);
    } catch (e) {
      _mostrarErro("Erro ao selecionar ficheiro: $e");
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FLUXO ASSÍNCRONO CORRIGIDO E ALINHADO COM AS COLUNAS DO BASEDEDADOS.DART
  Future<void> _submeter() async {
    if (!_podeSubmeter || _submetido) return;

    setState(() {
      _submetido = true; // Ativa o loading circular no botão
    });

    final String descricaoTexto = _descricaoController.text;
    final String pathFicheiro = _ficheiro!.path ?? 'cache_offline_path';

    try {
      // 1. Tenta enviar para o Render com limite de 20 segundos de resposta
      await _apiService.submeterEvidencia(
        userId: widget.userId,
        badgeId: widget.badgeId,
        descricao: descricaoTexto,
        ficheiroPath: pathFicheiro,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Evidência submetida para avaliação com sucesso!"), backgroundColor: Color(0xFF2E7D32)),
      );
      Navigator.pop(context, true);

    } catch (e) {
      debugPrint("Falha de rede ou timeout ao submeter evidência. Salvando localmente SQFlite... ($e)");

      try {
        final int idPedidoGeradoLocal = DateTime.now().millisecondsSinceEpoch;

        // CORREÇÃO CIRÚRGICA: Mapeamento de colunas batendo 100% com o teu base de dados
        await _dbLocal.salvarRegisto('candidatura_pedido', {
          'id_candidatura_pedido': idPedidoGeradoLocal, 
          'id_utilizador': widget.userId,
          'id_badge_modelo': widget.badgeId,
          'data_submisao': DateTime.now().toString(), // Grafia correta: apenas um "s"
          'estado_candidatura_pedido': 'Aguardando Sincronização', // Coluna correta do DB
        });

        // Para não perderes o texto longo e o anexo em offline, espelhamos para a tabela de evidencias
        try {
          await _dbLocal.salvarRegisto('evidencias', {
            'id_evidencia': idPedidoGeradoLocal + 1,
            'id_requisitos': null, // Atribuído pelo SLL na validação online
            'id_candidatura_pedido': idPedidoGeradoLocal,
            'descricao': descricaoTexto,
            'nome_ficheiro': _ficheiro!.name,
            'formato_ficheiro': _ficheiro!.extension ?? 'file',
            'data_submissao': DateTime.now().toString(),
            'estado_evidencia': 'Pendente',
            'caminho_ficheiro': pathFicheiro,
          });
        } catch (erroEvidencia) {
          debugPrint("Nota: Inserção na tabela secundária de evidências falhou: $erroEvidencia");
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("💾 Guardado localmente com sucesso! Será sincronizado assim que recuperar internet."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);

      } catch (errDb) {
        if (!mounted) return;
        _mostrarErro("Erro crítico ao gravar localmente no SQLite: $errDb");
      }
    } finally {
      // Regra de ouro: desliga sempre o indicador de progresso para não congelar o ecrã
      if (mounted) {
        setState(() {
          _submetido = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    final niveisIds = [1, 2, 3, 4, 5];

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: CircularProgressIndicator(color: _azul)),
      );
    }

    if (badge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: Text("Badge não encontrado")),
      );
    }

    final String nome = badge!['nome'] ?? badge!['nome_badge'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),

                  // Voltar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back, size: 20, color: _azul),
                              SizedBox(width: 6),
                              Text("Voltar", style: TextStyle(fontSize: 15, color: _azul, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Formulário
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CARD DO BADGE
                          Center(
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(color: Color(0xFFEEEEEE), shape: BoxShape.circle),
                                    child: const Center(child: Text("🏅", style: TextStyle(fontSize: 42))),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // NÍVEL INDICATOR
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Nível do Badge", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: niveisIds.map((id) {
                                    final letra = obterNivel(id);
                                    final isAtual = id.toString() == badge!['id_nivel']?.toString();
                                    final cor = obterCorNivel(letra);

                                    return _nivelCirculo(letra: letra, isAtual: isAtual, cor: cor);
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: Text("A - Júnior\nB - Intermédio", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                    Expanded(child: Text("C - Sénior\nD - Especialista", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                    Expanded(child: Text("E - Líder Mestre", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // CAIXA DE TEXTO DA DESCRIÇÃO
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.description_outlined, size: 18, color: _azul),
                                    SizedBox(width: 6),
                                    Text("Descrição do Desafio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _descricaoController,
                                  maxLines: 8,
                                  enabled: !_submetido,
                                  decoration: InputDecoration(
                                    hintText: "Descreva de forma detalhada o projeto, tarefas executadas e de que forma aplicou os conhecimentos desta Service Line...",
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F7F7),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Mínimo 500 caracteres ($_charCount/500)",
                                  style: TextStyle(fontSize: 12, color: _descricaoValida ? const Color(0xFF2E7D32) : Colors.orange.shade800, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // UPLOAD DE DOCUMENTOS
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.upload_outlined, size: 18, color: _azul),
                                    SizedBox(width: 6),
                                    Text("Anexar Ficheiro Comprovativo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: !_submetido ? _escolherFicheiro : null,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 28),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _ficheiro != null ? const Color(0xFF2E7D32) : Colors.grey.shade300, width: 1.5),
                                    ),
                                    child: _ficheiro == null
                                        ? Column(
                                            children: [
                                              Icon(Icons.upload, size: 32, color: Colors.grey.shade500),
                                              const SizedBox(height: 6),
                                              const Text("Clique para fazer upload", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                              const SizedBox(height: 4),
                                              Text("PDF, DOC, DOCX, JPG, PNG (max 10MB)", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              const Icon(Icons.check_circle, size: 32, color: Color(0xFF2E7D32)),
                                              const SizedBox(height: 6),
                                              Text(_ficheiro!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2E7D32)), textAlign: TextAlign.center),
                                              const SizedBox(height: 4),
                                              Text("Toque para alterar o ficheiro", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTÃO FIXO DE SUBMISSÃO
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _podeSubmeter && !_submetido ? _azul : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: _podeSubmeter && !_submetido ? _submeter : null,
                        icon: _submetido
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(_submetido ? "A processar submissão..." : "Submeter para Validação", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (!_podeSubmeter && !_submetido) ...[
                      const SizedBox(height: 6),
                      Text(
                        _ficheiro == null ? "Falta anexar o ficheiro comprovativo" : "A descrição necessita de ter pelo menos 500 caracteres",
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // HEADER PRINCIPAL
            Positioned(
              top: 0, left: 0, right: 0, height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [Image.asset('lib/img/logo.png', height: 35, fit: BoxFit.contain)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nivelCirculo({required String letra, required bool isAtual, required Color cor}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isAtual ? cor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isAtual ? cor : Colors.grey.shade400, width: isAtual ? 2 : 1.5),
      ),
      child: Center(
        child: Text(
          letra,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isAtual ? Colors.white : Colors.grey.shade600),
        ),
      ),
    );
  }
}