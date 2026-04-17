import 'package:flutter/material.dart';
import 'perfil.dart'; // Import necessário para o botão de perfil funcionar

class Progresso extends StatelessWidget {
  const Progresso({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ================= HEADER =================
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Logo -> Volta para o Main (HomePage)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text(
                        "SOFTINSA",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF39639C),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Ícone Notificação
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF1E90FF),
                      child: Icon(Icons.notifications, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    // Ícone Perfil -> Vai para perfil.dart
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Perfil()),
                        );
                      },
                      child: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF1E90FF),
                        child: Icon(Icons.person, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              // ================= BOTÃO VOLTAR =================
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () => Navigator.pop(context), // Volta exatamente para onde estava
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back, color: Color(0xFF39639C)),
                      SizedBox(width: 8),
                      Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
                    ],
                  ),
                ),
              ),

              // ================= CARD PONTOS TOTAIS =================
              Container(
                width: 160,
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4470AF),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars, color: Colors.white, size: 20),
                        SizedBox(width: 5),
                        Text("Pontos Totais", style: TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      "90 pts",
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              // ================= SEÇÃO: PROGRESSOS LEARNING PATHS =================
              sectionContainer("Progressos nas Learning Paths", [
                progressItem("Application Operations", 0.75, "75% Service Lines Concluídos"),
                const SizedBox(height: 15),
                progressItem("Sourcing & Talent Management e Hybrid Cloud", 0.20, "20% Service Lines Concluídos"),
              ]),

              // ================= SEÇÃO: PROGRESSOS DOS BADGES =================
              sectionContainer("Progressos dos Badges", [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    badgeCircle("4/178", "Badges comuns"),
                    badgeCircle("1/60", "Badges especias", isSmaller: true),
                  ],
                ),
              ]),

              // ================= SEÇÃO: RANKING DE CONQUISTAS =================
              sectionContainer("Ranking de conquistas", [
                rankingItem("🏅", "S/4HANA Architect - Nivel E", "Ganhou +30 pts", Colors.amber.shade100),
                const SizedBox(height: 10),
                rankingItem("🥈", "Business Process Master - Nivel C", "Ganhou +16 pts", Colors.grey.shade200),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para os Containers brancos de cada seção
  Widget sectionContainer(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF39639C).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  // Widget para as barras de progresso
  Widget progressItem(String title, double value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4470AF)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
      ],
    );
  }

  // Widget para os círculos de badges
  Widget badgeCircle(String text, String subtext, {bool isSmaller = false}) {
    return Column(
      children: [
        Container(
          width: isSmaller ? 80 : 110,
          height: isSmaller ? 80 : 110,
          decoration: const BoxDecoration(
            color: Color(0xFF4470AF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        Text(subtext, style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
      ],
    );
  }

  // Widget para os itens do ranking
  Widget rankingItem(String emoji, String title, String pts, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: bgColor, child: Text(emoji)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(pts, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
            ],
          ),
        ],
      ),
    );
  }
}