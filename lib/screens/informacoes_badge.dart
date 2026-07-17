// ============================================================================
// informacoes_badge.dart
//
// Página completa de detalhe de um badge.
// Mostra descrição, nível, requisitos, progresso, badges relacionados
// e botões para submeter evidências ou obter certificado.
// Carrega API primeiro e usa SQLite como fallback offline.
//
// A lógica original foi mantida.
// Os comentários explicam:
// - Responsabilidade de cada classe e função;
// - Fluxo entre API, SQLite e interface;
// - Pesquisa, filtros, navegação e estados;
// - Tratamento de imagens, ficheiros e modo offline.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import crucial para ler os requisitos offline
import 'submeter_badges.dart';
import 'certificado.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';

// Variável global que pode guardar uma notificação/objeto associado
// à disponibilidade de certificado para o badge atual.
Map<String, dynamic>? certificadoDisponivel;

// Converte o ID numérico do nível para a respetiva letra.
String obterNivel(dynamic idNivel) {
  switch (int.tryParse(idNivel.toString())) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

// Faz a conversão inversa: letra do nível para ID numérico.
int obterIdNivel(String letra) {
  switch (letra) {
    case 'A': return 1;
    case 'B': return 2;
    case 'C': return 3;
    case 'D': return 4;
    case 'E': return 5;
    default: return 1;
  }
}

// Devolve a cor visual de cada nível.
// A-D usam verde e E utiliza dourado.
Color obterCorNivel(String letraNivel) {
  switch (letraNivel) {
    case 'A':
    case 'B':
    case 'C':
    case 'D':
      return const Color(0xFF2E7D32); 
    case 'E':
      return const Color.fromARGB(255, 213, 181, 21); 
    default:
      return Colors.grey;
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

// Página de detalhe identificada por userId e badgeId.
class BadgeDetalhe extends StatefulWidget {
  final int userId;
  final int badgeId;

  const BadgeDetalhe({
    super.key,
    required this.userId,
    required this.badgeId,
  });

  @override
  State<BadgeDetalhe> createState() => _BadgeDetalheState();
}

// Guarda badge, progresso, relacionados, requisitos e estados visuais.
class _BadgeDetalheState extends State<BadgeDetalhe>
    with WidgetsBindingObserver {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local SQLite
  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  Timer? _refreshTimer;
  bool _aAtualizarTempoReal = false;

  Map<String, dynamic>? badge;
  Map<String, dynamic>? progresso;
  Map<String, dynamic>? candidaturaStatus;
  List<Map<String, dynamic>> badgesRelacionados = [];
  List<Map<String, dynamic>> requisitos = [];
  bool loading = true;
  bool descricaoExpandida = false;
  
  // Estado para controlar qual o nível que o utilizador está a inspecionar ativamente
  String nivelVisualizado = 'A';

  static const Color _azul = Color(0xFF4470AF);

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
    Map<String, dynamic> dados,
  ) {
    final int pontosExtra1 =
        _converterInteiro(
      dados['pontos_extra'],
    );

    final int pontosExtra2 =
        _converterInteiro(
      dados['pontos_bonus'],
    );

    final int pontosExtra =
        pontosExtra1 > pontosExtra2
            ? pontosExtra1
            : pontosExtra2;

    final bool ganhouBonus =
        _converterBooleano(
          dados['ganhou_bonus'],
        ) ||
        _converterBooleano(
          dados['premio_atribuido'],
        ) ||
        pontosExtra > 0;

    return _BadgeBonusInfo(
      ganhouBonus: ganhouBonus,
      pontosExtra: pontosExtra,
    );
  }

  String? _obterImagemBadge(
    Map<String, dynamic> dados,
  ) {
    final possibilidades = [
      dados['imagem_url'],
      dados['imagem'],
      dados['url_imagem'],
      dados['imagem_badge'],
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
        'texto': const Color(0xFF166534),
        'borda': const Color(0xFFBBF7D0),
      };
    }

    if (valor.contains('REJEIT') || valor.contains('RECUS') || valor.contains('CANCEL') || valor.contains('DESIST')) {
      return {
        'texto': const Color(0xFF991B1B),
        'borda': const Color(0xFFFECACA),
      };
    }

    if (valor.contains('AGUARDA') || valor.contains('PEND') || valor.contains('VALID')) {
      return {
        'texto': const Color(0xFF92400E),
        'borda': const Color(0xFFFDE68A),
      };
    }

    return {
      'texto': const Color(0xFF475569),
      'borda': const Color(0xFFCBD5E1),
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

    if (rows.isNotEmpty) {
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

    final fallbackPedido = await db.query(
      'candidatura_pedido',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
      orderBy: 'data_submisao DESC',
    );

    return fallbackPedido.map((row) {
      return <String, dynamic>{
        'id_candidatura_pedido': row['id_candidatura_pedido'],
        'id_badge_modelo': row['id_badge_modelo'],
        'id': row['id_badge_modelo'],
        'estado_geral': row['estado_candidatura_pedido'],
        'estado_candidatura_pedido': row['estado_candidatura_pedido'],
        'data_submissao': row['data_submisao'],
        'offline': true,
      };
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    carregar();

    _onMessageSubscription =
        FirebaseMessaging.onMessage.listen(
      (_) {
        _atualizarDetalheEmTempoReal(
          origem: 'push_foreground',
        );
      },
    );

    _onMessageOpenedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(
      (_) {
        _atualizarDetalheEmTempoReal(
          origem: 'push_aberta',
        );
      },
    );

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
      if (message != null) {
        _atualizarDetalheEmTempoReal(
          origem: 'push_inicial',
        );
      }
    });

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        _atualizarDetalheEmTempoReal(
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
      _atualizarDetalheEmTempoReal(
        origem: 'app_resumed',
      );
    }
  }

  Future<void> _atualizarDetalheEmTempoReal({
    required String origem,
  }) async {
    if (_aAtualizarTempoReal || !mounted) {
      return;
    }

    try {
      _aAtualizarTempoReal = true;

      debugPrint(
        '[TEMPO REAL DETALHE BADGE] Atualizar por: $origem',
      );

      await carregar();
    } catch (e) {
      debugPrint(
        '[TEMPO REAL DETALHE BADGE] Erro: $e',
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

  Future<void> _guardarCatalogoLocal(
    List<Map<String, dynamic>> badges,
  ) async {
    for (final badge in badges) {
      final idBadgeModelo =
          int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? 0).toString()) ?? 0;

      if (idBadgeModelo == 0) {
        continue;
      }

      await _dbLocal.salvarRegisto('badge_modelo', {
        'id_badge_modelo': idBadgeModelo,
        'id_serviceline': int.tryParse((badge['id_serviceline'] ?? 0).toString()),
        'id_areas': int.tryParse((badge['id_areas'] ?? 0).toString()),
        'id_nivel': int.tryParse((badge['id_nivel'] ?? 0).toString()),
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

  Future<List<Map<String, dynamic>>> _carregarConquistadosLocal() async {
    try {
      final db = await _dbLocal.database;
      final rows = await db.query(
        'cache_badges_utilizador',
        where: 'id_utilizador = ?',
        whereArgs: [widget.userId],
      );

      if (rows.isNotEmpty) {
        return rows.map((row) {
          return <String, dynamic>{
            'id': row['id_badge_modelo'],
            'id_badge_modelo': row['id_badge_modelo'],
            'id_badge_atribuido': row['id_badge_atribuido'],
            'data_atribuicao': row['data_atribuicao'],
            'pontos': row['pontos'] ?? 0,
            'ganhou_bonus': (row['ganhou_bonus'] ?? 0) == 1,
            'premio_atribuido': (row['premio_atribuido'] ?? 0) == 1,
            'pontos_extra': row['pontos_extra'] ?? 0,
            'pontos_bonus': row['pontos_extra'] ?? 0,
          };
        }).toList();
      }
    } catch (_) {}

    final localAtribuidos = await _dbLocal.listarTabela('badge_atribuido');

    return localAtribuidos
        .map(
          (e) => <String, dynamic>{
            'id': e['id_badge_modelo'],
            'id_badge_modelo': e['id_badge_modelo'],
            'data_atribuicao': e['data_atribuicao'],
            'ganhou_bonus': false,
            'premio_atribuido': false,
            'pontos_extra': 0,
            'pontos_bonus': 0,
          },
        )
        .toList();
  }

  // =========================================================================
  // CARREGAR DETALHE
  //
  // 1. Obtém catálogo e badges conquistados;
  // 2. Procura informação relacionada com certificado;
  // 3. Se falhar, lê badge_modelo e badge_atribuido no SQLite;
  // 4. Identifica o badge principal e o progresso do utilizador;
  // 5. Seleciona até cinco badges relacionados do mesmo nível;
  // 6. Atualiza o estado e carrega os requisitos.
  // =========================================================================
  Future<void> carregar() async {
    List<Map<String, dynamic>> todos = [];
    List<Map<String, dynamic>> obtidos = [];
    List<Map<String, dynamic>> statusCandidaturas = [];

    // Função local que aceita vários nomes possíveis para o ID do badge.
    int getId(Map b) => int.tryParse((b['id'] ?? b['id_badge_modelo'] ?? b['id_badge'] ?? '').toString()) ?? -1;

    try {
      // 1. Tenta carregar tudo em tempo real através do servidor (HTTP)
      todos = await _apiService.getTodosBadges();
      obtidos = await _apiService.getBadgesConquistados(widget.userId);
      statusCandidaturas = await _apiService.getStatusCandidaturasConsultor(widget.userId);
      await _guardarStatusCandidaturasCache(widget.userId, statusCandidaturas);

      await _guardarCatalogoLocal(todos);

      try {
        final notificacoes = await _apiService.getNotifications(widget.userId);
        certificadoDisponivel = notificacoes.firstWhere(
          (c) => c['id_badge_modelo'].toString() == widget.badgeId.toString(),
          orElse: () => <String, dynamic>{},
        );
        if (certificadoDisponivel?.isEmpty ?? true) certificadoDisponivel = null;
      } catch (_) {
        certificadoDisponivel = null;
      }

    } catch (e) {
      debugPrint("Modo Offline Ativo no Detalhe do Badge: Buscando no SQFlite... ($e)");
      
      // 2. FALLBACK: Carrega o modelo de cache local do SQLite se falhar a internet
      final localModelos = await _dbLocal.listarTabela('badge_modelo');

      todos = localModelos.map((e) => {
        'id': e['id_badge_modelo'],
        'id_badge_modelo': e['id_badge_modelo'],
        'nome': e['nome_badge'],
        'nome_badge': e['nome_badge'],
        'descricao': e['descricao_badge_modelo'],
        'descricao_badge_modelo': e['descricao_badge_modelo'],
        'pontos': e['pontos'],
        'id_nivel': e['id_nivel'],
        'tipo_badge': e['tipo_badge'],
        'imagem_url': e['imagem_url'] ?? e['imagem'],
        'imagem': e['imagem_url'] ?? e['imagem'],
      }).toList();

      obtidos = await _carregarConquistadosLocal();
      statusCandidaturas = await _carregarStatusCandidaturasCache(widget.userId);
    }

    // ── IDENTIFICAÇÃO DO BADGE PRINCIPAL ─────────────────────────────
    final badgeEncontrado = todos.firstWhere(
      (b) => getId(b) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    // Configura o nível visualizado inicial baseado no nível real do badge
    if (badgeEncontrado.isNotEmpty) {
      nivelVisualizado = obterNivel(badgeEncontrado['id_nivel']);
    }

    // ── PROGRESSO DO UTILIZADOR ─────────────────────
    final progressoEncontrado = obtidos.firstWhere(
      (b) => getId(b) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    final candidaturaStatusEncontrada = statusCandidaturas.firstWhere(
      (c) => getId(c) == widget.badgeId,
      orElse: () => <String, dynamic>{},
    );

    // ── BADGES RELACIONADOS ─────────────────────────
    final relacionados = todos
        .where((b) =>
            b['id_nivel']?.toString() == badgeEncontrado['id_nivel']?.toString() &&
            getId(b) != widget.badgeId)
        .take(5)
        .map((b) {
          final ob = obtidos.firstWhere(
            (o) => getId(o) == getId(b),
            orElse: () => <String, dynamic>{},
          );

          return {
            ...b,

            'conquistado':
                ob.isNotEmpty,

            'progress':
                ob['progress'] != null
                    ? double.tryParse(
                        ob['progress']
                            .toString(),
                      )
                    : null,

            'data_conquista':
                ob['data_atribuicao'] ??
                ob['data_conquista'],

            'data_atribuicao':
                ob['data_atribuicao'],

            /*
            * Dados do desafio.
            */
            'ganhou_bonus':
                ob['ganhou_bonus'],

            'premio_atribuido':
                ob['premio_atribuido'],

            'pontos_extra':
                ob['pontos_extra'],

            'pontos_bonus':
                ob['pontos_bonus'],
          };
        })
        .toList();

    if (mounted) {
      setState(() {
        badge = badgeEncontrado.isNotEmpty ? badgeEncontrado : null;
        progresso = progressoEncontrado.isNotEmpty ? progressoEncontrado : null;
        candidaturaStatus = candidaturaStatusEncontrada.isNotEmpty ? candidaturaStatusEncontrada : null;
        badgesRelacionados = relacionados;
        loading = false;
      });
      // Carrega os requisitos do nível padrão
      atualizarListaRequisitos(nivelVisualizado);
    }
  }

  // Método reativo para buscar requisitos na tabela correta do SQLite
  // =========================================================================
  // ATUALIZAR REQUISITOS
  //
  // Muda o nível selecionado e procura os requisitos:
  // - Primeiro na lista recebida juntamente com o badge;
  // - Caso não exista, na tabela local requisitos.
  // =========================================================================
  Future<void> atualizarListaRequisitos(String letraNivel) async {
    List<Map<String, dynamic>> reqs = [];
    final int alvoNivelId = obterIdNivel(letraNivel);

    final rawRequisitos = badge?['requisitos'];
    if (rawRequisitos is List) {
      reqs = rawRequisitos
          .map((item) => Map<String, dynamic>.from(item))
          .where((r) => r['id_nivel']?.toString() == alvoNivelId.toString() || rawRequisitos.length <= 5)
          .toList();
    } else {
      // Lê requisitos da tabela local oficial para fallback offline.
      final todosReqsLocais = await _dbLocal.listarTabela('requisitos');
      reqs = todosReqsLocais
          .where((r) => r['id_badge_modelo'].toString() == widget.badgeId.toString())
          .map((r) => {
                'titulo': r['nome_requisito'] ?? 'REQ', 
                'nome': r['descricao_requisito'] ?? 'Sem descrição cadastrada localmente.'
              })
          .toList();
    }

    if (mounted) {
      setState(() {
        nivelVisualizado = letraNivel;
        requisitos = reqs;
      });
    }
  }

  // Getter: considera conquistado quando existe um progresso associado.
  bool get conquistado => progresso != null && progresso!.isNotEmpty;

  // Getter: converte o campo progress para double, quando existe.
  double? get progressoValor => progresso != null
      ? double.tryParse(progresso!['progress']?.toString() ?? '')
      : null;

  // Getter: devolve a data de atribuição do badge.
  String? get dataConquista => progresso?['data_atribuicao']?.toString();

  // Formata a data para dd/MM/yyyy.
  String _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  static const List<String> _todosNiveis = ['A', 'B', 'C', 'D', 'E'];

  Future<void> _partilharNoLinkedIn() async {
    if (!conquistado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Só é possível partilhar badges já conquistados.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    /*
    * Este URL deve ser a página pública da WEB,
    * ou seja, a galeria onde o badge aparece publicamente.
    *
    * Troca pelo domínio/rota real do teu frontend web.
    */
    final String urlBadgePublico =
      'https://softinsa-web.onrender.com/galeria-badges'
      '${widget.userId}/'
      '${widget.badgeId}';

    final Uri linkedInUrl = Uri.parse(
      'https://www.linkedin.com/sharing/share-offsite/'
      '?url=${Uri.encodeComponent(urlBadgePublico)}',
    );

    try {
      final bool abriu = await launchUrl(
        linkedInUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!abriu && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o LinkedIn.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao abrir o LinkedIn: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  // =========================================================================
  // BUILD
  //
  // Trata primeiro os estados de carregamento e badge inexistente.
  // Depois constrói:
  // - Resumo do badge;
  // - Descrição expansível;
  // - Seletor de níveis;
  // - Requisitos;
  // - Ações de candidatura/certificado;
  // - Badges relacionados.
  // =========================================================================
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4470AF))),
      );
    }

    if (badge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: SafeArea(
          child: Center(child: Text("Badge não encontrado")),
        ),
      );
    }

    final nome = badge!['nome'] ?? badge!['nome_badge'] ?? '';
    final descricao = badge!['descricao'] ?? badge!['descricao_badge_modelo'] ?? '';
    final pontos = int.tryParse(badge!['points']?.toString() ?? badge!['pontos']?.toString() ?? '0') ?? 0;
    final nivelId = badge!['id_nivel'];
    final int? nivelIdInteiro = int.tryParse((nivelId ?? '').toString());
    final Map<String, Color> coresNivel = _coresNivelBadge(nivelIdInteiro);
    final _BadgeBonusInfo bonus =
        _obterBonusBadge(
      progresso ??
          const <String, dynamic>{},
    );

    final bool bonusAtivo =
        conquistado &&
        bonus.ganhouBonus;

    final int pontosExtra =
        bonus.pontosExtra;

    final int totalObtido =
        pontos + pontosExtra;

    final String? imagemUrl =
        _obterImagemBadge(
      badge!,
    );

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

    final String estadoCandidatura =
      candidaturaStatus?['estado_geral']?.toString() ??
      candidaturaStatus?['estado_final']?.toString() ??
      candidaturaStatus?['estado_candidatura_pedido']?.toString() ??
      '';

    final String estadoNormalizado =
      _normalizarEstado(estadoCandidatura);

    final bool temCandidatura =
      candidaturaStatus != null;

    final bool candidaturaEmValidacao =
      estadoNormalizado.contains('AGUARDA') ||
      estadoNormalizado.contains('PEND') ||
      estadoNormalizado.contains('VALID') ||
      estadoNormalizado.contains('EM_VALIDACAO');

    final coresEstadoCandidatura =
      _coresEstadoCandidatura(
      estadoCandidatura,
    );

    if (conquistado) {
      final String data =
          _formatarData(
        dataConquista,
      );

      estadoTexto =
          data.isNotEmpty
              ? 'Conquistado em $data'
              : 'Conquistado';

      estadoCor =
          bonusAtivo
              ? douradoEscuro
              : const Color(
                  0xFF2E7D32,
                );
    } else if (temCandidatura) {
      estadoTexto = _formatarEstadoHumano(
        estadoCandidatura,
      );

      estadoCor = coresEstadoCandidatura['texto'] ?? _azul;
    } else if (
      progressoValor != null &&
      progressoValor! > 0
    ) {
      estadoTexto =
          'Em progresso '
          '(${(progressoValor! * 100).toStringAsFixed(0)}%)';

      estadoCor = _azul;
    } else {
      estadoTexto =
          'Por Conquistar';

      estadoCor =
          Colors.grey;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 65),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voltar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 20, color: _azul),
                            SizedBox(width: 6),
                            Text("Voltar", style: TextStyle(color: _azul, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // CARD DO BADGE
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 160,
                                padding:
                                    const EdgeInsets.all(
                                  20,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: bonusAtivo
                                      ? fundoDourado
                                      : Colors.white,

                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),

                                  border: Border.all(
                                    color: bonusAtivo
                                        ? dourado
                                        : _azul.withOpacity(
                                            0.3,
                                          ),

                                    width: bonusAtivo
                                        ? 2
                                        : 1,
                                  ),

                                  boxShadow: bonusAtivo
                                      ? [
                                          BoxShadow(
                                            color: dourado
                                                .withOpacity(
                                              0.15,
                                            ),
                                            blurRadius: 9,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.all(
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
                                        size: 60,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 10,
                                    ),

                                    Text(
                                      nome,
                                      textAlign:
                                          TextAlign.center,
                                      style:
                                          const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),

                                    if (bonusAtivo) ...[
                                      const SizedBox(
                                        height: 8,
                                      ),

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
                                          textAlign:
                                              TextAlign.center,
                                          style:
                                              TextStyle(
                                            fontSize: 9,
                                            fontWeight:
                                                FontWeight.bold,
                                            color:
                                                douradoEscuro,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .stretch,
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: bonusAtivo
                                            ? fundoDourado
                                            : Colors.white,

                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),

                                        border:
                                            Border.all(
                                          color: bonusAtivo
                                              ? dourado
                                              : _azul.withOpacity(
                                                  0.3,
                                                ),

                                          width: bonusAtivo
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: bonusAtivo
                                                    ? dourado
                                                    : const Color(
                                                        0xFFFFC107,
                                                      ),
                                                size: 18,
                                              ),

                                              const SizedBox(
                                                width: 6,
                                              ),

                                              Text(
                                                '$pontos pontos',
                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight
                                                          .bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),

                                          if (
                                            bonusAtivo &&
                                            pontosExtra > 0
                                          ) ...[
                                            const SizedBox(
                                              height: 5,
                                            ),

                                            Text(
                                              '+$pontosExtra '
                                              'pontos extra',
                                              style:
                                                  const TextStyle(
                                                color:
                                                    douradoEscuro,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight
                                                        .bold,
                                              ),
                                            ),

                                            const SizedBox(
                                              height: 5,
                                            ),

                                            Divider(
                                              color: dourado
                                                  .withOpacity(
                                                0.35,
                                              ),
                                              height: 1,
                                            ),

                                            const SizedBox(
                                              height: 5,
                                            ),

                                            Text(
                                              'Total obtido: '
                                              '$totalObtido pontos',
                                              style:
                                                  const TextStyle(
                                                color:
                                                    douradoEscuro,
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight
                                                        .w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 8,
                                    ),

                                    Container(
                                      padding:
                                          const EdgeInsets
                                              .symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration:
                                          BoxDecoration(
                                        color: bonusAtivo
                                            ? fundoDourado
                                            : Colors.white,

                                        borderRadius:
                                            BorderRadius
                                                .circular(
                                          12,
                                        ),

                                        border:
                                            Border.all(
                                          color: bonusAtivo
                                              ? dourado
                                              : estadoCor
                                                  .withOpacity(
                                                    0.3,
                                                  ),

                                          width: bonusAtivo
                                              ? 1.5
                                              : 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            estadoTexto,
                                            style:
                                                TextStyle(
                                              color:
                                                  estadoCor,
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                              fontSize: 12,
                                            ),
                                          ),

                                          if (
                                            (temCandidatura || progressoValor != null) &&
                                            !conquistado
                                          ) ...[
                                            const SizedBox(
                                              height: 6,
                                            ),

                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                8,
                                              ),
                                              child:
                                                  LinearProgressIndicator(
                                                value:
                                                    candidaturaEmValidacao
                                                        ? 0.45
                                                    : (progressoValor ?? 0.0),
                                                minHeight:
                                                    6,
                                                backgroundColor:
                                                    Colors.grey
                                                        .shade200,
                                                color:
                                                    temCandidatura
                                                        ? (coresEstadoCandidatura['texto'] ?? _azul)
                                                        : _azul,
                                              ),
                                            ),
                                          ],

                                          if (temCandidatura) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              candidaturaStatus?['fase_geral']?.toString().trim().isNotEmpty == true
                                                  ? 'Fase: ${candidaturaStatus?['fase_geral']}'
                                                  : 'Candidatura registada',
                                              style: TextStyle(
                                                color: coresEstadoCandidatura['texto'] ?? _azul,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (
                            bonusAtivo &&
                            pontosExtra > 0
                          ) ...[
                            const SizedBox(
                              height: 12,
                            ),

                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    douradoClaro,

                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),

                                border:
                                    Border.all(
                                  color:
                                      const Color(
                                    0xFFF0D36B,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Desafio concluído em '
                                'tempo recorde • '
                                '+$pontosExtra pontos extra',

                                textAlign:
                                    TextAlign.center,

                                style:
                                    const TextStyle(
                                  color:
                                      douradoEscuro,
                                  fontSize:
                                      11,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // DESCRIÇÃO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _azul.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Descrição", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 8),
                            Text(descricao, maxLines: descricaoExpandida ? null : 3, overflow: descricaoExpandida ? TextOverflow.visible : TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            if (descricao.length > 120) ...[
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () => setState(() => descricaoExpandida = !descricaoExpandida),
                                child: Text(descricaoExpandida ? "Ver menos" : "Ler mais...", style: const TextStyle(color: _azul, fontSize: 12, fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // NÍVEL + REQUISITOS (INTERATIVO)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              width: 130,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _azul.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Nível", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _todosNiveis.map((n) {
                                      final isSelecionado = n == nivelVisualizado;
                                      final corCirculo = obterCorNivel(n);

                                      return InkWell(
                                        onTap: () => atualizarListaRequisitos(n),
                                        borderRadius: BorderRadius.circular(18),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: isSelecionado ? corCirculo : Colors.grey.shade100,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: isSelecionado ? corCirculo : Colors.grey.shade300, width: isSelecionado ? 2 : 1),
                                          ),
                                          child: Center(
                                            child: Text(n, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelecionado ? Colors.white : Colors.grey)),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // REQUISITOS LIST
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: _azul.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Requisitos (Nível $nivelVisualizado)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    const SizedBox(height: 12),
                                    if (requisitos.isEmpty)
                                      const Expanded(
                                        child: Center(
                                          child: Text(
                                            "Sem requisitos cadastrados.", 
                                            style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      )
                                    else
                                      ...requisitos.map((req) {
                                        final textoCirculo = req['titulo']?.toString() ?? 'REQ';
                                        final textoFrente = req['nome']?.toString() ?? '';
                                        
                                        // CORREÇÃO: Tratamento seguro de strings para evitar estouro de índice
                                        final abreviatura = textoCirculo.length > 3 ? textoCirculo.substring(0, 3) : textoCirculo;
                                        
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: const BoxDecoration(color: Color(0xFFFFC107), shape: BoxShape.circle),
                                                  child: Center(child: Text(abreviatura, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white))),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(child: Text(textoFrente, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // BOTÕES DE AÇÃO
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: conquistado
                          ? Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.black87, width: 1.5), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: _partilharNoLinkedIn,
                                    icon: Container(width: 22, height: 22, decoration: BoxDecoration(color: const Color(0xFF0077B5), borderRadius: BorderRadius.circular(4)), child: const Center(child: Text("in", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                                    label: const Text("Partilhar no LinkedIn", style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: const BorderSide(color: Colors.black87, width: 1.5), shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 12)),
                                    onPressed: () {
                                      /*
                                      * O histórico pertence normalmente
                                      * aos dados da conquista/progresso,
                                      * não ao modelo geral do badge.
                                      */
                                      final int idHistorico =
                                          int.tryParse(
                                            (
                                              progresso?[
                                                'id_candidatura_historico'
                                              ] ??
                                              progresso?[
                                                'id_historico'
                                              ] ??
                                              certificadoDisponivel?[
                                                'id_candidatura_historico'
                                              ] ??
                                              ''
                                            ).toString(),
                                          ) ??
                                          0;

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              CertificadoPage(
                                            userData: {
                                              'id_utilizador':
                                                  widget.userId,

                                              /*
                                              * Identifica exatamente o
                                              * badge selecionado.
                                              */
                                              'id_badge_modelo':
                                                  widget.badgeId,

                                              /*
                                              * Só envia o histórico quando
                                              * ele realmente existe.
                                              */
                                              if (idHistorico > 0)
                                                'id_candidatura_historico':
                                                    idHistorico,
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.download, size: 18),
                                    label: const Text("Obter certificado", style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ],
                            )
                          : SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: _azul, foregroundColor: Colors.white, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => SubmeterBadge(userId: widget.userId, badgeId: widget.badgeId)),
                                  );
                                },
                                icon: const Icon(Icons.upload_file, size: 18),
                                label: const Text("Submeter evidências", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // BADGES RELACIONADOS
                    if (badgesRelacionados.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text("Badges Relacionados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                      Divider(color: Colors.grey.shade300, height: 16, indent: 16, endIndent: 16),
                      ...badgesRelacionados.map((b) => _badgeRelacionadoCard(b)),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),

            // HEADER FIXO
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 65,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  // Cria o cartão de um badge relacionado.
  // Determina o estado e substitui a página atual pelo novo detalhe.
  Widget _badgeRelacionadoCard(
    Map<String, dynamic> b,
  ) {
    final bool conquistadoRel =
        b['conquistado'] == true;

    final int? nivelRel = int.tryParse((b['id_nivel'] ?? '').toString());
    final Map<String, Color> coresNivelRel = _coresNivelBadge(nivelRel);

    final double? progressRel =
        double.tryParse(
      b['progress']?.toString() ??
          '',
    );

    final int pontosRel =
        _converterInteiro(
      b['points'] ??
          b['pontos'],
    );

    final _BadgeBonusInfo bonus =
        _obterBonusBadge(
      b,
    );

    final bool bonusAtivo =
        conquistadoRel &&
        bonus.ganhouBonus;

    final int pontosExtra =
        bonus.pontosExtra;

    final int totalObtido =
        pontosRel + pontosExtra;

    final String nome =
        b['nome']?.toString() ??
        b['nome_badge']
            ?.toString() ??
        'Badge';

    final String descricao =
        b['descricao']
            ?.toString() ??
        b[
          'descricao_badge_modelo'
        ]?.toString() ??
        '';

    final String? imagemUrl =
        _obterImagemBadge(
      b,
    );

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

    if (conquistadoRel) {
      final String data =
          _formatarData(
        b['data_conquista']
            ?.toString(),
      );

      estadoTexto =
          data.isNotEmpty
              ? 'Conquistado em $data'
              : 'Conquistado';

      estadoCor =
          bonusAtivo
              ? douradoEscuro
              : const Color(
                  0xFF2E7D32,
                );
    } else if (
      progressRel != null &&
      progressRel > 0
    ) {
      estadoTexto =
          'Em Progresso';

      estadoCor =
          _azul;
    } else {
      estadoTexto =
          'Por conquistar';

      estadoCor =
          Colors.grey;
    }

    return GestureDetector(
      onTap: () {
        final int id =
            int.tryParse(
              (
                b['id'] ??
                b['id_badge_modelo'] ??
                b['id_badge'] ??
                ''
              ).toString(),
            ) ??
            -1;

        if (id != -1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BadgeDetalhe(
                userId:
                    widget.userId,
                badgeId: id,
              ),
            ),
          );
        }
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
                : conquistadoRel
                    ? const Color(
                        0xFF2E7D32,
                      ).withOpacity(
                        0.3,
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
                      0.15,
                    )
                  : Colors.black
                      .withOpacity(
                        0.03,
                      ),

              blurRadius:
                  bonusAtivo
                      ? 8
                      : 4,

              spreadRadius:
                  bonusAtivo
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

                          color: bonusAtivo
                              ? douradoClaro
                              : (coresNivelRel['fundo'] ?? const Color(0xFFEAF0FA)),

                          border:
                              Border.all(
                            color: bonusAtivo
                                ? dourado
                                : (coresNivelRel['borda'] ?? const Color(0xFFDBEAFE)),
                          ),
                        ),
                        child: BadgeImage(
                          imageUrl:
                              imagemUrl,
                          size: 54,
                        ),
                      ),

                      if (conquistadoRel)
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
                              size: 10,
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
                                  horizontal:
                                      7,
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
                                        8,
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
                        )
                          Text(
                            descricao,
                            style:
                                const TextStyle(
                              fontSize:
                                  11,
                              color:
                                  Colors.grey,
                            ),
                            maxLines:
                                2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
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
                      horizontal: 9,
                      vertical: 7,
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
                            : _azul.withOpacity(
                                0.6,
                              ),
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
                                : _azul,
                          ),
                        ),

                        Text(
                          '$pontosRel',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                            fontSize: 15,
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
                              fontSize: 8,
                              color:
                                  dourado,
                              fontWeight:
                                  FontWeight
                                      .bold,
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
                vertical: 7,
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
                        '+$pontosExtra extra • '
                        'Total: '
                        '$totalObtido pontos'
                    : estadoTexto,

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize:
                      10,
                  color:
                      estadoCor,
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
}

// Carrega a imagem do badge pela rede com spinner e fallback.
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

  // Ícone alternativo para imagens ausentes ou inválidas.
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