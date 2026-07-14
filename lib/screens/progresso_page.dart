// ============================================================================
// progresso_page.dart
//
// Painel de progresso do consultor.
// Calcula pontos, learning paths, badges comuns/especiais e top 3.
// Usa API como fonte principal e SQLite como fallback offline.
//
// Foram mantidas as instruções e a lógica originais.
// Os comentários servem para explicar responsabilidades, fluxo de dados,
// estado, navegação, cache SQLite e construção da interface.
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para fallbacks do SQFlite
import 'package:shared_preferences/shared_preferences.dart';

class _BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const _BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

class _MarcoConquista {
  final String id;
  final String titulo;
  final String descricao;
  final String icone;

  const _MarcoConquista({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.icone,
  });
}

// StatefulWidget porque os totais e listas são calculados
// depois de vários pedidos assíncronos.
class ProgressoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProgressoPage({super.key, required this.userData});

  @override
  State<ProgressoPage> createState() => _ProgressoPageState();
}

class _ProgressoPageState extends State<ProgressoPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local SQLite

  bool isLoading = true;
  int pontosTotal = 0;

  // Learning Paths
  List<Map<String, dynamic>> learningPaths = [];

  // Badges
  int badgesComuns = 0;
  int totalBadgesComuns = 0;
  int badgesEspeciais = 0;
  int totalBadgesEspeciais = 0;

  // Ranking / Destaques
  List<Map<String, dynamic>> ranking = [];
  List<_MarcoConquista> marcosAlcancados = [];

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

  int _obterTotalBadge(
    Map<String, dynamic> badge,
  ) {
    final int pontosBase =
        _converterInteiro(
      badge['pontos'],
    );

    final bonus =
        _obterBonusBadge(
      badge,
    );

    return pontosBase +
        bonus.pontosExtra;
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

  String _normalizarTexto(
    dynamic valor,
  ) {
    return valor
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll('Á', 'A')
            .replaceAll('À', 'A')
            .replaceAll('Â', 'A')
            .replaceAll('Ã', 'A')
            .replaceAll('É', 'E')
            .replaceAll('Ê', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Ô', 'O')
            .replaceAll('Õ', 'O')
            .replaceAll('Ú', 'U')
            .replaceAll('Ç', 'C') ??
        '';
  }

  bool _isBadgeEspecial(
    Map<String, dynamic> badge,
  ) {
    final _BadgeBonusInfo bonus =
        _obterBonusBadge(
      badge,
    );

    /*
    * Regra dos desafios:
    * Se o badge veio de um desafio com prémio/bónus,
    * conta como badge especial.
    */
    if (bonus.ganhouBonus || bonus.pontosExtra > 0) {
      return true;
    }

    final String tipo =
        _normalizarTexto(
      badge['tipo_badge'] ??
          badge['tipoBadge'] ??
          badge['tipo'] ??
          badge['tipo_lembrete'] ??
          badge['tipoLembrete'],
    );

    final String codigoNivel =
        _normalizarTexto(
      badge['codigo_nivel'] ??
          badge['codigoNivel'] ??
          badge['letra_nivel'] ??
          badge['codigo'],
    );

    final String nomeNivel =
        _normalizarTexto(
      badge['nome_nivel'] ??
          badge['nomeNivel'] ??
          badge['nivel'] ??
          badge['titulo_nivel'],
    );

    final String nomeBadge =
        _normalizarTexto(
      badge['nome'] ??
          badge['nome_badge'] ??
          badge['titulo'] ??
          badge['descricao'],
    );

    /*
    * Regra principal do tipo do badge.
    */
    if (
      tipo == 'ESPECIAL' ||
      tipo == 'SPECIAL' ||
      tipo.contains('DESAFIO')
    ) {
      return true;
    }

    /*
    * Regra por nome.
    * Serve para badges/desafios antigos onde o backend
    * ainda não envia tipo_badge corretamente.
    */
    if (
      nomeBadge.contains('DESAFIO') ||
      nomeBadge.contains('CHALLENGE')
    ) {
      return true;
    }

    /*
    * Regra do nível E.
    */
    if (codigoNivel == 'E') {
      return true;
    }

    if (
      nomeNivel == 'E' ||
      nomeNivel.contains('LIDER DE CONHECIMENTO') ||
      nomeNivel.contains('LEADER OF KNOWLEDGE')
    ) {
      return true;
    }

    final int idNivel =
        int.tryParse(
          badge['id_nivel']?.toString() ?? '',
        ) ??
        0;

    /*
    * Fallback antigo:
    * só usa id_nivel 5 se não houver informação melhor.
    */
    if (
      idNivel == 5 &&
      tipo.isEmpty &&
      codigoNivel.isEmpty &&
      nomeNivel.isEmpty
    ) {
      return true;
    }

    return false;
  }

  List<Map<String, dynamic>>
      _removerBadgesDuplicados(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<
      int,
      Map<String, dynamic>
    > unicos = {};

    for (final original in lista) {
      final badge =
          Map<String, dynamic>.from(
        original,
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
        'imagem':
            imagemNova ??
            imagemAtual,
        'imagem_url':
            imagemNova ??
            imagemAtual,
      };
    }

    return unicos.values.toList();
  }

  int _obterIdUtilizador() {
    return int.tryParse(
          widget.userData['id_utilizador']?.toString() ?? '',
        ) ??
        0;
  }

  List<_MarcoConquista> _calcularMarcos({
    required int totalBadgesObtidos,
    required int totalPontos,
    required int badgesEspeciaisObtidos,
    required bool concluiuDesafio,
  }) {
    final List<_MarcoConquista> lista = [];

    if (totalBadgesObtidos >= 1) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_PRIMEIRO_BADGE',
          titulo: 'Primeiro badge conquistado',
          descricao: 'Conquistaste o teu primeiro badge na Softinsa Academy.',
          icone: '🎉',
        ),
      );
    }

    if (totalBadgesObtidos >= 3) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_3_BADGES',
          titulo: '3 badges conquistados',
          descricao: 'Já conquistaste 3 badges. Continua o bom percurso!',
          icone: '🔥',
        ),
      );
    }

    if (totalBadgesObtidos >= 5) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_5_BADGES',
          titulo: '5 badges conquistados',
          descricao: 'Atingiste a marca dos 5 badges conquistados.',
          icone: '🏅',
        ),
      );
    }

    if (totalBadgesObtidos >= 10) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_10_BADGES',
          titulo: '10 badges conquistados',
          descricao: 'Chegaste aos 10 badges. Excelente evolução!',
          icone: '🚀',
        ),
      );
    }

    if (totalPontos >= 100) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_100_PONTOS',
          titulo: '100 pontos alcançados',
          descricao: 'Já acumulaste pelo menos 100 pontos.',
          icone: '⭐',
        ),
      );
    }

    if (totalPontos >= 500) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_500_PONTOS',
          titulo: '500 pontos alcançados',
          descricao: 'Atingiste uma marca importante de 500 pontos.',
          icone: '💎',
        ),
      );
    }

    if (badgesEspeciaisObtidos >= 1) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_PRIMEIRO_ESPECIAL',
          titulo: 'Primeiro badge especial',
          descricao: 'Conquistaste o teu primeiro badge especial ou desafio.',
          icone: '🏆',
        ),
      );
    }

    if (concluiuDesafio) {
      lista.add(
        const _MarcoConquista(
          id: 'MARCO_DESAFIO_CONCLUIDO',
          titulo: 'Desafio concluído',
          descricao: 'Concluíste um desafio com bónus especial.',
          icone: '⚡',
        ),
      );
    }

    return lista;
  }

  Future<void> _verificarCelebracaoMarcos(
    List<_MarcoConquista> marcos,
  ) async {
    if (!mounted || marcos.isEmpty) {
      return;
    }

    final int userId = _obterIdUtilizador();

    if (userId == 0) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    final String chave =
        'marcos_celebrados_$userId';

    final List<String> jaCelebrados =
        prefs.getStringList(chave) ?? <String>[];

    final List<_MarcoConquista> novos =
        marcos.where((marco) {
      return !jaCelebrados.contains(marco.id);
    }).toList();

    if (novos.isEmpty) {
      return;
    }

    /*
    * Mostra apenas um modal de cada vez.
    * Escolhemos o último porque normalmente é o marco mais alto.
    */
    final _MarcoConquista marcoParaCelebrar =
        novos.last;

    final List<String> atualizados = [
      ...jaCelebrados,
      ...novos.map((marco) => marco.id),
    ].toSet().toList();

    await prefs.setStringList(
      chave,
      atualizados,
    );

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (mounted) {
          _mostrarModalCelebracaoMarco(
            marcoParaCelebrar,
          );
        }
      },
    );
  }

  void _mostrarModalCelebracaoMarco(
    _MarcoConquista marco,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF7D6),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      marco.icone,
                      style: const TextStyle(
                        fontSize: 38,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Marco alcançado!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4470AF),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  marco.titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  marco.descricao,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4470AF),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Continuar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  // Executado uma vez quando a página é criada.
  void initState() {
    super.initState();
    _carregarDados();
  }

  // CARREGAR E CALCULAR O PROGRESSO
  // Obtém learning paths, catálogo e badges conquistados.
  // Em modo offline, adapta as tabelas SQLite ao formato esperado.
  // Depois calcula pontos, totais comuns/especiais e o top 3.
  Future<void> _carregarDados() async {
    final int userId =
      int.tryParse(
        widget.userData[
          'id_utilizador'
        ]?.toString() ??
        '',
      ) ??
      0;

    if (userId == 0) {
      debugPrint(
        'ID do utilizador inválido '
        'na página de progresso.',
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }
    List<Map<String, dynamic>> progressoRaw = [];
    List<Map<String, dynamic>> todosBadgesRaw = [];
    List<Map<String, dynamic>> obtidosRaw = [];
    Map<String, dynamic> dashboardRaw = {};

    try {
      // 1. TENTA OBTER OS DADOS EM TEMPO REAL ATRAVÉS DA API
      // Tenta ler o progresso estruturado das trilhas de aprendizagem
      try {
        progressoRaw =
            await _apiService
                .getProgressoLearningPaths(
          userId,
        );

        debugPrint(
          'Learning Paths recebidas: '
          '${progressoRaw.length}',
        );
      } catch (e, stackTrace) {
        debugPrint(
          'Erro ao carregar '
          'Learning Paths: $e',
        );

        debugPrint(
          stackTrace.toString(),
        );

        /*
        * Apenas as Learning Paths usam
        * a cache local. Os outros dados
        * continuam a ser carregados
        * normalmente através da API.
        */
        final localPaths =
            await _dbLocal.listarTabela(
          'learningpaths',
        );

        progressoRaw = localPaths
            .map(
              (e) => <String, dynamic>{
                'id_learningpaths':
                    e['id_learningpaths'],

                'nome_learningpath':
                    e['nome_learningpaths'],

                'total_badges':
                    e['numero_servicelines'] ??
                    0,

                'badges_conquistados':
                    0,

                'percentagem':
                    0,
              },
            )
            .toList();
      }

      try {
        dashboardRaw =
            await _apiService.getDashboard(
          userId,
        );

        debugPrint(
          'Dashboard no progresso: '
          '$dashboardRaw',
        );
      } catch (e) {
        debugPrint(
          'Erro ao carregar pontos atuais: '
          '$e',
        );

        dashboardRaw = {};
      }
      
      todosBadgesRaw = await _apiService.getTodosBadges();
      obtidosRaw = await _apiService.getBadgesConquistados(userId);

      // MIRRORING: Armazena em background os learningpaths recebidos para uso offline futuro
      for (final lp in progressoRaw) {
        await _dbLocal.salvarRegisto(
          'learningpaths',
          {
            'id_learningpaths':
                lp['id_learningpaths'] ??
                lp['id_learningpath'] ??
                lp['id'] ??
                0,

            'nome_learningpaths':
                lp['nome_learningpath'] ??
                lp['nome_learningpaths'] ??
                lp['nome'] ??
                'Learning Path',

            'numero_servicelines':
                lp['total_badges'] ??
                lp['numero_badges'] ??
                lp['badges_total'] ??
                lp['total'] ??
                0,
          },
        );
      }

    } catch (e) {
      debugPrint("Modo Offline Ativo no Painel de Progresso: Carregando tabelas locais... ($e)");
      
      // 2. FALLBACK OFFLINE-FIRST: Extrai o histórico e modelos locais a partir do SQFlite
      final localPaths = await _dbLocal.listarTabela('learningpaths');
      final localModelos = await _dbLocal.listarTabela('badge_modelo');
      final localAtribuidos = await _dbLocal.listarTabela('badge_atribuido');

      // Adapta os mapeamentos para manter consistência com os cálculos que a UI já espera
      progressoRaw = localPaths.map((e) => {
        'id_learningpaths': e['id_learningpaths'],
        'nome_learningpath': e['nome_learningpaths'],
        'total_badges': e['numero_servicelines'] ?? 0,
        // Calcula uma aproximação local de badges concluídos nesta trilha com base no SQLite
        'badges_conquistas_total': localAtribuidos.length,
        'percentagem': localPaths.isEmpty ? 0 : ((localAtribuidos.length / (e['numero_servicelines'] ?? 1)) * 100).clamp(0, 100).toInt()
      }).toList();

      todosBadgesRaw = localModelos.map((e) => {
        'id': e['id_badge_modelo'],
        'id_nivel': e['id_nivel'],
        'pontos': e['pontos']
      }).toList();

      obtidosRaw = localAtribuidos
      .map(
        (e) => <String, dynamic>{
          'id':
              e['id_badge_modelo'],

          'id_badge_modelo':
              e['id_badge_modelo'],

          'id_nivel':
              e['id_nivel'] ??
              1,

          'pontos':
              e['pontos'] ??
              0,

          'nome':
              e['nome'] ??
              'Badge Guardado',

          'descricao':
              e['descricao'],

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
        },
      )
      .toList();
    }

    obtidosRaw =
        _removerBadgesDuplicados(
      obtidosRaw,
    );

    // 3. PROCESSAMENTO DE CÁLCULO E MÉTRICAS (Lógica original otimizada e preservada)
    // Soma os pontos de todos os badges conquistados.
    final Map<String, dynamic>
        dadosDashboard =
        dashboardRaw['dashboard']
                is Map
            ? Map<String, dynamic>.from(
                dashboardRaw['dashboard'],
              )
            : dashboardRaw;

    final bool dashboardTemPontos =
        dadosDashboard.containsKey(
          'pontos_atuais',
        ) ||
        dadosDashboard.containsKey(
          'total_pontos',
        );

    final int pontosCalculados =
        obtidosRaw.fold<int>(
      0,
      (total, badge) =>
          total +
          _obterTotalBadge(
            badge,
          ),
    );

    final int pontosTotalCalc =
        dashboardTemPontos
            ? _converterInteiro(
                dadosDashboard[
                      'pontos_atuais'
                    ] ??
                    dadosDashboard[
                      'total_pontos'
                    ],
              )
            : pontosCalculados;

    int _idBadge(
      Map<String, dynamic> badge,
    ) {
      return int.tryParse(
            (
              badge['id'] ??
              badge['id_badge_modelo'] ??
              badge['badge_id'] ??
              badge['id_badge_atribuido'] ??
              ''
            ).toString(),
          ) ??
          0;
    }

    /*
    * Primeiro vemos quais badges conquistados são especiais.
    * Isto é importante para desafios, porque o catálogo geral
    * nem sempre traz os campos de bónus/desafio.
    */
    final Set<int> idsEspeciaisObtidos = {};

    int comunsObtidos = 0;
    int especiaisObtidos = 0;

    for (final badge in obtidosRaw) {
      final int id = _idBadge(badge);

      if (_isBadgeEspecial(badge)) {
        especiaisObtidos++;

        if (id > 0) {
          idsEspeciaisObtidos.add(id);
        }
      } else {
        comunsObtidos++;
      }
    }

    final bool concluiuDesafio =
      obtidosRaw.any(
    (badge) {
      final bonus =
          _obterBonusBadge(
        badge,
      );

      final String tipo =
          _normalizarTexto(
        badge['tipo_lembrete'] ??
            badge['tipoLembrete'] ??
            badge['tipo_badge'] ??
            badge['tipo'],
      );

      return bonus.ganhouBonus ||
          bonus.pontosExtra > 0 ||
          tipo.contains('DESAFIO');
    },
  );

  final int totalBadgesObtidos =
      comunsObtidos + especiaisObtidos;

  final List<_MarcoConquista> marcosCalculados =
      _calcularMarcos(
    totalBadgesObtidos: totalBadgesObtidos,
    totalPontos: pontosTotalCalc,
    badgesEspeciaisObtidos: especiaisObtidos,
    concluiuDesafio: concluiuDesafio,
  );

    /*
    * Agora contamos o catálogo.
    * Se o badge estiver nos especiais conquistados,
    * também conta como especial no total.
    */
    int comunsTotal = 0;
    int especiaisTotal = 0;

    for (final badge in todosBadgesRaw) {
      final int id = _idBadge(badge);

      final bool especial =
          _isBadgeEspecial(badge) ||
          idsEspeciaisObtidos.contains(id);

      if (especial) {
        especiaisTotal++;
      } else {
        comunsTotal++;
      }
    }

    // Ordenação descritiva por pontuação para fixar o top 3 do ranking pessoal
    // Ordena os badges por pontos, do maior para o menor.
    obtidosRaw.sort(
      (a, b) =>
          _obterTotalBadge(b)
              .compareTo(
        _obterTotalBadge(a),
      ),
    );

    final top3Badges = obtidosRaw.take(3).toList();

    if (mounted) {
      setState(() {
        learningPaths = List<Map<String, dynamic>>.from(progressoRaw);
        pontosTotal = pontosTotalCalc;
        badgesComuns = comunsObtidos;
        totalBadgesComuns = comunsTotal > 0 ? comunsTotal : 20; // Fallback estático seguro se a BD local estiver vazia
        badgesEspeciais = especiaisObtidos;
        totalBadgesEspeciais = especiaisTotal > 0 ? especiaisTotal : 4;
        ranking = top3Badges;
        marcosAlcancados = marcosCalculados;
        isLoading = false;
      });
      await _verificarCelebracaoMarcos(
        marcosCalculados,
      );
    }
  }

  @override
  // Constrói as secções: pontos, learning paths,
  // círculos de progresso e ranking pessoal.
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO SCROLLÁVEL ───────────────────────────────────
            Positioned.fill(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4470AF)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
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
                                        style: TextStyle(fontSize: 15, color: Color(0xFF4470AF), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── CARD PONTOS TOTAIS ──────────────────────
                          _pontosCard(),

                          const SizedBox(height: 16),

                          // ── SECÇÃO: LEARNING PATHS ─────────────────
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Progressos nas Learning Paths",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 14),
                                if (learningPaths.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      vertical: 18,
                                      horizontal: 12,
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
                                            Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.route_outlined,
                                          size: 30,
                                          color:
                                              Colors.grey.shade400,
                                        ),

                                        const SizedBox(
                                          height: 8,
                                        ),

                                        Text(
                                          'Sem Learning Paths '
                                          'disponíveis.',
                                          style: TextStyle(
                                            color:
                                                Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  ...learningPaths.map((lp) => _learningPathItem(lp)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── SECÇÃO: ANÉIS DE PROGRESSO DOS BADGES ──
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Progressos dos Badges",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _badgeCirculo(
                                      atual: badgesComuns,
                                      total: totalBadgesComuns,
                                      label: "Badges comuns",
                                    ),
                                    _badgeCirculo(
                                      atual: badgesEspeciais,
                                      total: totalBadgesEspeciais,
                                      label: "Badges especiais",
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── SECÇÃO: TOP 3 CONQUISTAS ───────────────
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Ranking de conquistas",
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 12),
                                if (ranking.isEmpty)
                                  Text(
                                    "Ainda sem conquistas no ranking.",
                                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                  )
                                else
                                  ...ranking.asMap().entries.map((e) => _rankingItem(e.value, e.key)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          _marcosSection(),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
            ),

            // ── FIXED HEADER LOGO ────────────────────────────────────
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

  // Cartão azul com a soma total dos pontos.
  Widget _pontosCard() {
    return Center(
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4470AF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Pontos Atuais",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "$pontosTotal pts",
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // Estrutura visual reutilizada nas secções da página.
  Widget _secaoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }

  // Cria uma learning path com barra linear e percentagem.
  // clamp mantém o progresso entre 0 e 1.
  Widget _learningPathItem(
    Map<String, dynamic> lp,
  ) {
    final String nome =
        lp['nome_learningpath']
            ?.toString() ??
        lp['nome_learningpaths']
            ?.toString() ??
        lp['nome']?.toString() ??
        'Learning Path';

    final int total =
        _converterInteiro(
      lp['total_badges'] ??
          lp['numero_badges'] ??
          lp['badges_total'] ??
          lp['total'] ??
          lp['numero_servicelines'],
    );

    final int conquistados =
        _converterInteiro(
      lp['badges_conquistados'] ??
          lp[
            'badges_conquistas_total'
          ] ??
          lp['total_conquistados'] ??
          lp['conquistados'],
    );

    int percentagem =
        _converterInteiro(
      lp['percentagem'] ??
          lp['progresso_percentagem'],
    );

    /*
    * Caso o backend não devolva
    * percentagem, calcula-a usando
    * os totais recebidos.
    */
    if (
      percentagem == 0 &&
      total > 0 &&
      conquistados > 0
    ) {
      percentagem =
          (
            conquistados /
            total *
            100
          ).round();
    }

    percentagem =
        percentagem.clamp(
      0,
      100,
    ).toInt();

    final double progresso =
        percentagem / 100;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              Text(
                '$percentagem%',
                style:
                    const TextStyle(
                  fontSize: 11,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      Color(
                    0xFF4470AF,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 7,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            child:
                LinearProgressIndicator(
              value: progresso,
              minHeight: 7,
              backgroundColor:
                  Colors.grey.shade200,
              color:
                  const Color(
                0xFF4470AF,
              ),
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            '$conquistados / $total '
            'badges concluídos',
            style: TextStyle(
              fontSize: 11,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // Cria o indicador circular de badges comuns ou especiais.
  Widget _badgeCirculo({required int atual, required int total, required String label}) {
    final double ratio = total > 0 ? (atual / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: _CirculoPainter(ratio: ratio),
              ),
              Text(
                "$atual/$total",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
        ),
          const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _marcosSection() {
    return _secaoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Marcos alcançados',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${marcosAlcancados.length}',
                  style: const TextStyle(
                    color: Color(0xFF4470AF),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Celebrações importantes do teu percurso.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 14),

          if (marcosAlcancados.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Text(
                'Ainda não existem marcos alcançados. '
                'Continua a conquistar badges para desbloquear celebrações.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            )
          else
            ...marcosAlcancados
                .reversed
                .take(4)
                .map(
                  (marco) => _marcoCard(
                    marco,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _marcoCard(
    _MarcoConquista marco,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFF0D36B),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF7D6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                marco.icone,
                style: const TextStyle(
                  fontSize: 22,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  marco.titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A6B00),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  marco.descricao,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cria uma linha do top 3 com estilo de ouro, prata ou bronze.
  Widget _rankingItem(
    Map<String, dynamic> item,
    int index,
  ) {
    final String nome =
        item['nome']?.toString() ??
        item['nome_badge']
            ?.toString() ??
        'Badge';

    final int pontosBase =
        _converterInteiro(
      item['pontos'],
    );

    final _BadgeBonusInfo bonus =
        _obterBonusBadge(
      item,
    );

    final bool ganhouBonus =
        bonus.ganhouBonus;

    final int pontosExtra =
        bonus.pontosExtra;

    final int totalObtido =
        pontosBase + pontosExtra;

    final String? imagemUrl =
        _obterImagemBadge(
      item,
    );

    const Color dourado =
        Color(0xFFD4A017);

    const Color douradoEscuro =
        Color(0xFF9A6B00);

    const Color douradoClaro =
        Color(0xFFFFF7D6);

    const Color fundoDourado =
        Color(0xFFFFFDF4);

    final rankingStyles = [
      {
        'bg':
            const Color(
          0xFFFFF8E1,
        ),
        'border':
            const Color(
          0xFFFFC107,
        ),
        'text':
            const Color(
          0xFF8A6D00,
        ),
        'label':
            '1.º lugar',
      },
      {
        'bg':
            const Color(
          0xFFF3F4F6,
        ),
        'border':
            const Color(
          0xFF9CA3AF,
        ),
        'text':
            const Color(
          0xFF4B5563,
        ),
        'label':
            '2.º lugar',
      },
      {
        'bg':
            const Color(
          0xFFFFF1E6,
        ),
        'border':
            const Color(
          0xFFD97706,
        ),
        'text':
            const Color(
          0xFF92400E,
        ),
        'label':
            '3.º lugar',
      },
    ];

    final int posicao =
        index < 0
            ? 0
            : index > 2
                ? 2
                : index;

    final style =
        rankingStyles[posicao];

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: ganhouBonus
            ? fundoDourado
            : style['bg'] as Color,

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border: Border.all(
          color: ganhouBonus
              ? dourado
              : style['border']
                  as Color,

          width: ganhouBonus
              ? 2
              : 1,
        ),

        boxShadow: ganhouBonus
            ? [
                BoxShadow(
                  color: dourado
                      .withOpacity(
                    0.15,
                  ),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset:
                      const Offset(
                    0,
                    2,
                  ),
                ),
              ]
            : [],
      ),
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.all(
                    3,
                  ),
                  decoration:
                      BoxDecoration(
                    color: ganhouBonus
                        ? douradoClaro
                        : style['bg']
                            as Color,

                    shape:
                        BoxShape.circle,

                    border:
                        Border.all(
                      color: ganhouBonus
                          ? dourado
                          : style[
                                'border'
                              ]
                              as Color,
                    ),
                  ),
                  child: BadgeImage(
                    imageUrl:
                        imagemUrl,
                    size: 42,
                  ),
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
                              fontSize: 13,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),

                          if (ganhouBonus)
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
                                  fontSize: 8,
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

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        style['label']
                            as String,
                        style:
                            TextStyle(
                          fontSize: 10,
                          color: ganhouBonus
                              ? douradoEscuro
                              : style[
                                    'text'
                                  ]
                                  as Color,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      if (
                        ganhouBonus &&
                        pontosExtra > 0
                      ) ...[
                        Text(
                          '$pontosBase pontos base '
                          '+ $pontosExtra extra',
                          style:
                              const TextStyle(
                            fontSize: 10,
                            color:
                                douradoEscuro,
                            fontWeight:
                                FontWeight
                                    .w600,
                          ),
                        ),

                        const SizedBox(
                          height: 2,
                        ),

                        Text(
                          'Total obtido: '
                          '$totalObtido pontos',
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                douradoEscuro,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ] else
                        Text(
                          'Ganhou '
                          '$pontosBase pts',
                          style:
                              TextStyle(
                            fontSize: 11,
                            color:
                                Colors.grey
                                    .shade600,
                          ),
                        ),
                    ],
                  ),
                ),

                Container(
                  width: 30,
                  height: 30,
                  decoration:
                      BoxDecoration(
                    color: ganhouBonus
                        ? dourado
                        : style['border']
                            as Color,
                    shape:
                        BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            12,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (
            ganhouBonus &&
            pontosExtra > 0
          )
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration:
                  const BoxDecoration(
                color:
                    fundoDourado,
                border:
                    Border(
                  top:
                      BorderSide(
                    color:
                        Color(
                      0xFFF0D36B,
                    ),
                  ),
                ),
              ),
              child:
                  const Text(
                'Desafio concluído em tempo recorde',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize: 10,
                  color:
                      douradoEscuro,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Desenha manualmente o círculo e o arco de progresso no Canvas.
class _CirculoPainter extends CustomPainter {
  final double ratio;

  _CirculoPainter({required this.ratio});

  @override
  // paint é chamado pelo Flutter para desenhar o indicador.
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFF4470AF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    if (ratio > 0) {
      final arcPaint = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        arcPaint,
      );
    }
  }

  @override
  // Só redesenha quando a proporção de progresso muda.
  bool shouldRepaint(_CirculoPainter old) => old.ratio != ratio;
}

// Carrega a imagem do badge pela rede e apresenta fallback em erro.
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