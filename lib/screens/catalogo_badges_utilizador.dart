import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart';
import 'informacoes_badge.dart';

String obterNivel(dynamic idNivel) {
  final int? nivel = int.tryParse(idNivel.toString());
  switch (nivel) {
    case 1: return 'A';
    case 2: return 'B';
    case 3: return 'C';
    case 4: return 'D';
    case 5: return 'E';
    default: return '-';
  }
}

class MeusBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MeusBadgesPage({super.key, required this.userData});

  @override
  State<MeusBadgesPage> createState() => _MeusBadgesPageState();
}

class _MeusBadgesPageState extends State<MeusBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados();

  List<Map<String, dynamic>> meusBadges = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarMeusBadges();
  }

  Future<void> _carregarMeusBadges() async {
    final int userId = int.parse(widget.userData['id_utilizador'].toString());

    try {
      // 1. Tenta ir buscar à API os badges que o consultor já conquistou
      final dados = await _apiService.getBadgesConquistados(userId);
      
      if (mounted) {
        setState(() {
          meusBadges = List<Map<String, dynamic>>.from(dados);
          isLoading = false;
        });
      }

      // 2. Sincroniza com o SQFlite local para consulta offline posterior
      for (var b in dados) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo em Os Seus Badges: $e");

      // 3. Fallback: Se falhar a rede, carrega os dados diretamente do SQLite local
      final dadosLocais = await _dbLocal.listarTabela('badge_atribuido');
      
      if (mounted) {
        setState(() {
          meusBadges = dadosLocais.map((e) => {
            'id': e['id_badge_modelo'],
            'nome': e['nome'] ?? 'Badge Conquistado',
            'descricao': e['descricao'] ?? 'Disponível em cache offline.',
            'pontos': e['pontos'] ?? 0,
            'data_atribuicao': e['data_atribuicao'],
            'id_nivel': e['id_nivel']
          }).toList();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text("Os seus Badges", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF4470AF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4470AF)))
            : meusBadges.isEmpty
                ? _estadoVazio()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: meusBadges.length,
                    itemBuilder: (context, index) => _badgeCard(meusBadges[index]),
                  ),
      ),
    );
  }

  Widget _badgeCard(Map<String, dynamic> badge) {
    final int pontos = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final int badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? '0').toString()) ?? 0;
    
    // Formata a data de conquista de forma amigável
    String dataFormatada = '—';
    if (badge['data_atribuicao'] != null) {
      try {
        final dt = DateTime.parse(badge['data_atribuicao'].toString());
        dataFormatada = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
      } catch (_) {
        dataFormatada = badge['data_atribuicao'].toString();
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BadgeDetalhe(
              userId: int.parse(widget.userData['id_utilizador'].toString()),
              badgeId: badgeId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                      child: const Center(child: Text("🏅", style: TextStyle(fontSize: 28))),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Color(0xFF2E7D32), shape: BoxShape.circle),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge['nome'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        badge['descricao'] ?? '',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (badge['id_nivel'] != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFEAF0FA), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            "Nível ${obterNivel(badge['id_nivel'])}",
                            style: const TextStyle(fontSize: 10, color: Color(0xFF4470AF)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF4470AF)), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Text("Pontos", style: TextStyle(fontSize: 9, color: Color(0xFF4470AF))),
                      const SizedBox(height: 2),
                      Text(
                        "$pontos",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4470AF)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Conquistado a $dataFormatada",
                style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "Nenhum badge conquistado",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
            ),
            const SizedBox(height: 6),
            Text(
              "Comece a realizar os desafios das Service Lines para ganhar o seu primeiro badge!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}