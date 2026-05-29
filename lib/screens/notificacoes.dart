import 'package:flutter/material.dart';

class Notificacoes extends StatelessWidget {
  const Notificacoes({super.key});

  final List<Map<String, dynamic>> _notificacoes = const [
    {
      "tipo": "perfil",
      "titulo": "Atualizou o perfil de acesso",
      "descricao":
          "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.",
      "remetente": "Ana Maria",
      "tempo": "59 min atrás",
    },
    {
      "tipo": "badge",
      "titulo": "Recebeu um novo Badge",
      "descricao":
          "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s.",
      "remetente": "System",
      "tempo": "12 horas atrás",
    },
    {
      "tipo": "validado",
      "titulo": "O seu Badge foi validado pelo Service Line Lider",
      "descricao":
          "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s.",
      "remetente": "System",
      "tempo": "12 horas atrás",
    },
    {
      "tipo": "expirado",
      "titulo": "Badges Expiraram",
      "descricao":
          "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s.",
      "remetente": "System",
      "tempo": "1 semana atrás",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
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
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4470AF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4470AF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: ListView(
                children: [
                  // Botão Voltar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        children: [
                          Icon(Icons.arrow_back, color: Color(0xFF39639C)),
                          SizedBox(width: 8),
                          Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  ..._notificacoes.map((n) => _notificacaoItem(n)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificacaoItem(Map<String, dynamic> n) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== Avatar / Ícone (Com largura definida para evitar erros de layout) ======
          SizedBox(
            width: 80, 
            child: Column(
              children: [
                _avatarIcone(n["tipo"], n["remetente"]),
                const SizedBox(height: 6),
                Text(
                  n["remetente"],
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis, // Evita que textos gigantes quebrem o layout
                ),
                const SizedBox(height: 2),
                Text(
                  n["tempo"],
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ====== Título + Descrição ======
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Alinhado à esquerda fica mais legível para textos longos
              children: [
                Text(
                  n["titulo"],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  n["descricao"],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarIcone(String tipo, String remetente) {
    if (tipo == "perfil") {
      return const CircleAvatar(
        radius: 28, // Reduzi ligeiramente o tamanho (de 38 para 28) para caber melhor em ecrãs pequenos
        backgroundColor: Color(0xFFDDE8F5),
        child: Icon(Icons.person, size: 32, color: Color(0xFF5B7FA6)),
      );
    } else if (tipo == "badge" || tipo == "validado") {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.green.shade400,
        // CORRIGIDO: weight agora é 700.0 (double)
        child: const Icon(Icons.check, size: 28, color: Colors.black87, weight: 700.0), 
      );
    } else {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.red.shade400,
        child: const Icon(Icons.priority_high, size: 28, color: Colors.white),
      );
    }
  }
}