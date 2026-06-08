import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../pop/notificacoes.dart';
import '../pop/definicoes.dart';
import 'catalogo_badges.dart';
import 'Perfil.dart';
import 'lembretes_page.dart';
import 'informacoes_badge.dart';
import 'definicoes_page.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  int pontos = 0;
  int totalBadges = 0;

  List<Map<String, dynamic>> removerBadgesDuplicados(
    List<Map<String, dynamic>> lista,
  ) {
    final Map<int, Map<String, dynamic>> unicos = {};

    for (final badge in lista) {
      final id = int.tryParse(
        (badge['id'] ??
        badge['id_badge_modelo'] ??
        badge['badge_id'] ??
        '').toString(),
      );

      if (id != null && !unicos.containsKey(id)) {
        unicos[id] = badge;
      }
    }

    return unicos.values.toList();
  }

  Future<void> carregarDados() async {
    final api = ApiService();

    final p = await api.getBadgesProgresso(
      widget.userData['id_utilizador'],
    );

    final r = await api.getBadgesRecomendados(
      widget.userData['id_utilizador'],
    );

    final e = await api.getBadgeEspecial();

    final dashboard = await api.getDashboard(
      widget.userData['id_utilizador'],
    );

    setState(() {
      progresso = removerBadgesDuplicados(p);
      recomendados = removerBadgesDuplicados(r);
      especial = e;

      /*widget.userData['pontos'] =
        int.parse(dashboard['total_pontos'].toString());

      widget.userData['badges'] =
        int.parse(dashboard['total_badges'].toString());*/


      print(dashboard);


      pontos = int.tryParse(dashboard['total_pontos']?.toString() ?? '0') ?? 0;
    totalBadges = int.tryParse(dashboard['total_badges']?.toString() ?? '0') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {

    String nomeCompleto = widget.userData['nome_completo'] ?? 'Utilizador';
    String primeiroNome = nomeCompleto.split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        // O Consumer fica à escuta do UtilizadorProvider. Sempre que o SQFlite mudar, a UI redesenha-se!
        child: Consumer<UtilizadorProvider>(
          builder: (context, provider, child) {
            
            // Se estiver a carregar os dados iniciais do disco e a memória estiver vazia, mostra loading
            if (provider.estaA_Carregar && provider.dashboard.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            }

            // Fallback amigável se a BD estiver totalmente vazia e o servidor offline
            if (provider.dashboard.isEmpty) {
              return const Center(child: Text("Sem ligação à internet e sem cache local disponível."));
            }

            // Mapeamento dinâmico baseado nos dados reativos guardados no Provider
            final int pontosAtuais = int.parse((provider.dashboard['total_pontos'] ?? 0).toString());
            final int totalBadges = int.parse((provider.dashboard['total_badges'] ?? 0).toString());
            final String ranking = provider.dashboard['ranking'] ?? 'N/A';

                  Row(
                    children: [
                      NotificationBell(userId: widget.userData['id_utilizador']),
                      const SizedBox(width: 10),
                      ProfileButton(
                        onProfile: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PerfilPage(
                                userData: widget.userData,
                              ),
                            ),
                          );
                        },
                        onSettings: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DefinicoesPage(
                                userData: widget.userData,
                              ),
                            ),
                          );
                        },
                        onLogout: () {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(), // Garante que o scroll funciona mesmo com poucos itens
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= HEADER =================
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Text(
                            "SOFTINSA",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF39639C),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [

                              buildInfoButton(
                                icon: Icons.emoji_events,
                                title: "Badges",
                                subtitle: "$totalBadges obtidos",
                                onTap: () {},
                              ),

                              buildInfoButton(
                                icon: Icons.star,
                                title: "Pontos totais",
                                subtitle: "$pontos pontos",
                                onTap: () {},
                              ),

                              buildInfoButton(
                                icon: Icons.note,
                                title: "Lembretes",
                                subtitle: "Ver lembretes",
                                onTap: () {
                                  final userId = widget.userData['id_utilizador'];

                                  if (userId == null) {
                                    debugPrint("Erro: userId está null");
                                    return;
                                  }

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LembretesPage(
                                        userId: userId is int ? userId : int.parse(userId.toString()),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // ================= BOTÃO CATÁLOGO =================
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: const StadiumBorder(),
                        elevation: 4,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CatalogoBadgesPage(
                              userData: widget.userData,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.grid_view),
                      label: const Text("Catálogo de Badges"),
                    ),

                    const SizedBox(height: 20),

                    // ================= PROGRESSO =================
                    sectionHeader("Badges com progresso", "Em desenvolvimento"),

                    if (progresso.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Sem progresso de momento"),
                      )
                    else
                      ...progresso.map((b) => badgeCard(
                        badge: b,
                        
                      )),

                    // ================= RECOMENDAÇÃO =================
                    sectionHeader("Recomendação de Badge", "Sugestão baseada na sua área"),

                    if (recomendados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Sem recomendações disponíveis"),
                      )
                    else
                      ...recomendados.map((b) => badgeCard(
                        badge: b,
                      )),

                    // ================= ESPECIAL =================
                    if (especial != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF39639C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem("Pontos", "$pontosAtuais"),
                            _buildStatItem("Badges", "$totalBadges"),
                            _buildStatItem("Ranking", ranking),
                          ],
                        ),
                      ),
                    ),

                      badgeCard(
                        badge: especial!,
                        highlight: true,
                      ),
                    ),

                    provider.badgesProgresso.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text("Nenhum badge em progresso de momento.", style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: provider.badgesProgresso.length,
                            itemBuilder: (context, index) {
                              final item = provider.badgesProgresso[index];
                              return _buildBadgeCard(
                                title: item['nome_badge'] ?? 'Badge',
                                description: item['descricao_badge_modelo'] ?? 'Sem descrição',
                                points: (item['pontos'] ?? 0).toString(),
                                progress: item['progresso'] != null 
                                    ? double.tryParse(item['progresso'].toString()) 
                                    : null,
                              );
                            },
                          ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Widgets auxiliares mantidos do teu design original
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ================= CARD BADGE =================
  Widget badgeCard({
    required Map<String, dynamic> badge,
    double? progress,
    bool highlight = false,
  }) {
    final String title = badge['nome'] ?? badge['nome_badge'] ?? '';
    final String description = badge['descricao'] ?? badge['descricao_badge_modelo'] ?? '';
    final int points = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final badgeId = int.tryParse(
      (badge['id'] ??
      badge['id_badge_modelo'] ??
      badge['badge_id'] ??
      '').toString(),
    );

    if (badgeId == null) {
      print("ERRO: badge sem ID -> $badge");
    }

    return GestureDetector(
      onTap: () {
        final int? badgeId = int.tryParse(
          (
            badge['id'] ??
            badge['id_badge_modelo'] ??
            badge['badge_id'] ??
            badge['idBadgeModelo'] ??
            ''
          ).toString(),
        );

        if (badgeId == null) {
          debugPrint("ERRO: badge sem ID -> $badge");

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Não foi possível abrir este badge. Falta o ID."),
            ),
          );

          return;
        }

        final int userId = int.parse(
          widget.userData['id_utilizador'].toString(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeDetalhe(
              userId: userId,
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.blueAccent,
              child: Text("🏅", style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (progress != null)
                    Column(
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("Pontos", style: TextStyle(fontSize: 10)),
                  Text(
                    "$points",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: highlight ? Colors.amber : Colors.black,
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