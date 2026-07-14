// ============================================================================
// utilizador_provider.dart
//
// Este ficheiro representa a camada de ESTADO GLOBAL da aplicação.
//
// O UtilizadorProvider:
// - Guarda dados que são utilizados por vários ecrãs;
// - Comunica com a API através de ApiService;
// - Guarda cópias locais no SQLite através de Basededados;
// - Usa a API como fonte principal;
// - Usa o SQLite como fallback quando não existe ligação;
// - Avisa os widgets quando os dados mudam através de notifyListeners().
//
// O Provider estende ChangeNotifier. Por isso, qualquer widget que esteja a
// observar este Provider pode ser reconstruído quando notifyListeners() é
// chamado.
//
// Fluxo geral:
// API disponível  -> recebe dados -> atualiza o estado -> guarda no SQLite.
// API indisponível -> tenta recuperar os dados anteriormente guardados no SQLite.
// ============================================================================

// Contém ChangeNotifier, usado para avisar a interface quando o estado muda.
import 'package:flutter/material.dart';

// Serviço responsável por fazer os pedidos HTTP ao backend.
import '../services/api_service.dart';
// Serviço responsável pela base de dados SQLite local.
import '../database/basededados.dart';

// ChangeNotifier permite que esta classe notifique os widgets
// sempre que alguma variável de estado for alterada.
class UtilizadorProvider with ChangeNotifier {
  // Instância privada utilizada para comunicar com a API REST.
  final ApiService _apiService = ApiService();
  // Instância privada utilizada para ler e escrever dados no SQLite.
  final Basededados _dbLocal = Basededados();

  // =====================================================
  // ESTADOS
  // =====================================================

  // Lista privada com os utilizadores carregados da API ou do SQLite.
  List<Map<String, dynamic>> _utilizadores = [];

  // Lista privada com as áreas disponíveis para registo e perfil.
  List<Map<String, dynamic>> _areas = [];

  // Objeto privado com os totais e dados apresentados no dashboard.
  Map<String, dynamic> _dashboard = {};

  // Badges que o utilizador ainda está a desenvolver.
  List<Map<String, dynamic>> _badgesProgresso = [];

  // Badges que já foram conquistados pelo utilizador.
  List<Map<String, dynamic>> _badgesConquistados = [];

  // Badges sugeridos pela aplicação para o utilizador.
  List<Map<String, dynamic>> _badgesRecomendados = [];

  List<Map<String, dynamic>> _learningPaths = [];

  // Controla a apresentação de indicadores de carregamento na interface.
  bool _estaA_Carregar = false;

  // =====================================================
  // GETTERS
  //
  // Os estados são privados, por isso começam por "_".
  // Estes getters permitem que os ecrãs consultem os dados,
  // mas impedem que os alterem diretamente.
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

  List<Map<String, dynamic>> get learningPaths =>
    _learningPaths;

  bool get estaA_Carregar =>
      _estaA_Carregar;

  // =====================================================
  // CARREGAR ÁREAS ANTES DO REGISTO
  // =====================================================

  // =========================================================================
  // CARREGAR ÁREAS
  //
  // Utilizado antes do registo, quando ainda não existe utilizador autenticado.
  // Ativa o estado de carregamento, tenta sincronizar as áreas e, no fim,
  // desativa o carregamento mesmo que ocorra um erro.
  //
  // O bloco finally é sempre executado.
  // =========================================================================
  Future<void> carregarAreas() async {
    // Informa a interface de que começou uma operação demorada.
    _estaA_Carregar = true;

    // Reconstrói os widgets que estão a observar este Provider.
    notifyListeners();

    print(
      '========== PROVIDER: CARREGAR ÁREAS ==========',
    );

    try {
      await _sincronizarAreas();
    } finally {
      // Este bloco é executado com sucesso ou com erro.
      // Garante que o indicador de carregamento é sempre desligado.
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

  // =========================================================================
  // INICIALIZAR TODOS OS DADOS
  //
  // Executado normalmente depois de um login bem-sucedido.
  // Carrega, por esta ordem:
  // 1. Áreas;
  // 2. Dashboard;
  // 3. Badges em progresso;
  // 4. Badges conquistados;
  // 5. Badges recomendados;
  // 6. Utilizadores.
  //
  // userId identifica o utilizador cujos dados devem ser carregados.
  // =========================================================================
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
      // As operações são aguardadas sequencialmente para manter
      // uma ordem previsível de carregamento.
      await _sincronizarAreas();

      await _carregarDashboard(userId);

      await _carregarLearningPaths(
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

  // =========================================================================
  // SINCRONIZAR ÁREAS
  //
  // Método privado, indicado pelo "_".
  //
  // Estratégia:
  // - Primeiro tenta obter as áreas através da API;
  // - Normaliza os nomes e tipos dos campos;
  // - Atualiza a lista _areas;
  // - Guarda cada área no SQLite;
  // - Se a API falhar, tenta recuperar as áreas do SQLite.
  // =========================================================================
  Future<void> _sincronizarAreas() async {
    try {
      // Fonte principal: backend REST.
      final dadosAreasRaw =
          await _apiService.getAreas();

      print(
        '[PROVIDER ÁREAS] Total recebido da API: '
        '${dadosAreasRaw.length}',
      );

      // Normaliza todas as áreas e elimina registos com ID inválido.
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
          // Cria um Map contendo apenas as colunas que existem
          // efetivamente na tabela local "areas".
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

          // salvarRegisto realiza o insert/update do registo local.
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
        // Fallback offline: SELECT * da tabela local "areas".
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

  // =========================================================================
  // NORMALIZAR ÁREA
  //
  // A API e o SQLite podem utilizar nomes ou tipos ligeiramente diferentes.
  // Esta função converte qualquer área recebida para uma estrutura uniforme.
  //
  // Exemplos:
  // - "id" ou "id_areas" passam a ser sempre "id_areas";
  // - "nome" ou "nome_area" passam a ser sempre "nome_area";
  // - números recebidos como String são convertidos para int;
  // - campos ausentes recebem valores por defeito.
  //
  // Esta função não faz pedidos nem altera o estado global.
  // Apenas recebe um Map e devolve outro Map normalizado.
  // =========================================================================
  Map<String, dynamic> _normalizarArea(
    Map<String, dynamic> area,
  ) {
    // É devolvido um novo Map para não alterar diretamente o Map original.
    return <String, dynamic>{
      // Tenta primeiro "id_areas"; se não existir, tenta "id".
      // tryParse evita uma exceção caso o valor não seja numérico.
      'id_areas': int.tryParse(
            (
              area['id_areas'] ??
              area['id'] ??
              0
            ).toString(),
          ) ??
          0,

      // Mantém null quando não existe service line.
      'id_serviceline':
          area['id_serviceline'] == null
          ? null
          : int.tryParse(
              area['id_serviceline']
                  .toString(),
            ),

      // Aceita os nomes "nome_area" e "nome".
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

      // Quando a API não devolve estado, assume "ATIVO".
      'estado_area':
          area['estado_area']
                  ?.toString() ??
              'ATIVO',
    };
  }

  // =====================================================
  // DASHBOARD
  // =====================================================

  // =========================================================================
  // CARREGAR DASHBOARD
  //
  // Tenta obter o dashboard através da API.
  // Quando tem sucesso:
  // - atualiza _dashboard;
  // - guarda os principais valores na tabela "consultor" do SQLite.
  //
  // Quando a API falha:
  // - procura o consultor no SQLite;
  // - reconstrói um dashboard simplificado;
  // - acrescenta "offline": true para indicar que os dados são locais.
  // =========================================================================
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

      // Obtém os dados online do utilizador.
      final dados =
          await _apiService.getDashboard(
        userId,
      );

      // Cria uma cópia tipada dos dados recebidos.
      _dashboard =
          Map<String, dynamic>.from(
        dados,
      );

      print(
        '[DASHBOARD] Resposta: $_dashboard',
      );

      try {
        // Guarda no SQLite apenas os campos necessários para
        // reconstruir o dashboard em modo offline.
        await _dbLocal.salvarRegisto(
          'consultor',
          {
            'id_utilizador': userId,

            'id_areas':
                _dashboard['id_areas'],

            // A API pode chamar ao campo "total_pontos" ou "pontos_atuais".
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

            // A API pode chamar ao campo "total_badges"
            // ou "badges_conquistas_total".
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
        // Quando a API falha, procura os dados na tabela "consultor".
        final dadosLocais =
            await _dbLocal.listarTabela(
          'consultor',
        );

        if (dadosLocais.isNotEmpty) {
          // Procura o registo correspondente ao utilizador atual.
          // Se não encontrar, utiliza o primeiro registo disponível.
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

          // Reconstrói a estrutura que os widgets esperam receber.
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
  // LEARNING PATHS
  // =====================================================

  Future<void> _carregarLearningPaths(
    int userId,
  ) async {
    try {
      print(
        '========== LEARNING PATHS DASHBOARD ==========',
      );

      final resultado =
          await _apiService
              .getProgressoLearningPaths(
        userId,
      );

      _learningPaths =
          List<Map<String, dynamic>>.from(
        resultado,
      );

      print(
        '[LEARNING PATHS] Total recebido: '
        '${_learningPaths.length}',
      );

      for (final lp in _learningPaths) {
        try {
          await _dbLocal.salvarRegisto(
            'learningpaths',
            {
              'id_learningpaths':
                  int.tryParse(
                        (
                          lp['id_learningpaths'] ??
                          lp['id_learningpath'] ??
                          lp['id'] ??
                          0
                        ).toString(),
                      ) ??
                      0,

              'nome_learningpaths':
                  lp['nome_learningpath'] ??
                  lp['nome_learningpaths'] ??
                  lp['nome'] ??
                  'Learning Path',

              'numero_servicelines':
                  int.tryParse(
                        (
                          lp['total_badges'] ??
                          lp['numero_badges'] ??
                          lp['badges_total'] ??
                          lp['total'] ??
                          0
                        ).toString(),
                      ) ??
                      0,
            },
          );
        } catch (erroCache) {
          print(
            '[LEARNING PATHS] '
            'Erro ao guardar na cache: '
            '$erroCache',
          );
        }
      }
    } catch (erroApi, stackTrace) {
      print(
        '[LEARNING PATHS] Erro na API: '
        '$erroApi',
      );
      print(stackTrace);

      try {
        final dadosLocais =
            await _dbLocal.listarTabela(
          'learningpaths',
        );

        _learningPaths =
            dadosLocais.map(
          (lp) {
            return <String, dynamic>{
              'id_learningpaths':
                  lp['id_learningpaths'],

              'id_learningpath':
                  lp['id_learningpaths'],

              'nome_learningpath':
                  lp['nome_learningpaths'] ??
                  'Learning Path',

              'nome_learningpaths':
                  lp['nome_learningpaths'] ??
                  'Learning Path',

              'total_badges':
                  lp['numero_servicelines'] ??
                  0,

              'badges_conquistados':
                  0,

              'percentagem':
                  0,
            };
          },
        ).toList();
      } catch (erroLocal) {
        print(
          '[LEARNING PATHS] '
          'Erro na cache local: '
          '$erroLocal',
        );

        _learningPaths = [];
      }
    }
  }

  // =====================================================
  // BADGES EM PROGRESSO
  // =====================================================

  // =========================================================================
  // CARREGAR BADGES EM PROGRESSO
  //
  // Obtém os badges em progresso através da API.
  // Depois guarda uma versão resumida de cada badge na tabela
  // "badge_atribuido" do SQLite.
  //
  // Se a API falhar, tenta utilizar os registos locais dessa tabela.
  // =========================================================================
  Future<void> _carregarBadgesProgresso(
    int userId,
  ) async {
    try {
      print(
        '========== BADGES EM PROGRESSO ==========',
      );

      // Pedido online dos badges que estão em desenvolvimento.
      final resultado =
          await _apiService
              .getBadgesProgresso(
        userId,
      );

      // Cria uma lista tipada e atualiza o estado global.
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
          // Guarda uma versão resumida do badge na cache local.
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
        // Fallback: utiliza os badges atribuídos existentes no SQLite.
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

  // =========================================================================
  // CARREGAR BADGES CONQUISTADOS
  //
  // Obtém através da API os badges já conquistados pelo utilizador.
  //
  // Neste momento não existe um fallback SQLite completo porque a tabela local
  // ainda não guarda todos os dados necessários, como nome, descrição e imagem.
  // Por isso, se a API falhar, a lista fica vazia.
  // =========================================================================
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

      // Pedido online dos badges já obtidos.
      final resultado =
          await _apiService
              .getBadgesConquistados(
        userId,
      );

      // Atualiza a lista observada pelos ecrãs.
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

  // =========================================================================
  // CARREGAR BADGES RECOMENDADOS
  //
  // Obtém sugestões de badges através da API.
  // Como ainda não existe cache local específica para estas recomendações,
  // a lista fica vazia quando o pedido falha.
  // =========================================================================
  Future<void> _carregarBadgesRecomendados(
    int userId,
  ) async {
    try {
      print(
        '========== BADGES RECOMENDADOS ==========',
      );

      // Pedido online das recomendações.
      final resultado =
          await _apiService
              .getBadgesRecomendados(
        userId,
      );

      // Atualiza o estado global com uma lista tipada.
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

  // =========================================================================
  // CARREGAR UTILIZADORES
  //
  // Obtém a lista de utilizadores através da API.
  // Para cada utilizador:
  // - normaliza o ID e os restantes campos;
  // - converte a aceitação dos termos para 0 ou 1;
  // - guarda o registo na tabela "utilizador" do SQLite.
  //
  // Se a API falhar, lê diretamente a lista guardada no SQLite.
  // =========================================================================
  Future<void> _carregarUtilizadores() async {
    try {
      // Obtém todos os utilizadores através da API.
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
        // Adapta os nomes e os tipos dos campos ao esquema SQLite.
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

          // SQLite não possui um tipo booleano próprio.
          // Por isso, true é guardado como 1 e false como 0.
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
          // Cria ou atualiza o utilizador na base de dados local.
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
        // Fallback offline: lê os utilizadores anteriormente guardados.
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

  // =========================================================================
  // ATUALIZAR DASHBOARD POR SWIPE
  //
  // Utilizado no pull-to-refresh da página principal.
  // Volta a carregar:
  // - dashboard;
  // - badges em progresso;
  // - badges conquistados;
  // - badges recomendados.
  //
  // No fim chama notifyListeners() para reconstruir os widgets que observam
  // este Provider.
  // =========================================================================
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

      await _carregarLearningPaths(
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

      // Apenas depois de todos os carregamentos estarem concluídos
      // é que os widgets são avisados.
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
      print(
        '[REFRESH] Learning Paths: '
        '${_learningPaths.length}',
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
