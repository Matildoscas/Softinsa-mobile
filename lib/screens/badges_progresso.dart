import 'package:flutter/material.dart';

class BadgesEmProgresso extends StatefulWidget {
  const BadgesEmProgresso({super.key});

  @override
  State<BadgesEmProgresso> createState() => _BadgesEmProgressoState();
}

class _BadgesEmProgressoState extends State<BadgesEmProgresso> {
  String? _nivelSelecionado;
  String? _tipoSelecionado;

  final List<String> _niveis = ["A", "B", "C", "D", "E"];
  final List<String> _tipos = ["Comum", "Especial"];

  // Lista de badges em progresso (simulada)
  final List<Map<String, dynamic>> _badges = [
    {
      "titulo": "The Watchtower - Nivel A",
      "subtitulo": "Observability & Performance Specialist",
      "pontos": 10,
      "progresso": 0.70,
      "percentagem": "70%",
      "nivel": "A",
      "tipo": "Comum",
    },
    {
      "titulo": "Container Scout - Nivel B",
      "subtitulo": "Cloud Infrastructure Expert",
      "pontos": 15,
      "progresso": 0.40,
      "percentagem": "40%",
      "nivel": "B",
      "tipo": "Especial",
    },
    {
      "titulo": "SAP Explorer - Nivel A",
      "subtitulo": "Introdução ao SAP: estrutura e módulos",
      "pontos": 10,
      "progresso": 0.55,
      "percentagem": "55%",
      "nivel": "A",
      "tipo": "Comum",
    },
  ];

  List<Map<String, dynamic>> get _badgesFiltrados {
    return _badges.where((b) {
      final nivelOk = _nivelSelecionado == null || b["nivel"] == _nivelSelecionado;
      final tipoOk = _tipoSelecionado == null || b["tipo"] == _tipoSelecionado;
      return nivelOk && tipoOk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _badgesFiltrados;

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

                  // ====== TÍTULO ======
                  Text(
                    "Badges em Progresso",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Tem ${filtrados.length} badge${filtrados.length == 1 ? '' : 's'} em progresso",
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),

                  SizedBox(height: 20),

                  // ====== FILTROS ======
                  Row(
                    children: [
                      Expanded(
                        child: _filtroDropdown(
                          label: "Filtrar por Nível",
                          valor: _nivelSelecionado,
                          opcoes: _niveis,
                          onChanged: (v) => setState(() => _nivelSelecionado = v),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _filtroDropdown(
                          label: "Tipo de badge",
                          valor: _tipoSelecionado,
                          opcoes: _tipos,
                          onChanged: (v) => setState(() => _tipoSelecionado = v),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  Divider(color: Colors.grey.shade300),

                  SizedBox(height: 12),

                  // ====== LISTA DE BADGES ======
                  if (filtrados.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                        child: Text(
                          "Nenhum badge encontrado",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ...filtrados.map((badge) => _badgeProgressoCard(badge)),

                  SizedBox(height: 20),

                  Divider(color: Colors.grey.shade300),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Widget: Dropdown de Filtro ======
  Widget _filtroDropdown({
    required String label,
    required String? valor,
    required List<String> opcoes,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: 16, color: Colors.black87),
            SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 6),
        Container(
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: valor,
              hint: Text("", style: TextStyle(fontSize: 13)),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text("Todos", style: TextStyle(fontSize: 13)),
                ),
                ...opcoes.map(
                  (o) => DropdownMenuItem<String>(
                    value: o,
                    child: Text(o, style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // ====== Widget: Card de Badge em Progresso ======
  Widget _badgeProgressoCard(Map<String, dynamic> badge) {
    return Container(
      margin: EdgeInsets.only(bottom: 14),
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
              // Ícone do badge
              CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFF0F7FF),
                child: Text("🏅", style: TextStyle(fontSize: 28)),
              ),
              SizedBox(width: 12),
              // Título e subtítulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge["titulo"],
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    SizedBox(height: 3),
                    Text(
                      badge["subtitulo"],
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              // Box de pontos
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF39639C), width: 1.5),
                ),
                child: Column(
                  children: [
                    Text("Pontos", style: TextStyle(fontSize: 10, color: Colors.black87)),
                    SizedBox(height: 2),
                    Text(
                      "${badge["pontos"]}",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 12),

          // Barra de progresso
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: badge["progresso"],
                  minHeight: 14,
                  backgroundColor: Color(0xFFE0E0E0),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black87),
                ),
              ),
              Text(
                badge["percentagem"],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}