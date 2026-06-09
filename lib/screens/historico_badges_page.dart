import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para o fallback de base de dados

class HistoricoBadgesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HistoricoBadgesPage({
    super.key,
    required this.userData,
  });

  @override
  State<HistoricoBadgesPage> createState() => _HistoricoBadgesPageState();
}

class _HistoricoBadgesPageState extends State<HistoricoBadgesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância para cache local do SQLite

  bool isLoading = true;
  List<Map<String, dynamic>> badges = [];

  @override
  void initState() {
    super.initState();
    carregarBadges();
  }

  Future<void> carregarBadges() async {
    final userId = widget.userData['id_utilizador'];
    List<Map<String, dynamic>> dadosRaw = [];

    try {
      // 1. Tenta ir buscar os badges conquistados em tempo real à API
      dadosRaw = await _apiService.getBadgesConquistados(userId);

      // 2. MIRRORING: Guarda os dados na cache local para suportar o modo offline
      for (var b in dadosRaw) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'data_validade': b['data_validade']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo no Histórico: Carregando cache local... ($e)");
      
      // 3. FALLBACK: Lê as tabelas locais se o servidor estiver inacessível
      final localAtribuidos = await _dbLocal.listarTabela('badge_atribuido');
      
      dadosRaw = localAtribuidos.map((e) => {
        'id': e['id_badge_modelo'],
        'nome': e['nome'] ?? 'Badge Conquistado',
        'descricao': e['descricao'] ?? 'Dados guardados localmente.',
        'pontos': e['pontos'] ?? 0,
        'data_atribuicao': e['data_atribuicao'],
        'data_validade': e['data_validade'],
      }).toList();
    }

    // 4. LÓGICA DE UNIFICAÇÃO (Preservada a remoção de duplicados original da tua colega)
    final Map<int, Map<String, dynamic>> unicos = {};
    for (final b in dadosRaw) {
      final id = int.tryParse(b['id'].toString());
      if (id != null && !unicos.containsKey(id)) {
        unicos[id] = Map<String, dynamic>.from(b);
      }
    }

    if (mounted) {
      setState(() {
        badges = unicos.values.toList();
        isLoading = false;
      });
    }
  }

  String _formatarData(dynamic data) {
    if (data == null) return "-";

    try {
      final dt = DateTime.parse(data.toString());
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return data.toString();
    }
  }

  Map<String, dynamic> _estadoBadge(Map<String, dynamic> badge) {
    final validadeRaw = badge['data_validade'];

    if (validadeRaw == null) {
      return {
        'texto': 'Sem validade definida',
        'cor': Colors.grey,
        'fundo': const Color(0xFFF5F5F5),
        'icone': Icons.help_outline,
      };
    }

    final validade = DateTime.tryParse(validadeRaw.toString());

    if (validade == null) {
      return {
        'texto': 'Data inválida',
        'cor': Colors.grey,
        'fundo': const Color(0xFFF5F5F5),
        'icone': Icons.help_outline,
      };
    }

    final hoje = DateTime.now();
    final diasRestantes = validade.difference(hoje).inDays;

    if (diasRestantes < 0) {
      return {
        'texto': 'Expirado',
        'cor': Colors.red,
        'fundo': const Color(0xFFFFEBEE),
        'icone': Icons.cancel_outlined,
      };
    }

    if (diasRestantes <= 30) {
      return {
        'texto': 'Expira em $diasRestantes d',
        'cor': Colors.orange,
        'fundo': const Color(0xFFFFF3E0),
        'icone': Icons.warning_amber_rounded,
      };
    }

    return {
      'texto': 'Ativo',
      'cor': const Color(0xFF2E7D32),
      'fundo': const Color(0xFFE8F5E9),
      'icone': Icons.check_circle_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ativos = badges.where((b) {
      final estado = _estadoBadge(b)['texto'].toString();
      return estado == 'Ativo' || estado.startsWith('Expira em');
    }).length;

    final expirados = badges.where((b) {
      return _estadoBadge(b)['texto'] == 'Expirado';
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // FIXED APP HEADER
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

            // BOTÃO VOLTAR
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: Color(0xFF4470AF)),
                        SizedBox(width: 6),
                        Text(
                          "Voltar",
                          style: TextStyle(
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

            // CARDS DE RESUMO (Calculados dinamicamente com base na cache ou rede)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _resumoCard(
                    titulo: "Ativos",
                    valor: ativos.toString(),
                    cor: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 10),
                  _resumoCard(
                    titulo: "Expirados",
                    valor: expirados.toString(),
                    cor: Colors.red,
                  ),
                ],
              ),
            ),

            // LISTAGEM PRINCIPAL
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4470AF),
                      ),
                    )
                  : badges.isEmpty
                      ? const Center(
                          child: Text(
                            "Ainda não tem badges conquistados.",
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: badges.length,
                          itemBuilder: (context, index) {
                            final badge = badges[index];
                            final estado = _estadoBadge(badge);
                            return _badgeHistoricoCard(
                              badge: badge,
                              estado: estado,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resumoCard({
    required String titulo,
    required String valor,
    required Color cor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: TextStyle(
                color: cor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              titulo,
              style: TextStyle(
                color: cor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badgeHistoricoCard({
    required Map<String, dynamic> badge,
    required Map<String, dynamic> estado,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xFFEAF0FA),
                child: Text("🏅", style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge['nome'] ?? "Badge",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badge['descricao'] ?? "",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: estado['fundo'],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      estado['icone'],
                      size: 14,
                      color: estado['cor'],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      estado['texto'],
                      style: TextStyle(
                        fontSize: 10,
                        color: estado['cor'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade100, height: 1),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dataInfo(
                label: "Conquistado",
                value: _formatarData(badge['data_atribuicao']),
              ),
              _dataInfo(
                label: "Validade",
                value: _formatarData(badge['data_validade']),
              ),
              _dataInfo(
                label: "Pontos",
                value: "${badge['pontos'] ?? 0}",
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dataInfo({
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}