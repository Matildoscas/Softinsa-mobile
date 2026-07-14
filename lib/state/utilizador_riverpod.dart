import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database/basededados.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
final baseDadosProvider = Provider<Basededados>((ref) => Basededados());

final utilizadorStateProvider =
    StateNotifierProvider<UtilizadorNotifier, UtilizadorState>((ref) {
  return UtilizadorNotifier(
    apiService: ref.read(apiServiceProvider),
    dbLocal: ref.read(baseDadosProvider),
  );
});

class UtilizadorState {
  final List<Map<String, dynamic>> utilizadores;
  final List<Map<String, dynamic>> areas;
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> badgesProgresso;
  final List<Map<String, dynamic>> badgesConquistados;
  final List<Map<String, dynamic>> badgesRecomendados;
  final List<Map<String, dynamic>> learningPaths;
  final bool estaACarregar;

  const UtilizadorState({
    this.utilizadores = const [],
    this.areas = const [],
    this.dashboard = const {},
    this.badgesProgresso = const [],
    this.badgesConquistados = const [],
    this.badgesRecomendados = const [],
    this.learningPaths = const [],
    this.estaACarregar = false,
  });

  UtilizadorState copyWith({
    List<Map<String, dynamic>>? utilizadores,
    List<Map<String, dynamic>>? areas,
    Map<String, dynamic>? dashboard,
    List<Map<String, dynamic>>? badgesProgresso,
    List<Map<String, dynamic>>? badgesConquistados,
    List<Map<String, dynamic>>? badgesRecomendados,
    List<Map<String, dynamic>>? learningPaths,
    bool? estaACarregar,
  }) {
    return UtilizadorState(
      utilizadores: utilizadores ?? this.utilizadores,
      areas: areas ?? this.areas,
      dashboard: dashboard ?? this.dashboard,
      badgesProgresso: badgesProgresso ?? this.badgesProgresso,
      badgesConquistados: badgesConquistados ?? this.badgesConquistados,
      badgesRecomendados: badgesRecomendados ?? this.badgesRecomendados,
      learningPaths: learningPaths ?? this.learningPaths,
      estaACarregar: estaACarregar ?? this.estaACarregar,
    );
  }
}

class UtilizadorNotifier extends StateNotifier<UtilizadorState> {
  UtilizadorNotifier({
    required ApiService apiService,
    required Basededados dbLocal,
  })  : _apiService = apiService,
        _dbLocal = dbLocal,
        super(const UtilizadorState());

  final ApiService _apiService;
  final Basededados _dbLocal;

  Future<void> carregarAreas() async {
    state = state.copyWith(estaACarregar: true);
    try {
      final areas = await _sincronizarAreas();
      state = state.copyWith(areas: areas);
    } finally {
      state = state.copyWith(estaACarregar: false);
    }
  }

  Future<void> inicializarDados(int userId) async {
    state = state.copyWith(estaACarregar: true);
    try {
      final areas = await _sincronizarAreas();
      final dashboard = await _carregarDashboard(userId);
      final learningPaths = await _carregarLearningPaths(userId);
      final badgesProgresso = await _carregarBadgesProgresso(userId);
      final badgesConquistados = await _carregarBadgesConquistados(userId);
      final badgesRecomendados = await _carregarBadgesRecomendados(userId);
      final utilizadores = await _carregarUtilizadores();

      state = state.copyWith(
        areas: areas,
        dashboard: dashboard,
        learningPaths: learningPaths,
        badgesProgresso: badgesProgresso,
        badgesConquistados: badgesConquistados,
        badgesRecomendados: badgesRecomendados,
        utilizadores: utilizadores,
      );
    } finally {
      state = state.copyWith(estaACarregar: false);
    }
  }

  Future<void> atualizarDashboard(int userId) async {
    final dashboard = await _carregarDashboard(userId);
    final learningPaths = await _carregarLearningPaths(userId);
    final badgesProgresso = await _carregarBadgesProgresso(userId);
    final badgesConquistados = await _carregarBadgesConquistados(userId);
    final badgesRecomendados = await _carregarBadgesRecomendados(userId);

    state = state.copyWith(
      dashboard: dashboard,
      learningPaths: learningPaths,
      badgesProgresso: badgesProgresso,
      badgesConquistados: badgesConquistados,
      badgesRecomendados: badgesRecomendados,
    );
  }

  Future<List<Map<String, dynamic>>> _sincronizarAreas() async {
    try {
      final dadosAreasRaw = await _apiService.getAreas();

      final areas = dadosAreasRaw
          .map(_normalizarArea)
          .where((area) => area['id_areas'] != 0)
          .toList();

      for (final area in areas) {
        final areaLocal = <String, dynamic>{
          'id_areas': area['id_areas'],
          'id_serviceline': area['id_serviceline'],
          'nome_area': area['nome_area'],
          'descricao_area': area['descricao_area'],
          'data_criacao': area['data_criacao'],
          'numero_consultores': area['numero_consultores'],
        };
        await _dbLocal.salvarRegisto('areas', areaLocal);
      }

      return areas;
    } catch (_) {
      final dadosLocais = await _dbLocal.listarTabela('areas');
      return dadosLocais
          .map(_normalizarArea)
          .where((area) => area['id_areas'] != 0)
          .toList();
    }
  }

  Map<String, dynamic> _normalizarArea(Map<String, dynamic> area) {
    return <String, dynamic>{
      'id_areas': int.tryParse((area['id_areas'] ?? area['id'] ?? 0).toString()) ?? 0,
      'id_serviceline': area['id_serviceline'] == null
          ? null
          : int.tryParse(area['id_serviceline'].toString()),
      'nome_area': area['nome_area']?.toString() ?? area['nome']?.toString() ?? 'Area sem nome',
      'descricao_area': area['descricao_area']?.toString() ?? area['descricao']?.toString() ?? '',
      'data_criacao': area['data_criacao']?.toString(),
      'numero_consultores': int.tryParse((area['numero_consultores'] ?? 0).toString()) ?? 0,
      'estado_area': area['estado_area']?.toString() ?? 'ATIVO',
    };
  }

  Future<Map<String, dynamic>> _carregarDashboard(int userId) async {
    try {
      final dados = await _apiService.getDashboard(userId);
      final dashboard = Map<String, dynamic>.from(dados);

      await _dbLocal.salvarRegisto('consultor', {
        'id_utilizador': userId,
        'id_areas': dashboard['id_areas'],
        'pontos_atuais': int.tryParse(
              (dashboard['total_pontos'] ?? dashboard['pontos_atuais'] ?? 0).toString(),
            ) ??
            0,
        'badges_conquistas_total': int.tryParse(
              (dashboard['total_badges'] ?? dashboard['badges_conquistas_total'] ?? 0).toString(),
            ) ??
            0,
        'progresso_nivel': dashboard['ranking'] ?? dashboard['progresso_nivel'] ?? 'N/A',
        'ultima_atualizacao_perfil': DateTime.now().toString(),
      });

      return dashboard;
    } on SocketException {
      return _carregarDashboardLocal(userId);
    } catch (_) {
      return _carregarDashboardLocal(userId);
    }
  }

  Future<Map<String, dynamic>> _carregarDashboardLocal(int userId) async {
    try {
      final dadosLocais = await _dbLocal.listarTabela('consultor');
      if (dadosLocais.isEmpty) {
        return <String, dynamic>{};
      }

      final meuConsultor = dadosLocais.firstWhere(
        (consultor) => consultor['id_utilizador'].toString() == userId.toString(),
        orElse: () => dadosLocais.first,
      );

      return {
        'total_pontos': meuConsultor['pontos_atuais'] ?? 0,
        'total_badges': meuConsultor['badges_conquistas_total'] ?? 0,
        'ranking': meuConsultor['progresso_nivel'] ?? 'N/A',
        'id_areas': meuConsultor['id_areas'],
        'offline': true,
      };
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<List<Map<String, dynamic>>> _carregarLearningPaths(int userId) async {
    try {
      final resultado = await _apiService.getProgressoLearningPaths(userId);
      final learningPaths = List<Map<String, dynamic>>.from(resultado);

      await _guardarLearningPathsCache(userId, learningPaths);

      for (final lp in learningPaths) {
        await _dbLocal.salvarRegisto('learningpaths', {
          'id_learningpaths': int.tryParse(
                (lp['id_learningpaths'] ?? lp['id_learningpath'] ?? lp['id'] ?? 0).toString(),
              ) ??
              0,
          'nome_learningpaths': lp['nome_learningpath'] ?? lp['nome_learningpaths'] ?? lp['nome'] ?? 'Learning Path',
          'numero_servicelines': int.tryParse(
                (lp['total_badges'] ?? lp['numero_badges'] ?? lp['badges_total'] ?? lp['total'] ?? 0)
                    .toString(),
              ) ??
              0,
        });
      }

      return learningPaths;
    } catch (_) {
      try {
        final learningPathsCache = await _carregarLearningPathsCache(userId);
        if (learningPathsCache.isNotEmpty) {
          return learningPathsCache;
        }

        final dadosLocais = await _dbLocal.listarTabela('learningpaths');
        return dadosLocais
            .map((lp) => <String, dynamic>{
                  'id_learningpaths': lp['id_learningpaths'],
                  'id_learningpath': lp['id_learningpaths'],
                  'nome_learningpath': lp['nome_learningpaths'] ?? 'Learning Path',
                  'nome_learningpaths': lp['nome_learningpaths'] ?? 'Learning Path',
                  'total_badges': lp['numero_servicelines'] ?? 0,
                  'badges_conquistados': 0,
                  'percentagem': 0,
                })
            .toList();
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesProgresso(int userId) async {
    try {
      final resultado = await _apiService.getBadgesProgresso(userId);
      final badges = List<Map<String, dynamic>>.from(resultado);

      for (final badge in badges) {
        await _guardarBadgeAtribuidoCache(
          userId: userId,
          badge: badge,
          estadoPadrao: 'Em Progresso',
        );
      }

      return badges;
    } catch (_) {
      return _carregarBadgesAtribuidosDoCache(
        userId: userId,
        estadosValidos: const ['Em Progresso', 'EM_PROGRESSO', 'PENDENTE'],
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesConquistados(int userId) async {
    try {
      final resultado = await _apiService.getBadgesConquistados(userId);
      final badges = List<Map<String, dynamic>>.from(resultado);

      for (final badge in badges) {
        await _guardarBadgeAtribuidoCache(
          userId: userId,
          badge: badge,
          estadoPadrao: 'Conquistado',
        );
      }

      return badges;
    } catch (_) {
      return _carregarBadgesAtribuidosDoCache(
        userId: userId,
        estadosValidos: const [
          'Conquistado',
          'CONQUISTADO',
          'Concluido',
          'CONCLUIDO',
          'Aprovado',
          'APROVADO',
          'Validado',
          'VALIDADO',
          'Completo',
          'COMPLETO',
        ],
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesRecomendados(int userId) async {
    try {
      final resultado = await _apiService.getBadgesRecomendados(userId);
      final badges = List<Map<String, dynamic>>.from(resultado);

      await _guardarBadgesRecomendadosCache(userId, badges);

      return badges;
    } catch (_) {
      return _carregarBadgesRecomendadosCache(userId);
    }
  }

  Future<List<Map<String, dynamic>>> _carregarUtilizadores() async {
    try {
      final dadosRaw = await _apiService.getUtilizadores();
      final utilizadores = List<Map<String, dynamic>>.from(dadosRaw);

      for (final user in utilizadores) {
        final userLocal = <String, dynamic>{
          'id_utilizador': int.tryParse((user['id_utilizador'] ?? user['id'] ?? 0).toString()) ?? 0,
          'nome_completo': user['nome_completo'] ?? user['nome'] ?? '',
          'email': user['email'] ?? '',
          'contacto': user['contacto'] ?? '',
          'estado_conta': user['estado_conta'] ?? 'Ativo',
          'password': user['password'] ?? '',
          'aceitou_termos': (user['aceitou_termos'] == true ||
                  user['aceitou_termos'] == 1 ||
                  user['aceitar_termos'] == 1)
              ? 1
              : 0,
        };

        await _dbLocal.salvarRegisto('utilizador', userLocal);
      }

      return utilizadores;
    } catch (_) {
      try {
        return await _dbLocal.listarTabela('utilizador');
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }
  }

  Future<void> _guardarBadgeAtribuidoCache({
    required int userId,
    required Map<String, dynamic> badge,
    required String estadoPadrao,
  }) async {
    final int idBadgeModelo =
        int.tryParse(
              (
                badge['id_badge_modelo'] ??
                badge['id_badge'] ??
                badge['id_badgeModelo'] ??
                badge['badge_id'] ??
                badge['id'] ??
                badge['id_badge_atribuido'] ??
                0
              ).toString(),
            ) ??
            0;

    final int idBadgeAtribuido =
        int.tryParse(
              (
                badge['id_badge_atribuido'] ??
                badge['id_atribuido'] ??
                badge['id'] ??
                idBadgeModelo
              ).toString(),
            ) ??
            idBadgeModelo;

    if (idBadgeAtribuido == 0) {
      return;
    }

    final int idModeloPersistido =
        idBadgeModelo == 0
            ? idBadgeAtribuido
            : idBadgeModelo;

    final String estadoBadge =
        badge['estado_badge_atribuido']?.toString() ??
        badge['estado']?.toString() ??
        badge['status']?.toString() ??
        estadoPadrao;

    await _dbLocal.salvarRegisto('badge_modelo', {
      'id_badge_modelo': idModeloPersistido,
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
      'imagem': null,
    });

    await _dbLocal.salvarRegisto('badge_atribuido', {
      'id_badge_atribuido': idBadgeAtribuido,
      'id_badge_modelo': idModeloPersistido,
      'data_atribuicao': badge['data_atribuicao']?.toString(),
      'data_validade': badge['data_validade']?.toString(),
      'estado_badge_atribuido': estadoBadge,
    });

    await _dbLocal.salvarRegisto('obtem', {
      'id_utilizador': userId,
      'id_badge_atribuido': idBadgeAtribuido,
    });

    await _guardarBadgeUtilizadorCache(
      userId: userId,
      idBadgeModelo: idModeloPersistido,
      idBadgeAtribuido: idBadgeAtribuido,
      badge: badge,
      estadoPadrao: estadoPadrao,
    );
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesAtribuidosDoCache({
    required int userId,
    required List<String> estadosValidos,
  }) async {
    try {
      final cacheDetalhe = await _carregarBadgesUtilizadorCache(
        userId: userId,
        estadosValidos: estadosValidos,
      );

      if (cacheDetalhe.isNotEmpty) {
        return cacheDetalhe;
      }

      final badgeAtribuido = await _dbLocal.listarTabela('badge_atribuido');
      final badgeModelo = await _dbLocal.listarTabela('badge_modelo');
      final obtem = await _dbLocal.listarTabela('obtem');

      final idsAtribuidosDoUtilizador = obtem
          .where((row) => row['id_utilizador'].toString() == userId.toString())
          .map((row) => row['id_badge_atribuido'].toString())
          .toSet();

      final mapaModelo = <String, Map<String, dynamic>>{};
      for (final modelo in badgeModelo) {
        final idModelo = (modelo['id_badge_modelo'] ?? '').toString();
        if (idModelo.isNotEmpty) {
          mapaModelo[idModelo] = modelo;
        }
      }

      final resultado = <Map<String, dynamic>>[];
      for (final atribuido in badgeAtribuido) {
        final idAtribuido = (atribuido['id_badge_atribuido'] ?? '').toString();
        if (!idsAtribuidosDoUtilizador.contains(idAtribuido)) {
          continue;
        }

        final estado = (atribuido['estado_badge_atribuido'] ?? '').toString();
        final estadoUpper = estado.toUpperCase();

        final estadoCompativel = estadosValidos.any(
          (e) => e.toUpperCase() == estadoUpper,
        );

        if (!estadoCompativel) {
          continue;
        }

        final idModelo = (atribuido['id_badge_modelo'] ?? '').toString();
        final modelo = mapaModelo[idModelo] ?? const <String, dynamic>{};

        resultado.add({
          'id_badge_atribuido': atribuido['id_badge_atribuido'],
          'id_badge_modelo': atribuido['id_badge_modelo'],
          'id': atribuido['id_badge_modelo'],
          'nome': modelo['nome_badge'] ?? 'Badge',
          'nome_badge': modelo['nome_badge'] ?? 'Badge',
          'descricao': modelo['descricao_badge_modelo'] ?? '',
          'descricao_badge_modelo': modelo['descricao_badge_modelo'] ?? '',
          'pontos': modelo['pontos'] ?? 0,
          'data_atribuicao': atribuido['data_atribuicao'],
          'data_validade': atribuido['data_validade'],
          'estado_badge_atribuido': atribuido['estado_badge_atribuido'],
          'imagem_url': modelo['imagem_url'],
          'offline': true,
        });
      }

      return resultado;
    } catch (_) {
      return <Map<String, dynamic>>[];
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
    required int idBadgeModelo,
    required int idBadgeAtribuido,
    required Map<String, dynamic> badge,
    required String estadoPadrao,
  }) async {
    await _ensureTabelaCacheBadgesUtilizador();

    final db = await _dbLocal.database;
    final int pontosBase = int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0;
    int pontosExtra =
      int.tryParse((badge['pontos_extra'] ?? badge['pontos_bonus'] ?? 0).toString()) ?? 0;

    final bool ganhouBonusBool =
      ((badge['ganhou_bonus'] == true) || (badge['premio_atribuido'] == true) || pontosExtra > 0);

    if (ganhouBonusBool && pontosExtra == 0 && pontosBase > 0) {
      pontosExtra = pontosBase;
    }

    final ganhouBonus = ganhouBonusBool ? 1 : 0;

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

  Future<List<Map<String, dynamic>>> _carregarBadgesUtilizadorCache({
    required int userId,
    required List<String> estadosValidos,
  }) async {
    try {
      await _ensureTabelaCacheBadgesUtilizador();
      final db = await _dbLocal.database;

      final rows = await db.query(
        'cache_badges_utilizador',
        where: 'id_utilizador = ?',
        whereArgs: [userId],
      );

      if (rows.isEmpty) {
        return <Map<String, dynamic>>[];
      }

      final normalized = rows.where((row) {
        final estado = (row['estado_badge_atribuido'] ?? '').toString().toUpperCase();
        return estadosValidos.any((e) => e.toUpperCase() == estado);
      }).map((row) {
        return <String, dynamic>{
          'id_badge_atribuido': row['id_badge_atribuido'],
          'id_badge_modelo': row['id_badge_modelo'],
          'id': row['id_badge_modelo'],
          'nome': row['nome_badge'] ?? 'Badge',
          'nome_badge': row['nome_badge'] ?? 'Badge',
          'descricao': row['descricao_badge'] ?? '',
          'descricao_badge_modelo': row['descricao_badge'] ?? '',
          'pontos': row['pontos'] ?? 0,
          'id_nivel': row['id_nivel'],
          'imagem_url': row['imagem_url'],
          'imagem': row['imagem_url'],
          'pontos_extra': row['pontos_extra'] ?? 0,
          'pontos_bonus': row['pontos_extra'] ?? 0,
          'ganhou_bonus': (row['ganhou_bonus'] ?? 0) == 1,
          'premio_atribuido': (row['premio_atribuido'] ?? 0) == 1,
          'estado_badge_atribuido': row['estado_badge_atribuido'],
          'data_atribuicao': row['data_atribuicao'],
          'data_validade': row['data_validade'],
          'tipo_badge': row['tipo_badge'],
          'offline': true,
        };
      }).toList();

      return normalized;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _ensureTabelaLearningPathsUtilizador() async {
    final db = await _dbLocal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_learningpaths_utilizador (
        id_utilizador INTEGER,
        id_learningpaths INTEGER,
        nome_learningpaths TEXT,
        total_badges INTEGER,
        badges_conquistados INTEGER,
        percentagem INTEGER,
        data_cache TEXT,
        PRIMARY KEY (id_utilizador, id_learningpaths)
      )
    ''');
  }

  Future<void> _guardarLearningPathsCache(
    int userId,
    List<Map<String, dynamic>> learningPaths,
  ) async {
    await _ensureTabelaLearningPathsUtilizador();

    final db = await _dbLocal.database;
    await db.delete(
      'cache_learningpaths_utilizador',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
    );

    for (final lp in learningPaths) {
      final idLearningPath =
          int.tryParse((lp['id_learningpaths'] ?? lp['id_learningpath'] ?? lp['id'] ?? 0).toString()) ?? 0;

      if (idLearningPath == 0) {
        continue;
      }

      final totalBadges = int.tryParse(
            (lp['total_badges'] ?? lp['numero_badges'] ?? lp['badges_total'] ?? lp['total'] ?? 0).toString(),
          ) ??
          0;

      final badgesConquistados = int.tryParse(
            (lp['badges_conquistados'] ??
                    lp['badges_concluidos'] ??
                    lp['badges_conquistas_total'] ??
                    lp['total_conquistados'] ??
                    lp['conquistados'] ??
                    0)
                .toString(),
          ) ??
          0;

      int percentagem =
          int.tryParse((lp['percentagem'] ?? lp['progresso_percentagem'] ?? 0).toString()) ?? 0;

      if (percentagem == 0 && totalBadges > 0 && badgesConquistados > 0) {
        percentagem = ((badgesConquistados / totalBadges) * 100).round();
      }

      await db.insert(
        'cache_learningpaths_utilizador',
        {
          'id_utilizador': userId,
          'id_learningpaths': idLearningPath,
          'nome_learningpaths': lp['nome_learningpath'] ?? lp['nome_learningpaths'] ?? lp['nome'] ?? 'Learning Path',
          'total_badges': totalBadges,
          'badges_conquistados': badgesConquistados,
          'percentagem': percentagem.clamp(0, 100),
          'data_cache': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarLearningPathsCache(int userId) async {
    try {
      await _ensureTabelaLearningPathsUtilizador();
      final db = await _dbLocal.database;

      final rows = await db.query(
        'cache_learningpaths_utilizador',
        where: 'id_utilizador = ?',
        whereArgs: [userId],
      );

      return rows
          .map((row) => <String, dynamic>{
                'id_learningpaths': row['id_learningpaths'],
                'id_learningpath': row['id_learningpaths'],
                'nome_learningpath': row['nome_learningpaths'],
                'nome_learningpaths': row['nome_learningpaths'],
                'total_badges': row['total_badges'] ?? 0,
                'badges_conquistados': row['badges_conquistados'] ?? 0,
                'badges_conquistas_total': row['badges_conquistados'] ?? 0,
                'total_conquistados': row['badges_conquistados'] ?? 0,
                'percentagem': row['percentagem'] ?? 0,
                'offline': true,
              })
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _ensureTabelaBadgesRecomendados() async {
    final db = await _dbLocal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_badges_recomendados (
        id_badge_modelo INTEGER,
        id_utilizador INTEGER,
        nome_badge TEXT,
        descricao_badge TEXT,
        pontos INTEGER,
        imagem_url TEXT,
        data_cache TEXT,
        PRIMARY KEY (id_badge_modelo, id_utilizador)
      )
    ''');
  }

  Future<void> _guardarBadgesRecomendadosCache(
    int userId,
    List<Map<String, dynamic>> badges,
  ) async {
    await _ensureTabelaBadgesRecomendados();

    final db = await _dbLocal.database;
    await db.delete(
      'cache_badges_recomendados',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
    );

    for (final badge in badges) {
      final idBadgeModelo =
          int.tryParse((badge['id_badge_modelo'] ?? badge['id'] ?? badge['badge_id'] ?? 0).toString()) ?? 0;
      if (idBadgeModelo == 0) {
        continue;
      }

      await db.insert(
        'cache_badges_recomendados',
        {
          'id_badge_modelo': idBadgeModelo,
          'id_utilizador': userId,
          'nome_badge': badge['nome_badge'] ?? badge['nome'] ?? 'Badge',
          'descricao_badge': badge['descricao_badge'] ?? badge['descricao'] ?? '',
          'pontos': int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0,
          'imagem_url': badge['imagem_url'] ?? badge['imagem']?.toString(),
          'data_cache': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesRecomendadosCache(int userId) async {
    try {
      await _ensureTabelaBadgesRecomendados();
      final db = await _dbLocal.database;

      final rows = await db.query(
        'cache_badges_recomendados',
        where: 'id_utilizador = ?',
        whereArgs: [userId],
      );

      return rows
          .map((row) => <String, dynamic>{
                'id_badge_modelo': row['id_badge_modelo'],
                'id': row['id_badge_modelo'],
                'nome': row['nome_badge'],
                'nome_badge': row['nome_badge'],
                'descricao': row['descricao_badge'],
                'descricao_badge': row['descricao_badge'],
                'pontos': row['pontos'] ?? 0,
                'imagem_url': row['imagem_url'],
                'offline': true,
              })
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
