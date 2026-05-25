import 'package:flutter/material.dart';

class BadgeDetalhe extends StatelessWidget {
  const BadgeDetalhe({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
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
                  Spacer(),
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

            // ================= CONTEÚDO COM SCROLL =================
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ====== BOTÃO VOLTAR ======
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF39639C)),
                        SizedBox(width: 8),
                        Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== CARD BADGE PRINCIPAL ======
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Color(0xFF39639C).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Color(0xFFEEEEEE),
                          child: Text("🏅", style: TextStyle(fontSize: 42)),
                        ),
                        SizedBox(height: 12),
                        Text(
                          "SAP Explorer",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== CARD DESCRIÇÃO ======
                  _borderedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Descrição",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                            children: [
                              TextSpan(
                                text:
                                    "Lorem Ipsum is simply dummy text of the printing and typesetting industry. "
                                    "Lorem Ipsum has been the industry's standard dummy. ",
                              ),
                              TextSpan(
                                text: "Ler mais...",
                                style: TextStyle(color: Color(0xFF39639C)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== NÍVEL + REQUISITOS (linha) ======
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Nível
                      Expanded(
                        flex: 4,
                        child: _borderedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Nível",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _nivelCircle("A", active: true),
                                  _nivelCircle("D"),
                                  _nivelCircle("B"),
                                  _nivelCircle("E"),
                                  _nivelCircle("C"),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(width: 12),

                      // Card Requisitos
                      Expanded(
                        flex: 6,
                        child: _borderedCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Requisitos",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              SizedBox(height: 12),
                              _requisitoItem("A1", "Completar formação Associada"),
                              SizedBox(height: 8),
                              _requisitoItem("A2", "Completar formação Associada"),
                              SizedBox(height: 8),
                              _requisitoItem("A3", "Completar formação Associada"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // ====== SEPARADOR + TÍTULO BADGES RELACIONADOS ======
                  Divider(thickness: 1, color: Colors.grey.shade300),
                  SizedBox(height: 8),
                  Text(
                    "Badges Relacionados",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Divider(thickness: 1, color: Colors.grey.shade300),

                  SizedBox(height: 12),

                  // ====== LISTA DE BADGES RELACIONADOS ======
                  _badgeRelacionadoCard(
                    titulo: "The Watchtower - Nível A",
                    subtitulo: "Observability & Performance Specialist",
                    subtitulo2: "Container Scout",
                    pontos: "10",
                    conquistado: false,
                  ),
                  SizedBox(height: 12),
                  _badgeRelacionadoCard(
                    titulo: "Container Scout - Nível A",
                    subtitulo: "Cloud Infrastructure Expert",
                    subtitulo2: "Platform Engineer",
                    pontos: "12",
                    conquistado: true,
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

  // ====== Widget: Card com borda azul ======
  Widget _borderedCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF39639C).withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }

  // ====== Widget: Círculo de nível ======
  Widget _nivelCircle(String label, {bool active = false}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? Color(0xFFE8C200) : Color(0xFFEEEEEE),
        border: Border.all(color: Colors.grey.shade300),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: active ? Colors.black : Colors.black54,
        ),
      ),
    );
  }

  // ====== Widget: Item de Requisito ======
  Widget _requisitoItem(String nivel, String texto) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Color(0xFFE8C200),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              nivel,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ====== Widget: Card de Badge Relacionado ======
  Widget _badgeRelacionadoCard({
    required String titulo,
    required String subtitulo,
    required String subtitulo2,
    required String pontos,
    required bool conquistado,
  }) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Color(0xFFF0F7FF),
                child: Text("🏅", style: TextStyle(fontSize: 26)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      subtitulo2,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text("Pontos", style: TextStyle(fontSize: 10, color: Colors.black54)),
                    SizedBox(height: 2),
                    Text(
                      pontos,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Divider(height: 1, color: Colors.grey.shade200),
          SizedBox(height: 8),
          Text(
            conquistado ? "Conquistado ✓" : "Por conquistar",
            style: TextStyle(
              fontSize: 12,
              color: conquistado ? Color(0xFF39639C) : Colors.grey,
              fontWeight: conquistado ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}