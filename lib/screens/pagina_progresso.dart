import 'package:flutter/material.dart';

class Progresso extends StatelessWidget {
  const Progresso({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER COM PESQUISA =================
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      "SOFTINSA",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF39639C),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Pesquisar...",
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // Ícone de notificações
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(0xFF4470AF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  ),
                  SizedBox(width: 8),
                  // Ícone de perfil
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Color(0xFF4470AF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person_outline, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // ================= BOTÃO VOLTAR =================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                child: Row(
                  children: [
                    Icon(Icons.arrow_back, color: Color(0xFF39639C)),
                    SizedBox(width: 8),
                    Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
                  ],
                ),
              ),
            ),

            SizedBox(height: 12),

            // ================= CONTEÚDO COM SCROLL =================
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ====== CARD PONTOS TOTAIS (AZUL) ======
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Color(0xFF4470AF),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.star, color: Colors.white, size: 32),
                        SizedBox(height: 8),
                        Text(
                          "Pontos Totais",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "90 pts",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== SECÇÃO LEARNING PATHS ======
                  _sectionCard(
                    title: "Progressos nas Learning Paths",
                    child: Column(
                      children: [
                        _learningPathItem(
                          "Application Operations",
                          0.75,
                          "75% Service Lines Concluídos",
                        ),
                        SizedBox(height: 14),
                        _learningPathItem(
                          "Sourcing & Talent Management e  Hybrid Cloud",
                          0.20,
                          "20% Service Lines Concluídos",
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== SECÇÃO BADGES ======
                  _sectionCard(
                    title: "Progressos dos Badges",
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _badgeProgressCircle("4/178", "Badges comuns"),
                        _badgeProgressCircle("1/60", "Badges especiais"),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== SECÇÃO RANKING ======
                  _sectionCard(
                    title: "Ranking de conquistas",
                    child: Column(
                      children: [
                        _rankingItem(
                          "S/4HANA Architect - Nível E",
                          "+30 pts",
                          Colors.amber,
                          Icons.emoji_events,
                        ),
                        Divider(height: 16),
                        _rankingItem(
                          "Business Process Master - Nível C",
                          "+16 pts",
                          Colors.blueGrey.shade300,
                          Icons.emoji_events,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Widget: Card de Secção ======
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // ====== Widget: Item de Learning Path com barra de progresso ======
  Widget _learningPathItem(String title, double progress, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4470AF)),
          ),
        ),
        SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // ====== Widget: Círculo de progresso de badges ======
  Widget _badgeProgressCircle(String value, String label) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Color(0xFF4470AF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ====== Widget: Item do Ranking ======
  Widget _rankingItem(String title, String points, Color medalColor, IconData icon) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(0xFFF0F7FF),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: medalColor, size: 22),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Color(0xFF39639C)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            "Ganhou $points",
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF39639C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}