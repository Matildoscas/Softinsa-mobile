import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/api_service.dart';

bool isEspecial(int nivel) => nivel == 5;
bool isComum(int nivel) => nivel >= 1 && nivel <= 4;

class ProgressoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProgressoPage({super.key, required this.userData});

  @override
  State<ProgressoPage> createState() => _ProgressoPageState();
}

class _ProgressoPageState extends State<ProgressoPage> {
  bool isLoading = true;

  int pontosTotal = 0;

  // Learning Paths
  List<Map<String, dynamic>> learningPaths = [];

  // Badges
  int badgesComuns = 0;
  int totalBadgesComuns = 0;
  int badgesEspeciais = 0;
  int totalBadgesEspeciais = 0;

  // Ranking
  List<Map<String, dynamic>> ranking = [];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final api = ApiService();
      final userId = widget.userData['id_utilizador'];

      final progresso = await api.getProgressoLearningPaths(userId);

      // 1. Todos os badges do catálogo (sem filtro de utilizador)
      final todos = await api.getTodosBadges();

      // 2. Badges conquistados/em progresso do utilizador
      final obtidos = await api.getBadgesConquistados(widget.userData['id_utilizador']);

      int pontosTotalCalc = 0;

      for (final b in obtidos) {
        final pontos = int.tryParse(b['pontos']?.toString() ?? '0') ?? 0;
        pontosTotalCalc += pontos;
      }

      int comunsTotal = 0;
      int especiaisTotal = 0;

      for (final b in todos) {
        final nivel = int.tryParse(b['id_nivel'].toString()) ?? 0;

        if (nivel == 5) {
          especiaisTotal++;
        } else if (nivel >= 1 && nivel <= 4) {
          comunsTotal++;
        }
      }

      int comunsObtidos = 0;
      int especiaisObtidos = 0;

      for (final b in obtidos) {
        final nivel = int.tryParse(b['id_nivel'].toString()) ?? 0;

        if (nivel == 5) {
          especiaisObtidos++;
        } else if (nivel >= 1 && nivel <= 4) {
          comunsObtidos++;
        }
      }

      obtidos.sort((a, b) {
        final pontosA = int.tryParse(a['pontos']?.toString() ?? '0') ?? 0;
        final pontosB = int.tryParse(b['pontos']?.toString() ?? '0') ?? 0;
        return pontosB.compareTo(pontosA); // ordem desc
      });

      final top3Badges = obtidos.take(3).toList();

      setState(() {
        learningPaths = List<Map<String, dynamic>>.from(progresso);

        pontosTotal = pontosTotalCalc;
        badgesComuns = comunsObtidos;
        totalBadgesComuns = comunsTotal;

        badgesEspeciais = especiaisObtidos;
        totalBadgesEspeciais = especiaisTotal;
        ranking = top3Badges;

        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro ao carregar progresso: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO ──────────────────────────────────────────────
            Positioned.fill(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF4470AF)))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        children: [
                          SizedBox(height: headerHeight),

                          // Voltar
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.arrow_back,
                                          size: 20,
                                          color: Color(0xFF4470AF)),
                                      SizedBox(width: 6),
                                      Text(
                                        "Voltar",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF4470AF),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── PONTOS TOTAIS ──────────────────────────
                          _pontosCard(),

                          const SizedBox(height: 16),

                          // ── LEARNING PATHS ─────────────────────────
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Progressos nas Learning Paths",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (learningPaths.isEmpty)
                                  Text(
                                    "Sem learning paths disponíveis.",
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                  )
                                else
                                  ...learningPaths.map(
                                      (lp) => _learningPathItem(lp)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── PROGRESSO DOS BADGES ───────────────────
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Progressos dos Badges",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _badgeCirculo(
                                      atual: badgesComuns,
                                      total: totalBadgesComuns,
                                      label: "Badges comuns",
                                    ),
                                    _badgeCirculo(
                                      atual: badgesEspeciais,
                                      total: totalBadgesEspeciais,
                                      label: "Badges especiais",
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── RANKING ────────────────────────────────
                          _secaoCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Ranking de conquistas",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (ranking.isEmpty)
                                  Text(
                                    "Ainda sem conquistas no ranking.",
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13),
                                  )
                                else
                                  ...ranking.asMap().entries.map(
                                        (e) => _rankingItem(
                                            e.value, e.key),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ── HEADER ────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Image.asset(
                      'lib/img/logo.png',
                      height: 35,
                      fit: BoxFit.contain,
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

  // ── PONTOS CARD ───────────────────────────────────────────────────────────
  Widget _pontosCard() {
    return Center(
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4470AF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Pontos Totais",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "$pontosTotal pts",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SECÃO CARD WRAPPER ────────────────────────────────────────────────────
  Widget _secaoCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── LEARNING PATH ITEM ────────────────────────────────────────────────────
  Widget _learningPathItem(Map<String, dynamic> lp) {
    final String nome = lp['nome_learningpath'] ?? '';

    final int total = int.tryParse(lp['total_badges'].toString()) ?? 0;

    final int conquistados =
        int.tryParse(lp['badges_conquistados'].toString()) ?? 0;

    final int percentagem =
        int.tryParse(lp['percentagem'].toString()) ?? 0;

    final double progresso = percentagem / 100;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nome,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF4470AF),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            "$conquistados / $total badges concluídos • $percentagem%",
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // ── CÍRCULO DE BADGES ─────────────────────────────────────────────────────
  Widget _badgeCirculo({
    required int atual,
    required int total,
    required String label,
  }) {
    final double ratio = total > 0 ? (atual / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: _CirculoPainter(ratio: ratio),
              ),
              Text(
                "$atual/$total",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ── RANKING ITEM ──────────────────────────────────────────────────────────
  Widget _rankingItem(Map<String, dynamic> item, int index) {
    final String nome = item['nome'] ?? '';
    final int pontos =
        int.tryParse(item['pontos']?.toString() ?? '0') ?? 0;

    final medalhas = ["🥇", "🥈", "🥉"];
    final medalha = index < 3 ? medalhas[index] : "🏅";

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Medalha
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: index == 0
                ? const Color(0xFFFFF8E1) // ouro
                : index == 1
                    ? const Color(0xFFE0E0E0) // prata
                    : index == 2
                        ? const Color(0xFFF3E5F5) // bronze
                        : const Color(0xFFF0F0F0), // fallback
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                medalha,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nome + pontos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  "Ganhou +$pontos pts",
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PAINTER DO CÍRCULO ────────────────────────────────────────────────────────
class _CirculoPainter extends CustomPainter {
  final double ratio;

  _CirculoPainter({required this.ratio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Fundo
    final bgPaint = Paint()
      ..color = const Color(0xFF4470AF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Arco de progresso (anel exterior)
    if (ratio > 0) {
      final arcPaint = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 6),
        -math.pi / 2,
        2 * math.pi * ratio,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CirculoPainter old) => old.ratio != ratio;
}