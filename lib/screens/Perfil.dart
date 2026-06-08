import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/utilizador_provider.dart';

class Perfil extends StatelessWidget {
  const Perfil({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        // O Consumer fica à escuta do Provider para redesenhar o ecrã se houver Sync em background
        child: Consumer<UtilizadorProvider>(
          builder: (context, provider, child) {
            
            // Extração segura dos dados guardados na cache do SQFlite local
            final dashboard = provider.dashboard;
            final consultor = dashboard['consultor'] ?? {};
            
            // Mapeamento dinâmico baseado nos campos oficiais do teu pgAdmin/JSON
            final String nomeConsultor = dashboard['nome_completo'] ?? 'Consultor';
            final String emailConsultor = dashboard['email'] ?? 'Sem e-mail registado';
            final String progressoNivel = consultor['progresso_nivel'] ?? 'Nível Inicial';
            final String pontosAtuais = (consultor['pontos_atuais'] ?? 0).toString();

            return Column(
              children: [
                // ================= HEADER COM PESQUISA =================
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Clicar no logótipo remove o ecrã da stack e regressa à HomePage
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          "SOFTINSA",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF39639C),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const TextField(
                            decoration: InputDecoration(
                              hintText: "Pesquisar no perfil...",
                              prefixIcon: Icon(Icons.search, color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= CARD INFORMATIVO DO CONSULTOR =================
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 35,
                          backgroundColor: Color(0xFF39639C),
                          child: Icon(Icons.person, size: 45, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeConsultor,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                emailConsultor,
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Progresso: $progressoNivel",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ================= TÍTULO DA LISTA DE BADGES =================
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Os Meus Badges Atribuídos",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // ================= LISTA DINÂMICA OFFLINE-FIRST =================
                Expanded(
                  child: provider.badgesProgresso.isEmpty
                      ? const Center(
                          child: Text(
                            "Ainda não existem badges guardados localmente.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: provider.badgesProgresso.length,
                          itemBuilder: (context, index) {
                            final badge = provider.badgesProgresso[index];
                            return _buildBadgeCard(
                              title: badge['nome_badge'] ?? 'Badge Gamificado',
                              description: badge['descricao_badge_modelo'] ?? 'Sincronizado da plataforma Softinsa.',
                              points: pontosAtuais,
                              date: badge['data_atribuicao'] ?? 'Pendente',
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Card modular de Badges adaptado para o teu design gráfico original
  Widget _buildBadgeCard({
    required String title,
    required String description,
    required String points,
    required String date,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFE8F0FE),
                child: Icon(Icons.workspace_premium, color: Color(0xFF39639C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF39639C)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text("Pontos", style: TextStyle(fontSize: 10)),
                    Text(
                      points,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          Text(
            "Conquistado a: $date",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}