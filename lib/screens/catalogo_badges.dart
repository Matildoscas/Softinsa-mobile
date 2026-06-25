import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para a cache local
import 'catalogo_badges_utilizador.dart';
import 'informacoes_badge.dart';

String obterNivel(dynamic idNivel) {
  final int? nivel = int.tryParse(idNivel.toString());
  switch (nivel) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

class CatalogoBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CatalogoBadgesPage({super.key, required this.userData});

  @override
  State<CatalogoBadgesPage> createState() => _CatalogoBadgesPageState();
}

class _CatalogoBadgesPageState extends State<CatalogoBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Chave de acesso ao SQLite local

  List<Map<String, dynamic>> todosBadges = [];
  List<Map<String, dynamic>> badgesFiltrados = [];
  bool isLoading = true;

  String pesquisa = '';
  String? filtroNivel;
  String? ordenacao;
  List<String> niveis = [];

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final api = ApiService();

    // 1. Todos os badges do catálogo (sem filtro de utilizador)
    final todos = await api.getTodosBadges();

    // 2. Badges conquistados/em progresso do utilizador
    final obtidos = await api.getBadgesConquistados(widget.userData['id_utilizador']);

    final pendentes = await api.getCandidaturasPendentes(
      widget.userData['id_utilizador'],
    );

    print("TODOS:");
    print(todos);

    print("OBTIDOS:");
    print(obtidos);

    // 3. Merge: para cada badge do catálogo, procuramos se o utilizador
    //    tem dados (progress, data_conquista, conquistado)
    final Map<int, Map<String, dynamic>> mapaObtidos = {
      for (final b in obtidos)
        (int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? '').toString()) ?? -1): b,
    };

    final Map<int, Map<String, dynamic>> mapaPendentes = {
      for (final c in pendentes)
        (int.tryParse((c['id_badge_modelo'] ?? c['id'] ?? '').toString()) ?? -1): c,
    };

    final merged = todos.map((badge) {
      final id = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? '').toString()) ?? -1;
      final dadosUtilizador = mapaObtidos[id];
      final candidaturaPendente = mapaPendentes[id];

      return {
        ...badge,
        'conquistado': dadosUtilizador != null,
        'data_conquista': dadosUtilizador?['data_atribuicao'],
        'em_validacao': candidaturaPendente != null,
        'estado_validacao': candidaturaPendente?['estado_validacao'] ?? 'Em validação',
        'progress': dadosUtilizador?['progress'] ?? (dadosUtilizador != null ? 1.0 : 0.0),
      };
    }).toList();

    if (mounted) {
      setState(() {
        todosBadges = merged;
        _extrairNiveis();
        _aplicarFiltros();
        isLoading = false;
      });
    }
  }

  void _extrairNiveis() {
    niveis = todosBadges
        .map((b) => obterNivel(b['id_nivel']))
        .where((n) => n != '-')
        .toSet()
        .toList()
      ..sort();
  }

  void _aplicarFiltros() {
    var lista = todosBadges.where((b) {
      final matchPesquisa = pesquisa.isEmpty ||
          (b['nome'] ?? '').toLowerCase().contains(pesquisa.toLowerCase()) ||
          (b['descricao'] ?? '').toLowerCase().contains(pesquisa.toLowerCase());
      final matchNivel = filtroNivel == null || obterNivel(b['id_nivel']) == filtroNivel;
      return matchPesquisa && matchNivel;
    }).toList();

    if (ordenacao == 'az') {
      lista.sort((a, b) => (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
    } else if (ordenacao == 'za') {
      lista.sort((a, b) => (b['nome'] ?? '').toString().compareTo((a['nome'] ?? '').toString()));
    }

    setState(() {
      badgesFiltrados = lista;
    });
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: headerHeight),

                  // Voltar + título
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, size: 22, color: Color(0xFF4470AF)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Todos os Badges", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(
                              isLoading ? "A carregar..." : "Existem ${todosBadges.length} badges disponíveis",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Barra de pesquisa
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      onChanged: (v) {
                        pesquisa = v;
                        _aplicarFiltros();
                      },
                      decoration: InputDecoration(
                        hintText: "Pesquisar badges...",
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xFF4470AF), width: 1.5)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Filtros
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdownFiltro<String>(
                            icon: Icons.filter_alt_outlined,
                            label: "Filtrar por Nível",
                            value: filtroNivel,
                            items: niveis,
                            itemLabel: (v) => "Nível $v",
                            todosLabel: "Todos os Níveis",
                            onChanged: (v) {
                              filtroNivel = v;
                              _aplicarFiltros();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDropdownFiltro<String>(
                            icon: Icons.sort_by_alpha,
                            label: "Ordenar por Nome",
                            value: ordenacao,
                            items: const ['az', 'za'],
                            itemLabel: (v) => v == 'az' ? 'Nome: A → Z' : 'Nome: Z → A',
                            todosLabel: "Sem ordenação",
                            onChanged: (v) {
                              ordenacao = v;
                              _aplicarFiltros();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade200, height: 1),

                  // Lista de Badges
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4470AF)))
                        : badgesFiltrados.isEmpty
                            ? const Center(child: Text("Nenhum badge encontrado", style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: badgesFiltrados.length,
                                itemBuilder: (context, index) {
                                  final b = badgesFiltrados[index];
                                  final bool conquistado = b['conquistado'] == true;
                                  final bool emValidacao = b['em_validacao'] == true;
                                  final double? progress = double.tryParse(b['progress']?.toString() ?? '');

                                  return _badgeCard(
                                    badge: b,
                                    conquistado: conquistado,
                                    emValidacao: emValidacao,
                                    progress: progress != null && progress > 0 ? progress : null,
                                    dataConquista: b['data_conquista']?.toString(),
                                  );
                                },
                              ),
                  ),

                  // Bottom bar
                  _buildBottomBar(),
                ],
              ),
            ),

            // FIXED HEADER LOGO
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
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

  Widget _badgeCard({
    required Map<String, dynamic> badge,
    required bool conquistado,
    double? progress,
    String? dataConquista,
    required bool emValidacao,
  }) {
    final int pontos = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final int badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? '0').toString()) ?? 0;

    String estadoTexto;
    Color estadoCor;

    if (conquistado) {
      final dataFormatada = _formatarData(dataConquista);
      estadoTexto = dataFormatada != null ? "Conquistado em $dataFormatada" : "Conquistado";
      estadoCor = const Color(0xFF2E7D32);
    } else if (emValidacao) {
      estadoTexto = badge['estado_validacao']?.toString() ?? "Em validação";
      estadoCor = Colors.amber.shade800; // Alterado para dar um tom de aviso real de pendente
    } else if (progress != null && progress > 0) {
      estadoTexto = "Em Progresso";
      estadoCor = const Color(0xFF4470AF);
    } else {
      estadoTexto = "Por Conquistar";
      estadoCor = Colors.grey;
    }

    print("BADGE NO CARD: ${badge['nome']} -> ${badge['imagem']}");

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeDetalhe(
              userId: int.parse(widget.userData['id_utilizador'].toString()),
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: conquistado
                ? const Color(0xFF2E7D32).withOpacity(0.4)
                : emValidacao
                    ? Colors.amber.withOpacity(0.5)
                    : Colors.grey.shade200,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    BadgeImage(
                      imageUrl: badge['imagem']?.toString(),
                      size: 60,
                    ),
                    if (conquistado)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                        ),
                      ),
                    if (emValidacao && !conquistado)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                          child: const Icon(Icons.hourglass_bottom, color: Colors.white, size: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge['nome'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        badge['descricao'] ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (badge['id_nivel'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEAF0FA), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            "Nível ${obterNivel(badge['id_nivel'])}",
                            style: const TextStyle(fontSize: 10, color: Color(0xFF4470AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4470AF)), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text("Pontos", style: TextStyle(fontSize: 9, color: Color(0xFF4470AF))),
                      const SizedBox(height: 2),
                      Text(
                        "$pontos",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4470AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (progress != null && !conquistado) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade200,
                  color: const Color(0xFF4470AF),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text("${(progress * 100).toStringAsFixed(0)}% concluído", style: const TextStyle(fontSize: 10, color: Color(0xFF4470AF))),
              ),
            ],
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

  String? _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  Widget _buildDropdownFiltro<T>({
    required IconData icon,
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required String todosLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey), overflow: TextOverflow.ellipsis)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
          style: const TextStyle(fontSize: 11, color: Colors.black),
          items: [
            DropdownMenuItem<T>(value: null, child: Text(todosLabel, style: TextStyle(color: Colors.grey.shade600))),
            ...items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: _bottomBarButton(
              icon: Icons.emoji_events,
              label: "Os seus Badges",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MeusBadgesPage(userData: widget.userData)),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bottomBarButton(
              icon: Icons.access_time,
              label: "Badges em Progresso",
              onTap: () {
                setState(() {
                  filtroNivel = null;
                  ordenacao = null;
                  pesquisa = '';
                  badgesFiltrados = todosBadges.where((b) {
                    final conquistado = b['conquistado'] == true;
                    final prog = double.tryParse(b['progress']?.toString() ?? '');
                    return !conquistado && prog != null && prog > 0;
                  }).toList();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBarButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.black87, width: 1.5)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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