import 'package:flutter/material.dart';

class BadgeConquistadosPage extends StatelessWidget {
  const BadgeConquistadosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/logo_softinsa.png', height: 40, fit: BoxFit.contain),
                  Row(
                    children: [
                      _headerIcon(Icons.notifications),
                      const SizedBox(width: 10),
                      _headerIcon(Icons.person),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _backButton(context),
                    const SizedBox(height: 20),
                    const Text(
                      "Todos os seus Badges conquistados",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF2D3E50)),
                    ),
                    const Text("Tem 4/12 badges", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    
                    const SizedBox(height: 20),
                    
                    // FILTROS
                    Row(
                      children: [
                        Expanded(child: _filterField("Filtrar por Nível")),
                        const SizedBox(width: 15),
                        Expanded(child: _filterField("Tipo de badge")),
                      ],
                    ),
                    
                    const SizedBox(height: 20),

                    // LISTA DE CARDS (Envolvidos numa borda azul conforme a imagem)
                    Container(
                      padding: const EdgeInsets.all(8),
                        child: Column(
                        children: [
                          _badgeConquistadoCard("SAP Explorer - Nivel A", "03/02/2025", 10, "🏆"),
                          _badgeConquistadoCard("Module Navigator - Nivel B", "12/03/2025", 15, "🎖️"),
                          _badgeConquistadoCard("Business Process Master - Nivel C", "28/03/2025", 20, "🏅"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ================= FOOTER =================
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Widget para os filtros
  Widget _filterField(String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.filter_alt_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 35,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade100),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }

  // Widget para o Card de Conquista
  Widget _badgeConquistadoCard(String title, String data, int pontos, String emoji) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFFF0F7FF),
                  child: Text(emoji, style: const TextStyle(fontSize: 25)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Text(
                        "Introdução ao SAP: estrutura, módulos principais, conceitos de ERP empresarial.",
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                _pontosWidget(pontos),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Text(
              "Conquistado a $data",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pontosWidget(int valor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF39639C)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Text("Pontos", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          Text("$valor", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _footerButton("Badges Comuns"),
          _footerButton("Badges Especiais"),
          _footerButton("Catálogo"),
        ],
      ),
    );
  }

  Widget _footerButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _headerIcon(IconData icon) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.shade400,
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _backButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: const Row(
        children: [
          Icon(Icons.arrow_back, size: 18, color: Color(0xFF39639C)),
          SizedBox(width: 8),
          Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
        ],
      ),
    );
  }
}