import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart';
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

class MeusBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MeusBadgesPage({super.key, required this.userData});

  @override
  State<MeusBadgesPage> createState() => _MeusBadgesPageState();
}

class _MeusBadgesPageState extends State<MeusBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados();

  List<Map<String, dynamic>> meusBadges = [];
  bool isLoading = true;

  List<Map<String, dynamic>> meusBadgesFiltrados = [];

  String pesquisa = '';
  String? filtroNivel;
  String? ordenacao;

  List<String> niveis = [];

  @override
  void initState() {
    super.initState();
    _carregarMeusBadges();
  }

  void _extrairNiveis() {
    niveis = meusBadges
        .map((b) => obterNivel(b['id_nivel']))
        .where((n) => n != '-')
        .toSet()
        .toList()
      ..sort();
  }

  void _aplicarFiltros() {
    var lista = meusBadges.where((b) {
      final nome = (b['nome'] ?? b['nome_badge'] ?? '').toString().toLowerCase();
      final descricao = (b['descricao'] ?? b['descricao_badge_modelo'] ?? '').toString().toLowerCase();

      final matchPesquisa = pesquisa.isEmpty ||
          nome.contains(pesquisa.toLowerCase()) ||
          descricao.contains(pesquisa.toLowerCase());

      final matchNivel =
          filtroNivel == null || obterNivel(b['id_nivel']) == filtroNivel;

      return matchPesquisa && matchNivel;
    }).toList();

    if (ordenacao == 'az') {
      lista.sort(
        (a, b) => (a['nome'] ?? a['nome_badge'] ?? '')
            .toString()
            .compareTo((b['nome'] ?? b['nome_badge'] ?? '').toString()),
      );
    } else if (ordenacao == 'za') {
      lista.sort(
        (a, b) => (b['nome'] ?? b['nome_badge'] ?? '')
            .toString()
            .compareTo((a['nome'] ?? a['nome_badge'] ?? '').toString()),
      );
    } else if (ordenacao == 'pontos_desc') {
      lista.sort((a, b) {
        final pontosA = int.tryParse(a['pontos']?.toString() ?? '0') ?? 0;
        final pontosB = int.tryParse(b['pontos']?.toString() ?? '0') ?? 0;
        return pontosB.compareTo(pontosA);
      });
    } else if (ordenacao == 'pontos_asc') {
      lista.sort((a, b) {
        final pontosA = int.tryParse(a['pontos']?.toString() ?? '0') ?? 0;
        final pontosB = int.tryParse(b['pontos']?.toString() ?? '0') ?? 0;
        return pontosA.compareTo(pontosB);
      });
    }

    setState(() {
      meusBadgesFiltrados = lista;
    });
  }

  Future<void> _carregarMeusBadges() async {
    final int userId = int.parse(widget.userData['id_utilizador'].toString());

    try {
      // 1. Tenta ir buscar à API os badges que o consultor já conquistou
      final dados = await _apiService.getBadgesConquistados(userId);
      
      if (mounted) {
        setState(() {
          meusBadges = List<Map<String, dynamic>>.from(dados);
          meusBadgesFiltrados = List<Map<String, dynamic>>.from(dados);
          _extrairNiveis();
          isLoading = false;
        });
      }

      // 2. Sincroniza com o SQFlite local para consulta offline posterior
      for (var b in dados) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo em Os Seus Badges: $e");

      // 3. Fallback: Se falhar a rede, carrega os dados diretamente do SQLite local
      final dadosLocais = await _dbLocal.listarTabela('badge_atribuido');
      
      if (mounted) {
        setState(() {
          meusBadges = dadosLocais.map((e) => {
            'id': e['id_badge_modelo'],
            'nome': e['nome'] ?? 'Badge Conquistado',
            'descricao': e['descricao'] ?? 'Disponível em cache offline.',
            'pontos': e['pontos'] ?? 0,
            'data_atribuicao': e['data_atribuicao'],
            'id_nivel': e['id_nivel']
          }).toList();
          isLoading = false;
        });
      }
    }
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
                const SizedBox(height: headerHeight),

                // Voltar + título
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 22,
                          color: Color(0xFF4470AF),
                        ),
                      ),

                      const SizedBox(width: 10),

                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Os seus Badges",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "Badges conquistados",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
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
                      hintText: "Pesquisar badges conquistados...",
                      hintStyle: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: Color(0xFF4470AF),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Filtro nível + ordenação
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
                          label: "Ordenar",
                          value: ordenacao,
                          items: const [
                            'az',
                            'za',
                            'pontos_desc',
                            'pontos_asc',
                          ],
                          itemLabel: (v) {
                            if (v == 'az') return 'Nome: A → Z';
                            if (v == 'za') return 'Nome: Z → A';
                            if (v == 'pontos_desc') return 'Mais pontos';
                            if (v == 'pontos_asc') return 'Menos pontos';
                            return v;
                          },
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

                                // Conteúdo
                                Expanded(
                                  child: isLoading
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFF4470AF),
                                          ),
                                        )
                                      : meusBadges.isEmpty
                                        ? _estadoVazio()
                                        : meusBadgesFiltrados.isEmpty
                                            ? const Center(
                                                child: Text(
                                                  "Nenhum badge encontrado",
                                                  style: TextStyle(color: Colors.grey),
                                                ),
                                              )
                                            : ListView.builder(
                                                padding: const EdgeInsets.symmetric(vertical: 12),
                                                itemCount: meusBadgesFiltrados.length,
                                                itemBuilder: (context, index) =>
                                                    _badgeCard(meusBadgesFiltrados[index]),
                                              ),
                                ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
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
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            size: 16,
            color: Colors.grey,
          ),
          style: const TextStyle(
            fontSize: 11,
            color: Colors.black,
          ),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text(
                todosLabel,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<T>(
                value: item,
                child: Text(itemLabel(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _badgeCard(Map<String, dynamic> badge) {
    final int pontos = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final int badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? '0').toString()) ?? 0;
    
    // Formata a data de conquista de forma amigável
    String dataFormatada = '—';
    if (badge['data_atribuicao'] != null) {
      try {
        final dt = DateTime.parse(badge['data_atribuicao'].toString());
        dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (_) {
        dataFormatada = badge['data_atribuicao'].toString();
      }
    }

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
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
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
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
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
                        badge['nome'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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
            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Conquistado a $dataFormatada",
                style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "Nenhum badge conquistado",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 6),
            Text(
              "Comece a realizar os desafios das Service Lines para ganhar o seu primeiro badge!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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