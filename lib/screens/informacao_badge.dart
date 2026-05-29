import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'submeter_badge.dart';

String obterNivel(dynamic idNivel) {
  switch (idNivel) {
    case 1:
      return 'A';
    case 2:
      return 'B';
    case 3:
      return 'C';
    case 4:
      return 'D';
    case 5:
      return 'E';
    default:
      return '-';
  }
}

Color obterCorNivel(String letraNivel) {
  switch (letraNivel) {
    case 'A':
      return const Color(0xFF2E7D32); 
    case 'B':
      return const Color(0xFF2E7D32); 
    case 'C':
      return const Color(0xFF2E7D32); 
    case 'D':
      return const Color(0xFF2E7D32); 
    case 'E':
      return const Color.fromARGB(255, 213, 181, 21); 
    default:
      return Colors.grey;
  }
}

class BadgeDetalhe extends StatefulWidget {
  final int userId;
  final int badgeId;

  

  const BadgeDetalhe({
    super.key,
    required this.userId,
    required this.badgeId,
  });

  @override
  State<BadgeDetalhe> createState() => _BadgeDetalheState();
}

class _BadgeDetalheState extends State<BadgeDetalhe> {
  Map<String, dynamic>? badge;
  Map<String, dynamic>? progresso;
  List<Map<String, dynamic>> badgesRelacionados = [];
  List<Map<String, dynamic>> requisitos = [];
  bool loading = true;
  bool descricaoExpandida = false;

  static const Color _azul = Color(0xFF4470AF);
  

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
  final api = ApiService();

  final todos = await api.getTodosBadges();
  final obtidos = await api.getBadgesObtidos(widget.userId);

  // 🔥 helper seguro para id
  int getId(Map b) =>
      int.tryParse((b['id'] ?? b['id_badge']).toString()) ?? -1;

  // ── BADGE PRINCIPAL ─────────────────────────────
  final badgeEncontrado = todos.firstWhere(
    (b) => getId(b) == widget.badgeId,
    orElse: () => <String, dynamic>{},
  );

  // ── PROGRESSO DO UTILIZADOR ─────────────────────
  final progressoEncontrado = obtidos.firstWhere(
    (b) => getId(b) == widget.badgeId,
    orElse: () => <String, dynamic>{},
  );

  // ── BADGES RELACIONADOS ─────────────────────────
  final relacionados = todos
      .where((b) =>
          b['id_nivel']?.toString() ==
              badgeEncontrado['id_nivel']?.toString() &&
          getId(b) != widget.badgeId)
      .take(5)
      .map((b) {
        final ob = obtidos.firstWhere(
          (o) => getId(o) == getId(b),
          orElse: () => <String, dynamic>{},
        );

        return {
          ...b,
          'conquistado': ob.isNotEmpty &&
              (ob['conquistado'] == true || ob['conquistado'] == 1),
          'progress': ob['progress'] != null
              ? double.tryParse(ob['progress'].toString())
              : null,
          'data_conquista': ob['data_atribuicao'] ?? ob['data_conquista'],
        };
      })
      .toList();

  // ── REQUISITOS (seguro) ─────────────────────────
  List<Map<String, dynamic>> reqs = [];

  final raw = badgeEncontrado['requisitos'];
  if (raw is List) {
    reqs = List<Map<String, dynamic>>.from(raw);
  }

  setState(() {
    badge = badgeEncontrado.isNotEmpty ? badgeEncontrado : null;
    progresso =
        progressoEncontrado.isNotEmpty ? progressoEncontrado : null;
    badgesRelacionados = relacionados;
    requisitos = reqs;
    loading = false;
  });
}

  bool get conquistado => progresso != null && progresso!.isNotEmpty;

  double? get progressoValor => progresso != null
    ? double.tryParse(progresso!['progress']?.toString() ?? '')
    : null;

  String? get dataConquista => progresso?['data_atribuicao']?.toString();

  String _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  // Níveis existentes para o grid de níveis
  static const List<String> _todosNiveis = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4470AF))),
      );
    }

    if (badge == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        body: SafeArea(
          child: Column(
            children: [
              const Expanded(
                child: Center(child: Text("Badge não encontrado")),
              ),
            ],
          ),
        ),
      );
    }

    final nome = badge!['nome']?.toString() ?? '';
    final descricao = badge!['descricao']?.toString() ?? '';
    final pontos =
        int.tryParse(badge!['pontos']?.toString() ?? '0') ?? 0;
    final nivelAtual = badge!['id_nivel']?.toString() ?? '';

    // Encontra o id_nivel atual do badge
    final nivelId = badge!['id_nivel']; 
    // Transforma o ID (ex: 1) na Letra (ex: 'A')
    final letraNivel = obterNivel(nivelId); 
    // Obtém a cor correspondente à letra
    final corDoNivel = obterCorNivel(letraNivel);

    // Texto de estado
    String estadoTexto;
    Color estadoCor;
    if (conquistado) {
      final data = _formatarData(dataConquista);
      estadoTexto = data.isNotEmpty ? "Conquistado em $data" : "Conquistado";
      estadoCor = const Color(0xFF2E7D32);
    } else if (progressoValor != null && progressoValor! > 0) {
      estadoTexto =
          "Em progresso (${(progressoValor! * 100).toStringAsFixed(0)}%)";
      estadoCor = _azul;
    } else {
      estadoTexto = "Por Conquistar";
      estadoCor = Colors.grey;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO SCROLLÁVEL ────────────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voltar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back,
                                size: 20, color: _azul),
                            SizedBox(width: 6),
                            Text("Voltar",
                                style: TextStyle(
                                    color: _azul, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── CARD TOPO: ícone + nome ──────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Ícone grande
                          Container(
                            width: 160,
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
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAF0FA),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text("🏅",
                                        style: TextStyle(fontSize: 44)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  nome,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Info lateral: pontos + estado
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color: _azul.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star,
                                          color: Color(0xFFFFC107),
                                          size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        "$pontos pontos",
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            estadoCor.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        estadoTexto,
                                        style: TextStyle(
                                          color: estadoCor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (progressoValor != null &&
                                          !conquistado) ...[
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: LinearProgressIndicator(
                                            value: progressoValor,
                                            minHeight: 6,
                                            backgroundColor:
                                                Colors.grey.shade200,
                                            color: _azul,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── DESCRIÇÃO ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
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
                            const Text(
                              "Descrição",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              descricao,
                              maxLines:
                                  descricaoExpandida ? null : 3,
                              overflow: descricaoExpandida
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                            if (descricao.length > 120) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setState(() =>
                                    descricaoExpandida =
                                        !descricaoExpandida),
                                child: Text(
                                  descricaoExpandida
                                      ? "Ver menos"
                                      : "Ler mais...",
                                  style: const TextStyle(
                                      color: _azul,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── NÍVEL + REQUISITOS (lado a lado) ─────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            // Nível
                            Container(
                              width: 130,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: _azul.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Nível",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _todosNiveis.map((n) {
                                      // 1. Converte o ID numérico na letra correspondente ('A', 'B', etc.)
                                      final letraAtualDoBadge = obterNivel(badge!['id_nivel']);
                                      
                                      // 2. Compara a letra do mapa ('n') com a letra real do badge
                                      final isAtual = n == letraAtualDoBadge;
                                      
                                      // 3. Descobre qual é a cor customizada para a bolinha atual (seja ela a selecionada ou não)
                                      final corDoNivel = obterCorNivel(n);

                                      return Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          // Se for o nível atual, pinta com a cor dinâmica do nível. Se não, fica cinzento claro.
                                          color: isAtual
                                              ? corDoNivel
                                              : Colors.grey.shade100,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isAtual
                                                ? corDoNivel
                                                : Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            n,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              // O texto fica branco na bolinha ativa para dar leitura, e cinzento nas desativadas
                                              color: isAtual
                                                  ? Colors.white
                                                  : Colors.grey,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // Requisitos
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _azul.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Requisitos",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 12),
                                    if (requisitos.isEmpty)
                                      const Text(
                                        "Sem requisitos específicos",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey),
                                      )
                                    else
                                      ...requisitos
                                          .asMap()
                                          .entries
                                          .map((entry) {
                                        final idx = entry.key;
                                        final req = entry.value;
                                        final label =
                                            "${nivelAtual}${idx + 1}";
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8),
                                          child: Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      30),
                                              border: Border.all(
                                                  color: Colors
                                                      .grey.shade200),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 28,
                                                  height: 28,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color:
                                                        Color(0xFFFFC107),
                                                    shape:
                                                        BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      label,
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    req['descricao']
                                                            ?.toString() ??
                                                        req['nome']
                                                            ?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── BOTÕES DE AÇÃO ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: conquistado
                          ? Row(
                              children: [
                                // Partilhar no LinkedIn
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: const BorderSide(
                                          color: Colors.black87, width: 1.5),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      // TODO: partilhar no LinkedIn
                                    },
                                    icon: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0077B5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          "in",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                    label: const Text(
                                      "Partilhar no LinkedIn",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Obter certificado
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: const BorderSide(
                                          color: Colors.black87, width: 1.5),
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      // TODO: download certificado
                                    },
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text(
                                      "Obter certificado",
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity, // Faz o botão ocupar a largura toda
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _azul, // Cor azul que já tens definida
                                  foregroundColor: Colors.white,
                                  shape: const StadiumBorder(),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubmeterBadge(
                                        userId: widget.userData['id_utilizador'],
                                        badgeId: badge['id'],
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text(
                                  "Submeter evidências",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // ── BADGES RELACIONADOS ───────────────────────────
                    if (badgesRelacionados.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Badges Relacionados",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Divider(
                          color: Colors.grey.shade300,
                          height: 16,
                          indent: 16,
                          endIndent: 16),
                      ...badgesRelacionados
                          .map((b) => _badgeRelacionadoCard(b)),
                      const SizedBox(height: 24),
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
              height: 65,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  // ─── CARD BADGE RELACIONADO ───────────────────────────────────────────────
  Widget _badgeRelacionadoCard(Map<String, dynamic> b) {
    final bool conquistado =
        b['conquistado'] == true || b['conquistado'] == 1;
    final double? progress =
        double.tryParse(b['progress']?.toString() ?? '');
    final int pontos =
        int.tryParse(b['pontos']?.toString() ?? '0') ?? 0;

    String estadoTexto;
    Color estadoCor;
    if (conquistado) {
      final data = _formatarData(b['data_conquista']?.toString());
      estadoTexto =
          data.isNotEmpty ? "Conquistado em $data" : "Conquistado";
      estadoCor = const Color(0xFF2E7D32);
    } else if (progress != null && progress > 0) {
      estadoTexto = "Em Progresso";
      estadoCor = _azul;
    } else {
      estadoTexto = "Por conquistar";
      estadoCor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        final id =
            int.tryParse(b['id_badge']?.toString() ?? '') ?? -1;
        if (id != -1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BadgeDetalhe(
                userId: widget.userId,
                badgeId: id,
              ),
            ),
          );
        }
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: conquistado
                ? const Color(0xFF2E7D32).withOpacity(0.3)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: conquistado
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFEAF0FA),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text("🏅",
                            style: TextStyle(fontSize: 26)),
                      ),
                    ),
                    if (conquistado)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Color(0xFF2E7D32),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check,
                              color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['nome']?.toString() ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        b['descricao']?.toString() ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    border:
                        Border.all(color: _azul.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Text("Pontos",
                          style: TextStyle(
                              fontSize: 9, color: _azul)),
                      Text(
                        "$pontos",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: _azul),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                estadoTexto,
                style: TextStyle(
                    fontSize: 11,
                    color: estadoCor,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}