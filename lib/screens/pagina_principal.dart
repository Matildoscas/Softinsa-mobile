import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HomePage({super.key, required this.userData});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  List<Map<String, dynamic>> progresso = [];
  List<Map<String, dynamic>> recomendados = [];
  Map<String, dynamic>? especial;

  @override
  void initState() {
    super.initState();
    carregarDados();
  }

  Future<void> carregarDados() async {
    final api = ApiService();

    final p = await api.getBadgesProgresso(
      widget.userData['id_utilizador'],
    );

    final r = await api.getBadgesRecomendados(
      widget.userData['id_utilizador'],
    );

    final e = await api.getBadgeEspecial();

    final dashboard = await api.getDashboard(
      widget.userData['id_utilizador'],
    );

    setState(() {
      progresso = p;
      recomendados = r;
      especial = e;

      widget.userData['pontos'] =
        int.parse(dashboard['total_pontos'].toString());

      widget.userData['badges'] =
        int.parse(dashboard['total_badges'].toString());
    });
  }

  @override
  Widget build(BuildContext context) {

    String nomeCompleto = widget.userData['nome_completo'] ?? 'Utilizador';
    String primeiroNome = nomeCompleto.split(' ')[0];
    int pontos = widget.userData['pontos'] ?? 0;
    int totalBadges = widget.userData['badges'] ?? 0;

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
                    'lib/img/logo.png',
                    height: 35, // Ajustei para 40 para não esticar demasiado a barra, mas podes usar 70 se preferires
                    fit: BoxFit.contain,
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

                    // ================= PROGRESSO =================
                    sectionHeader("Badges com progresso", "Em desenvolvimento"),

                    if (progresso.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Sem progresso de momento"),
                      )
                    else
                      ...progresso.map((b) => badgeCard(
                        title: b['nome'],
                        description: b['descricao'],
                        points: b['pontos'],
                        progress: b['progress'], // 🔥 agora 0
                      )),

                    // ================= RECOMENDAÇÃO =================
                    sectionHeader("Recomendação de Badge", "Sugestão baseada na sua área"),

                    if (recomendados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Sem recomendações disponíveis"),
                      )
                    else
                      ...recomendados.map((b) => badgeCard(
                        title: b['nome'],
                        description: b['descricao'],
                        points: b['pontos'],
                      )),

                    // ================= ESPECIAL =================
                    if (especial != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          "Obtenha este badge em ${especial!['dias']} dias e ganhe o dobro dos pontos",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),

                      badgeCard(
                        title: especial!['nome'],
                        description: especial!['descricao'],
                        points: especial!['pontos'],
                        highlight: true,
                      ),
                    ],

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
        height: 100, // <--- Definimos uma altura fixa para todos serem iguais
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
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
            // Usamos um widget invisível ou o texto para manter o alinhamento
            Text(
              subtitle ?? "", // Se não houver subtítulo, fica uma string vazia
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
