import 'package:flutter/material.dart';
import 'catalogo.dart'; 
import 'badges_progresso.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  Image.asset(
                    'assets/logo_softinsa.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade400,
                        child: const Icon(Icons.notifications, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade400,
                        child: const Icon(Icons.person, color: Colors.white, size: 18),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF4470AF), Color(0xFF3A5C94)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF39639C).withAlpha(76),
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
                                fontSize: 22, 
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),
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

                    // ================= BOTÃO CATÁLOGO =================
                    Center(
                      child: SizedBox(
                        width: 200,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: const StadiumBorder(),
                            elevation: 2,
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CatalogoPage()),
                            );
                          },
                          icon: const Icon(Icons.grid_view, size: 16),
                          label: const Text(
                            "Catálogo de Badges", 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ),
                    ),

                    // ================= SECÇÕES DE BADGES =================
                    // Nota: Passamos o "context" aqui para a função sectionHeader
                    sectionHeader(context, "Badges com progresso", "Tem 1 badge com progresso"),
                    
                    badgeCard(
                      title: "The Watchtower - Nível A",
                      description: "Observability & Performance Specialist",
                      points: 10,
                      progress: 0.7,
                    ),

                    sectionHeader(context, "Recomendação de Badge", "O nosso sistema recomenda:"),
                    
                    badgeCard(
                      title: "Script Initiate - Nível A",
                      description: "Automation & Deployment (CI/CD)",
                      points: 10,
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Obtenha este badge em 3 dias e ganhe o dobro dos pontos",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black),
                        ),
                      ),
                    ),

                    badgeCard(
                      title: "ERP Insight Specialist - Nível D",
                      description: "Introdução ao SAP...",
                      points: 42,
                      highlight: true,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= WIDGETS AUXILIARES =================

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
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(38),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 8),
                        overflow: TextOverflow.ellipsis,
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

  // ATUALIZAÇÃO AQUI: Adicionado BuildContext context
  Widget sectionHeader(BuildContext context, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          TextButton(
            onPressed: () {
              // Navega para a página de progresso
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BadgeProgressoPage()),
              );
            },
            child: const Text("Ver Todos", style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }

  Widget badgeCard({
    required String title,
    required String description,
    required int points,
    double? progress,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(51)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFF0F7FF),
            child: Text("🏅", style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF39639C)),
                      ),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlight ? Colors.amber : const Color(0xFF39639C),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Pontos", style: TextStyle(fontSize: 9, color: Colors.grey)),
                Text(
                  "$points",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: highlight ? Colors.amber.shade700 : Colors.black,
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