// ============================================================================
// historico_badges_page.dart
//
// Página de histórico dos badges conquistados.
// Mostra datas, pontos e estado de validade de cada badge.
// Usa API como fonte principal e SQLite como fallback offline.
//
// Foram mantidas as instruções e a lógica originais.
// Os comentários servem para explicar responsabilidades, fluxo de dados,
// estado, navegação, cache SQLite e construção da interface.
// ============================================================================

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para o fallback de base de dados
import 'informacoes_badge.dart';

class _BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const _BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

// StatefulWidget porque a lista e os indicadores são carregados
// de forma assíncrona.
class HistoricoBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HistoricoBadgesPage({
    super.key,
    required this.userData,
  });

  @override
  State<HistoricoBadgesPage> createState() => _HistoricoBadgesPageState();
}

class _HistoricoBadgesPageState extends State<HistoricoBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância para cache local do SQLite

  bool isLoading = true;
  List<Map<String, dynamic>> badges = [];

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
    final int pontosExtra =
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
          imagem
              ?.toString()
              .trim() ??
          '';

      if (
        valor.isEmpty ||
        valor.toLowerCase() ==
            'null'
      ) {
        continue;
      }

      /*
      * Cloudinary ou outro URL completo.
      */
      if (
        valor.startsWith(
          'https://',
        ) ||
        valor.startsWith(
          'http://',
        )
      ) {
        return valor;
      }

      /*
      * Remove /api do endereço base:
      *
      * https://softinsa-api.onrender.com/api
      * passa para
      * https://softinsa-api.onrender.com
      */
      final String servidor =
          ApiService.baseUrl
              .replaceFirst(
        RegExp(
          r'/api/?$',
        ),
        '',
      );

      if (
        valor.startsWith('/')
      ) {
        return '$servidor$valor';
      }

      return '$servidor/$valor';
    }

    return null;
  }

  @override
  // Executado uma vez e inicia o carregamento dos badges.
  void initState() {
    super.initState();
    carregarBadges();
  }

  // CARREGAR HISTÓRICO
  // 1. Tenta obter badges conquistados através da API;
  // 2. Guarda atribuição, datas e estado no SQLite;
  // 3. Se falhar, reconstrói a lista com a cache local;
  // 4. Remove badges duplicados através de um Map por ID.
  Future<void> carregarBadges() async {
    final int userId =
        int.tryParse(
          widget.userData['id_utilizador']?.toString() ?? '',
        ) ??
        0;

    List<Map<String, dynamic>> conquistados = [];
    List<Map<String, dynamic>> pendentes = [];

    try {
      conquistados =
          await _apiService.getBadgesConquistados(userId);

      pendentes =
          await _apiService.getCandidaturasPendentes(userId);

      for (final b in conquistados) {
        await _dbLocal.salvarRegisto(
          'badge_atribuido',
          {
            'id_badge_atribuido':
                b['id_badge_atribuido'] ??
                b['id'] ??
                0,

            'id_badge_modelo':
                b['id_badge_modelo'] ??
                b['id'] ??
                0,

            'nome':
                b['nome'] ??
                b['nome_badge'] ??
                'Badge',

            'descricao':
                b['descricao'] ??
                b[
                  'descricao_badge_modelo'
                ] ??
                '',

            'pontos':
                _converterInteiro(
              b['pontos'],
            ),

            'imagem':
                b['imagem'] ??
                b['imagem_url'],

            'imagem_url':
                b['imagem_url'] ??
                b['imagem'],

            'data_atribuicao':
                b['data_atribuicao']
                    ?.toString(),

            'data_validade':
                b['data_validade']
                    ?.toString(),

            'estado_badge_atribuido':
                b[
                  'estado_badge_atribuido'
                ] ??
                'Conquistado',
          },
        );
      }
    } catch (e) {
      debugPrint(
        'Modo Offline Ativo no Histórico: $e',
      );

      final localAtribuidos =
          await _dbLocal.listarTabela(
        'badge_atribuido',
      );

      conquistados =
          localAtribuidos.map(
        (e) => <String, dynamic>{
          'id': e['id_badge_modelo'],
          'id_badge_modelo': e['id_badge_modelo'],
          'nome': e['nome'] ?? 'Badge Conquistado',
          'descricao':
              e['descricao'] ??
              'Dados guardados localmente.',
          'pontos': e['pontos'] ?? 0,
          'data_atribuicao': e['data_atribuicao'],
          'data_validade': e['data_validade'],
          'imagem': e['imagem'],
          'imagem_url': e['imagem_url'],
          'ganhou_bonus': e['ganhou_bonus'] ?? false,
          'premio_atribuido':
              e['premio_atribuido'] ?? false,
          'pontos_extra': e['pontos_extra'] ?? 0,
          'pontos_bonus': e['pontos_bonus'] ?? 0,
        },
      ).toList();

      pendentes = [];
    }

    final Map<String, Map<String, dynamic>> unicos = {};

    for (final badgeOriginal in conquistados) {
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

      if (id == null || id <= 0) {
        continue;
      }

      final bonus =
          _obterBonusBadge(
        badge,
      );

      unicos['obtido_$id'] = {
        ...badge,
        'id': id,
        'id_badge_modelo':
            badge['id_badge_modelo'] ?? id,
        'tipo_historico': 'OBTIDO',
        'estado_historico': 'Conquistado',
        'data_evento':
            badge['data_atribuicao'] ??
            badge['data_conquista'],
        'ganhou_bonus': bonus.ganhouBonus,
        'premio_atribuido': bonus.ganhouBonus,
        'pontos_extra': bonus.pontosExtra,
        'pontos_bonus': bonus.pontosExtra,
      };
    }

    for (final pedidoOriginal in pendentes) {
      final pedido =
          Map<String, dynamic>.from(
        pedidoOriginal,
      );

      final int? idBadge =
          int.tryParse(
        (
          pedido['id_badge_modelo'] ??
          pedido['id'] ??
          pedido['badge_id'] ??
          ''
        ).toString(),
      );

      if (idBadge == null || idBadge <= 0) {
        continue;
      }

      /*
      * Se já está conquistado, o histórico deve mostrar
      * a versão conquistada, não a candidatura antiga.
      */
      if (unicos.containsKey('obtido_$idBadge')) {
        continue;
      }

      final String estado =
          (
            pedido['estado_validacao'] ??
            pedido['estado_candidatura_pedido'] ??
            pedido['estado_candidatura'] ??
            pedido['estado_final'] ??
            pedido['estado'] ??
            'Em validação'
          ).toString();

      unicos['pedido_$idBadge'] = {
        ...pedido,
        'id': idBadge,
        'id_badge_modelo': idBadge,
        'tipo_historico': 'PEDIDO',
        'estado_historico': estado,
        'data_evento':
            pedido['data_submissao'] ??
            pedido['data_submisao'] ??
            pedido['data_candidatura'] ??
            pedido['data_entrada_historico'] ??
            pedido['data_validacao'],
        'nome':
            pedido['nome'] ??
            pedido['nome_badge'] ??
            pedido['nome_badge_modelo'] ??
            'Badge em validação',
        'descricao':
            pedido['descricao'] ??
            pedido['descricao_badge_modelo'] ??
            '',
        'pontos':
            pedido['pontos'] ?? 0,
        'imagem_url':
            pedido['imagem_url'] ??
            pedido['imagem'] ??
            pedido['url_imagem'],
        'imagem':
            pedido['imagem_url'] ??
            pedido['imagem'] ??
            pedido['url_imagem'],
        'ganhou_bonus': false,
        'premio_atribuido': false,
        'pontos_extra': 0,
        'pontos_bonus': 0,
      };
    }

    final listaFinal =
        unicos.values.toList();

    listaFinal.sort(
      (a, b) {
        final dataA =
            DateTime.tryParse(
              a['data_evento']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final dataB =
            DateTime.tryParse(
              b['data_evento']?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return dataB.compareTo(dataA);
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      badges = listaFinal;
      isLoading = false;
    });
  }

  // Formata datas para dd/MM/yyyy e aceita valores inválidos
  // sem interromper a página.
  String _formatarData(dynamic data) {
    if (data == null) return "-";

    try {
      final dt = DateTime.parse(data.toString());
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return data.toString();
    }
  }

  // Calcula o estado visual do badge através de data_validade.
  // Pode devolver: sem validade, data inválida, expirado,
  // a expirar em até 30 dias ou ativo.
  Map<String, dynamic> _estadoHistorico(
    Map<String, dynamic> badge,
  ) {
    final String tipo =
        badge['tipo_historico']
            ?.toString()
            .toUpperCase() ??
        '';

    final String estado =
        badge['estado_historico']
            ?.toString()
            .toUpperCase() ??
        '';

    if (tipo == 'PEDIDO') {
      if (
        estado.contains('REJEIT') ||
        estado.contains('RECUS')
      ) {
        return {
          'texto': 'Rejeitado',
          'cor': Colors.red,
          'fundo': const Color(0xFFFFEBEE),
          'icone': Icons.cancel_outlined,
        };
      }

      if (
        estado.contains('RETIFIC') ||
        estado.contains('ALTERA')
      ) {
        return {
          'texto': 'Necessita retificação',
          'cor': Colors.deepOrange,
          'fundo': const Color(0xFFFFF3E0),
          'icone': Icons.edit_note,
        };
      }

      if (
        estado.contains('TM') &&
        !estado.contains('SLL')
      ) {
        return {
          'texto': 'A aguardar Talent Manager',
          'cor': const Color(0xFF4470AF),
          'fundo': const Color(0xFFEFF6FF),
          'icone': Icons.manage_accounts_outlined,
        };
      }

      if (
        estado.contains('SLL') ||
        estado.contains('SERVICE')
      ) {
        return {
          'texto': 'A aguardar SLL',
          'cor': Colors.purple,
          'fundo': const Color(0xFFF3E8FF),
          'icone': Icons.verified_user_outlined,
        };
      }

      return {
        'texto': 'Em validação',
        'cor': Colors.orange,
        'fundo': const Color(0xFFFFF3E0),
        'icone': Icons.hourglass_bottom,
      };
    }

    final validadeRaw =
        badge['data_validade'];

    if (validadeRaw == null) {
      return {
        'texto': 'Conquistado',
        'cor': const Color(0xFF2E7D32),
        'fundo': const Color(0xFFE8F5E9),
        'icone': Icons.check_circle_outline,
      };
    }

    final validade =
        DateTime.tryParse(
      validadeRaw.toString(),
    );

    if (validade == null) {
      return {
        'texto': 'Conquistado',
        'cor': const Color(0xFF2E7D32),
        'fundo': const Color(0xFFE8F5E9),
        'icone': Icons.check_circle_outline,
      };
    }

    final hoje =
        DateTime.now();

    final diasRestantes =
        validade.difference(hoje).inDays;

    if (diasRestantes < 0) {
      return {
        'texto': 'Expirado',
        'cor': Colors.red,
        'fundo': const Color(0xFFFFEBEE),
        'icone': Icons.cancel_outlined,
      };
    }

    if (diasRestantes <= 30) {
      return {
        'texto': 'Expira em $diasRestantes d',
        'cor': Colors.orange,
        'fundo': const Color(0xFFFFF3E0),
        'icone': Icons.warning_amber_rounded,
      };
    }

    return {
      'texto': 'Conquistado',
      'cor': const Color(0xFF2E7D32),
      'fundo': const Color(0xFFE8F5E9),
      'icone': Icons.check_circle_outline,
    };
  }

  @override
  // Calcula os totais de ativos e expirados e constrói a página.
  Widget build(BuildContext context) {
    final conquistados = badges.where((b) {
      return b['tipo_historico'] == 'OBTIDO';
    }).length;

    final emProcesso = badges.where((b) {
      return b['tipo_historico'] == 'PEDIDO';
    }).length;

    final expirados = badges.where((b) {
      return _estadoHistorico(b)['texto'] == 'Expirado';
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // FIXED APP HEADER
            Container(
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

            // BOTÃO VOLTAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF4470AF)),
                        SizedBox(width: 6),
                        Text(
                          "Voltar",
                          style: TextStyle(
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

            // CARDS DE RESUMO (Calculados dinamicamente com base na cache ou rede)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _resumoCard(
                    titulo: "Obtidos",
                    valor: conquistados.toString(),
                    cor: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  _resumoCard(
                    titulo: "Em processo",
                    valor: emProcesso.toString(),
                    cor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _resumoCard(
                    titulo: "Expirados",
                    valor: expirados.toString(),
                    cor: Colors.red,
                  ),
                ],
              ),
            ),

            // LISTAGEM PRINCIPAL
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4470AF),
                      ),
                    )
                  : badges.isEmpty
                      ? const Center(
                          child: Text(
                            "Ainda não existe histórico de badges ou candidaturas.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: badges.length,
                          itemBuilder: (context, index) {
                            final badge = badges[index];
                            final estado = _estadoHistorico(badge);
                            return _badgeHistoricoCard(
                              badge: badge,
                              estado: estado,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // Cartão reutilizado para apresentar o total de ativos/expirados.
  Widget _resumoCard({
    required String titulo,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                color: cor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cria o cartão completo de um badge no histórico.
  Widget _badgeHistoricoCard({
    required Map<String, dynamic> badge,
    required Map<String, dynamic> estado,
  }) {
    final int pontos =
        _converterInteiro(
      badge['pontos'],
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

    const Color dourado =
        Color(0xFFD4A017);

    const Color douradoEscuro =
        Color(0xFF9A6B00);

    const Color douradoClaro =
        Color(0xFFFFF7D6);

    const Color fundoDourado =
        Color(0xFFFFFDF4);

    final int badgeId =
      int.tryParse(
        (
          badge['id_badge_modelo'] ??
          badge['id'] ??
          0
        ).toString(),
      ) ??
      0;

    return GestureDetector(
      onTap: badgeId <= 0
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BadgeDetalhe(
                    userId: int.parse(
                      widget.userData['id_utilizador']
                          .toString(),
                    ),
                    badgeId: badgeId,
                  ),
                ),
              );
            },
      child: Container(
          margin:
              const EdgeInsets.only(
            bottom: 12,
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
                  : Colors.grey.shade200,

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
                        0.03,
                      ),

                blurRadius: ganhouBonus
                    ? 9
                    : 5,

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
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .center,
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
                                color:
                                    Colors.grey,
                                fontSize:
                                    11,
                              ),
                              maxLines:
                                  2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
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
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            estado['fundo'],

                        borderRadius:
                            BorderRadius
                                .circular(
                          20,
                        ),
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            estado['icone'],
                            size: 14,
                            color:
                                estado['cor'],
                          ),

                          const SizedBox(
                            width: 4,
                          ),

                          Text(
                            estado['texto'],
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              color:
                                  estado['cor'],
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                color: ganhouBonus
                    ? const Color(
                        0xFFF0D36B,
                      )
                    : Colors.grey.shade100,
                height: 1,
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Expanded(
                      child: _dataInfo(
                        label:
                            badge['tipo_historico'] == 'PEDIDO'
                                ? 'Submetido'
                                : 'Conquistado',
                        value: _formatarData(
                          badge['data_evento'] ??
                              badge['data_atribuicao'] ??
                              badge['data_submissao'] ??
                              badge['data_submisao'],
                        ),
                      ),
                    ),

                    Expanded(
                      child: _dataInfo(
                        label:
                            'Validade',
                        value: _formatarData(
                          badge[
                            'data_validade'
                          ],
                        ),
                      ),
                    ),

                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Pontos',
                            style:
                                TextStyle(
                              fontSize:
                                  10,
                              color:
                                  Colors.grey,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            '$pontos',
                            style:
                                const TextStyle(
                              fontSize:
                                  11,
                              fontWeight:
                                  FontWeight
                                      .w600,
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
                                fontSize:
                                    9,
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
                ganhouBonus &&
                pontosExtra > 0
              )
                Container(
                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 14,
                    vertical: 8,
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

                  child: Text(
                    'Recebeste +$pontosExtra '
                    'pontos extra • '
                    'Total obtido: '
                    '$totalObtido pontos',

                    textAlign:
                        TextAlign.center,

                    style:
                        const TextStyle(
                      fontSize:
                          10,
                      color:
                          douradoEscuro,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        )
      );
  }

  // Pequeno componente utilizado para data de conquista,
  // validade e pontos.
  Widget _dataInfo({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Componente para imagem online com spinner e fallback.
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