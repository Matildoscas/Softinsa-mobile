import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'catalogo_badges.dart';
import 'informacoes_badge.dart';

// Função auxiliar para converter o ID do nível na sua respetiva letra/Sinal
String obterNivel(dynamic idNivel) {
  if (idNivel == null) return '-';
  switch (int.tryParse(idNivel.toString())) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

String obterNivelPorBadge(Map<String, dynamic> badge) {
  if (badge['id_nivel'] != null) {
    return obterNivel(badge['id_nivel']);
  }

  switch (int.tryParse(badge['id']?.toString() ?? '')) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

class MeusBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MeusBadgesPage({super.key, required this.userData});

  @override
  State<MeusBadgesPage> createState() => _MeusBadgesPageState();
}

class _MeusBadgesPageState extends State<MeusBadgesPage> {
  List<Map<String, dynamic>> todosOsMeusBadges = [];
  List<Map<String, dynamic>> badgesFiltrados = [];
  bool isLoading = true;

  String pesquisa = '';
  String? filtroNivel;
  String? ordenacao;
  String? filtroTipo; // null = todos, 'comum', 'especial'

  List<String> niveis = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    final api = ApiService();
    try {
      final obtidos =
          await api.getBadgesConquistados(widget.userData['id_utilizador']);
      setState(() {
        todosOsMeusBadges = List<Map<String, dynamic>>.from(obtidos);
        _extrairNiveis();
        _aplicarFiltros();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar badges: $e");
      setState(() => isLoading = false);
    }
  }

  void _extrairNiveis() {
    niveis = todosOsMeusBadges
        .map((b) => obterNivel(b['id_nivel']))
        .where((n) => n != '-')
        .toSet()
        .toList()
      ..sort();
  }

  void _aplicarFiltros() {
    setState(() {
      var lista = todosOsMeusBadges.where((b) {
        final matchPesquisa = pesquisa.isEmpty ||
            (b['nome'] ?? '').toLowerCase().contains(pesquisa.toLowerCase()) ||
            (b['descricao'] ?? '')
                .toLowerCase()
                .contains(pesquisa.toLowerCase());

        final matchNivel =
            filtroNivel == null || obterNivel(b['id_nivel']) == filtroNivel;

        final matchTipo = filtroTipo == null ||
            (filtroTipo == 'especial'
                ? obterNivel(b['id_nivel']) == 'E'
                : obterNivel(b['id_nivel']) != 'E');

        return matchPesquisa && matchNivel && matchTipo;
      }).toList();

      if (ordenacao == 'az') {
        lista.sort((a, b) =>
            (a['nome'] ?? '').toString().compareTo((b['nome'] ?? '').toString()));
      } else if (ordenacao == 'za') {
        lista.sort((a, b) =>
            (b['nome'] ?? '').toString().compareTo((a['nome'] ?? '').toString()));
      }

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
            // ── CONTEÚDO ──────────────────────────────────────────────
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
                          child: const Icon(Icons.arrow_back,
                              size: 22, color: Color(0xFF4470AF)),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Os Meus Badges",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              isLoading
                                  ? "A carregar..."
                                  : "${badgesFiltrados.length} badge${badgesFiltrados.length != 1 ? 's' : ''}",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
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
                        hintStyle:
                            const TextStyle(color: Colors.grey, fontSize: 13),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.grey, size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide:
                              BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(
                              color: Color(0xFF4470AF), width: 1.5),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── 3 DROPDOWNS ───────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Filtrar por Nível
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
                        const SizedBox(width: 8),
                        // Filtrar por Tipo
                        Expanded(
                          child: _buildDropdownFiltro<String>(
                            icon: Icons.category_outlined,
                            label: "Tipo de Badge",
                            value: filtroTipo,
                            items: const ['comum', 'especial'],
                            itemLabel: (v) =>
                                v == 'especial' ? 'Especiais' : 'Comuns',
                            todosLabel: "Todos os Tipos",
                            onChanged: (v) {
                              filtroTipo = v;
                              _aplicarFiltros();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Ordenar por Nome
                        Expanded(
                          child: _buildDropdownFiltro<String>(
                            icon: Icons.sort_by_alpha,
                            label: "Ordenar",
                            value: ordenacao,
                            items: const ['az', 'za'],
                            itemLabel: (v) =>
                                v == 'az' ? 'Nome: A → Z' : 'Nome: Z → A',
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

                  // ── LISTA ─────────────────────────────────────────────
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF4470AF)),
                          )
                        : badgesFiltrados.isEmpty
                            ? _estadoVazio()
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                itemCount: badgesFiltrados.length,
                                itemBuilder: (context, index) =>
                                    _badgeCard(badgesFiltrados[index]),
                              ),
                  ),

                  // ── BOTTOM BAR ────────────────────────────────────────
                  _buildBottomBar(),
                ],
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

  // ── ESTADO VAZIO ──────────────────────────────────────────────────────────
  Widget _estadoVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_outlined,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "Nenhum badge encontrado",
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555555)),
          ),
          const SizedBox(height: 4),
          Text(
            "Tenta ajustar os filtros ou a pesquisa.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  // ── CARD DE BADGE ─────────────────────────────────────────────────────────
  Widget _badgeCard(Map<String, dynamic> badge) {
    final int pontos =
        int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final String dataFormatada =
        _formatarData(badge['data_atribuicao']?.toString()) ?? '—';
    final bool isEspecial = obterNivel(badge['id_nivel']) == 'E';

    return GestureDetector(
      onTap: () {
        // Navega para a página de detalhes do badge, tal como no catálogo
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeDetalhe(
              userId: widget.userData['id_utilizador'],
              badgeId: badge['id'], // IMPORTANTE
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
              color: const Color(0xFF2E7D32).withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícone com check
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text("🏅", style: TextStyle(fontSize: 28)),
                  ),
                ),
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
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    badge['nome'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    badge['descricao'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      // Nível
                      if (badge['id_nivel'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF0FA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "Nível ${obterNivel(badge['id_nivel'])}",
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFF4470AF)),
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Especial
                      if (isEspecial)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.star,
                                  size: 9, color: Color(0xFFF9A825)),
                              SizedBox(width: 2),
                              Text(
                                "Especial",
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFFF9A825)),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Data
                      Icon(Icons.calendar_today_outlined,
                          size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(
                        dataFormatada,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Pontos
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4470AF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("Pontos",
                      style:
                          TextStyle(fontSize: 9, color: Color(0xFF4470AF))),
                  const SizedBox(height: 2),
                  Text(
                    "$pontos",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF4470AF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── BOTTOM BAR ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bottomBarButton(
              icon: Icons.workspace_premium_outlined,
              label: "Badges Comuns",
              onTap: () {
                setState(() {
                  filtroTipo = 'comum';
                  filtroNivel = null;
                  ordenacao = null;
                  pesquisa = '';
                });
                _aplicarFiltros();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _bottomBarButton(
              icon: Icons.star_outline,
              label: "Badges Especiais",
              onTap: () {
                setState(() {
                  filtroTipo = 'especial';
                  filtroNivel = null;
                  ordenacao = null;
                  pesquisa = '';
                });
                _aplicarFiltros();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _bottomBarButton(
              icon: Icons.menu_book_outlined,
              label: "Catálogo",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CatalogoBadgesPage(userData: widget.userData),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black87, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── DROPDOWN GENÉRICO ──────────────────────────────────────────────────────
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 16, color: Colors.grey),
          style: const TextStyle(fontSize: 11, color: Colors.black),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(todosLabel,
                  style: TextStyle(color: Colors.grey.shade600)),
            ),
            ...items.map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item)),
                )),
          ],
          onChanged: onChanged,
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
}