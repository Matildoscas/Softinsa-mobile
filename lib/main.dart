import 'package:flutter/material.dart'; // Importa a biblioteca principal do Flutter

void main() {
  runApp(MyApp()); // Inicializa a app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: HomePage(), // Define a página inicial
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7), // Cor de fundo semelhante ao Figma
      body: SafeArea( // Garante que não invade notch / status bar
        child: Column(
          children: [

            // ================= HEADER =================
            Container(
              color: Colors.white, // Fundo branco
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Espaçamento interno
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaço entre elementos
                children: [

                  // LOGO
                  Text(
                    "SOFTINSA", // Nome (substitui SVG)
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF39639C),
                    ),
                  ),

                  // ICONES DIREITA
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue, // Fundo azul
                        child: Icon(Icons.notifications, color: Colors.white, size: 18), // Sino
                      ),
                      SizedBox(width: 10), // Espaço entre ícones
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Icon(Icons.person, color: Colors.white, size: 18), // Utilizador
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView( // Permite scroll
                child: Column(
                  children: [

                   // ================= WELCOME CARD  =================
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30), // Aumentado de 16 para 30
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4470AF), Color(0xFF3A5C94)],
                    ),
                    borderRadius: BorderRadius.circular(24), // Cantos ligeiramente mais arredondados
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF39639C).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Bom dia, Utilizador!",
                        style: TextStyle(
                            color: Colors.white, 
                            fontSize: 22, // Texto maior
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24), // Mais espaço interno
                      
                      // LINHA DE BOTÕES
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          buildInfoButton(
                            icon: Icons.emoji_events,
                            title: "Badges",
                            subtitle: "5 obtidos",
                            onTap: () {},
                          ),
                          buildInfoButton(
                            icon: Icons.star,
                            title: "Pontos",
                            subtitle: "90 total",
                            onTap: () {},
                          ),
                          buildInfoButton(
                            icon: Icons.note,
                            title: "Lembretes",
                            subtitle: "Ver mais",
                            onTap: () {},
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                   // ================= BOTÃO CATÁLOGO (MAIS PEQUENO E EQUILIBRADO) =================
Center(
  child: SizedBox(
    width: 200, // Largura fixa para não ocupar o ecrã todo
    height: 40,  // Altura reduzida
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        side: BorderSide(color: Colors.grey.shade300), // Borda fina para definição
        shape: const StadiumBorder(),
        elevation: 2,
        padding: EdgeInsets.zero, // Remove padding interno extra
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CatalogoPage()),
        );
      },
      icon: const Icon(Icons.grid_view, size: 16), // Ícone menor
      label: const Text(
        "Catálogo de Badges", 
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
      ),
    ),
  ),
),


                    // ================= SECÇÃO =================
                    sectionHeader("Badges com progresso", "Tem 1 badge com progresso"),

                    badgeCard(
                      title: "The Watchtower - Nível A",
                      description: "Observability & Performance Specialist",
                      points: 10,
                      progress: 0.7,
                    ),

                    // ================= OUTRA SECÇÃO =================
                    sectionHeader("Recomendação de Badge", "O nosso sistema recomenda:"),

                    badgeCard(
                      title: "Script Initiate - Nível A",
                      description: "Automation & Deployment (CI/CD)",
                      points: 10,
                    ),

                    // ================= ESPECIAL =================
                    Padding(
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

  // ================= BOTÃO DE INFORMAÇÃO =================
  Widget buildInfoButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded( // Faz os 3 ocuparem espaço igual
      child: GestureDetector(
        onTap: onTap, // Permite clique
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4), // Espaço entre botões
          padding: EdgeInsets.all(10), // Espaçamento interno
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), // Fundo semi-transparente (igual Figma)
            borderRadius: BorderRadius.circular(16), // Cantos arredondados
          ),
          child: Row(
            children: [

              // Ícone dentro de mini caixa
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Caixa do ícone
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),

              SizedBox(width: 8),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER DE SECÇÃO =================
  Widget sectionHeader(String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Espaçamento
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaço entre elementos
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), // Título
              Text(subtitle, style: TextStyle(fontSize: 12)), // Subtítulo
            ],
          ),
          TextButton(
            onPressed: () {}, // Botão "Ver todos"
            child: Text("Ver Todos"),
          )
        ],
      ),
    );
  }

  // ================= CARD DE BADGE =================
  Widget badgeCard({
    required String title,
    required String description,
    required int points,
    double? progress,
    bool highlight = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margem
      padding: EdgeInsets.all(12), // Padding interno
      decoration: BoxDecoration(
        color: Colors.white, // Fundo branco
        borderRadius: BorderRadius.circular(12), // Bordas arredondadas
        border: Border.all(color: Colors.grey.shade300), // Borda leve
      ),
      child: Row(
        children: [

          // ICONE
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade50,
            child: Text("🏅", style: TextStyle(fontSize: 24)), // Emoji
          ),

          SizedBox(width: 10),

          // TEXTO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey)),

                // PROGRESS BAR (se existir)
                if (progress != null)
                  Column(
                    children: [
                      SizedBox(height: 6),
                      LinearProgressIndicator(value: progress), // Barra de progresso
                    ],
                  )
              ],
            ),
          ),

          // PONTOS
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text("Pontos", style: TextStyle(fontSize: 10)),
                Text(
                  "$points",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.amber : Colors.black, // Destaque amarelo
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