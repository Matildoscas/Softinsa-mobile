import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../pop/notificacoes.dart';
import '../pop/definicoes.dart';
import 'catalogo_badges.dart';
import 'Perfil.dart';
import 'lembretes_page.dart';
import 'informacoes_badge.dart';
import 'definicoes_page.dart';
import '../providers/utilizador_provider.dart'; // Import do teu provider estruturado

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Mantemos o filtro de duplicados que a tua colega programou muito bem
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

  @override
  Widget build(BuildContext context) {
    String nomeCompleto = widget.userData['nome_completo'] ?? 'Utilizador';
    String primeiroNome = nomeCompleto.split(' ')[0];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      // Injeção do Consumer no topo do Scaffold para atualizar todo o ecrã dinamicamente
      body: SafeArea(
        child: Consumer<UtilizadorProvider>(
          builder: (context, provider, child) {
            // Se o provider estiver a carregar os dados do SQLite/API pela primeira vez
            if (provider.estaA_Carregar && provider.dashboard.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4470AF)),
              );
            }

            // Extração segura dos dados calculados pelo Provider (Online ou da Cache)
            final int pontosAtuais = int.tryParse((provider.dashboard['total_pontos'] ?? provider.dashboard['pontos_atuais'] ?? '0').toString()) ?? 0;
            final int totalBadgesObtidos = int.tryParse((provider.dashboard['total_badges'] ?? provider.dashboard['badges_conquistas_total'] ?? '0').toString()) ?? 0;
            
            // Filtramos as listas dinâmicas reativas que vieram do SQLite/API via Provider
            final listaProgresso = removerBadgesDuplicados(provider.badgesProgresso);
            
            // Nota: Como as recomendações e o badge especial não pertencem ao fluxo reativo do consultor,
            // podes mantê-los vazios na cache ou deixá-los falhar graciosamente se estiver offline.
            final listaRecomendados = removerBadgesDuplicados(provider.areas.isNotEmpty ? provider.areas : []); 

            return Column(
              children: [
                // ================= HEADER =================
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset(
                        'lib/img/logo.png',
                        height: 35,
                        fit: BoxFit.contain,
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
                            onLogout: () async {
                              // 1. Fecha o menu lateral para não ficar aberto visualmente em background
                              Navigator.pop(context); 

                              // 2. Destrói os tokens de autenticação locais para esquecer o utilizador
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.remove('token');
                              await prefs.remove('user');

                              // 3. Expulsa o consultor para a página de login limpando o histórico de ecrãs
                              if (context.mounted) {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/login',
                                  (_) => false,
                                );
                              }
                            }
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                // ================= CONTEÚDO COM REFRESH SEGURO =================
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF4470AF),
                    onRefresh: () => provider.atualizarDashboard(
                      int.parse(widget.userData['id_utilizador'].toString()),
                    ),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // ================= WELCOME CARD =================
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4470AF), Color(0xFF3A5C94)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Bom dia, $primeiroNome!${provider.dashboard['offline'] == true ? " (Modo Offline)" : ""}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    buildInfoButton(
                                      icon: Icons.emoji_events,
                                      title: "Badges",
                                      subtitle: "$totalBadgesObtidos obtidos",
                                      onTap: () {},
                                    ),
                                    buildInfoButton(
                                      icon: Icons.star,
                                      title: "Pontos totais",
                                      subtitle: "$pontosAtuais pontos",
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
                                  builder: (_) => CatalogoBadgesPage(userData: widget.userData),
                                ),
                              );
                            },
                            icon: const Icon(Icons.grid_view),
                            label: const Text("Catálogo de Badges"),
                          ),

                          const SizedBox(height: 20),

                          // ================= PROGRESSO REATIVO =================
                          sectionHeader("Badges com progresso", "Em desenvolvimento"),
                          if (listaProgresso.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("Sem progresso de momento", style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ...listaProgresso.map((b) => badgeCard(badge: b)),

                          // ================= RECOMENDAÇÃO =================
                          sectionHeader("Recomendação de Badge", "Sugestão baseada na sua área"),
                          if (listaRecomendados.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text("Sem recomendações disponíveis de momento", style: TextStyle(color: Colors.grey)),
                            )
                          else
                            ...listaRecomendados.map((b) => badgeCard(badge: b)),

                          const SizedBox(height: 20),
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

  // ================= BOTÃO INFO (Visual original preservado) =================
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subtitle ?? "",
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  color: subtitle != null ? Colors.white70 : Colors.transparent,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER SECÇÃO =================
  Widget sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: const Text("Ver Todos", style: TextStyle(fontSize: 12, color: Color(0xFF4470AF))),
          )
        ],
      ),
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

    return GestureDetector(
      onTap: () {
        final int? badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? badge['badge_id'] ?? badge['idBadgeModelo'] ?? '').toString());

        if (badgeId == null) {
          debugPrint("ERRO: badge sem ID -> $badge");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Não foi possível abrir este badge. Falta o ID.")),
          );
          return;
        }

        final int userId = int.parse(widget.userData['id_utilizador'].toString());

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
          border: Border.all(color: highlight ? Colors.amber.shade600 : Colors.grey.shade300, width: highlight ? 1.5 : 1),
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (progress != null)
                    Column(
                      children: [
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: progress, color: const Color(0xFF4470AF)),
                      ],
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4470AF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text("Pontos", style: TextStyle(fontSize: 10, color: Color(0xFF4470AF))),
                  Text(
                    "$points",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: highlight ? Colors.amber.shade800 : Colors.black,
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
