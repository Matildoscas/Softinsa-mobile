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
import '../providers/utilizador_provider.dart'; // Import obrigatório para o Consumer

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int pontos = 0;
  int totalBadges = 0;

  // Declaração das variáveis de estado que a tua colega se esqueceu de criar
  List<Map<String, dynamic>> progresso = [];
  List<Map<String, dynamic>> recomendados = [];
  Map<String, dynamic>? especial;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  List<Map<String, dynamic>> removerBadgesDuplicados(List<Map<String, dynamic>> lista) {
    final Map<int, Map<String, dynamic>> unicos = {};

    for (final badge in lista) {
      final id = int.tryParse(
        (badge['id'] ?? badge['id_badge_modelo'] ?? badge['badge_id'] ?? '').toString(),
      );

      if (id != null && !unicos.containsKey(id)) {
        unicos[id] = badge;
      }
    }
    return unicos.values.toList();
  }

  Future<void> carregarDados() async {
    try {
      final api = ApiService();
      final p = await api.getBadgesProgresso(widget.userData['id_utilizador']);
      final r = await api.getBadgesRecomendados(widget.userData['id_utilizador']);
      final e = await api.getBadgeEspecial();
      final dashboard = await api.getDashboard(widget.userData['id_utilizador']);

      setState(() {
        progresso = removerBadgesDuplicados(p);
        recomendados = removerBadgesDuplicados(r);
        especial = e;
        pontos = int.tryParse(dashboard['total_pontos']?.toString() ?? '0') ?? 0;
        totalBadges = int.tryParse(dashboard['total_badges']?.toString() ?? '0') ?? 0;
      });
    } catch (e) {
      debugPrint("Erro ao carregar dados na Home: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String nomeCompleto = widget.userData['nome_completo'] ?? 'Utilizador';
    String primeiroNome = nomeCompleto.split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Consumer<UtilizadorProvider>(
          builder: (context, provider, child) {
            if (provider.estaA_Carregar && provider.dashboard.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
            }

            if (provider.dashboard.isEmpty) {
              return const Center(child: Text("Sem ligação à internet e sem cache disponível."));
            }

            final int pontosAtuais = int.parse((provider.dashboard['total_pontos'] ?? 0).toString());
            final int totalBadgesProvider = int.parse((provider.dashboard['total_badges'] ?? 0).toString());
            final String ranking = provider.dashboard['ranking'] ?? 'N/A';

            return Column(
              children: [
                // ================= TOP BAR (SOFTINSA + PERFIL) =================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "SOFTINSA",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF39639C),
                        ),
                      ),
                      Row(
                        children: [
                          NotificationBell(userId: widget.userData['id_utilizador']),
                          const SizedBox(width: 10),
                          ProfileButton(
                            onProfile: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PerfilPage(userData: widget.userData),
                                ),
                              );
                            },
                            onSettings: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DefinicoesPage(userData: widget.userData),
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

                // ================= CONTEÚDO EM SCROLL =================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Olá, Utilizador!
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Olá, $primeiroNome!",
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // Botões rápidos de Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoButton(
                                icon: Icons.emoji_events,
                                title: "Badges",
                                subtitle: "$totalBadgesProvider obtidos",
                                onTap: () {},
                              ),
                              _buildInfoButton(
                                icon: Icons.star,
                                title: "Pontos",
                                subtitle: "$pontosAtuais pts",
                                onTap: () {},
                              ),
                              _buildInfoButton(
                                icon: Icons.note,
                                title: "Lembretes",
                                subtitle: "Ver todos",
                                onTap: () {
                                  final userId = widget.userData['id_utilizador'];
                                  if (userId == null) return;
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
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Botão de Atalho para o Catálogo
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF39639C),
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CatalogoBadgesPage(userData: widget.userData),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.grid_view),
                              label: const Text("Catálogo de Badges"),
                            ),
                          ),
                        ),

                        // Estatísticas Globais (Painel Azul)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF39639C),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem("Pontos", "$pontosAtuais"),
                              _buildStatItem("Badges", "$totalBadgesProvider"),
                              _buildStatItem("Ranking", ranking),
                            ],
                          ),
                        ),

                        // Badges com Progresso
                        _buildSectionHeader("Badges com progresso", "Em desenvolvimento"),
                        if (progresso.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("Sem progresso de momento", style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...progresso.map((b) => badgeCard(badge: b)),

                        // Recomendação
                        _buildSectionHeader("Recomendação de Badge", "Sugestão para a sua área"),
                        if (recomendados.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("Sem recomendações disponíveis", style: TextStyle(color: Colors.grey)),
                          )
                        else
                          ...recomendados.map((b) => badgeCard(badge: b)),

                        // Especial
                        if (especial != null) ...[
                          _buildSectionHeader("Badge Especial", "Destaque exclusivo"),
                          badgeCard(badge: especial!, highlight: true),
                        ],
                        
                        const SizedBox(height: 24),
                      ],
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

  // Métodos Auxiliares Corrigidos e Estruturados
  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoButton({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ]),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF39639C), size: 20),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget badgeCard({required Map<String, dynamic> badge, double? progress, bool highlight = false}) {
    final String title = badge['nome'] ?? badge['nome_badge'] ?? '';
    final String description = badge['descricao'] ?? badge['descricao_badge_modelo'] ?? '';
    final int points = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () {
        final int? badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? badge['badge_id'] ?? '').toString());
        if (badgeId == null) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeDetalhe(
              userId: int.parse(widget.userData['id_utilizador'].toString()),
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlight ? Colors.amber : Colors.grey.shade300, width: highlight ? 1.5 : 1),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xFFEAF0FA),
              child: Text("🏅", style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF39639C)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text("Pontos", style: TextStyle(fontSize: 8)),
                  Text("$points", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}