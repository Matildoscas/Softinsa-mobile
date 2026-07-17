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
import 'package:sqflite/sqflite.dart';
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
    final int pontosBase =
        _converterInteiro(
      badge['pontos'],
    );

    final int pontosExtra1 =
        _converterInteiro(
      badge['pontos_extra'],
    );

    final int pontosExtra2 =
        _converterInteiro(
      badge['pontos_bonus'],
    );

    int pontosExtra =
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

    if (ganhouBonus && pontosExtra == 0 && pontosBase > 0) {
      pontosExtra = pontosBase;
    }

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
        await _guardarBadgeUtilizadorCache(
          userId: userId,
          badge: b,
          estadoPadrao: 'Conquistado',
        );
      }
    } catch (e) {
      debugPrint(
        'Modo Offline Ativo no Perfil '
        '(Carregando cache local): $e',
      );

        final badgesLocais =
          await _carregarBadgesUtilizadorDoCache(
        userId,
        );

        final todosLocais =
          await _dbLocal.listarTabela(
        'badge_modelo',
        );

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

  Future<void> _ensureTabelaCacheBadgesUtilizador() async {
    final db = await _dbLocal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_badges_utilizador (
        id_utilizador INTEGER,
        id_badge_modelo INTEGER,
        id_badge_atribuido INTEGER,
        nome_badge TEXT,
        descricao_badge TEXT,
        pontos INTEGER,
        id_nivel INTEGER,
        imagem_url TEXT,
        pontos_extra INTEGER,
        ganhou_bonus INTEGER,
        premio_atribuido INTEGER,
        estado_badge_atribuido TEXT,
        data_atribuicao TEXT,
        data_validade TEXT,
        tipo_badge TEXT,
        PRIMARY KEY (id_utilizador, id_badge_modelo, id_badge_atribuido)
      )
    ''');
  }

  Future<void> _guardarBadgeUtilizadorCache({
    required int userId,
    required Map<String, dynamic> badge,
    required String estadoPadrao,
  }) async {
    await _ensureTabelaCacheBadgesUtilizador();
    final db = await _dbLocal.database;

    final idBadgeModelo =
        int.tryParse((badge['id_badge_modelo'] ?? badge['id'] ?? badge['badge_id'] ?? 0).toString()) ?? 0;

    if (idBadgeModelo == 0) {
      return;
    }

    final idBadgeAtribuido =
        int.tryParse((badge['id_badge_atribuido'] ?? badge['id'] ?? idBadgeModelo).toString()) ?? idBadgeModelo;

    final pontosExtra =
        int.tryParse((badge['pontos_extra'] ?? badge['pontos_bonus'] ?? 0).toString()) ?? 0;

    final ganhouBonus =
        ((badge['ganhou_bonus'] == true) || (badge['premio_atribuido'] == true) || pontosExtra > 0) ? 1 : 0;

    await _dbLocal.salvarRegisto('badge_modelo', {
      'id_badge_modelo': idBadgeModelo,
      'id_serviceline': int.tryParse((badge['id_serviceline'] ?? 0).toString()),
      'id_areas': int.tryParse((badge['id_areas'] ?? 0).toString()),
      'id_nivel': int.tryParse((badge['id_nivel'] ?? 0).toString()),
      'id_utilizador': userId,
      'nome_badge': badge['nome_badge'] ?? badge['nome'] ?? 'Badge',
      'descricao_badge_modelo': badge['descricao_badge_modelo'] ?? badge['descricao'] ?? '',
      'data_criacao_badge_modelo': badge['data_atribuicao']?.toString(),
      'estado_badge_modelo': badge['estado_badge_modelo'] ?? 'ATIVO',
      'numero_requisitos': int.tryParse((badge['numero_requisitos'] ?? 0).toString()) ?? 0,
      'pontos': int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0,
      'tempo_expiracao': badge['tempo_expiracao']?.toString(),
      'imagem_url': badge['imagem_url'] ?? badge['imagem']?.toString() ?? badge['url_imagem']?.toString(),
      'imagem': null,
    });

    await _dbLocal.salvarRegisto('badge_atribuido', {
      'id_badge_atribuido': idBadgeAtribuido,
      'id_badge_modelo': idBadgeModelo,
      'data_atribuicao': badge['data_atribuicao']?.toString(),
      'data_validade': badge['data_validade']?.toString(),
      'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? estadoPadrao,
    });

    await _dbLocal.salvarRegisto('obtem', {
      'id_utilizador': userId,
      'id_badge_atribuido': idBadgeAtribuido,
    });

    await db.insert(
      'cache_badges_utilizador',
      {
        'id_utilizador': userId,
        'id_badge_modelo': idBadgeModelo,
        'id_badge_atribuido': idBadgeAtribuido,
        'nome_badge': badge['nome_badge'] ?? badge['nome'] ?? 'Badge',
        'descricao_badge': badge['descricao_badge_modelo'] ?? badge['descricao'] ?? '',
        'pontos': int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0,
        'id_nivel': int.tryParse((badge['id_nivel'] ?? 0).toString()) ?? 0,
        'imagem_url': badge['imagem_url'] ?? badge['imagem']?.toString(),
        'pontos_extra': pontosExtra,
        'ganhou_bonus': ganhouBonus,
        'premio_atribuido': ganhouBonus,
        'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? estadoPadrao,
        'data_atribuicao': badge['data_atribuicao']?.toString(),
        'data_validade': badge['data_validade']?.toString(),
        'tipo_badge': badge['tipo_badge'] ?? badge['tipo']?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesUtilizadorDoCache(int userId) async {
    await _ensureTabelaCacheBadgesUtilizador();
    final db = await _dbLocal.database;

    final badgeModelo = await _dbLocal.listarTabela('badge_modelo');
    final modelosPorId = <String, Map<String, dynamic>>{};
    for (final m in badgeModelo) {
      final id = (m['id_badge_modelo'] ?? '').toString();
      if (id.isNotEmpty) {
        modelosPorId[id] = m;
      }
    }

    final rows = await db.query(
      'cache_badges_utilizador',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
    );

    if (rows.isNotEmpty) {
      return rows.map((row) {
        final idModelo = (row['id_badge_modelo'] ?? '').toString();
        final modelo = modelosPorId[idModelo] ?? const <String, dynamic>{};

        final nome = (row['nome_badge']?.toString().trim().isNotEmpty ?? false)
            ? row['nome_badge']
            : (modelo['nome_badge'] ?? 'Badge');

        final descricao = (row['descricao_badge']?.toString().trim().isNotEmpty ?? false)
            ? row['descricao_badge']
            : (modelo['descricao_badge_modelo'] ?? 'Disponivel em cache offline.');

        final imagem = row['imagem_url'] ?? modelo['imagem_url'];

        final pontosBase = _converterInteiro(row['pontos'] ?? modelo['pontos']);
        int pontosExtra = _converterInteiro(row['pontos_extra']);
        final bool ganhouBonus = (row['ganhou_bonus'] ?? 0) == 1 || (row['premio_atribuido'] ?? 0) == 1;
        if (ganhouBonus && pontosExtra == 0 && pontosBase > 0) {
          pontosExtra = pontosBase;
        }

        return <String, dynamic>{
          'id_badge_atribuido': row['id_badge_atribuido'],
          'id_badge_modelo': row['id_badge_modelo'],
          'id': row['id_badge_modelo'],
          'nome': nome,
          'nome_badge': nome,
          'descricao': descricao,
          'descricao_badge_modelo': descricao,
          'pontos': pontosBase,
          'id_nivel': row['id_nivel'] ?? modelo['id_nivel'],
          'imagem_url': imagem,
          'imagem': imagem,
          'pontos_extra': pontosExtra,
          'pontos_bonus': pontosExtra,
          'ganhou_bonus': ganhouBonus,
          'premio_atribuido': ganhouBonus,
          'estado_badge_atribuido': row['estado_badge_atribuido'],
          'data_atribuicao': row['data_atribuicao'],
          'offline': true,
        };
      }).toList();
    }

    final badgeAtribuido = await _dbLocal.listarTabela('badge_atribuido');
    final obtem = await _dbLocal.listarTabela('obtem');

    final idsAtribuidos = obtem
        .where((row) => row['id_utilizador'].toString() == userId.toString())
        .map((row) => row['id_badge_atribuido'].toString())
        .toSet();

    final resultado = <Map<String, dynamic>>[];
    for (final atribuido in badgeAtribuido) {
      final idAtribuido = (atribuido['id_badge_atribuido'] ?? '').toString();
      if (!idsAtribuidos.contains(idAtribuido)) {
        continue;
      }

      final idModelo = (atribuido['id_badge_modelo'] ?? '').toString();
      final modelo = modelosPorId[idModelo] ?? const <String, dynamic>{};

      resultado.add({
        'id_badge_atribuido': atribuido['id_badge_atribuido'],
        'id_badge_modelo': atribuido['id_badge_modelo'],
        'id': atribuido['id_badge_modelo'],
        'nome': modelo['nome_badge'] ?? 'Badge',
        'nome_badge': modelo['nome_badge'] ?? 'Badge',
        'descricao': modelo['descricao_badge_modelo'] ?? '',
        'descricao_badge_modelo': modelo['descricao_badge_modelo'] ?? '',
        'pontos': modelo['pontos'] ?? 0,
        'id_nivel': modelo['id_nivel'],
        'imagem_url': modelo['imagem_url'],
        'imagem': modelo['imagem_url'],
        'pontos_extra': 0,
        'pontos_bonus': 0,
        'ganhou_bonus': false,
        'premio_atribuido': false,
        'estado_badge_atribuido': atribuido['estado_badge_atribuido'],
        'data_atribuicao': atribuido['data_atribuicao'],
        'offline': true,
      });
    }

    return resultado;
  }

  @override
  // Constrói o perfil.
  // O Provider é utilizado para obter dados atualizados do dashboard,
  // enquanto userData mantém os dados básicos da sessão.
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    
    // Consome o estado global para obter os dados atualizados do dashboard.
    final userProvider = ref.watch(utilizadorStateProvider);

    final int pontosDashboard =
        _converterInteiro(
      userProvider.dashboard[
            'total_pontos'
          ] ??
          userProvider.dashboard[
            'pontos_atuais'
          ],
    );

    final int pontosCalculados =
        badgesConquistados.fold(
      0,
      (acumulado, badge) {
        final int base = _converterInteiro(
          badge['pontos'],
        );

        final bonus = _obterBonusBadge(
          badge,
        );

        return acumulado + base + bonus.pontosExtra;
      },
    );

    final int pontosAtuais =
        pontosDashboard > 0
            ? (pontosCalculados > pontosDashboard
                ? pontosCalculados
                : pontosDashboard)
            : pontosCalculados;

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