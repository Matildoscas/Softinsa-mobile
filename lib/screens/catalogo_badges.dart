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
import 'package:sqflite/sqflite.dart';
// Serviço responsável pelos pedidos ao backend.
import '../services/api_service.dart';
// Serviço SQLite disponível para cache local.
import '../database/basededados.dart'; // Import central para a cache local
import 'catalogo_badges_utilizador.dart';
import 'informacoes_badge.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';

// =========================================================================
// OBTER NÍVEL
//
// Converte o ID numérico do nível para a respetiva letra:
// 1=A, 2=B, 3=C, 4=D e 5=E.
// Quando o valor não é válido, devolve "-".
// =========================================================================
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
class _CatalogoBadgesPageState extends State<CatalogoBadgesPage>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Chave de acesso ao SQLite local
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  Timer? _refreshTimer;
  bool _aAtualizarTempoReal = false;

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

    return BadgeBonusInfo(
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

  String _removerAcentos(String texto) {
    return texto
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Ä', 'A')
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ë', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ì', 'I')
        .replaceAll('Î', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ò', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ö', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ù', 'U')
        .replaceAll('Û', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C');
  }

  String _normalizarEstado(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) {
      return '';
    }

    return _removerAcentos(texto.toUpperCase()).replaceAll(' ', '_');
  }

  String _formatarEstadoHumano(String? valor) {
    final estado = _normalizarEstado(valor);
    if (estado.isEmpty) {
      return 'Sem estado';
    }

    const mapa = <String, String>{
      'EM_VALIDACAO_TM': 'Talent Manager a validar',
      'EM_VALIDACAO_SLL': 'Service Line Leader a validar',
      'AGUARDA_VALIDACAO_TM': 'A aguardar validação do Talent Manager',
      'AGUARDA_VALIDACAO_SLL': 'A aguardar validação do Service Line Leader',
      'AGUARDANDO_TM': 'A aguardar avaliação do Talent Manager',
      'AGUARDANDO_SLL': 'A aguardar avaliação do Service Line Leader',
      'EM_VALIDACAO': 'Em validação',
      'PENDENTE': 'Pendente',
      'APROVADO': 'Aprovado',
      'APROVADA': 'Aprovada',
      'APROVADO_FINAL': 'Aprovado em definitivo',
      'REJEITADO': 'Rejeitado',
      'REJEITADA': 'Rejeitada',
      'REJEITADO_TM': 'Candidatura rejeitada',
      'REJEITADO_SLL': 'Candidatura rejeitada',
      'RECUSADO': 'Recusado',
      'DESISTIDA': 'Desistida',
      'DESISTIDO': 'Desistida',
      'CANCELADO': 'Cancelado',
      'FINALIZADO': 'Concluído',
      'CONCLUIDO': 'Concluído',
      'HISTORICO': 'Concluído',
    };

    if (mapa.containsKey(estado)) {
      return mapa[estado]!;
    }

    final textoBase = (valor ?? estado).replaceAll('_', ' ').trim();
    if (textoBase.isEmpty) {
      return 'Sem estado';
    }

    return textoBase[0].toUpperCase() + textoBase.substring(1).toLowerCase();
  }

  Map<String, Color> _coresEstadoCandidatura(String? estado) {
    final valor = _normalizarEstado(estado);

    if (valor.contains('APROV')) {
      return {
        'fundo': const Color(0xFFDCFCE7),
        'texto': const Color(0xFF166534),
      };
    }

    if (valor.contains('REJEIT') || valor.contains('RECUS') || valor.contains('CANCEL') || valor.contains('DESIST')) {
      return {
        'fundo': const Color(0xFFFEE2E2),
        'texto': const Color(0xFF991B1B),
      };
    }

    if (valor.contains('AGUARDA') || valor.contains('PEND') || valor.contains('VALID')) {
      return {
        'fundo': const Color(0xFFFEF3C7),
        'texto': const Color(0xFF92400E),
      };
    }

    return {
      'fundo': const Color(0xFFE5E7EB),
      'texto': const Color(0xFF475569),
    };
  }

  Map<String, Color> _coresNivelBadge(int? idNivel) {
    switch (idNivel) {
      case 1:
        return {
          'fundo': const Color(0xFFEEF7FF),
          'borda': const Color(0xFFBFDBFE),
          'texto': const Color(0xFF1D4ED8),
        };
      case 2:
        return {
          'fundo': const Color(0xFFF0FDF4),
          'borda': const Color(0xFFBBF7D0),
          'texto': const Color(0xFF15803D),
        };
      case 3:
        return {
          'fundo': const Color(0xFFFFF7ED),
          'borda': const Color(0xFFFED7AA),
          'texto': const Color(0xFFC2410C),
        };
      case 4:
        return {
          'fundo': const Color(0xFFFAF5FF),
          'borda': const Color(0xFFE9D5FF),
          'texto': const Color(0xFF7E22CE),
        };
      case 5:
        return {
          'fundo': const Color(0xFFFFF8E1),
          'borda': const Color(0xFFF0D36B),
          'texto': const Color(0xFF9A6B00),
        };
      default:
        return {
          'fundo': const Color(0xFFEFF6FF),
          'borda': const Color(0xFFDBEAFE),
          'texto': const Color(0xFF4470AF),
        };
    }
  }

  Map<int, Map<String, dynamic>> _mapaStatusPorBadge(List<Map<String, dynamic>> lista) {
    final resultado = <int, Map<String, dynamic>>{};

    final ordenada = List<Map<String, dynamic>>.from(lista)
      ..sort((a, b) {
        final dataA = DateTime.tryParse(
              (a['data_submissao'] ?? a['data_submisao'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final dataB = DateTime.tryParse(
              (b['data_submissao'] ?? b['data_submisao'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return dataB.compareTo(dataA);
      });

    for (final item in ordenada) {
      final idBadge = int.tryParse((item['id_badge_modelo'] ?? item['id'] ?? '').toString()) ?? -1;
      if (idBadge <= 0 || resultado.containsKey(idBadge)) {
        continue;
      }

      resultado[idBadge] = item;
    }

    return resultado;
  }

  List<Map<String, dynamic>> todosBadges = [];
  List<Map<String, dynamic>> badgesFiltrados = [];
  bool isLoading = true;

  String pesquisa = '';
  String? filtroNivel;
  String? ordenacao;
  List<String> niveis = [];

  @override
    void initState() {
      super.initState();

      WidgetsBinding.instance.addObserver(this);

      carregarDados();

      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          _atualizarCatalogoEmTempoReal(
            origem: 'push_foreground',
          );
        },
      );

      _onMessageOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          _atualizarCatalogoEmTempoReal(
            origem: 'push_aberta',
          );
        },
      );

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((message) {
        if (message != null) {
          _atualizarCatalogoEmTempoReal(
            origem: 'push_inicial',
          );
        }
      });

      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) {
          _atualizarCatalogoEmTempoReal(
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
      _atualizarCatalogoEmTempoReal(
        origem: 'app_resumed',
      );
    }
  }

  Future<void> _atualizarCatalogoEmTempoReal({
    required String origem,
  }) async {
    if (_aAtualizarTempoReal || !mounted) {
      return;
    }

    try {
      _aAtualizarTempoReal = true;

      debugPrint(
        '[TEMPO REAL CATÁLOGO] Atualizar por: $origem',
      );

      await carregarDados();
    } catch (e) {
      debugPrint(
        '[TEMPO REAL CATÁLOGO] Erro: $e',
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
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    final int userId =
        int.tryParse(widget.userData['id_utilizador']?.toString() ?? '') ?? 0;

    List<Map<String, dynamic>> todos = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> obtidos = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> pendentes = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> statusCandidaturas = <Map<String, dynamic>>[];

    try {
      try {
        todos = await _apiService.getTodosBadges();
        obtidos = await _apiService.getBadgesConquistados(userId);
        statusCandidaturas = await _apiService.getStatusCandidaturasConsultor(userId);
        pendentes = await _apiService.getCandidaturasPendentes(userId);

        await _guardarCatalogoCache(todos);
        await _guardarBadgesUtilizadorCache(userId, obtidos);
        await _guardarStatusCandidaturasCache(userId, statusCandidaturas);
      } catch (e) {
        debugPrint('Modo offline no catálogo: $e');
        todos = await _carregarCatalogoDoCache();
        obtidos = await _carregarBadgesUtilizadorDoCache(userId);
        statusCandidaturas = await _carregarStatusCandidaturasCache(userId);
        pendentes = List<Map<String, dynamic>>.from(statusCandidaturas);
      }

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

    final Map<int, Map<String, dynamic>> mapaStatus =
        _mapaStatusPorBadge(statusCandidaturas);

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

        final Map<String, dynamic>?
          candidaturaStatus =
          mapaStatus[id] ?? candidaturaPendente;

        final String estadoBrutoCandidatura =
          candidaturaStatus?['estado_geral']?.toString() ??
          candidaturaStatus?['estado_final']?.toString() ??
          candidaturaStatus?['estado_validacao']?.toString() ??
          candidaturaStatus?['estado_candidatura_pedido']?.toString() ??
          '';

        final String estadoNormalizado =
          _normalizarEstado(estadoBrutoCandidatura);

        final bool candidaturaEmValidacao =
          estadoNormalizado.contains('AGUARDA') ||
          estadoNormalizado.contains('PEND') ||
          estadoNormalizado.contains('VALID') ||
          estadoNormalizado.contains('EM_VALIDACAO');

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
        'id_nivel': _resolverIdNivelBadge(badge),

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
          candidaturaStatus != null && candidaturaEmValidacao,

        'tem_candidatura':
          candidaturaStatus != null,

        'estado_candidatura':
          estadoBrutoCandidatura,

        'fase_candidatura':
          candidaturaStatus?['fase_geral']?.toString(),

        'estado_validacao':
          _formatarEstadoHumano(
            estadoBrutoCandidatura,
          ),

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

          var lista = todosBadges.where((b) {
            final matchPesquisa = pesquisa.isEmpty ||
                (b['nome'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(pesquisa.toLowerCase()) ||
                (b['descricao'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(pesquisa.toLowerCase());

            final matchNivel =
                filtroNivel == null ||
                obterNivel(b['id_nivel']) == filtroNivel;

            return matchPesquisa && matchNivel;
          }).toList();

          if (ordenacao == 'az') {
            lista.sort(
              (a, b) => (a['nome'] ?? '')
                  .toString()
                  .compareTo(
                    (b['nome'] ?? '').toString(),
                  ),
            );
          } else if (ordenacao == 'za') {
            lista.sort(
              (a, b) => (b['nome'] ?? '')
                  .toString()
                  .compareTo(
                    (a['nome'] ?? '').toString(),
                  ),
            );
          }

          badgesFiltrados = lista;
        });
      }
    } catch (e) {
      debugPrint('Erro inesperado no catálogo: $e');
      if (mounted) {
        setState(() {
          todosBadges = <Map<String, dynamic>>[];
          badgesFiltrados = <Map<String, dynamic>>[];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
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

  Future<void> _ensureTabelaStatusCandidaturasCache() async {
    final db = await _dbLocal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_status_candidaturas (
        id_utilizador INTEGER,
        id_candidatura_pedido INTEGER,
        id_badge_modelo INTEGER,
        estado_geral TEXT,
        fase_geral TEXT,
        estado_final TEXT,
        estado_candidatura_pedido TEXT,
        data_submissao TEXT,
        PRIMARY KEY (id_utilizador, id_candidatura_pedido, id_badge_modelo)
      )
    ''');
  }

  Future<void> _guardarStatusCandidaturasCache(
    int userId,
    List<Map<String, dynamic>> candidaturas,
  ) async {
    await _ensureTabelaStatusCandidaturasCache();
    final db = await _dbLocal.database;

    await db.delete(
      'cache_status_candidaturas',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
    );

    for (int idx = 0; idx < candidaturas.length; idx++) {
      final c = candidaturas[idx];

      final idBadge = int.tryParse((c['id_badge_modelo'] ?? c['id'] ?? 0).toString()) ?? 0;
      if (idBadge <= 0) {
        continue;
      }

      final idCandidatura = int.tryParse((c['id_candidatura_pedido'] ?? '').toString()) ?? (idx + 1);

      await db.insert(
        'cache_status_candidaturas',
        {
          'id_utilizador': userId,
          'id_candidatura_pedido': idCandidatura,
          'id_badge_modelo': idBadge,
          'estado_geral': c['estado_geral']?.toString() ?? c['estado_validacao']?.toString(),
          'fase_geral': c['fase_geral']?.toString(),
          'estado_final': c['estado_final']?.toString(),
          'estado_candidatura_pedido': c['estado_candidatura_pedido']?.toString(),
          'data_submissao': c['data_submissao']?.toString() ?? c['data_submisao']?.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarStatusCandidaturasCache(int userId) async {
    await _ensureTabelaStatusCandidaturasCache();
    final db = await _dbLocal.database;

    final rows = await db.query(
      'cache_status_candidaturas',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
      orderBy: 'data_submissao DESC',
    );

    return rows.map((row) {
      return <String, dynamic>{
        'id_candidatura_pedido': row['id_candidatura_pedido'],
        'id_badge_modelo': row['id_badge_modelo'],
        'id': row['id_badge_modelo'],
        'estado_geral': row['estado_geral'],
        'fase_geral': row['fase_geral'],
        'estado_final': row['estado_final'],
        'estado_candidatura_pedido': row['estado_candidatura_pedido'],
        'data_submissao': row['data_submissao'],
        'offline': true,
      };
    }).toList();
  }

  Future<void> _guardarCatalogoCache(List<Map<String, dynamic>> todos) async {
    for (final badge in todos) {
      final idBadgeModelo =
          int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? 0).toString()) ?? 0;
      if (idBadgeModelo == 0) {
        continue;
      }

      await _dbLocal.salvarRegisto('badge_modelo', {
        'id_badge_modelo': idBadgeModelo,
        'id_serviceline': int.tryParse((badge['id_serviceline'] ?? 0).toString()),
        'id_areas': int.tryParse((badge['id_areas'] ?? 0).toString()),
        'id_nivel': _resolverIdNivelBadge(badge),
        'id_utilizador': null,
        'nome_badge': badge['nome_badge'] ?? badge['nome'] ?? 'Badge',
        'descricao_badge_modelo': badge['descricao_badge_modelo'] ?? badge['descricao'] ?? '',
        'data_criacao_badge_modelo': badge['data_criacao_badge_modelo']?.toString(),
        'estado_badge_modelo': badge['estado_badge_modelo'] ?? 'ATIVO',
        'numero_requisitos': int.tryParse((badge['numero_requisitos'] ?? 0).toString()) ?? 0,
        'pontos': int.tryParse((badge['pontos'] ?? 0).toString()) ?? 0,
        'tempo_expiracao': badge['tempo_expiracao']?.toString(),
        'tipo_badge': badge['tipo_badge'] ?? badge['tipo']?.toString(),
        'imagem_url': badge['imagem_url'] ?? badge['imagem']?.toString() ?? badge['url_imagem']?.toString(),
        'imagem': null,
      });

      final requisitosBadge = badge['requisitos'];
      if (requisitosBadge is List) {
        for (int idx = 0; idx < requisitosBadge.length; idx++) {
          final req = requisitosBadge[idx];
          if (req is! Map) {
            continue;
          }

          final mapaReq = Map<String, dynamic>.from(req);

          final int idReq = int.tryParse(
                (mapaReq['id_requisitos'] ?? mapaReq['id_requisito'] ?? '').toString(),
              ) ??
              (idBadgeModelo * 1000 + idx + 1);

          await _dbLocal.salvarRegisto('requisitos', {
            'id_requisitos': idReq,
            'id_badge_modelo': idBadgeModelo,
            'id_utilizador': null,
            'nome_requisito': mapaReq['nome_requisito'] ?? mapaReq['nome'] ?? mapaReq['titulo'] ?? 'Requisito',
            'titulo': mapaReq['titulo'] ?? mapaReq['nome_requisito'] ?? mapaReq['nome'] ?? 'Requisito',
            'descricao_requisito': mapaReq['descricao_requisito'] ?? mapaReq['descricao'] ?? '',
            'tipo_requisito': mapaReq['tipo_requisito']?.toString(),
          });
        }
      }
    }
  }

  Future<void> _guardarBadgesUtilizadorCache(
    int userId,
    List<Map<String, dynamic>> badges,
  ) async {
    await _ensureTabelaCacheBadgesUtilizador();
    final db = await _dbLocal.database;

    for (final badge in badges) {
      final idBadgeModelo =
          int.tryParse((badge['id_badge_modelo'] ?? badge['id'] ?? badge['badge_id'] ?? 0).toString()) ?? 0;
      if (idBadgeModelo == 0) {
        continue;
      }

      final idBadgeAtribuido =
          int.tryParse((badge['id_badge_atribuido'] ?? badge['id'] ?? idBadgeModelo).toString()) ?? idBadgeModelo;

      final pontosExtra =
          int.tryParse((badge['pontos_extra'] ?? badge['pontos_bonus'] ?? 0).toString()) ?? 0;

      final ganhouBonus =
          ((badge['ganhou_bonus'] == true) || (badge['premio_atribuido'] == true) || pontosExtra > 0) ? 1 : 0;

      await _dbLocal.salvarRegisto('badge_atribuido', {
        'id_badge_atribuido': idBadgeAtribuido,
        'id_badge_modelo': idBadgeModelo,
        'data_atribuicao': badge['data_atribuicao']?.toString(),
        'data_validade': badge['data_validade']?.toString(),
        'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? 'Conquistado',
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
          'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? 'Conquistado',
          'data_atribuicao': badge['data_atribuicao']?.toString(),
          'data_validade': badge['data_validade']?.toString(),
          'tipo_badge': badge['tipo_badge'] ?? badge['tipo']?.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> _carregarCatalogoDoCache() async {
    final dados = await _dbLocal.listarTabela('badge_modelo');
    return dados.map((e) {
      return <String, dynamic>{
        'id': e['id_badge_modelo'],
        'id_badge_modelo': e['id_badge_modelo'],
        'id_nivel': e['id_nivel'],
        'nome': e['nome_badge'] ?? 'Badge',
        'nome_badge': e['nome_badge'] ?? 'Badge',
        'descricao': e['descricao_badge_modelo'] ?? '',
        'descricao_badge_modelo': e['descricao_badge_modelo'] ?? '',
        'pontos': e['pontos'] ?? 0,
        'imagem_url': e['imagem_url'] ?? e['imagem'],
        'imagem': e['imagem_url'] ?? e['imagem'],
        'tipo_badge': e['tipo_badge'],
        'offline': true,
      };
    }).toList();
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

  // =========================================================================
  // EXTRAIR NÍVEIS
  //
  // Lê os níveis existentes, remove inválidos e duplicados com toSet(),
  // converte novamente para lista e ordena alfabeticamente.
  // =========================================================================
  void _extrairNiveis() {
    niveis = todosBadges
        .map((b) => obterNivel(_resolverIdNivelBadge(b)))
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
      final matchNivel = filtroNivel == null || obterNivel(_resolverIdNivelBadge(b)) == filtroNivel;
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

    final int? idNivelBadge =
        _resolverIdNivelBadge(
      badge,
    );

    final Map<String, Color> coresNivel =
        _coresNivelBadge(
      idNivelBadge,
    );

    final bool temCandidatura =
        badge['tem_candidatura'] == true;

    final String estadoCandidatura =
        badge['estado_candidatura']?.toString() ??
        badge['estado_validacao']?.toString() ??
        '';

    final Map<String, Color> coresEstado =
        _coresEstadoCandidatura(
      estadoCandidatura,
    );

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
    } else if (temCandidatura) {
      estadoTexto =
        badge['estado_validacao']?.toString().trim().isNotEmpty == true
          ? badge['estado_validacao'].toString()
          : _formatarEstadoHumano(estadoCandidatura);

      estadoCor =
        coresEstado['texto'] ??
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
                              : (coresNivel['fundo'] ?? const Color(0xFFEFF6FF)),

                          border:
                              Border.all(
                            color: bonusAtivo
                                ? dourado
                              : (coresNivel['borda'] ?? const Color(0xFFDBEAFE)),

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
                        temCandidatura &&
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
                              BoxDecoration(
                              color:
                                coresEstado['texto'] ?? Colors.amber,
                              shape:
                                BoxShape.circle,
                            ),
                            child:
                              Icon(
                              emValidacao
                                ? Icons.hourglass_bottom
                                : Icons.info_outline,
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
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration:
                                BoxDecoration(
                              color: bonusAtivo
                                  ? douradoClaro
                                  : (coresNivel['fundo'] ?? const Color(0xFFEAF0FA)),
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
                                fontSize: 10,
                                color: bonusAtivo
                                    ? douradoEscuro
                                    : (coresNivel['texto'] ?? const Color(0xFF4470AF)),
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