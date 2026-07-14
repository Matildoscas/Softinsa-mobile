// ============================================================================
// pagina_principal.dart
//
// Dashboard principal da aplicação depois do login.
//
// Responsabilidades principais:
// - Receber os dados básicos do utilizador autenticado;
// - Escutar o estado Riverpod e mostrar dados online ou em cache;
// - Apresentar pontos, total de badges e acesso aos lembretes;
// - Listar badges conquistados, em progresso e recomendados;
// - Remover badges duplicados antes de os mostrar;
// - Atualizar o dashboard através de pull-to-refresh;
// - Abrir perfil, definições, notificações, catálogo e detalhes de badges;
// - Terminar sessão, removendo os dados do SharedPreferences;
// - Carregar imagens de badges com indicador e imagem alternativa.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pop/notificacoes.dart';
import '../pop/definicoes.dart';
import '../state/utilizador_riverpod.dart';

import 'catalogo_badges.dart';
import 'Perfil.dart';
import 'lembretes_page.dart';
import 'informacoes_badge.dart';
import 'definicoes_page.dart';
import 'progresso_page.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'timeline_profissional_page.dart';

class HomePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({
    super.key,
    required this.userData,
  });

  @override
  ConsumerState<HomePage> createState() =>
      _HomePageState();
}

class BadgeBonusInfo {
  final bool ganhouBonus;
  final int pontosExtra;

  const BadgeBonusInfo({
    required this.ganhouBonus,
    required this.pontosExtra,
  });
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {

  StreamSubscription<RemoteMessage>? _onMessageSubscription;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSubscription;
  bool _dadosIniciaisCarregados = false;

  BadgeBonusInfo obterBonusBadge(
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

    return BadgeBonusInfo(
      ganhouBonus: ganhouBonus,
      pontosExtra: pontosExtra,
    );
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

  List<Map<String, dynamic>>
    removerBadgesDuplicados(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<
      int,
      Map<String, dynamic>
    > unicos = {};

    for (final badgeOriginal in lista) {
      final badge =
          Map<String, dynamic>.from(
        badgeOriginal,
      );

      final id = int.tryParse(
        (
          badge['id'] ??
          badge['id_badge_modelo'] ??
          badge['badge_id'] ??
          badge['idBadgeModelo'] ??
          badge[
            'id_badge_atribuido'
          ] ??
          ''
        ).toString(),
      );

      if (id == null) {
        continue;
      }

      final bonusNovo =
          obterBonusBadge(badge);

      if (!unicos.containsKey(id)) {
        unicos[id] = {
          ...badge,
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
          obterBonusBadge(atual);

      final maiorBonus =
          bonusNovo.pontosExtra >
                  bonusAtual.pontosExtra
              ? bonusNovo.pontosExtra
              : bonusAtual.pontosExtra;

      unicos[id] = {
        ...atual,
        ...badge,

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
      };
    }

    return unicos.values.toList();
  }

  @override
    void initState() {
      super.initState();

      WidgetsBinding.instance.addObserver(this);

      _onMessageSubscription =
          FirebaseMessaging.onMessage.listen(
        (RemoteMessage message) {
          _atualizarDashboardEmTempoReal(
            origem: 'push_foreground',
          );
        },
      );

      _onMessageOpenedSubscription =
          FirebaseMessaging.onMessageOpenedApp.listen(
        (RemoteMessage message) {
          _atualizarDashboardEmTempoReal(
            origem: 'push_aberta',
          );
        },
      );

      FirebaseMessaging.instance
          .getInitialMessage()
          .then((message) {
        if (message != null) {
          _atualizarDashboardEmTempoReal(
            origem: 'push_inicial',
          );
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _dadosIniciaisCarregados) {
          return;
        }

        final int userId = int.tryParse(
              widget.userData['id_utilizador']?.toString() ?? '',
            ) ??
            0;

        if (userId > 0) {
          _dadosIniciaisCarregados = true;
          ref
              .read(utilizadorStateProvider.notifier)
              .inicializarDados(userId);
        }
      });
    }

    @override
    void didChangeAppLifecycleState(
      AppLifecycleState state,
    ) {
      if (state == AppLifecycleState.resumed) {
        _atualizarDashboardEmTempoReal(
          origem: 'app_resumed',
        );
      }
    }

    Future<void> _atualizarDashboardEmTempoReal({
      required String origem,
    }) async {
      final int userId = int.tryParse(
            widget.userData['id_utilizador']
                    ?.toString() ??
                '',
          ) ??
          0;

      if (userId == 0 || !mounted) {
        return;
      }

      debugPrint(
        '[TEMPO REAL DASHBOARD] Atualizar por: $origem',
      );

      try {
        await ref
            .read(utilizadorStateProvider.notifier)
            .atualizarDashboard(userId);
      } catch (e) {
        debugPrint(
          '[TEMPO REAL DASHBOARD] Erro: $e',
        );
      }
    }

    @override
    void dispose() {
      WidgetsBinding.instance.removeObserver(this);
      _onMessageSubscription?.cancel();
      _onMessageOpenedSubscription?.cancel();
      super.dispose();
    }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(utilizadorStateProvider);

    final String nomeCompleto =
        widget.userData['nome_completo']
            ?.toString()
            .trim() ??
        'Utilizador';

    final String primeiroNome =
        nomeCompleto.isNotEmpty
        ? nomeCompleto.split(' ').first
        : 'Utilizador';

    final int userId = int.tryParse(
          widget.userData['id_utilizador']
                  ?.toString() ??
              '',
        ) ??
        0;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (
              provider.estaACarregar &&
              provider.dashboard.isEmpty
            ) {
              return const Center(
                child:
                    CircularProgressIndicator(
                  color: Color(0xFF4470AF),
                ),
              );
            }

            final listaConquistados =
                removerBadgesDuplicados(
              provider.badgesConquistados,
            );

            final listaProgresso =
                removerBadgesDuplicados(
              provider.badgesProgresso,
            );

            final listaRecomendados =
                removerBadgesDuplicados(
              provider.badgesRecomendados,
            );

            final learningPaths =
                List<Map<String, dynamic>>.from(
              provider.learningPaths,
            );

            final int pontosAtuais =
                _converterInteiro(
              provider.dashboard[
                'total_pontos'
              ] ??
              provider.dashboard[
                'pontos_atuais'
              ],
            );

            final int totalDashboard =
                int.tryParse(
                  (
                    provider.dashboard[
                          'total_badges'
                        ] ??
                    provider.dashboard[
                          'badges_conquistas_total'
                        ] ??
                    0
                  ).toString(),
                ) ??
                0;

            // Se o dashboard não devolver o contador,
            // utiliza o tamanho da lista conquistada.
            final int totalBadgesObtidos =
                totalDashboard > 0
                ? totalDashboard
                : listaConquistados.length;

            return Column(
              children: [
                // ================= HEADER =================
                Container(
                  color: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Image.asset(
                        'lib/img/logo.png',
                        height: 35,
                        fit: BoxFit.contain,
                      ),
                      Row(
                        children: [
                          NotificationBell(
                            userId: userId,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          ProfileButton(
                            onProfile: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PerfilPage(
                                    userData:
                                        widget
                                            .userData,
                                  ),
                                ),
                              );
                            },
                            onSettings: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DefinicoesPage(
                                    userData:
                                        widget
                                            .userData,
                                  ),
                                ),
                              );
                            },
                            onLogout: () async {
                              final prefs =
                                  await SharedPreferences
                                      .getInstance();

                              await prefs.remove(
                                'token',
                              );
                              await prefs.remove(
                                'user',
                              );

                              if (
                                context.mounted
                              ) {
                                Navigator
                                    .pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (_) => false,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ================= CONTEÚDO =================
                Expanded(
                  child: RefreshIndicator(
                    color:
                        const Color(
                      0xFF4470AF,
                    ),
                    onRefresh: () =>
                      ref.read(utilizadorStateProvider.notifier)
                            .atualizarDashboard(
                      userId,
                    ),
                    child:
                        SingleChildScrollView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // ============= BEM-VINDO =============
                          Container(
                            margin:
                                const EdgeInsets
                                    .all(16),
                            padding:
                                const EdgeInsets
                                    .all(16),
                            decoration:
                                BoxDecoration(
                              gradient:
                                  const LinearGradient(
                                colors: [
                                  Color(
                                    0xFF4470AF,
                                  ),
                                  Color(
                                    0xFF3A5C94,
                                  ),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                Text(
                                  'Bom dia, '
                                  '$primeiroNome!'
                                  '${provider.dashboard['offline'] == true ? '' : ''}',
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white,
                                    fontSize: 18,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                                const SizedBox(
                                  height: 20,
                                ),
                                Row(
                                  children: [
                                    buildInfoButton(
                                      icon: Icons
                                          .emoji_events,
                                      title:
                                          'Badges',
                                      subtitle:
                                          '$totalBadgesObtidos obtidos',
                                      onTap: () {},
                                    ),
                                    buildInfoButton(
                                      icon:
                                          Icons.star,
                                      title:
                                          'Pontos totais',
                                      subtitle:
                                          '$pontosAtuais pontos',
                                      onTap: () {},
                                    ),
                                    buildInfoButton(
                                      icon:
                                          Icons.note,
                                      title:
                                          'Lembretes',
                                      subtitle:
                                          'Ver lembretes',
                                      onTap: () {
                                        if (
                                          userId ==
                                              0
                                        ) {
                                          debugPrint(
                                            'ID do utilizador inválido',
                                          );
                                          return;
                                        }

                                        Navigator
                                            .push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    LembretesPage(
                                              userId:
                                                  userId,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ============= CATÁLOGO =============
                          ElevatedButton.icon(
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  Colors.white,
                              foregroundColor:
                                  Colors.black,
                              shape:
                                  const StadiumBorder(),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CatalogoBadgesPage(
                                    userData:
                                        widget
                                            .userData,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.grid_view,
                            ),
                            label: const Text(
                              'Catálogo de Badges',
                            ),
                          ),

                          const SizedBox(height: 10),

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4470AF),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              elevation: 4,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TimelineProfissionalPage(
                                    userData: widget.userData,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.timeline),
                            label: const Text('Timeline profissional'),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // ============= LEARNING PATHS =============
                          learningPathsDashboardCard(
                            learningPaths: learningPaths,
                            userData: widget.userData,
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          // ============= CONQUISTADOS =============
                          sectionHeader(
                            'Badges conquistados',
                            '${listaConquistados.length} obtidos',
                          ),

                          if (
                            listaConquistados
                                .isEmpty
                          )
                            const EmptyMessage(
                              mensagem:
                                  'Ainda não conquistou badges',
                            )
                          else
                            ...listaConquistados
                            .take(3)
                            .map(
                              (badge) => badgeCard(
                                badge: badge,
                              ),
                            ),

                          // ============= PROGRESSO =============
                          sectionHeader(
                            'Badges com progresso',
                            'Em desenvolvimento',
                          ),

                          if (
                            listaProgresso
                                .isEmpty
                          )
                            const EmptyMessage(
                              mensagem:
                                  'Sem progresso de momento',
                            )
                          else
                            ...listaProgresso
                                .take(3)
                                .map(
                                  (badge) =>
                                      badgeCard(
                                    badge:
                                        badge,
                                  ),
                                ),

                          // ============= RECOMENDADOS =============
                          sectionHeader(
                            'Recomendação de Badge',
                            'Sugestão baseada na sua área',
                          ),

                          if (
                            listaRecomendados
                                .isEmpty
                          )
                            const EmptyMessage(
                              mensagem:
                                  'Sem recomendações disponíveis',
                            )
                          else
                            ...listaRecomendados
                                .take(3)
                                .map(
                                  (badge) =>
                                      badgeCard(
                                    badge:
                                        badge,
                                  ),
                                ),

                          const SizedBox(
                            height: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget learningPathsDashboardCard({
    required List<Map<String, dynamic>> learningPaths,
    required Map<String, dynamic> userData,
  }) {
    final principais =
        learningPaths.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progresso nos Learning Paths',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Acompanha o teu percurso de evolução',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProgressoPage(
                        userData: userData,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Ver progresso',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4470AF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (principais.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 18,
                horizontal: 12,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 30,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sem Learning Paths disponíveis.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ...principais.map(
              (lp) => learningPathMiniItem(lp),
            ),
        ],
      ),
    );
  }

  Widget learningPathMiniItem(
    Map<String, dynamic> lp,
  ) {
    final String nome =
        lp['nome_learningpath']
            ?.toString() ??
        lp['nome_learningpaths']
            ?.toString() ??
        lp['nome']
            ?.toString() ??
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
          lp['badges_conquistas_total'] ??
          lp['total_conquistados'] ??
          lp['conquistados'],
    );

    int percentagem =
        _converterInteiro(
      lp['percentagem'] ??
          lp['progresso_percentagem'],
    );

    if (
      percentagem == 0 &&
      total > 0 &&
      conquistados > 0
    ) {
      percentagem =
          ((conquistados / total) * 100)
              .round();
    }

    percentagem =
        percentagem.clamp(
      0,
      100,
    );

    final double progresso =
        percentagem / 100;

    return Padding(
      padding: const EdgeInsets.only(
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              Text(
                '$percentagem%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4470AF),
                ),
              ),
            ],
          ),

          const SizedBox(height: 7),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 7,
              backgroundColor:
                  Colors.grey.shade200,
              color: const Color(0xFF4470AF),
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '$conquistados / $total badges concluídos',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BOTÃO INFORMATIVO
  // =====================================================
  Widget buildInfoButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          margin:
              const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 4,
          ),
          decoration: BoxDecoration(
            color:
                Colors.white.withOpacity(
              0.15,
            ),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.2),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign:
                    TextAlign.center,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style:
                    const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              Text(
                subtitle ?? '',
                textAlign:
                    TextAlign.center,
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // CABEÇALHO DE SECÇÃO
  // =====================================================
  Widget sectionHeader(
    String title,
    String subtitle,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CatalogoBadgesPage(
                    userData:
                        widget.userData,
                  ),
                ),
              );
            },
            child: const Text(
              'Ver Todos',
              style: TextStyle(
                fontSize: 12,
                color:
                    Color(0xFF4470AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // CARD DO BADGE
  // =====================================================
  Widget badgeCard({
    required Map<String, dynamic>
        badge,
    double? progress,
  }) {
    final String title =
        badge['nome']?.toString() ??
        badge['nome_badge']
            ?.toString() ??
        'Badge';

    final String description =
        badge['descricao']
            ?.toString() ??
        badge[
          'descricao_badge_modelo'
        ]?.toString() ??
        '';

    final int points =
        _converterInteiro(
      badge['pontos'],
    );

    final String? imagemUrl =
        badge['imagem_url']
            ?.toString() ??
        badge['imagem']
            ?.toString() ??
        badge['url_imagem']
            ?.toString();

    final bonus =
        obterBonusBadge(badge);

    final bool ganhouBonus =
        bonus.ganhouBonus;

    final int pontosExtra =
        bonus.pontosExtra;

    final int totalObtido =
        points + pontosExtra;

    final Color corDourada =
        Colors.amber.shade700;

    final Color fundoDourado =
        const Color(0xFFFFFDF4);

    return GestureDetector(
      onTap: () {
        final int? badgeId =
            int.tryParse(
          (
            badge['id'] ??
            badge[
              'id_badge_modelo'
            ] ??
            badge['badge_id'] ??
            badge[
              'idBadgeModelo'
            ] ??
            ''
          ).toString(),
        );

        if (badgeId == null) {
          debugPrint(
            'ERRO: badge sem ID -> '
            '$badge',
          );

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Não foi possível abrir '
                'este badge. Falta o ID.',
              ),
            ),
          );

          return;
        }

        final int userId =
            int.tryParse(
              widget.userData[
                'id_utilizador'
              ]?.toString() ??
              '',
            ) ??
            0;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BadgeDetalhe(
              userId: userId,
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: ganhouBonus
              ? fundoDourado
              : Colors.white,

          borderRadius:
              BorderRadius.circular(
            12,
          ),

          border: Border.all(
            color: ganhouBonus
                ? corDourada
                : Colors.grey.shade300,

            width: ganhouBonus
                ? 2
                : 1,
          ),

          boxShadow: ganhouBonus
              ? [
                  BoxShadow(
                    color: Colors.amber
                        .withOpacity(0.15),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets
                            .all(3),
                    decoration:
                        BoxDecoration(
                      shape:
                          BoxShape.circle,

                      color: ganhouBonus
                          ? const Color(
                              0xFFFFF7D6,
                            )
                          : const Color(
                              0xFFEFF6FF,
                            ),

                      border:
                          Border.all(
                        color: ganhouBonus
                            ? corDourada
                            : const Color(
                                0xFFDBEAFE,
                              ),
                      ),
                    ),
                    child: BadgeImage(
                      imageUrl:
                          imagemUrl,
                      size: 56,
                    ),
                  ),

                  const SizedBox(
                    width: 10,
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
                              title,
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
                                      const Color(
                                    0xFFFFF7D6,
                                  ),
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
                                        Color(
                                      0xFF9A6B00,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (
                          description
                              .isNotEmpty
                        )
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              top: 3,
                            ),
                            child: Text(
                              description,
                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.grey,
                              ),
                              maxLines:
                                  2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),

                        if (
                          progress !=
                              null
                        )
                          Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              top: 8,
                            ),
                            child:
                                LinearProgressIndicator(
                              value:
                                  progress,
                              color:
                                  const Color(
                                0xFF4470AF,
                              ),
                            ),
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
                      color: ganhouBonus
                          ? fundoDourado
                          : Colors.white,

                      border:
                          Border.all(
                        color: ganhouBonus
                            ? corDourada
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
                            fontSize:
                                10,

                            color: ganhouBonus
                                ? const Color(
                                    0xFF9A6B00,
                                  )
                                : const Color(
                                    0xFF4470AF,
                                  ),
                          ),
                        ),

                        Text(
                          '$points',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),

                        if (
                          ganhouBonus &&
                          pontosExtra > 0
                        )
                          Text(
                            '+$pontosExtra extra',
                            style:
                                TextStyle(
                              fontSize:
                                  9,
                              fontWeight:
                                  FontWeight
                                      .bold,
                              color:
                                  corDourada,
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
                  vertical: 7,
                  horizontal: 12,
                ),

                decoration:
                    const BoxDecoration(
                  color:
                      Color(
                    0xFFFFFDF4,
                  ),

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
                        Color(
                      0xFF9A6B00,
                    ),

                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class EmptyMessage extends StatelessWidget {
  final String mensagem;

  const EmptyMessage({
    super.key,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.all(16),
      child: Text(
        mensagem,
        style: const TextStyle(
          color: Colors.grey,
        ),
      ),
    );
  }
}

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