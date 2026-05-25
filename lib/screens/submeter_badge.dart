import 'package:flutter/material.dart';

class SubmeterBadge extends StatefulWidget {
  const SubmeterBadge({super.key});

  @override
  State<SubmeterBadge> createState() => _SubmeterBadgeState();
}

class _SubmeterBadgeState extends State<SubmeterBadge> {
  final TextEditingController _descricaoController = TextEditingController();
  String? _ficheiroAnexado;
  int _charCount = 0;
  final int _minChars = 500;

  @override
  void initState() {
    super.initState();
    _descricaoController.addListener(() {
      setState(() {
        _charCount = _descricaoController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    super.dispose();
  }

  bool get _podeSubmeter => _charCount >= _minChars && _ficheiroAnexado != null;

  void _submeter() {
    if (_podeSubmeter) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Badge submetido para validação!"),
          backgroundColor: Color(0xFF4470AF),
        ),
      );
    }
  }

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
                          "Business Process Master",
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

                  // ====== CARD NÍVEL ======
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Color(0xFF39639C).withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Nível",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        // Círculos A B C D E
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ["A", "B", "C", "D", "E"]
                              .map((l) => _nivelCircle(l))
                              .toList(),
                        ),
                        SizedBox(height: 12),
                        // Legenda em 2 colunas
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _legendaItem("A - Júnior"),
                                  _legendaItem("B - Intermedio"),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _legendaItem("C - Sénior"),
                                  _legendaItem("D - Espicialista"),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _legendaItem("E - Lider Conhecimento"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== SECÇÃO DESCRIÇÃO ======
                  Row(
                    children: [
                      Icon(Icons.description_outlined, color: Colors.black87, size: 20),
                      SizedBox(width: 6),
                      Text(
                        "Descrição",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _descricaoController,
                      maxLines: 7,
                      decoration: InputDecoration(
                        hintText: "Descreva o que aprendeu e como aplicou os conhecimentos...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  SizedBox(height: 6),

                  Text(
                    "Mínimo 500 caracteres ($_charCount/$_minChars)",
                    style: TextStyle(
                      fontSize: 12,
                      color: _charCount >= _minChars
                          ? Colors.green.shade600
                          : Colors.grey,
                    ),
                  ),

                  SizedBox(height: 16),

                  // ====== SECÇÃO ANEXAR FICHEIRO ======
                  Row(
                    children: [
                      Icon(Icons.upload_outlined, color: Colors.black87, size: 20),
                      SizedBox(width: 6),
                      Text(
                        "Anexar Ficheiro",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  GestureDetector(
                    onTap: () {
                      // Simulação de seleção de ficheiro
                      setState(() {
                        _ficheiroAnexado = "documento_evidencia.pdf";
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFFF0F4FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _ficheiroAnexado != null
                              ? Color(0xFF39639C)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: _ficheiroAnexado != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Color(0xFF39639C), size: 22),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _ficheiroAnexado!,
                                    style: TextStyle(
                                      color: Color(0xFF39639C),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Icon(Icons.upload_outlined, color: Colors.grey, size: 28),
                                SizedBox(height: 6),
                                Text(
                                  "Clique para fazer upload",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "PDF, DOC, DOCX, JPG, PNG (max 10MB)",
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),

            // ================= BOTÃO SUBMETER (FIXO EM BAIXO) =================
            Container(
              color: Color(0xFFF7F7F7),
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _podeSubmeter ? _submeter : null,
                      icon: Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        "Submeter para Validação",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2C5FD4),
                        disabledBackgroundColor: Color(0xFF2C5FD4).withValues(alpha: 0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  if (!_podeSubmeter)
                    Text(
                      "Preencha todos os campos para submeter",
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Widget: Círculo de nível ======
  Widget _nivelCircle(String label) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Color(0xFF39639C).withValues(alpha: 0.6), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  // ====== Widget: Legenda de nível ======
  Widget _legendaItem(String texto) {
    return Padding(
      padding: EdgeInsets.only(bottom: 2),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
    );
  }
}