import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../database/basededados.dart';

class UtilizadorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados();

  // =====================================================
  // ESTADOS
  // =====================================================

  List<Map<String, dynamic>> _utilizadores = [];
  List<Map<String, dynamic>> _areas = [];

  Map<String, dynamic> _dashboard = {};

  List<Map<String, dynamic>> _badgesProgresso = [];
  List<Map<String, dynamic>> _badgesConquistados = [];
  List<Map<String, dynamic>> _badgesRecomendados = [];

  bool _estaA_Carregar = false;

  // =====================================================
  // GETTERS
  // =====================================================

  List<Map<String, dynamic>> get utilizadores =>
      _utilizadores;

  List<Map<String, dynamic>> get areas =>
      _areas;

  Map<String, dynamic> get dashboard =>
      _dashboard;

  List<Map<String, dynamic>> get badgesProgresso =>
      _badgesProgresso;

  List<Map<String, dynamic>> get badgesConquistados =>
      _badgesConquistados;

  List<Map<String, dynamic>> get badgesRecomendados =>
      _badgesRecomendados;

  bool get estaA_Carregar =>
      _estaA_Carregar;

  // =====================================================
  // CARREGAR ÁREAS ANTES DO REGISTO
  // =====================================================

  Future<void> carregarAreas() async {
    _estaA_Carregar = true;
    notifyListeners();

    print(
      '========== PROVIDER: CARREGAR ÁREAS ==========',
    );

    try {
      await _sincronizarAreas();
    } finally {
      _estaA_Carregar = false;
      notifyListeners();

      print(
        '[PROVIDER ÁREAS] Total final: ${_areas.length}',
      );
      print(
        '===============================================',
      );
    }
  }

  // =====================================================
  // INICIALIZAR TODOS OS DADOS DEPOIS DO LOGIN
  // =====================================================

  Future<void> inicializarDados(int userId) async {
    _estaA_Carregar = true;
    notifyListeners();

    print(
      '========== INICIALIZAR DADOS ==========',
    );
    print(
      '[PROVIDER] ID do utilizador: $userId',
    );

    try {
      await _sincronizarAreas();

      await _carregarDashboard(userId);

      await _carregarBadgesProgresso(
        userId,
      );

      await _carregarBadgesConquistados(
        userId,
      );

      await _carregarBadgesRecomendados(
        userId,
      );

      await _carregarUtilizadores();
    } catch (e, stackTrace) {
      print(
        '[PROVIDER] Erro geral: $e',
      );
      print(stackTrace);
    } finally {
      _estaA_Carregar = false;
      notifyListeners();

      print(
        '[PROVIDER] Dashboard carregado: '
        '${_dashboard.isNotEmpty}',
      );
      print(
        '[PROVIDER] Badges em progresso: '
        '${_badgesProgresso.length}',
      );
      print(
        '[PROVIDER] Badges conquistados: '
        '${_badgesConquistados.length}',
      );
      print(
        '[PROVIDER] Badges recomendados: '
        '${_badgesRecomendados.length}',
      );
      print(
        '========================================',
      );
    }
  }

  // =====================================================
  // ÁREAS
  // =====================================================

  Future<void> _sincronizarAreas() async {
    try {
      final dadosAreasRaw =
          await _apiService.getAreas();

      print(
        '[PROVIDER ÁREAS] Total recebido da API: '
        '${dadosAreasRaw.length}',
      );

      _areas = dadosAreasRaw
          .map(_normalizarArea)
          .where(
            (area) =>
                area['id_areas'] != 0,
          )
          .toList();

      print(
        '[PROVIDER ÁREAS] Total normalizado: '
        '${_areas.length}',
      );

      for (final area in _areas) {
        print(
          '[PROVIDER ÁREAS] '
          '${area['id_areas']} - '
          '${area['nome_area']}',
        );

        try {
          // Guardamos apenas colunas que existem
          // atualmente na tabela SQLite "areas".
          final areaLocal =
              <String, dynamic>{
            'id_areas':
                area['id_areas'],
            'id_serviceline':
                area['id_serviceline'],
            'nome_area':
                area['nome_area'],
            'descricao_area':
                area['descricao_area'],
            'data_criacao':
                area['data_criacao'],
            'numero_consultores':
                area['numero_consultores'],
          };

          await _dbLocal.salvarRegisto(
            'areas',
            areaLocal,
          );
        } catch (erroCache) {
          // Um erro no SQLite não apaga os dados
          // que já foram recebidos da API.
          print(
            '[PROVIDER ÁREAS] '
            'Erro ao guardar no SQLite: '
            '$erroCache',
          );
        }
      }
    } catch (erroApi, stackTrace) {
      print(
        '[PROVIDER ÁREAS] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      print(
        '[PROVIDER ÁREAS] '
        'A carregar cache SQLite...',
      );

      try {
        final dadosLocais =
            await _dbLocal.listarTabela(
          'areas',
        );

        _areas = dadosLocais
            .map(_normalizarArea)
            .where(
              (area) =>
                  area['id_areas'] != 0,
            )
            .toList();

        print(
          '[PROVIDER ÁREAS] '
          'Recuperadas da cache: '
          '${_areas.length}',
        );
      } catch (erroLocal) {
        print(
          '[PROVIDER ÁREAS] '
          'Erro na cache local: '
          '$erroLocal',
        );

        _areas = [];
      }
    }
  }

  Map<String, dynamic> _normalizarArea(
    Map<String, dynamic> area,
  ) {
    return <String, dynamic>{
      'id_areas': int.tryParse(
            (
              area['id_areas'] ??
              area['id'] ??
              0
            ).toString(),
          ) ??
          0,

      'id_serviceline':
          area['id_serviceline'] == null
          ? null
          : int.tryParse(
              area['id_serviceline']
                  .toString(),
            ),

      'nome_area':
          area['nome_area']?.toString() ??
          area['nome']?.toString() ??
          'Área sem nome',

      'descricao_area':
          area['descricao_area']
                  ?.toString() ??
              area['descricao']
                  ?.toString() ??
              '',

      'data_criacao':
          area['data_criacao']
              ?.toString(),

      'numero_consultores':
          int.tryParse(
                (
                  area['numero_consultores'] ??
                  0
                ).toString(),
              ) ??
              0,

      'estado_area':
          area['estado_area']
                  ?.toString() ??
              'ATIVO',
    };
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  Future<void> _carregarDashboard(
    int userId,
  ) async {
    try {
      print(
        '========== DASHBOARD ==========',
      );
      print(
        '[DASHBOARD] Utilizador: $userId',
      );

      final dados =
          await _apiService.getDashboard(
        userId,
      );

      _dashboard =
          Map<String, dynamic>.from(
        dados,
      );

      print(
        '[DASHBOARD] Resposta: $_dashboard',
      );

      try {
        await _dbLocal.salvarRegisto(
          'consultor',
          {
            'id_utilizador': userId,

            'id_areas':
                _dashboard['id_areas'],

            'pontos_atuais':
                int.tryParse(
                      (
                        _dashboard[
                              'total_pontos'
                            ] ??
                        _dashboard[
                              'pontos_atuais'
                            ] ??
                        0
                      ).toString(),
                    ) ??
                    0,

            'badges_conquistas_total':
                int.tryParse(
                      (
                        _dashboard[
                              'total_badges'
                            ] ??
                        _dashboard[
                              'badges_conquistas_total'
                            ] ??
                        0
                      ).toString(),
                    ) ??
                    0,

            'progresso_nivel':
                _dashboard['ranking'] ??
                _dashboard[
                  'progresso_nivel'
                ] ??
                'N/A',

            'ultima_atualizacao_perfil':
                DateTime.now()
                    .toString(),
          },
        );
      } catch (erroCache) {
        print(
          '[DASHBOARD] '
          'Erro ao guardar cache: '
          '$erroCache',
        );
      }
    } catch (erroApi, stackTrace) {
      print(
        '[DASHBOARD] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      try {
        final dadosLocais =
            await _dbLocal.listarTabela(
          'consultor',
        );

        if (dadosLocais.isNotEmpty) {
          final meuConsultor =
              dadosLocais.firstWhere(
            (consultor) =>
                consultor[
                      'id_utilizador'
                    ].toString() ==
                userId.toString(),
            orElse: () =>
                dadosLocais.first,
          );

          _dashboard = {
            'total_pontos':
                meuConsultor[
                      'pontos_atuais'
                    ] ??
                0,

            'total_badges':
                meuConsultor[
                      'badges_conquistas_total'
                    ] ??
                0,

            'ranking':
                meuConsultor[
                      'progresso_nivel'
                    ] ??
                'N/A',

            'id_areas':
                meuConsultor[
                  'id_areas'
                ],

            'offline': true,
          };
        }
      } catch (erroLocal) {
        print(
          '[DASHBOARD] '
          'Erro na cache local: '
          '$erroLocal',
        );

        _dashboard = {};
      }
    }
  }

  // =====================================================
  // BADGES EM PROGRESSO
  // =====================================================

  Future<void> _carregarBadgesProgresso(
    int userId,
  ) async {
    try {
      print(
        '========== BADGES EM PROGRESSO ==========',
      );

      final resultado =
          await _apiService
              .getBadgesProgresso(
        userId,
      );

      _badgesProgresso =
          List<Map<String, dynamic>>.from(
        resultado,
      );

      print(
        '[PROGRESSO] Total recebido: '
        '${_badgesProgresso.length}',
      );

      for (
        final badge in _badgesProgresso
      ) {
        try {
          await _dbLocal.salvarRegisto(
            'badge_atribuido',
            {
              'id_badge_atribuido':
                  int.tryParse(
                        (
                          badge[
                                'id_badge_atribuido'
                              ] ??
                          badge['id'] ??
                          0
                        ).toString(),
                      ) ??
                      0,

              'id_badge_modelo':
                  int.tryParse(
                        (
                          badge[
                                'id_badge_modelo'
                              ] ??
                          badge[
                                'id_modelo'
                              ] ??
                          badge['badge_id'] ??
                          0
                        ).toString(),
                      ) ??
                      0,

              'data_atribuicao':
                  badge[
                        'data_atribuicao'
                      ]?.toString(),

              'data_validade':
                  badge[
                        'data_validade'
                      ]?.toString(),

              'estado_badge_atribuido':
                  badge[
                        'estado_badge_atribuido'
                      ] ??
                  'Em Progresso',
            },
          );
        } catch (erroCache) {
          print(
            '[PROGRESSO] '
            'Erro ao guardar na cache: '
            '$erroCache',
          );
        }
      }
    } catch (erroApi, stackTrace) {
      print(
        '[PROGRESSO] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      try {
        final dadosLocais =
            await _dbLocal.listarTabela(
          'badge_atribuido',
        );

        _badgesProgresso =
            List<Map<String, dynamic>>.from(
          dadosLocais,
        );
      } catch (erroLocal) {
        print(
          '[PROGRESSO] '
          'Erro na cache local: '
          '$erroLocal',
        );

        _badgesProgresso = [];
      }
    }
  }

  // =====================================================
  // BADGES CONQUISTADOS
  // =====================================================

  Future<void> _carregarBadgesConquistados(
    int userId,
  ) async {
    try {
      print(
        '========== BADGES CONQUISTADOS ==========',
      );
      print(
        '[CONQUISTADOS] '
        'Utilizador: $userId',
      );

      final resultado =
          await _apiService
              .getBadgesConquistados(
        userId,
      );

      _badgesConquistados =
          List<Map<String, dynamic>>.from(
        resultado,
      );

      print(
        '[CONQUISTADOS] Total recebido: '
        '${_badgesConquistados.length}',
      );

      for (
        final badge
            in _badgesConquistados
      ) {
        print(
          '[CONQUISTADOS] '
          'ID: '
          '${badge['id'] ?? badge['id_badge_modelo']}'
          ' | Nome: '
          '${badge['nome'] ?? badge['nome_badge']}'
          ' | Imagem: '
          '${badge['imagem'] ?? badge['imagem_url']}',
        );
      }
    } catch (erroApi, stackTrace) {
      print(
        '[CONQUISTADOS] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      // Ainda não existe uma tabela SQLite completa
      // com o nome, descrição e imagem dos badges
      // conquistados. Por isso, neste momento,
      // o fallback fica vazio.
      _badgesConquistados = [];
    }
  }

  // =====================================================
  // BADGES RECOMENDADOS
  // =====================================================

  Future<void> _carregarBadgesRecomendados(
    int userId,
  ) async {
    try {
      print(
        '========== BADGES RECOMENDADOS ==========',
      );

      final resultado =
          await _apiService
              .getBadgesRecomendados(
        userId,
      );

      _badgesRecomendados =
          List<Map<String, dynamic>>.from(
        resultado,
      );

      print(
        '[RECOMENDADOS] Total recebido: '
        '${_badgesRecomendados.length}',
      );
    } catch (erroApi, stackTrace) {
      print(
        '[RECOMENDADOS] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      _badgesRecomendados = [];
    }
  }

  // =====================================================
  // UTILIZADORES
  // =====================================================

  Future<void> _carregarUtilizadores() async {
    try {
      final dadosRaw =
          await _apiService
              .getUtilizadores();

      _utilizadores =
          List<Map<String, dynamic>>.from(
        dadosRaw,
      );

      for (
        final user in _utilizadores
      ) {
        final userLocal =
            <String, dynamic>{
          'id_utilizador':
              int.tryParse(
                    (
                      user[
                            'id_utilizador'
                          ] ??
                      user['id'] ??
                      0
                    ).toString(),
                  ) ??
                  0,

          'nome_completo':
              user['nome_completo'] ??
              user['nome'] ??
              '',

          'email':
              user['email'] ?? '',

          'contacto':
              user['contacto'] ?? '',

          'estado_conta':
              user['estado_conta'] ??
              'Ativo',

          'password':
              user['password'] ?? '',

          'aceitou_termos':
              (
                user['aceitou_termos'] ==
                        true ||
                    user['aceitou_termos'] ==
                        1 ||
                    user[
                          'aceitar_termos'
                        ] ==
                        1
              )
              ? 1
              : 0,
        };

        try {
          await _dbLocal.salvarRegisto(
            'utilizador',
            userLocal,
          );
        } catch (erroCache) {
          print(
            '[UTILIZADORES] '
            'Erro ao guardar na cache: '
            '$erroCache',
          );
        }
      }
    } catch (erroApi, stackTrace) {
      print(
        '[UTILIZADORES] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      try {
        _utilizadores =
            await _dbLocal.listarTabela(
          'utilizador',
        );
      } catch (erroLocal) {
        print(
          '[UTILIZADORES] '
          'Erro na cache local: '
          '$erroLocal',
        );

        _utilizadores = [];
      }
    }
  }

  // =====================================================
  // ATUALIZAR DASHBOARD POR SWIPE
  // =====================================================

  Future<void> atualizarDashboard(
    int userId,
  ) async {
    print(
      '========== ATUALIZAR DASHBOARD ==========',
    );

    try {
      await _carregarDashboard(
        userId,
      );

      await _carregarBadgesProgresso(
        userId,
      );

      await _carregarBadgesConquistados(
        userId,
      );

      await _carregarBadgesRecomendados(
        userId,
      );

      notifyListeners();

      print(
        '[REFRESH] Dashboard atualizado',
      );
      print(
        '[REFRESH] Progresso: '
        '${_badgesProgresso.length}',
      );
      print(
        '[REFRESH] Conquistados: '
        '${_badgesConquistados.length}',
      );
      print(
        '[REFRESH] Recomendados: '
        '${_badgesRecomendados.length}',
      );
    } catch (e, stackTrace) {
      print(
        '[REFRESH] Erro ao atualizar: '
        '$e',
      );
      print(stackTrace);
    }

    print(
      '==========================================',
    );
  }
}
