import 'package:flutter/material.dart';

class BadgeProgressoPage extends StatelessWidget {
  const BadgeProgressoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header Softinsa
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset(
                  'assets/logo_softinsa.png',
                  height: 40, // Ajusta a altura conforme necessário
                  fit: BoxFit.contain,
                ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade400,
                        child: const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue.shade400,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 18,
                            color: Color(0xFF39639C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Voltar",
                            style: TextStyle(color: Color(0xFF39639C)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Badges em Progresso",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Text(
                      "Tem 1 badges em progresso",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),

                    const Divider(
                      color: Colors.grey,
                      thickness: 0.5,
                    ), // Linha superior
                    // CARD DO BADGE EM PROGRESSO
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const CircleAvatar(
                                  radius: 35,
                                  backgroundColor: Color(0xFFF0F7FF),
                                  child: Text(
                                    "🏅",
                                    style: TextStyle(fontSize: 30),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "The Watchtower - Nível A",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Text(
                                        "Observability & Performance Specialist",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Caixa de Pontos
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF39639C),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Column(
                                    children: [
                                      Text(
                                        "Pontos",
                                        style: TextStyle(fontSize: 10),
                                      ),
                                      Text(
                                        "10",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // BARRA DE PROGRESSO COM TEXTO (Stack)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 5,
                                child: LinearProgressIndicator(
                                  value: 0.7,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(
                      color: Colors.grey,
                      thickness: 0.5,
                    ), // Linha inferior
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
