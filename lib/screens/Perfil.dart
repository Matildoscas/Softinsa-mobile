// ============================================================================
// perfil.dart
//
// Página de perfil do consultor.
// Mostra nome, foto, badges conquistados e acessos ao progresso,
// histórico e catálogo pessoal. Usa API como fonte principal
// e SQLite como fallback offline.
//
// Foram mantidas as instruções e a lógica originais.
// Os comentários servem para explicar responsabilidades, fluxo de dados,
// estado, navegação, cache SQLite e construção da interface.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import crucial para ler a cache offline
import '../state/utilizador_riverpod.dart';
import 'catalogo_badges_utilizador.dart';
import 'informacoes_badge.dart';
import 'progresso_page.dart';
import 'historico_badges_page.dart';

// Converte o ID numérico do nível para a respetiva letra.
// 1=A, 2=B, 3=C, 4=D e 5=E.
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

class _BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const _BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

// StatefulWidget porque os badges, o catálogo e o carregamento
// são atualizados depois de pedidos assíncronos.
class PerfilPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const PerfilPage({super.key, required this.userData});

  @override
  ConsumerState<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends ConsumerState<PerfilPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local para modo Offline

  Widget _perfilResumoCard({
    required IconData icon,
    required String titulo,
    required String valor,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFFF8F9FA,
        ),
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border: Border.all(
          color:
              const Color(
            0xFFD6DBE1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                const Color(
              0xFF4470AF,
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style:
                    const TextStyle(
                  fontSize: 10,
                  color:
                      Colors.grey,
                ),
              ),

              Text(
                valor,
                style:
                    const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.bold,
                  color:
                      Color(
                    0xFF344054,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> badgesConquistados = [];
  List<Map<String, dynamic>> todosBadges = []; // CORREÇÃO: Movido de global para local da Store
  bool isLoading = true;

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

  List<Map<String, dynamic>>
    _removerBadgesDuplicados(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<
      int,
      Map<String, dynamic>
    > unicos = {};

    for (final badgeOriginal in lista) {
      final badge =
          Map<String, dynamic>.from(
        badgeOriginal,
      );

      final int? id =
          int.tryParse(
        (
          badge['id'] ??
          badge['id_badge_modelo'] ??
          badge['badge_id'] ??
          badge['id_badge_atribuido'] ??
          ''
        ).toString(),
      );

      if (id == null) {
        continue;
      }

      final bonusNovo =
          _obterBonusBadge(
        badge,
      );

      if (!unicos.containsKey(id)) {
        unicos[id] = {
          ...badge,

          'id': id,

          'ganhou_bonus':
              bonusNovo.ganhouBonus,

          'premio_atribuido':
              bonusNovo.ganhouBonus,

          'pontos_extra':
              bonusNovo.pontosExtra,

          'pontos_bonus':
              bonusNovo.pontosExtra,
        };

        continue;
      }

      final atual = unicos[id]!;

      final bonusAtual =
          _obterBonusBadge(
        atual,
      );

      final int maiorBonus =
          bonusNovo.pontosExtra >
                  bonusAtual.pontosExtra
              ? bonusNovo.pontosExtra
              : bonusAtual.pontosExtra;

      final String? imagemAtual =
          _obterImagemBadge(
        atual,
      );

      final String? imagemNova =
          _obterImagemBadge(
        badge,
      );

      unicos[id] = {
        ...atual,
        ...badge,

        'id': id,

        'ganhou_bonus':
            bonusAtual.ganhouBonus ||
            bonusNovo.ganhouBonus,

        'premio_atribuido':
            bonusAtual.ganhouBonus ||
            bonusNovo.ganhouBonus,

        'pontos_extra':
            maiorBonus,

        'pontos_bonus':
            maiorBonus,

        'imagem_url':
            imagemNova ??
            imagemAtual,

        'imagem':
            imagemNova ??
            imagemAtual,
      };
    }

    return unicos.values.toList();
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

    final String texto =
        valor
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    return [
      'true',
      't',
      '1',
      'sim',
      'yes',
    ].contains(texto);
  }

  _BadgeBonusInfo _obterBonusBadge(
    Map<String, dynamic> badge,
  ) {
    final int pontosExtra1 =
        _converterInteiro(
      badge['pontos_extra'],
    );

    final int pontosExtra2 =
        _converterInteiro(
      badge['pontos_bonus'],
    );

    final int pontosExtra =
        pontosExtra1 > pontosExtra2
            ? pontosExtra1
            : pontosExtra2;

    final bool ganhouBonus =
        _converterBooleano(
          badge['ganhou_bonus'],
        ) ||
        _converterBooleano(
          badge['premio_atribuido'],
        ) ||
        pontosExtra > 0;

    return _BadgeBonusInfo(
      ganhouBonus: ganhouBonus,
      pontosExtra: pontosExtra,
    );
  }

  String? _obterImagemBadge(
    Map<String, dynamic> badge,
  ) {
    final possibilidades = [
      badge['imagem_url'],
      badge['imagem'],
      badge['url_imagem'],
      badge['imagem_badge'],
    ];

    for (final imagem in possibilidades) {
      final String valor =
          imagem?.toString().trim() ??
          '';

      if (
        valor.isNotEmpty &&
        valor != 'null'
      ) {
        return valor;
      }
    }

    return null;
  }

  @override
  // Executado uma vez. Inicia o carregamento dos dados do perfil.
  void initState() {
    super.initState();
    _carregarDadosPerfil();
  }

  // CARREGAR DADOS DO PERFIL
  // 1. Obtém badges conquistados e catálogo completo da API;
  // 2. Atualiza o estado da página;
  // 3. Guarda os badges atribuídos no SQLite;
  // 4. Se a API falhar, lê badge_atribuido e badge_modelo localmente.
  Future<void> _carregarDadosPerfil() async {
    final int userId = int.parse(widget.userData['id_utilizador'].toString());
    
    try {
      // 1. Tenta puxar tudo da API via HTTP
      final obtidos = await _apiService.getBadgesConquistados(userId);
      final todos = await _apiService.getTodosBadges();

      final obtidosUnicos =
          _removerBadgesDuplicados(
        obtidos,
      );

      if (mounted) {
        setState(() {
          badgesConquistados =
              List<Map<String, dynamic>>.from(
            obtidosUnicos,
          );
          todosBadges = List<Map<String, dynamic>>.from(todos);
          isLoading = false;
        });
      }

      // 2. Faz o Mirroring (Sincronização em Background para o SQFlite)
      for (var b in obtidosUnicos) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint(
        'Modo Offline Ativo no Perfil '
        '(Carregando cache local): $e',
      );

      final obtidosLocais =
          await _dbLocal.listarTabela(
        'badge_atribuido',
      );

      final todosLocais =
          await _dbLocal.listarTabela(
        'badge_modelo',
      );

      final List<Map<String, dynamic>>
          badgesLocais =
          obtidosLocais.map(
        (e) {
          return <String, dynamic>{
            'id':
                e['id_badge_modelo'],

            'id_badge_modelo':
                e['id_badge_modelo'],

            'nome':
                e['nome'] ??
                'Badge Guardado',

            'descricao':
                e['descricao'] ??
                'Disponível em modo offline.',

            'pontos':
                e['pontos'] ??
                0,

            'data_atribuicao':
                e['data_atribuicao'],

            'id_nivel':
                e['id_nivel'],

            'imagem':
                e['imagem'],

            'imagem_url':
                e['imagem_url'],

            'ganhou_bonus':
                e['ganhou_bonus'] ??
                false,

            'premio_atribuido':
                e['premio_atribuido'] ??
                false,

            'pontos_extra':
                e['pontos_extra'] ??
                0,

            'pontos_bonus':
                e['pontos_bonus'] ??
                0,
          };
        },
      ).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        badgesConquistados =
            _removerBadgesDuplicados(
          badgesLocais,
        );

        todosBadges =
            List<Map<String, dynamic>>
                .from(
          todosLocais,
        );

        isLoading = false;
      });
    }
  }

  @override
  // Constrói o perfil.
  // O Provider é utilizado para obter dados atualizados do dashboard,
  // enquanto userData mantém os dados básicos da sessão.
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    
    // Consome o estado global para obter os dados atualizados do dashboard.
    final userProvider = ref.watch(utilizadorStateProvider);

    final int pontosAtuais =
        _converterInteiro(
      userProvider.dashboard[
            'total_pontos'
          ] ??
          userProvider.dashboard[
            'pontos_atuais'
          ],
    );

    final int totalDashboard =
        _converterInteiro(
      userProvider.dashboard[
            'total_badges'
          ] ??
          userProvider.dashboard[
            'badges_conquistas_total'
          ],
    );

    final int totalBadgesObtidos =
        totalDashboard > 0
            ? totalDashboard
            : badgesConquistados.length;
    
    final String nome = userProvider.dashboard.isNotEmpty 
        ? (userProvider.dashboard['nome_completo'] ?? widget.userData['nome_completo'] ?? 'Utilizador')
        : (widget.userData['nome_completo'] ?? 'Utilizador');
        
    final String? fotoUrl = widget.userData['foto_url']?.toString();
    final int totalBadges = todosBadges.isNotEmpty ? todosBadges.length : 24; // Fallback estático seguro

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO ──────────────────────────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: headerHeight),

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
                                Icon(Icons.arrow_back, size: 20, color: Color(0xFF4470AF)),
                                SizedBox(width: 6),
                                Text(
                                  "Voltar",
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF4470AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Avatar + nome + resumo
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF4470AF,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                20,
                              ),
                              image: fotoUrl != null &&
                                      fotoUrl.isNotEmpty
                                  ? DecorationImage(
                                      image:
                                          NetworkImage(
                                        fotoUrl,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: fotoUrl == null ||
                                    fotoUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 52,
                                  )
                                : null,
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Text(
                            nome,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(
                                0xFF111111,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _perfilResumoCard(
                                    icon:
                                        Icons.emoji_events,
                                    titulo:
                                        'Badges',
                                    valor:
                                        '$totalBadgesObtidos',
                                  ),
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child: _perfilResumoCard(
                                    icon:
                                        Icons.star,
                                    titulo:
                                        'Pontos atuais',
                                    valor:
                                        '$pontosAtuais',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botões Progresso + Histórico
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _outlineButton(
                              icon: Icons.trending_up,
                              label: "Progresso",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProgressoPage(userData: widget.userData)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _outlineButton(
                              icon: Icons.history, // Ícone corrigido para histórico
                              label: "Histórico Badges",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => HistoricoBadgesPage(userData: widget.userData)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cabeçalho "Os seus badges"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Os seus badges", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                isLoading
                                    ? "A carregar..."
                                    : "Tem $totalBadgesObtidos/$totalBadges badges",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MeusBadgesPage(userData: widget.userData)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF4470AF)),
                                  SizedBox(width: 5),
                                  Text(
                                    "Ver Todos",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF4470AF), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Lista de badges com tratamento de estados
                    isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(color: Color(0xFF4470AF)),
                          )
                        : badgesConquistados.isEmpty
                            ? _estadoVazio()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: badgesConquistados.length,
                                itemBuilder: (context, index) => _badgeCard(badgesConquistados[index]),
                              ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── HEADER FIXED ──────────────────────────────────────────
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

  // ── CARD DE BADGE REATIVO ─────────────────────────────────────────────────
  // Cria o cartão de um badge conquistado.
  // Ao tocar, abre BadgeDetalhe com o ID do badge e do utilizador.
  Widget _badgeCard(
    Map<String, dynamic> badge,
  ) {
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
        badge['nome_badge']
            ?.toString() ??
        'Badge';

    final String descricao =
        badge['descricao']
            ?.toString() ??
        badge[
          'descricao_badge_modelo'
        ]?.toString() ??
        '';

    final String? imagemUrl =
        _obterImagemBadge(
      badge,
    );

    final String dataFormatada =
        _formatarData(
          badge['data_atribuicao']
              ?.toString(),
        ) ??
        '—';

    final _BadgeBonusInfo bonus =
        _obterBonusBadge(
      badge,
    );

    final bool ganhouBonus =
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

    return GestureDetector(
      onTap: () {
        if (badgeId == 0) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível abrir este badge.',
              ),
            ),
          );

          return;
        }

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
              badgeId:
                  badgeId,
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
          color: ganhouBonus
              ? fundoDourado
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),

          border: Border.all(
            color: ganhouBonus
                ? dourado
                : const Color(
                    0xFF2E7D32,
                  ).withOpacity(
                    0.3,
                  ),

            width: ganhouBonus
                ? 2
                : 1,
          ),

          boxShadow: [
            BoxShadow(
              color: ganhouBonus
                  ? dourado.withOpacity(
                      0.16,
                    )
                  : Colors.black.withOpacity(
                      0.04,
                    ),

              blurRadius: ganhouBonus
                  ? 9
                  : 6,

              spreadRadius: ganhouBonus
                  ? 1
                  : 0,

              offset:
                  const Offset(
                0,
                2,
              ),
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

                          color: ganhouBonus
                              ? douradoClaro
                              : const Color(
                                  0xFFEFF6FF,
                                ),

                          border:
                              Border.all(
                            color: ganhouBonus
                                ? dourado
                                : const Color(
                                    0xFFDBEAFE,
                                  ),

                            width: ganhouBonus
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

                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding:
                              const EdgeInsets
                                  .all(
                            3,
                          ),
                          decoration:
                              BoxDecoration(
                            color: ganhouBonus
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

                            if (ganhouBonus)
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal:
                                      8,
                                  vertical:
                                      3,
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
                                    fontSize:
                                        9,
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
                              horizontal:
                                  8,
                              vertical:
                                  2,
                            ),
                            decoration:
                                BoxDecoration(
                              color: ganhouBonus
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

                                color: ganhouBonus
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
                      color: ganhouBonus
                          ? fundoDourado
                          : Colors.white,

                      border:
                          Border.all(
                        color: ganhouBonus
                            ? dourado
                            : const Color(
                                0xFF4470AF,
                              ),

                        width: ganhouBonus
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

                            color: ganhouBonus
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
                            fontSize: 15,
                          ),
                        ),

                        if (
                          ganhouBonus &&
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

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration:
                  BoxDecoration(
                color: ganhouBonus
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
                ganhouBonus &&
                        pontosExtra > 0
                    ? 'Conquistado a '
                        '$dataFormatada • '
                        'Recebeste '
                        '+$pontosExtra pontos extra • '
                        'Total obtido: '
                        '$totalObtido pontos'
                    : 'Conquistado a '
                        '$dataFormatada',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize: 10,

                  color: ganhouBonus
                      ? douradoEscuro
                      : const Color(
                          0xFF2E7D32,
                        ),

                  fontWeight:
                      ganhouBonus
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

  // Componente reutilizado nos botões Progresso e Histórico.
  Widget _outlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
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
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // Estado apresentado quando o utilizador ainda não tem badges.
  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "Ainda sem badges",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 4),
          Text("Completa desafios para conquistar badges.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  // Converte uma data ISO para dd/MM/yyyy.
  // Se não conseguir converter, devolve o texto original.
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

// Componente responsável por mostrar a imagem online do badge.
// Inclui carregamento, tratamento de erro e ícone de fallback.
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