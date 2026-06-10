import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import crucial para ler os requisitos offline
import 'submeter_badges.dart';
import 'certificado_page.dart';

Map<String, dynamic>? certificadoDisponivel;

String obterNivel(dynamic idNivel) {
  switch (int.tryParse(idNivel.toString())) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

int obterIdNivel(String letra) {
  switch (letra) {
    case 'A': return 1;
    case 'B': return 2;
    case 'C': return 3;
    case 'D': return 4;
    case 'E': return 5;
    default: return 1;
  }
}

Color obterCorNivel(String letraNivel) {
  switch (letraNivel) {
    case 'A':
    case 'B':
    case 'C':
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
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local SQLite

  Map<String, dynamic>? badge;
  Map<String, dynamic>? progresso;
  List<Map<String, dynamic>> badgesRelacionados = [];
  List<Map<String, dynamic>> requisitos = [];
  bool loading = true;
  bool descricaoExpandida = false;
  
  // Estado para controlar qual o nível que o utilizador está a inspecionar ativamente
  String nivelVisualizado = 'A';

  static const Color _azul = Color(0xFF4470AF);

  @override
  void initState() {
    super.initState();
    carregar();
  }

  Future<void> carregar() async {
    List<Map<String, dynamic>> todos = [];
    List<Map<String, dynamic>> obtidos = [];

    int getId(Map b) => int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? b['id_badge'] ?? '').toString()) ?? -1;

    try {
      // 1. Tenta carregar tudo em tempo real através do servidor (HTTP)
      todos = await _apiService.getTodosBadges();
      obtidos = await _apiService.getBadgesConquistados(widget.userId);

      try {
        final notificacoes = await _apiService.getNotifications(widget.userId);
        certificadoDisponivel = notificacoes.firstWhere(
          (c) => c['id_badge_modelo'].toString() == widget.badgeId.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (certificadoDisponivel?.isEmpty ?? true) certificadoDisponivel = null;
      } catch (_) {
        certificadoDisponivel = null;
      }

    } catch (e) {
      debugPrint("Modo Offline Ativo no Detalhe do Badge: Buscando no SQFlite... ($e)");
      
      // 2. FALLBACK: Carrega o modelo de cache local do SQLite se falhar a internet
      final localModelos = await _dbLocal.listarTabela('badge_modelo');
      final localAtribuidos = await _dbLocal.listarTabela('badge_atribuido');

      todos = localModelos.map((e) => {
        'id': e['id_badge_modelo'],
        'nome': e['nome_badge'],
        'descricao': e['descricao_badge_modelo'],
        'pontos': e['pontos'],
        'id_nivel': e['id_nivel']
      }).toList();

      obtidos = localAtribuidos.map((e) => {
        'id': e['id_badge_modelo'],
        'data_atribuicao': e['data_atribuicao'],
      }).toList();
    }

    // ── IDENTIFICAÇÃO DO BADGE PRINCIPAL ─────────────────────────────
    final badgeEncontrado = todos.firstWhere(
      (b) => getId(b) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    // Configura o nível visualizado inicial baseado no nível real do badge
    if (badgeEncontrado.isNotEmpty) {
      nivelVisualizado = obterNivel(badgeEncontrado['id_nivel']);
    }

    // ── PROGRESSO DO UTILIZADOR ─────────────────────
    final progressoEncontrado = obtidos.firstWhere(
      (b) => getId(b) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    // ── BADGES RELACIONADOS ─────────────────────────
    final relacionados = todos
        .where((b) =>
            b['id_nivel']?.toString() == badgeEncontrado['id_nivel']?.toString() &&
            getId(b) != widget.badgeId)
        .take(5)
        .map((b) {
          final ob = obtidos.firstWhere(
            (o) => getId(o) == getId(b),
            orElse: () => <String, dynamic>{},
          );

          return {
            ...b,
            'conquistado': ob.isNotEmpty,
            'progress': ob['progress'] != null ? double.tryParse(ob['progress'].toString()) : null,
            'data_conquista': ob['data_atribuicao'] ?? ob['data_conquista'],
          };
        })
        .toList();

    if (mounted) {
      setState(() {
        badge = badgeEncontrado.isNotEmpty ? badgeEncontrado : null;
        progresso = progressoEncontrado.isNotEmpty ? progressoEncontrado : null;
        badgesRelacionados = relacionados;
        loading = false;
      });
      // Carrega os requisitos do nível padrão
      atualizarListaRequisitos(nivelVisualizado);
    }
  }

  // Método reativo para buscar requisitos na tabela correta do SQLite
  Future<void> atualizarListaRequisitos(String letraNivel) async {
    List<Map<String, dynamic>> reqs = [];
    final int alvoNivelId = obterIdNivel(letraNivel);

    final rawRequisitos = badge?['requisitos'];
    if (rawRequisitos is List) {
      reqs = rawRequisitos
          .map((item) => Map<String, dynamic>.from(item))
          .where((r) => r['id_nivel']?.toString() == alvoNivelId.toString() || rawRequisitos.length <= 5)
          .toList();
    } else {
      // CORREÇÃO DE TABELA: Buscando da tabela 'badge_requisito' mapeada no SQLite
      final todosReqsLocais = await _dbLocal.listarTabela('badge_requisito');
      reqs = todosReqsLocais
          .where((r) => r['id_badge_modelo'].toString() == widget.badgeId.toString())
          .map((r) => {
                'titulo': r['nome_requisito'] ?? 'REQ', 
                'nome': r['descricao_requisito'] ?? 'Sem descrição cadastrada localmente.'
              })
          .toList();
    }

    if (mounted) {
      setState(() {
        nivelVisualizado = letraNivel;
        requisitos = reqs;
      });
    }
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

  static const List<String> _todosNiveis = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4470AF))),
      );
    }

    if (badge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: SafeArea(
          child: Center(child: Text("Badge não encontrado")),
        ),
      );
    }

    final nome = badge!['nome'] ?? badge!['nome_badge'] ?? '';
    final descricao = badge!['descricao'] ?? badge!['descricao_badge_modelo'] ?? '';
    final pontos = int.tryParse(badge!['points']?.toString() ?? badge!['pontos']?.toString() ?? '0') ?? 0;
    final nivelId = badge!['id_nivel']; 
    final letraNivelReal = obterNivel(nivelId); 
    final corDoNivel = obterCorNivel(letraNivelReal);

    String estadoTexto;
    Color estadoCor;
    if (conquistado) {
      final data = _formatarData(dataConquista);
      estadoTexto = data.isNotEmpty ? "Conquistado em $data" : "Conquistado";
      estadoCor = const Color(0xFF2E7D32);
    } else if (progressoValor != null && progressoValor! > 0) {
      estadoTexto = "Em progresso (${(progressoValor! * 100).toStringAsFixed(0)}%)";
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
                            Icon(Icons.arrow_back, size: 20, color: _azul),
                            SizedBox(width: 6),
                            Text("Voltar", style: TextStyle(color: _azul, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CARD TOPO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 160,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _azul.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                BadgeImage(
                                  imageUrl: badge!['imagem']?.toString(),
                                  size: 60,
                                ),
                                const SizedBox(height: 10),
                                Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _azul.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                                      const SizedBox(width: 6),
                                      Text("$pontos pontos", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: estadoCor.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(estadoTexto, style: TextStyle(color: estadoCor, fontWeight: FontWeight.w600, fontSize: 12)),
                                      if (progressoValor != null && !conquistado) ...[
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: LinearProgressIndicator(value: progressoValor, minHeight: 6, backgroundColor: Colors.grey.shade200, color: _azul),
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

                    // DESCRIÇÃO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _azul.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Descrição", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            Text(descricao, maxLines: descricaoExpandida ? null : 3, overflow: descricaoExpandida ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            if (descricao.length > 120) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setState(() => descricaoExpandida = !descricaoExpandida),
                                child: Text(descricaoExpandida ? "Ver menos" : "Ler mais...", style: const TextStyle(color: _azul, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NÍVEL + REQUISITOS (INTERATIVO)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 130,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _azul.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Nível", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _todosNiveis.map((n) {
                                      final isSelecionado = n == nivelVisualizado;
                                      final corCirculo = obterCorNivel(n);

                                      return InkWell(
                                        onTap: () => atualizarListaRequisitos(n),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelecionado ? corCirculo : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: isSelecionado ? corCirculo : Colors.grey.shade300, width: isSelecionado ? 2 : 1),
                                          ),
                                          child: Center(
                                            child: Text(n, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelecionado ? Colors.white : Colors.grey)),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // REQUISITOS LIST
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _azul.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Requisitos (Nível $nivelVisualizado)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 12),
                                    if (requisitos.isEmpty)
                                      const Expanded(
                                        child: Center(
                                          child: Text(
                                            "Sem requisitos cadastrados.", 
                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      )
                                    else
                                      ...requisitos.map((req) {
                                        final textoCirculo = req['titulo']?.toString() ?? 'REQ';
                                        final textoFrente = req['nome']?.toString() ?? '';
                                        
                                        // CORREÇÃO: Tratamento seguro de strings para evitar estouro de índice
                                        final abreviatura = textoCirculo.length > 3 ? textoCirculo.substring(0, 3) : textoCirculo;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                                                  child: Center(child: Text(abreviatura, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(textoFrente, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // BOTÕES DE AÇÃO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: conquistado
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.black87, width: 1.5), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: () {}, 
                                    icon: Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF0077B5), borderRadius: BorderRadius.circular(4)), child: const Center(child: Text("in", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                                    label: const Text("Partilhar no LinkedIn", style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.black87, width: 1.5), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CertificadoCompetenciasPage(
                                            userData: {'id_utilizador': widget.userId},
                                            certificadoData: {
                                              'nome_badge': nome,
                                              'descricao_badge_modelo': descricao,
                                              'pontos': pontos,
                                              'id_nivel': nivelId,
                                              'data_emissao': _formatarData(dataConquista)
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text("Obter certificado", style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _azul, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SubmeterBadge(userId: widget.userId, badgeId: widget.badgeId)),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text("Submeter evidências", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // BADGES RELACIONADOS
                    if (badgesRelacionados.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Badges Relacionados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Divider(color: Colors.grey.shade300, height: 16, indent: 16, endIndent: 16),
                      ...badgesRelacionados.map((b) => _badgeRelacionadoCard(b)),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),

            // HEADER FIXO
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 65,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset('lib/img/logo.png', height: 35, fit: BoxFit.contain),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeRelacionadoCard(Map<String, dynamic> b) {
    final bool conquistadoRel = b['conquistado'] == true;
    final double? progressRel = double.tryParse(b['progress']?.toString() ?? '');
    final int pontosRel = int.tryParse(b['points']?.toString() ?? b['pontos']?.toString() ?? '0') ?? 0;

    String estadoTexto;
    Color estadoCor;
    if (conquistadoRel) {
      final data = _formatarData(b['data_conquista']?.toString());
      estadoTexto = data.isNotEmpty ? "Conquistado em $data" : "Conquistado";
      estadoCor = const Color(0xFF2E7D32);
    } else if (progressRel != null && progressRel > 0) {
      estadoTexto = "Em Progresso";
      estadoCor = _azul;
    } else {
      estadoTexto = "Por conquistar";
      estadoCor = Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        final id = int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? b['id_badge'] ?? '').toString()) ?? -1;
        if (id != -1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => BadgeDetalhe(userId: widget.userId, badgeId: id)),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: conquistadoRel ? const Color(0xFF2E7D32).withOpacity(0.3) : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
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
                      decoration: BoxDecoration(color: conquistadoRel ? const Color(0xFFE8F5E9) : const Color(0xFFEAF0FA), shape: BoxShape.circle),
                      child: 
                        BadgeImage(
                          imageUrl: b['imagem']?.toString(),
                          size: 60,
                        ),
                    ),
                    if (conquistadoRel)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(b['descricao']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: _azul.withOpacity(0.6)), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text("Pontos", style: TextStyle(fontSize: 9, color: _azul)),
                      Text("$pontosRel", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _azul)),
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
              child: Text(estadoTexto, style: TextStyle(fontSize: 11, color: estadoCor, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}

class BadgeImage extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const BadgeImage({
    super.key,
    required this.imageUrl,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    if (!hasImage) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFEFF6FF),
        child: Icon(
          Icons.workspace_premium,
          size: size * 0.45,
          color: Colors.amber,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: 8,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.workspace_premium,
              size: size * 0.45,
              color: Colors.amber,
            );
          },
        ),
      ),
    );
  }
}