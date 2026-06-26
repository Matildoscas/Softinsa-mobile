import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pop/notificacoes.dart';
import '../pop/definicoes.dart';
import '../providers/utilizador_provider.dart';

import 'catalogo_badges.dart';
import 'Perfil.dart';
import 'lembretes_page.dart';
import 'informacoes_badge.dart';
import 'definicoes_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({
    super.key,
    required this.userData,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>>
      removerBadgesDuplicados(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<int, Map<String, dynamic>>
        unicos = {};

    for (final badge in lista) {
      final id = int.tryParse(
        (
          badge['id'] ??
          badge['id_badge_modelo'] ??
          badge['badge_id'] ??
          badge['idBadgeModelo'] ??
          badge['id_badge_atribuido'] ??
          ''
        ).toString(),
      );

      if (
        id != null &&
        !unicos.containsKey(id)
      ) {
        unicos[id] = badge;
      }
    }

    return unicos.values.toList();
  }

  @override
  Widget build(BuildContext context) {
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
        child: Consumer<UtilizadorProvider>(
          builder: (
            context,
            provider,
            child,
          ) {
            if (
              provider.estaA_Carregar &&
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

            final int pontosAtuais =
                int.tryParse(
                  (
                    provider.dashboard[
                          'total_pontos'
                        ] ??
                    provider.dashboard[
                          'pontos_atuais'
                        ] ??
                    0
                  ).toString(),
                ) ??
                0;

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
                        provider
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
                                  '${provider.dashboard['offline'] == true ? ' (Modo Offline)' : ''}',
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

                          const SizedBox(
                            height: 20,
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
                                  (badge) =>
                                      badgeCard(
                                    badge:
                                        badge,
                                    highlight:
                                        false,
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
    required Map<String, dynamic> badge,
    double? progress,
    bool highlight = false,
  }) {
    final String title =
        badge['nome']?.toString() ??
        badge['nome_badge']?.toString() ??
        'Badge';

    final String description =
        badge['descricao']?.toString() ??
        badge['descricao_badge_modelo']
            ?.toString() ??
        '';

    final int points = int.tryParse(
          badge['pontos']?.toString() ??
              '0',
        ) ??
        0;

    final String? imagemUrl =
        badge['imagem_url']?.toString() ??
        badge['imagem']?.toString() ??
        badge['url_imagem']?.toString();

    return GestureDetector(
      onTap: () {
        final int? badgeId =
            int.tryParse(
          (
            badge['id'] ??
            badge['id_badge_modelo'] ??
            badge['badge_id'] ??
            badge['idBadgeModelo'] ??
            ''
          ).toString(),
        );

        if (badgeId == null) {
          debugPrint(
            'ERRO: badge sem ID -> $badge',
          );

          ScaffoldMessenger.of(context)
              .showSnackBar(
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
                  ]
                  ?.toString() ??
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
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: highlight
                ? Colors.amber.shade600
                : Colors.grey.shade300,
            width: highlight
                ? 1.5
                : 1,
          ),
        ),
        child: Row(
          children: [
            BadgeImage(
              imageUrl: imagemUrl,
              size: 60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
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
                  if (
                    description.isNotEmpty
                  )
                    Text(
                      description,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey,
                      ),
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                    ),
                  if (progress != null)
                    Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        top: 8,
                      ),
                      child:
                          LinearProgressIndicator(
                        value: progress,
                        color:
                            const Color(
                          0xFF4470AF,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                  color:
                      const Color(
                    0xFF4470AF,
                  ),
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Pontos',
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          Color(
                        0xFF4470AF,
                      ),
                    ),
                  ),
                  Text(
                    '$points',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: highlight
                          ? Colors.amber
                              .shade800
                          : Colors.black,
                    ),
                  ),
                ],
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