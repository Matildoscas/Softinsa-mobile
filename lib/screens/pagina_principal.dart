import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/utilizador_provider.dart'; // Importa o teu Provider local

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
    // REESCRITA OFFLINE-FIRST: Acorda o Provider no primeiro frame para ler o SQLite local e disparar o Sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int userId = widget.userData['id_utilizador'] ?? 0;
      Provider.of<UtilizadorProvider>(context, listen: false).inicializarDados(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final int userId = widget.userData['id_utilizador'] ?? 0;

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

            return RefreshIndicator(
              // Pull-to-Refresh: Se o utilizador puxar o ecrã para baixo, força uma nova sincronização com o pgAdmin
              onRefresh: () async {
                await provider.atualizarDashboard(userId);
              },
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
                          const Spacer(),
                          Text(
                            widget.userData['nome_completo'] ?? 'Consultor',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            backgroundColor: Colors.grey,
                            radius: 16,
                            child: Icon(Icons.person, color: Colors.white, size: 20),
                          )
                        ],
                      ),
                    ),

                    // ================= CARD DE PONTOS / RANKING =================
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
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

                    // ================= LISTA DE BADGES EM PROGRESSO =================
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "Badges em Progresso",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildBadgeCard({
    required String title,
    required String description,
    required String points,
    double? progress,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (progress != null)
                  Column(
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress, color: Colors.blueAccent, backgroundColor: Colors.grey[200]),
                    ],
                  )
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
                  points,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.amber : Colors.black,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}