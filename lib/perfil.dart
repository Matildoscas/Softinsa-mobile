import 'package:flutter/material.dart';

class Perfil extends StatelessWidget {
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
                  // Logo que volta para a Home ao clicar
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

            // ================= CARD PERFIL (AZUL) =================
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF4470AF),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    child: Icon(
                      Icons.person_outline,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Ana Luisa",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // ================= BOTÕES PROGRESSO / HISTÓRICO =================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: actionButton(Icons.trending_up, "Progresso")),
                  SizedBox(width: 12),
                  Expanded(
                    child: actionButton(Icons.history, "Histórico Badges"),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20),

            // ================= SECÇÃO BADGES =================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Os seus badges",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Tem 5/12 badges",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed:
                        () {}, // Aqui abriria a página de todos os badges
                    icon: Icon(Icons.menu_book, size: 16),
                    label: Text("Ver Todos"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ],
              ),
            ),

            // ================= LISTA DE BADGES (SCROLL) =================
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  profileBadgeCard(
                    "SAP Explorer - Nível A",
                    "10",
                    "03/02/2025",
                  ),
                  profileBadgeCard(
                    "Module Navigator - Nível B",
                    "13",
                    "12/02/2025",
                  ),
                  profileBadgeCard(
                    "Business Process Master - Nível C",
                    "16",
                    "28/03/2025",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget para os botões arredondados de Progresso/Histórico
  Widget actionButton(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black87),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Widget para o Card de Badge específico do Perfil
  Widget profileBadgeCard(String title, String points, String date) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Color(0xFFF0F7FF),
                child: Text("🏅", style: TextStyle(fontSize: 20)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "Introdução ao SAP: estrutura, módulos principais...",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFF39639C)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text("Pontos", style: TextStyle(fontSize: 10)),
                    Text(points, style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 20),
          Text(
            "Conquistado a $date",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
