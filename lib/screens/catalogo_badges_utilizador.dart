// ============================================================================
// catalogo_badges_utilizador.dart
//
// Catálogo pessoal do utilizador.
// Apresenta apenas os badges já conquistados e permite pesquisar,
// filtrar por nível e ordenar por nome ou pontuação.
// Utiliza a API e guarda atribuições no SQLite para consulta offline.
//
// A lógica original foi mantida.
// Os comentários explicam:
// - Responsabilidade de cada classe e função;
// - Fluxo entre API, SQLite e interface;
// - Pesquisa, filtros, navegação e estados;
// - Tratamento de imagens, ficheiros e modo offline.
// ============================================================================

// Componentes visuais e navegação do Flutter.
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
// Serviço utilizado para obter os badges conquistados.
import '../services/api_service.dart';
// Base de dados SQLite utilizada como cache offline.
import '../database/basededados.dart';
import 'informacoes_badge.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

// Converte o ID do nível para A, B, C, D ou E.
String obterNivel(dynamic idNivel) {
  final int? nivel = _normalizarIdNivel(idNivel);
  switch (nivel) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

int? _normalizarIdNivel(dynamic valor) {
  if (valor == null) {
    return null;
  }

  final texto = valor.toString().trim();
  if (texto.isEmpty) {
    return null;
  }

  final numero = int.tryParse(texto);
  if (numero != null && numero >= 1 && numero <= 5) {
    return numero;
  }

  final upper = texto.toUpperCase();
  if (upper == 'A' || upper == 'INICIANTE' || upper == 'JUNIOR' || upper == 'JÚNIOR') return 1;
  if (upper == 'B' || upper == 'INTERMEDIO' || upper == 'INTERMÉDIO') return 2;
  if (upper == 'C' || upper == 'AVANCADO' || upper == 'AVANÇADO' || upper == 'SENIOR' || upper == 'SÉNIOR') return 3;
  if (upper == 'D' || upper == 'EXPERT' || upper == 'ESPECIALISTA') return 4;
  if (upper == 'E' || upper == 'MASTER' || upper == 'LIDER DE CONHECIMENTO' || upper == 'LÍDER DE CONHECIMENTO' || upper == 'LEADER OF KNOWLEDGE') return 5;

  if (upper.startsWith('NIVEL ') || upper.startsWith('NÍVEL ')) {
    return _normalizarIdNivel(upper.split(' ').last);
  }

  return null;
}

class _BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const _BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

// Página dos badges conquistados pelo utilizador.
class MeusBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MeusBadgesPage({super.key, required this.userData});

  @override
  State<MeusBadgesPage> createState() => _MeusBadgesPageState();
}

// Estado da página: listas, carregamento, pesquisa, filtro e ordenação.
class _MeusBadgesPageState extends State<MeusBadgesPage>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados();
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  Timer? _refreshTimer;
  bool _aAtualizarTempoReal = false;

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

    WidgetsBinding.instance.addObserver(this);

    _carregarMeusBadges();

    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (_) {
        _atualizarMeusBadgesEmTempoReal(
          origem: 'push_foreground',
        );
      },
    );

    _onMessageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      (_) {
        _atualizarMeusBadgesEmTempoReal(
          origem: 'push_aberta',
        );
      },
    );

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
      if (message != null) {
        _atualizarMeusBadgesEmTempoReal(
          origem: 'push_inicial',
        );
      }
    });

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _atualizarMeusBadgesEmTempoReal(
          origem: 'timer_30s',
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _atualizarMeusBadgesEmTempoReal(
        origem: 'app_resumed',
      );
    }
  }

  Future<void> _atualizarMeusBadgesEmTempoReal({
    required String origem,
  }) async {
    if (_aAtualizarTempoReal || !mounted) {
      return;
    }

    try {
      _aAtualizarTempoReal = true;

      debugPrint(
        '[TEMPO REAL MEUS BADGES] Atualizar por: $origem',
      );

      await _carregarMeusBadges();
    } catch (e) {
      debugPrint(
        '[TEMPO REAL MEUS BADGES] Erro: $e',
      );
    } finally {
      _aAtualizarTempoReal = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onMessageSubscription?.cancel();
    _onMessageOpenedSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

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

  _BadgeBonusInfo _obterBonusBadge(
    Map<String, dynamic> badge,
  ) {
    final int pontosBase =
        _converterInteiro(
      badge['pontos'],
    );

    int pontosExtra =
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

    if (ganhouBonus && pontosExtra == 0 && pontosBase > 0) {
      pontosExtra = pontosBase;
    }

    return _BadgeBonusInfo(
      ganhouBonus: ganhouBonus,
      pontosExtra: pontosExtra,
    );
  }

  int? _resolverIdNivelBadge(Map<String, dynamic> badge) {
    final candidatos = [
      badge['id_nivel'],
      badge['codigo_nivel'],
      badge['nivel'],
      badge['nome_nivel'],
    ];

    for (final valor in candidatos) {
      final nivel = _normalizarIdNivel(valor);
      if (nivel != null) {
        return nivel;
      }
    }

    return null;
  }

  // Extrai os níveis existentes nos badges conquistados.
  // Remove níveis repetidos e ordena a lista.
  void _extrairNiveis() {
    niveis = meusBadges
        .map((b) => obterNivel(_resolverIdNivelBadge(b)))
        .where((n) => n != '-')
        .toSet()
        .toList()
      ..sort();
  }

  // =========================================================================
  // APLICAR FILTROS
  //
  // Pesquisa no nome e descrição, filtra por nível e permite ordenar:
  // - Nome A-Z;
  // - Nome Z-A;
  // - Mais pontos;
  // - Menos pontos.
  // =========================================================================
  void _aplicarFiltros() {
    var lista = meusBadges.where((b) {
      final nome = (b['nome'] ?? b['nome_badge'] ?? '').toString().toLowerCase();
      final descricao = (b['descricao'] ?? b['descricao_badge_modelo'] ?? '').toString().toLowerCase();

      final matchPesquisa = pesquisa.isEmpty ||
          nome.contains(pesquisa.toLowerCase()) ||
          descricao.contains(pesquisa.toLowerCase());

      final matchNivel =
          filtroNivel == null || obterNivel(_resolverIdNivelBadge(b)) == filtroNivel;

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
    } else if (
      ordenacao == 'pontos_desc'
      ) {
        lista.sort((a, b) {
          final pontosA =
              _converterInteiro(
                a['pontos'],
              ) +
              _obterBonusBadge(a)
                  .pontosExtra;

          final pontosB =
              _converterInteiro(
                b['pontos'],
              ) +
              _obterBonusBadge(b)
                  .pontosExtra;

          return pontosB.compareTo(
            pontosA,
          );
        });
      } else if (
        ordenacao == 'pontos_asc'
      ) {
        lista.sort((a, b) {
          final pontosA =
              _converterInteiro(
                a['pontos'],
              ) +
              _obterBonusBadge(a)
                  .pontosExtra;

          final pontosB =
              _converterInteiro(
                b['pontos'],
              ) +
              _obterBonusBadge(b)
                  .pontosExtra;

          return pontosA.compareTo(
            pontosB,
          );
        });
      }

    setState(() {
      meusBadgesFiltrados = lista;
    });
  }

  // =========================================================================
  // CARREGAR OS MEUS BADGES
  //
  // 1. Obtém os badges conquistados através da API;
  // 2. Atualiza as listas e os níveis da interface;
  // 3. Guarda cada atribuição no SQLite;
  // 4. Se a API falhar, adapta os dados locais de badge_atribuido.
  // =========================================================================
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
        await _guardarBadgeUtilizadorCache(
          userId: userId,
          badge: b,
          estadoPadrao: 'Conquistado',
        );
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo em Os Seus Badges: $e");

      // 3. Fallback: Se falhar a rede, carrega os dados cacheados com detalhe
      final badgesLocais = await _carregarBadgesUtilizadorDoCache(userId);

      if (mounted) {
        setState(() {
          meusBadges =
              badgesLocais;

          meusBadgesFiltrados =
              List<Map<String, dynamic>>
                  .from(
            badgesLocais,
          );

          _extrairNiveis();

          isLoading = false;
        });
      }
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
      'id_nivel': _resolverIdNivelBadge(badge),
      'id_utilizador': userId,
      'nome_badge': badge['nome_badge'] ?? badge['nome'] ?? 'Badge',
      'descricao_badge_modelo': badge['descricao_badge_modelo'] ?? badge['descricao'] ?? '',
      'data_criacao_badge_modelo': badge['data_atribuicao']?.toString(),
      'estado_badge_modelo': badge['estado_badge_modelo'] ?? 'ATIVO',
      'numero_requisitos': int.tryParse((badge['numero_requisitos'] ?? 0).toString()) ?? 0,
      'pontos': int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0,
      'tempo_expiracao': badge['tempo_expiracao']?.toString(),
      'tipo_badge': badge['tipo_badge'] ?? badge['tipo']?.toString(),
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
        'id_nivel': _resolverIdNivelBadge(badge),
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
          'id_nivel': _normalizarIdNivel(row['id_nivel']) ?? _normalizarIdNivel(modelo['id_nivel']),
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
        'nome': modelo['nome_badge'] ?? 'Badge Conquistado',
        'nome_badge': modelo['nome_badge'] ?? 'Badge Conquistado',
        'descricao': modelo['descricao_badge_modelo'] ?? 'Disponivel em cache offline.',
        'descricao_badge_modelo': modelo['descricao_badge_modelo'] ?? 'Disponivel em cache offline.',
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
// =========================================================================
// BUILD
//
// Constrói a pesquisa, filtros, lista pessoal e cabeçalho fixo.
// Distingue carregamento, lista vazia e pesquisa sem resultados.
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

  // Componente genérico utilizado pelos dois dropdowns.
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

  // Cria o cartão de um badge conquistado.
  // Formata a data e abre o detalhe quando o utilizador toca no cartão.
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
        badge['imagem_url']
            ?.toString() ??
        badge['imagem']
            ?.toString() ??
        badge['url_imagem']
            ?.toString();

    final int? idNivelBadge =
      _resolverIdNivelBadge(
      badge,
    );

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

    String dataFormatada = '—';

    if (
      badge['data_atribuicao'] !=
      null
    ) {
      try {
        final dt = DateTime.parse(
          badge['data_atribuicao']
              .toString(),
        );

        dataFormatada =
            '${dt.day.toString().padLeft(2, '0')}/'
            '${dt.month.toString().padLeft(2, '0')}/'
            '${dt.year}';
      } catch (_) {
        dataFormatada =
            badge['data_atribuicao']
                .toString();
      }
    }

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

                            if (
                              ganhouBonus
                            )
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
                          idNivelBadge !=
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
                              '${obterNivel(idNivelBadge)}',
                              style:
                                  TextStyle(
                                fontSize:
                                    10,

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

  // Estado apresentado quando o utilizador ainda não conquistou badges.
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

// Componente reutilizável para carregar a imagem do badge.
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

  // Ícone apresentado quando a imagem não está disponível.
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