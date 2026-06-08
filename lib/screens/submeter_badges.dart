import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
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

  Map<String, dynamic>? badge;
  bool isLoading = true;

  final TextEditingController _descricaoController = TextEditingController();
  PlatformFile? _ficheiro;
  bool _submetido = false;

  // Níveis fixos
  static const List<Map<String, String>> _niveis = [
    {'letra': 'A', 'descricao': 'Júnior'},
    {'letra': 'B', 'descricao': 'Intermédio'},
    {'letra': 'C', 'descricao': 'Sénior'},
    {'letra': 'D', 'descricao': 'Especialista'},
    {'letra': 'E', 'descricao': 'Líder Conhecimento'},
  ];

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
    try {
      final api = ApiService();
      final todos = await api.getTodosBadges();
      final encontrado = todos.firstWhere(
        (b) => int.tryParse(b['id'].toString()) == widget.badgeId,
        orElse: () => <String, dynamic>{},
      );
      setState(() {
        badge = encontrado.isNotEmpty ? encontrado : null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar badge: $e");
      setState(() => isLoading = false);
    }
  }

  String _letraNivel() {
    if (badge == null) return '';
    return obterNivel(badge!['id_nivel']);
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

  Future<void> _submeter() async {
    if (!_podeSubmeter) return;
    setState(() => _submetido = true);

    try {
      final api = ApiService();

      await api.submeterEvidencia(
        userId: widget.userId,
        badgeId: widget.badgeId,
        descricao: _descricaoController.text,
        ficheiroPath: _ficheiro!.path!,
      );

      // 🔥 RECARREGAR DADOS COMO NO CATÁLOGO
      final todos = await api.getTodosBadges();
      final obtidos = await api.getBadgesConquistados(widget.userId);

      final atualizado = obtidos.any(
        (b) => int.tryParse(b['id'].toString()) == widget.badgeId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            atualizado
                ? "Badge conquistado com sucesso! 🎉"
                : "Evidência submetida para avaliação",
          ),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Erro ao submeter: $e");
      _mostrarErro("Erro ao submeter. Tenta novamente.");
      setState(() => _submetido = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    final niveis = [1, 2, 3, 4, 5];

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

    final String nome = badge!['nome']?.toString() ?? '';
    final String letraNivelAtual = _letraNivel();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO ──────────────────────────────────────────────
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: headerHeight),

                  // Voltar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back,
                                  size: 20, color: _azul),
                              SizedBox(width: 6),
                              Text(
                                "Voltar",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: _azul,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── CARD DO BADGE ────────────────────────────
                          Center(
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _azul.withOpacity(0.3)),
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEEEEEE),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text("🏅",
                                          style:
                                              TextStyle(fontSize: 42)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    nome,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── NÍVEL ─────────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: _azul.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Nível",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Bolinhas
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: niveis.map((id) {
                                    final letra = obterNivel(id);
                                    final isAtual = id == badge!['id_nivel'];
                                    final cor = obterCorNivel(letra);

                                    return _nivelCirculo(
                                      letra: letra,
                                      isAtual: isAtual,
                                      cor: cor,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                                // Legenda em 2 colunas
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text("A - Júnior",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          Text("B - Intermédio",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text("C - Sénior",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                          Text("D - Especialista",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: const [
                                          Text("E - Líder Conhecimento",
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── DESCRIÇÃO ─────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _azul.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.description_outlined,
                                        size: 18, color: _azul),
                                    SizedBox(width: 6),
                                    Text(
                                      "Descrição",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _descricaoController,
                                  maxLines: 8,
                                  decoration: InputDecoration(
                                    hintText:
                                        "Descreva o que aprendeu e como aplicou os conhecimentos...",
                                    hintStyle: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F7F7),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Mínimo 500 caracteres ($_charCount/500)",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _descricaoValida
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── ANEXAR FICHEIRO ───────────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _azul.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.upload_outlined,
                                        size: 18, color: _azul),
                                    SizedBox(width: 6),
                                    Text(
                                      "Anexar Ficheiro",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _escolherFicheiro,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 28),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F7),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _ficheiro != null
                                            ? const Color(0xFF2E7D32)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: _ficheiro == null
                                        ? Column(
                                            children: [
                                              Icon(Icons.upload,
                                                  size: 32,
                                                  color:
                                                      Colors.grey.shade500),
                                              const SizedBox(height: 6),
                                              const Text(
                                                "Clique para fazer upload",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "PDF, DOC, DOCX, JPG, PNG (max 10MB)",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        Colors.grey.shade500),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              const Icon(
                                                  Icons.check_circle,
                                                  size: 32,
                                                  color:
                                                      Color(0xFF2E7D32)),
                                              const SizedBox(height: 6),
                                              Text(
                                                _ficheiro!.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF2E7D32),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "Toque para alterar",
                                                style: TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        Colors.grey.shade500),
                                              ),
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

            // ── BOTÃO FIXO NO FUNDO ────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
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
                          backgroundColor:
                              _podeSubmeter ? _azul : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed:
                            _podeSubmeter && !_submetido ? _submeter : null,
                        icon: _submetido
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline,
                                size: 20),
                        label: Text(
                          _submetido
                              ? "A submeter..."
                              : "Submeter para Validação",
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (!_podeSubmeter) ...[
                      const SizedBox(height: 6),
                      const Text(
                        "Preencha todos os campos para submeter",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFFF9800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── HEADER ────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Image.asset(
                      'lib/img/logo.png',
                      height: 35,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOLINHA DE NÍVEL ──────────────────────────────────────────────────────
  Widget _nivelCirculo({required String letra, required bool isAtual, required Color cor,}) {
    final Color cor = obterCorNivel(letra);

    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isAtual ? cor : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isAtual ? cor : Colors.grey.shade400,
              width: isAtual ? 2 : 1.5,
            ),
          ),
          child: Center(
            child: Text(
              letra,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isAtual ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}