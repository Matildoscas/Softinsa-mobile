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
        estadosValidos: const ['Conquistado', 'CONQUISTADO', 'Concluido', 'CONCLUIDO'],
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
        int.tryParse((badge['id_badge_modelo'] ?? badge['id'] ?? badge['badge_id'] ?? 0).toString()) ?? 0;

    final int idBadgeAtribuido =
        int.tryParse((badge['id_badge_atribuido'] ?? badge['id'] ?? idBadgeModelo).toString()) ?? idBadgeModelo;

    if (idBadgeModelo == 0 || idBadgeAtribuido == 0) {
      return;
    }

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
  }

  Future<List<Map<String, dynamic>>> _carregarBadgesAtribuidosDoCache({
    required int userId,
    required List<String> estadosValidos,
  }) async {
    try {
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
