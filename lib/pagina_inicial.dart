import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    // ===== DADOS DA BD =====
    String nomeCompleto = userData['nome'] ?? 'Utilizador';
    String primeiroNome = nomeCompleto.split(' ')[0];
    int pontos = userData['pontos'] ?? 0;
    int totalBadges = userData['badges'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [

            // ================= HEADER =================
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
                    children: const [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.notifications, color: Colors.white, size: 18),
                      ),
                      SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView(
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
                            "Bom dia, $primeiroNome!",
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
                                onTap: () {},
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
                      onPressed: () {},
                      icon: const Icon(Icons.grid_view),
                      label: const Text("Catálogo de Badges"),
                    ),

                    const SizedBox(height: 20),

                    // ================= BADGES COM PROGRESSO =================
                    sectionHeader("Badges com progresso", "Tem 1 badge com progresso"),

                    badgeCard(
                      title: "The Watchtower - Nível A",
                      description: "Observability & Performance Specialist",
                      points: 10,
                      progress: 0.7,
                    ),

                    // ================= RECOMENDAÇÃO =================
                    sectionHeader("Recomendação de Badge", "O nosso sistema recomenda:"),

                    badgeCard(
                      title: "Script Initiate - Nível A",
                      description: "Automation & Deployment (CI/CD)",
                      points: 10,
                    ),

                    // ================= ESPECIAL =================
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Obtenha este badge em 3 dias e ganhe o dobro dos pontos",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),

                    badgeCard(
                      title: "ERP Insight Specialist - Nível D",
                      description: "Introdução ao SAP...",
                      points: 42,
                      highlight: true,
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

  // ================= BOTÃO INFO =================
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
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                    if (subtitle != null)
                      Text(subtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
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
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(subtitle, style: const TextStyle(fontSize: 12)),
            ],
          ),
          TextButton(
            onPressed: () {},
            child: const Text("Ver Todos"),
          )
        ],
      ),
    );
  }

  // ================= CARD BADGE =================
  Widget badgeCard({
    required String title,
    required String description,
    required int points,
    double? progress,
    bool highlight = false,
  }) {
    return Container(
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
                Text(description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),

                if (progress != null)
                  Column(
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress),
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
                  "$points",
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