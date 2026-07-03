// ============================================================================
// catalogo_badges.dart
//
// Catálogo geral dos badges da aplicação.
// Carrega todos os badges, os badges conquistados e as candidaturas pendentes.
// Depois junta estes dados para apresentar o estado individual de cada badge.
// Também permite pesquisar, filtrar por nível, ordenar e abrir o detalhe.
//
// A lógica original foi mantida.
// Os comentários explicam:
// - Responsabilidade de cada classe e função;
// - Fluxo entre API, SQLite e interface;
// - Pesquisa, filtros, navegação e estados;
// - Tratamento de imagens, ficheiros e modo offline.
// ============================================================================

// Widgets visuais, navegação, formulários e componentes Material.
import 'package:flutter/material.dart';
// Serviço responsável pelos pedidos ao backend.
import '../services/api_service.dart';
// Serviço SQLite disponível para cache local.
import '../database/basededados.dart'; // Import central para a cache local
import 'catalogo_badges_utilizador.dart';
import 'informacoes_badge.dart';

// =========================================================================
// OBTER NÍVEL
//
// Converte o ID numérico do nível para a respetiva letra:
// 1=A, 2=B, 3=C, 4=D e 5=E.
// Quando o valor não é válido, devolve "-".
// =========================================================================
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

class BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

// Página do catálogo completo.
// É StatefulWidget porque a lista, pesquisa, filtros e carregamento mudam.
class CatalogoBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CatalogoBadgesPage({super.key, required this.userData});

  @override
  State<CatalogoBadgesPage> createState() => _CatalogoBadgesPageState();
}

// Estado privado do catálogo.
// Guarda os dados originais e a versão filtrada apresentada na interface.
class _CatalogoBadgesPageState extends State<CatalogoBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Chave de acesso ao SQLite local

  int _converterInteiro(
    dynamic valor,
  ) {
    if (valor == null) {
      return 0;
    }

    if (valor is int) {
      return valor;
    }

    if (valor is double) {
      return valor.round();
    }

    return int.tryParse(
          valor.toString(),
        ) ??
        double.tryParse(
          valor.toString(),
        )?.round() ??
        0;
  }

  bool _converterBooleano(
    dynamic valor,
  ) {
    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor == 1;
    }

    final texto = valor
        ?.toString()
        .trim()
        .toLowerCase();

    return [
      'true',
      't',
      '1',
      'sim',
      'yes',
    ].contains(texto);
  }

  BadgeBonusInfo _obterBonusBadge(
    Map<String, dynamic> badge,
  ) {
    final int pontosExtra =
        _converterInteiro(
      badge['pontos_extra'] ??
          badge['pontos_bonus'],
    );

    final bool ganhouBonus =
        _converterBooleano(
          badge['ganhou_bonus'] ??
              badge['premio_atribuido'],
        ) ||
        pontosExtra > 0;

    return BadgeBonusInfo(
      ganhouBonus: ganhouBonus,
      pontosExtra: pontosExtra,
    );
  }

  List<Map<String, dynamic>> todosBadges = [];
  List<Map<String, dynamic>> badgesFiltrados = [];
  bool isLoading = true;

  String pesquisa = '';
  String? filtroNivel;
  String? ordenacao;
  List<String> niveis = [];

  @override
  // Executado uma única vez quando a página é criada.
  // Inicia imediatamente o carregamento do catálogo.
  void initState() {
    super.initState();
    carregarDados();
  }

  // =========================================================================
  // CARREGAR DADOS
  //
  // 1. Obtém todos os badges do catálogo;
  // 2. Obtém os badges conquistados pelo utilizador;
  // 3. Obtém as candidaturas ainda pendentes;
  // 4. Cria Maps indexados pelo ID para acelerar as pesquisas;
  // 5. Faz o merge dos dados gerais com o estado individual;
  // 6. Extrai os níveis, aplica os filtros e termina o carregamento.
  // =========================================================================
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
    // Cada badge conquistado fica associado ao respetivo ID.
    // Isto evita percorrer toda a lista para cada badge do catálogo.
    final Map<int, Map<String, dynamic>> mapaObtidos = {
      for (final b in obtidos)
        (int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? '').toString()) ?? -1): b,
    };

    // Estrutura semelhante para candidaturas em validação.
    final Map<int, Map<String, dynamic>> mapaPendentes = {
      for (final c in pendentes)
        (int.tryParse((c['id_badge_modelo'] ?? c['id'] ?? '').toString()) ?? -1): c,
    };

    // Acrescenta a cada badge campos específicos do utilizador:
    // conquistado, data, validação e progresso.
    final merged = todos.map((badge) {
      final int id =
          int.tryParse(
            (
              badge['id'] ??
              badge['id_badge_modelo'] ??
              ''
            ).toString(),
          ) ??
          -1;

      final Map<String, dynamic>?
          dadosUtilizador =
          mapaObtidos[id];

      final Map<String, dynamic>?
          candidaturaPendente =
          mapaPendentes[id];

      final BadgeBonusInfo bonus =
          dadosUtilizador != null
              ? _obterBonusBadge(
                  dadosUtilizador,
                )
              : const BadgeBonusInfo(
                  ganhouBonus: false,
                  pontosExtra: 0,
                );

      return {
        ...badge,

        'conquistado':
            dadosUtilizador != null,

        'data_conquista':
            dadosUtilizador?[
              'data_atribuicao'
            ],

        'data_atribuicao':
            dadosUtilizador?[
              'data_atribuicao'
            ],

        'em_validacao':
            candidaturaPendente != null,

        'estado_validacao':
            candidaturaPendente?[
              'estado_validacao'
            ] ??
            'Em validação',

        'progress':
            dadosUtilizador?['progress'] ??
            (
              dadosUtilizador != null
                  ? 1.0
                  : 0.0
            ),

        /*
        * Dados do desafio conquistado.
        */
        'ganhou_bonus':
            bonus.ganhouBonus,

        'premio_atribuido':
            bonus.ganhouBonus,

        'pontos_extra':
            bonus.pontosExtra,

        'pontos_bonus':
            bonus.pontosExtra,
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

  // =========================================================================
  // EXTRAIR NÍVEIS
  //
  // Lê os níveis existentes, remove inválidos e duplicados com toSet(),
  // converte novamente para lista e ordena alfabeticamente.
  // =========================================================================
  void _extrairNiveis() {
    niveis = todosBadges
        .map((b) => obterNivel(b['id_nivel']))
        .where((n) => n != '-')
        .toSet()
        .toList()
      ..sort();
  }

  // =========================================================================
  // APLICAR FILTROS
  //
  // Filtra pelo texto pesquisado e pelo nível selecionado.
  // Depois aplica a ordenação A-Z ou Z-A.
  // A lista final é guardada em badgesFiltrados.
  // =========================================================================
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
  // =========================================================================
  // BUILD
  //
  // Constrói o cabeçalho, pesquisa, dropdowns, lista de badges
  // e barra inferior. A lista reage ao carregamento e aos filtros.
  // =========================================================================
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

  // =========================================================================
  // CARD DO BADGE
  //
  // Determina o estado visual:
  // - Conquistado;
  // - Em validação;
  // - Em progresso;
  // - Por conquistar.
  //
  // Mostra imagem, nível, pontos, progresso e abre BadgeDetalhe ao toque.
  // =========================================================================
  Widget _badgeCard({
    required Map<String, dynamic>
        badge,
    required bool conquistado,
    double? progress,
    String? dataConquista,
    required bool emValidacao,
  }) {
    final int pontos =
        _converterInteiro(
      badge['pontos'],
    );

    final int badgeId =
        int.tryParse(
          (
            badge['id'] ??
            badge['id_badge_modelo'] ??
            0
          ).toString(),
        ) ??
        0;

    final String nome =
        badge['nome']?.toString() ??
        badge['nome_badge']?.toString() ??
        'Badge';

    final String descricao =
        badge['descricao']?.toString() ??
        badge['descricao_badge_modelo']
            ?.toString() ??
        '';

    final String? imagemUrl =
        badge['imagem_url']?.toString() ??
        badge['imagem']?.toString() ??
        badge['url_imagem']?.toString();

    final BadgeBonusInfo bonus =
        _obterBonusBadge(badge);

    final bool bonusAtivo =
        conquistado &&
        bonus.ganhouBonus;

    final int pontosExtra =
        bonus.pontosExtra;

    final int totalObtido =
        pontos + pontosExtra;

    const Color dourado =
        Color(0xFFD4A017);

    const Color douradoEscuro =
        Color(0xFF9A6B00);

    const Color douradoClaro =
        Color(0xFFFFF7D6);

    const Color fundoDourado =
        Color(0xFFFFFDF4);

    String estadoTexto;
    Color estadoCor;

    if (conquistado) {
      final dataFormatada =
          _formatarData(
        dataConquista,
      );

      estadoTexto =
          dataFormatada != null
              ? 'Conquistado em '
                  '$dataFormatada'
              : 'Conquistado';

      if (
        bonusAtivo &&
        pontosExtra > 0
      ) {
        estadoTexto +=
            ' • Recebeste '
            '+$pontosExtra pontos extra';
      }

      estadoCor = bonusAtivo
          ? douradoEscuro
          : const Color(
              0xFF2E7D32,
            );
    } else if (emValidacao) {
      estadoTexto =
          badge['estado_validacao']
              ?.toString() ??
          'Em validação';

      estadoCor =
          Colors.amber.shade800;
    } else if (
      progress != null &&
      progress > 0
    ) {
      estadoTexto =
          'Em Progresso';

      estadoCor =
          const Color(
        0xFF4470AF,
      );
    } else {
      estadoTexto =
          'Por Conquistar';

      estadoCor =
          Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BadgeDetalhe(
              userId: int.parse(
                widget.userData[
                  'id_utilizador'
                ].toString(),
              ),
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: bonusAtivo
              ? fundoDourado
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border: Border.all(
            color: bonusAtivo
                ? dourado
                : conquistado
                    ? const Color(
                        0xFF2E7D32,
                      ).withOpacity(
                        0.4,
                      )
                    : emValidacao
                        ? Colors.amber
                            .withOpacity(
                              0.5,
                            )
                        : Colors.grey
                            .shade200,

            width: bonusAtivo
                ? 2
                : 1,
          ),

          boxShadow: [
            BoxShadow(
              color: bonusAtivo
                  ? dourado.withOpacity(
                      0.16,
                    )
                  : Colors.black.withOpacity(
                      0.04,
                    ),
              blurRadius: bonusAtivo
                  ? 9
                  : 6,
              spreadRadius: bonusAtivo
                  ? 1
                  : 0,
              offset:
                  const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .all(
                          3,
                        ),
                        decoration:
                            BoxDecoration(
                          shape:
                              BoxShape.circle,

                          color: bonusAtivo
                              ? douradoClaro
                              : const Color(
                                  0xFFEFF6FF,
                                ),

                          border:
                              Border.all(
                            color: bonusAtivo
                                ? dourado
                                : const Color(
                                    0xFFDBEAFE,
                                  ),

                            width: bonusAtivo
                                ? 1.5
                                : 1,
                          ),
                        ),
                        child: BadgeImage(
                          imageUrl:
                              imagemUrl,
                          size: 58,
                        ),
                      ),

                      if (conquistado)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .all(
                              3,
                            ),
                            decoration:
                                BoxDecoration(
                              color: bonusAtivo
                                  ? dourado
                                  : const Color(
                                      0xFF2E7D32,
                                    ),
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons.check,
                              color:
                                  Colors.white,
                              size: 12,
                            ),
                          ),
                        ),

                      if (
                        emValidacao &&
                        !conquistado
                      )
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .all(
                              3,
                            ),
                            decoration:
                                const BoxDecoration(
                              color:
                                  Colors.amber,
                              shape:
                                  BoxShape.circle,
                            ),
                            child:
                                const Icon(
                              Icons
                                  .hourglass_bottom,
                              color:
                                  Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 5,
                          crossAxisAlignment:
                              WrapCrossAlignment
                                  .center,
                          children: [
                            Text(
                              nome,
                              style:
                                  const TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize:
                                    13,
                              ),
                            ),

                            if (bonusAtivo)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color:
                                      douradoClaro,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                  border:
                                      Border.all(
                                    color:
                                        const Color(
                                      0xFFF0D36B,
                                    ),
                                  ),
                                ),
                                child:
                                    const Text(
                                  'Desafio concluído',
                                  style:
                                      TextStyle(
                                    fontSize: 9,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    color:
                                        douradoEscuro,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (
                          descricao.isNotEmpty
                        ) ...[
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            descricao,
                            style:
                                const TextStyle(
                              fontSize: 11,
                              color:
                                  Colors.grey,
                            ),
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                        ],

                        if (
                          badge[
                            'id_nivel'
                          ] !=
                          null
                        ) ...[
                          const SizedBox(
                            height: 5,
                          ),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration:
                                BoxDecoration(
                              color: bonusAtivo
                                  ? douradoClaro
                                  : const Color(
                                      0xFFEAF0FA,
                                    ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child: Text(
                              'Nível '
                              '${obterNivel(badge['id_nivel'])}',
                              style:
                                  TextStyle(
                                fontSize: 10,
                                color: bonusAtivo
                                    ? douradoEscuro
                                    : const Color(
                                        0xFF4470AF,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration:
                        BoxDecoration(
                      color: bonusAtivo
                          ? fundoDourado
                          : Colors.white,

                      border:
                          Border.all(
                        color: bonusAtivo
                            ? dourado
                            : const Color(
                                0xFF4470AF,
                              ),

                        width: bonusAtivo
                            ? 1.5
                            : 1,
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Pontos',
                          style:
                              TextStyle(
                            fontSize: 9,
                            color: bonusAtivo
                                ? douradoEscuro
                                : const Color(
                                    0xFF4470AF,
                                  ),
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          '$pontos',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize:
                                15,
                          ),
                        ),

                        if (
                          bonusAtivo &&
                          pontosExtra > 0
                        )
                          Text(
                            '+$pontosExtra extra',
                            style:
                                const TextStyle(
                              fontSize: 9,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  dourado,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (
              progress != null &&
              !conquistado
            ) ...[
              Padding(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius
                              .circular(
                        10,
                      ),
                      child:
                          LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor:
                            Colors.grey
                                .shade200,
                        color:
                            const Color(
                          0xFF4470AF,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Align(
                      alignment:
                          Alignment
                              .centerRight,
                      child: Text(
                        '${(progress * 100).toStringAsFixed(0)}% concluído',
                        style:
                            const TextStyle(
                          fontSize: 10,
                          color:
                              Color(
                            0xFF4470AF,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              width: double.infinity,
              margin:
                  const EdgeInsets.only(
                top: 8,
              ),
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration:
                  BoxDecoration(
                color: bonusAtivo
                    ? fundoDourado
                    : const Color(
                        0xFFFBFDFF,
                      ),

                border:
                    const Border(
                  top: BorderSide(
                    color:
                        Color(
                      0xFFE5E7EB,
                    ),
                  ),
                ),
              ),
              child: Text(
                bonusAtivo &&
                        pontosExtra > 0
                    ? '$estadoTexto • '
                        'Total obtido: '
                        '$totalObtido pontos'
                    : estadoTexto,

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize: 10,
                  color: estadoCor,
                  fontWeight:
                      bonusAtivo
                          ? FontWeight.w600
                          : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Converte uma data ISO para dd/MM/yyyy.
  // Se a conversão falhar, devolve o texto original.
  String? _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  // Dropdown genérico reutilizado no filtro de nível e na ordenação.
  // O tipo T permite usar o mesmo componente com diferentes tipos de valores.
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

  // Barra inferior com acesso aos badges conquistados
  // e um filtro rápido para badges em progresso.
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

  // Componente visual reutilizado nos dois botões da barra inferior.
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

// =========================================================================
// IMAGEM DO BADGE
//
// Carrega a imagem através da rede.
// Apresenta um spinner durante o carregamento e um ícone de fallback
// quando a URL está vazia ou ocorre um erro.
// =========================================================================
class BadgeImage extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double zoom;

  const BadgeImage({
    super.key,
    required this.imageUrl,
    this.size = 60,
    this.zoom = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return _fallback();
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
        scale: zoom,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          loadingBuilder: (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            debugPrint(
              'Erro ao carregar imagem: $error',
            );
            debugPrint(
              'URL da imagem: $url',
            );

            return _fallback();
          },
        ),
      ),
    );
  }

  // Imagem alternativa utilizada quando não existe imagem válida.
  Widget _fallback() {
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
}