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
      final valor =
          imagem?.toString().trim();

      if (
        valor != null &&
        valor.isNotEmpty &&
        valor != 'null'
      ) {
        return valor;
      }
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
        widget.userData[
          'id_utilizador'
        ]?.toString() ??
        '',
      ) ??
      0;
    List<Map<String, dynamic>> dadosRaw = [];

    try {
      // 1. Tenta ir buscar os badges conquistados em tempo real à API
      dadosRaw = await _apiService.getBadgesConquistados(userId);

      // 2. MIRRORING: Guarda os dados na cache local para suportar o modo offline
      for (var b in dadosRaw) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'data_validade': b['data_validade']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo no Histórico: Carregando cache local... ($e)");
      
      // 3. FALLBACK: Lê as tabelas locais se o servidor estiver inacessível
      final localAtribuidos = await _dbLocal.listarTabela('badge_atribuido');
      
      dadosRaw = localAtribuidos
      .map(
        (e) => <String, dynamic>{
          'id':
              e['id_badge_modelo'],

          'id_badge_modelo':
              e['id_badge_modelo'],

          'nome':
              e['nome'] ??
              'Badge Conquistado',

          'descricao':
              e['descricao'] ??
              'Dados guardados localmente.',

          'pontos':
              e['pontos'] ??
              0,

          'data_atribuicao':
              e['data_atribuicao'],

          'data_validade':
              e['data_validade'],

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

    // 4. LÓGICA DE UNIFICAÇÃO (Preservada a remoção de duplicados original da tua colega)
    // A chave do Map é o ID. Assim, cada badge aparece uma única vez.
    final Map<
      int,
      Map<String, dynamic>
    > unicos = {};

    for (final badgeOriginal in dadosRaw) {
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
          _obterImagemBadge(atual);

      final String? imagemNova =
          _obterImagemBadge(badge);

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
  Map<String, dynamic> _estadoBadge(Map<String, dynamic> badge) {
    final validadeRaw = badge['data_validade'];

    if (validadeRaw == null) {
      return {
        'texto': 'Sem validade definida',
        'cor': Colors.grey,
        'fundo': const Color(0xFFF5F5F5),
        'icone': Icons.help_outline,
      };
    }

    final validade = DateTime.tryParse(validadeRaw.toString());

    if (validade == null) {
      return {
        'texto': 'Data inválida',
        'cor': Colors.grey,
        'fundo': const Color(0xFFF5F5F5),
        'icone': Icons.help_outline,
      };
    }

    final hoje = DateTime.now();
    final diasRestantes = validade.difference(hoje).inDays;

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
      'texto': 'Ativo',
      'cor': const Color(0xFF2E7D32),
      'fundo': const Color(0xFFE8F5E9),
      'icone': Icons.check_circle_outline,
    };
  }

  @override
  // Calcula os totais de ativos e expirados e constrói a página.
  Widget build(BuildContext context) {
    final ativos = badges.where((b) {
      final estado = _estadoBadge(b)['texto'].toString();
      return estado == 'Ativo' || estado.startsWith('Expira em');
    }).length;

    final expirados = badges.where((b) {
      return _estadoBadge(b)['texto'] == 'Expirado';
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
                    titulo: "Ativos",
                    valor: ativos.toString(),
                    cor: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 10),
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
                            "Ainda não tem badges conquistados.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: badges.length,
                          itemBuilder: (context, index) {
                            final badge = badges[index];
                            final estado = _estadoBadge(badge);
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

    return Container(
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
                        'Conquistado',
                    value: _formatarData(
                      badge[
                        'data_atribuicao'
                      ],
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