import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class SubmeterBadge extends StatefulWidget {
  // 1. Definir os dados que a página precisa de receber
  final String badgeName;
  final int idNivelBadge;

  const SubmeterBadge({
    super.key,
    required this.badgeName,
    required this.idNivelBadge,
  });

  @override
  State<SubmeterBadge> createState() => _SubmeterBadgeState();
}

class _SubmeterBadgeState extends State<SubmeterBadge> {
  final TextEditingController _descricaoController = TextEditingController();
  
  // Variáveis para o ficheiro real
  File? _ficheiroSelecionado;
  String? _nomeFicheiro;
  
  int _charCount = 0;
  final int _minChars = 500;
  bool _isLoading = false;

  // ================= AS TUAS FUNÇÕES DE LÓGICA =================
  String obterNivel(dynamic idNivel) {
    switch (idNivel) {
      case 1:
        return 'A';
      case 2:
        return 'B';
      case 3:
        return 'C';
      case 4:
        return 'D';
      case 5:
        return 'E';
      default:
        return '-';
    }
  }

  Color obterCorNivel(String letraNivel) {
    switch (letraNivel) {
      case 'A':
      case 'B':
      case 'C':
      case 'D':
        return const Color(0xFF2E7D32); 
      case 'E':
        return const Color.fromARGB(255, 213, 181, 21); 
      default:
        return Colors.grey;
    }
  }

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

  bool get _podeSubmeter => _charCount >= _minChars && _ficheiroSelecionado != null && !_isLoading;

  // ================= LÓGICA: SELECIONAR FICHEIRO REAL =================
  Future<void> _selecionarFicheiro() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _ficheiroSelecionado = File(result.files.single.path!);
          _nomeFicheiro = result.files.single.name;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao selecionar ficheiro: $e")),
      );
    }
  }

  // ================= LÓGICA: ENVIO PARA A BASE DE DADOS =================
  Future<void> _submeterEvidenciaBD() async {
    setState(() => _isLoading = true);

    try {
      String mockStorageUrl = "storage/evidencias/$_nomeFicheiro";
      // 2. Agora usamos o widget.idNivelBadge que veio da tela anterior
      String letraNivelAtual = obterNivel(widget.idNivelBadge);

      // Aqui farias o envio do objeto para o teu banco de dados
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Evidências enviadas com sucesso!"),
          backgroundColor: Color(0xFF4470AF),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro ao submeter: $e"),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submeter() {
    if (_podeSubmeter) {
      _submeterEvidenciaBD();
    }
  }

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
                    decoration: const BoxDecoration(color: Color(0xFF4470AF), shape: BoxShape.circle),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: Color(0xFF4470AF), shape: BoxShape.circle),
                    child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),

            // ================= CONTEÚDO COM SCROLL =================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ====== BOTÃO VOLTAR ======
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF39639C)),
                        SizedBox(width: 8),
                        Text("Voltar", style: TextStyle(color: Color(0xFF39639C))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ====== CARD BADGE PRINCIPAL ======
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF39639C).withAlpha(102)),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 45,
                          backgroundColor: Color(0xFFEEEEEE),
                          child: Text("🏅", style: TextStyle(fontSize: 42)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.badgeName, // 3. Usa o nome dinâmico aqui
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ====== CARD NÍVEL (DINÂMICO E CONSISTENTE) ======
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF39639C).withAlpha(102)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Nível",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ["A", "B", "C", "D", "E"]
                              .map((l) => _nivelCircle(l))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
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

                  const SizedBox(height: 16),

                  // ====== SECÇÃO DESCRIÇÃO ======
                  const Row(
                    children: [
                      Icon(Icons.description_outlined, color: Colors.black87, size: 20),
                      SizedBox(width: 6),
                      Text("Descrição", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _descricaoController,
                      maxLines: 7,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: "Descreva o que aprendeu e como aplicou os conhecimentos...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Mínimo 500 caracteres ($_charCount/$_minChars)",
                    style: TextStyle(
                      fontSize: 12,
                      color: _charCount >= _minChars ? Colors.green.shade600 : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ====== SECÇÃO ANEXAR FICHEIRO ======
                  const Row(
                    children: [
                      Icon(Icons.upload_outlined, color: Colors.black87, size: 20),
                      SizedBox(width: 6),
                      Text("Anexar Ficheiro", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  GestureDetector(
                    onTap: _isLoading ? null : _selecionarFicheiro,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _nomeFicheiro != null ? const Color(0xFF39639C) : Colors.grey.shade300,
                        ),
                      ),
                      child: _nomeFicheiro != null
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF39639C), size: 22),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _nomeFicheiro!,
                                    style: const TextStyle(
                                      color: Color(0xFF39639C),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _ficheiroSelecionado = null;
                                      _nomeFicheiro = null;
                                    });
                                  },
                                  child: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
                                )
                              ],
                            )
                          : const Column(
                              children: [
                                Icon(Icons.upload_outlined, color: Colors.grey, size: 28),
                                SizedBox(height: 6),
                                Text(
                                  "Clique para fazer upload",
                                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: Colors.black87),
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

                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ================= BOTÃO SUBMETER =================
            Container(
              color: const Color(0xFFF7F7F7),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _podeSubmeter ? _submeter : null,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        _isLoading ? "A guardar..." : "Submeter para Validação",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C5FD4),
                        disabledBackgroundColor: const Color(0xFF2C5FD4).withAlpha(153),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!_podeSubmeter && !_isLoading)
                    Text(
                      "Preencha todos os campos para submeter",
                      style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== Widget: Círculo de nível adaptado às tuas funções ======
  Widget _nivelCircle(String label) {
    // 4. Agora usa widget.idNivelBadge dinamicamente
    String letraNivelBadge = obterNivel(widget.idNivelBadge);
    
    bool isCurrent = letraNivelBadge == label;
    Color corCirculo = isCurrent ? obterCorNivel(label) : Colors.grey.shade300;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCurrent ? corCirculo : Colors.white,
        border: Border.all(
          color: isCurrent ? corCirculo : Colors.grey.shade400,
          width: isCurrent ? 2.5 : 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isCurrent ? Colors.white : Colors.black54,
        ),
      ),
    );
  }

  Widget _legendaItem(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(texto, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
    );
  }
}