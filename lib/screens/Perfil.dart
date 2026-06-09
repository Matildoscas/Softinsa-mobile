import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import crucial para ler a cache offline
import '../providers/utilizador_provider.dart';
import 'catalogo_badges_utilizador.dart';
import 'informacoes_badge.dart';
import 'progresso_page.dart';
import 'historico_badges_page.dart';

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

class PerfilPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PerfilPage({super.key, required this.userData});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local para modo Offline

  List<Map<String, dynamic>> badgesConquistados = [];
  List<Map<String, dynamic>> todosBadges = []; // CORREÇÃO: Movido de global para local da Store
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosPerfil();
  }

  Future<void> _carregarDadosPerfil() async {
    final int userId = int.parse(widget.userData['id_utilizador'].toString());
    
    try {
      // 1. Tenta puxar tudo da API via HTTP
      final obtidos = await _apiService.getBadgesConquistados(userId);
      final todos = await _apiService.getTodosBadges();

      if (mounted) {
        setState(() {
          badgesConquistados = List<Map<String, dynamic>>.from(obtidos);
          todosBadges = List<Map<String, dynamic>>.from(todos);
          isLoading = false;
        });
      }

      // 2. Faz o Mirroring (Sincronização em Background para o SQFlite)
      for (var b in obtidos) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': b['id_badge_atribuido'] ?? b['id'] ?? 0,
          'id_badge_modelo': b['id_badge_modelo'] ?? b['id'] ?? 0,
          'data_atribuicao': b['data_atribuicao']?.toString(),
          'estado_badge_atribuido': 'Conquistado',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo no Perfil (Carregando cache local): $e");
      
      // 3. Fallback de Emergência: Lê as tabelas locais do SQFlite se a API falhar
      final obtidosLocais = await _dbLocal.listarTabela('badge_atribuido');
      final todosLocais = await _dbLocal.listarTabela('badge_modelo');

      if (mounted) {
        setState(() {
          // Filtra apenas os que estão conquistados na cache local
          badgesConquistados = obtidosLocais.map((e) => {
            'id': e['id_badge_modelo'],
            'nome': e['nome'] ?? 'Badge Guardado',
            'descricao': e['descricao'] ?? 'Disponível em modo offline.',
            'pontos': e['pontos'] ?? 0,
            'data_atribuicao': e['data_atribuicao'],
            'id_nivel': e['id_nivel']
          }).toList();
          
          todosBadges = List<Map<String, dynamic>>.from(todosLocais);
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    
    // Consome o Provider para obter os dados do consultor atualizados em tempo real na Home
    final userProvider = Provider.of<UtilizadorProvider>(context);
    
    final String nome = userProvider.dashboard.isNotEmpty 
        ? (userProvider.dashboard['nome_completo'] ?? widget.userData['nome_completo'] ?? 'Utilizador')
        : (widget.userData['nome_completo'] ?? 'Utilizador');
        
    final String? fotoUrl = widget.userData['foto_url'];
    final int totalBadges = todosBadges.isNotEmpty ? todosBadges.length : 24; // Fallback estático seguro

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO ──────────────────────────────────────────────
            Positioned.fill(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: headerHeight),

                    // Voltar
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Row(
                              children: [
                                Icon(Icons.arrow_back, size: 20, color: Color(0xFF4470AF)),
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

                    // Avatar + nome
                    Container(
                      color: Colors.white,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4470AF),
                              borderRadius: BorderRadius.circular(20),
                              image: fotoUrl != null
                                  ? DecorationImage(image: NetworkImage(fotoUrl), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: fotoUrl == null
                                ? const Icon(Icons.person, color: Colors.white, size: 52)
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            nome,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF111111)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botões Progresso + Histórico
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _outlineButton(
                              icon: Icons.trending_up,
                              label: "Progresso",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProgressoPage(userData: widget.userData)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _outlineButton(
                              icon: Icons.history, // Ícone corrigido para histórico
                              label: "Histórico Badges",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => HistoricoBadgesPage(userData: widget.userData)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cabeçalho "Os seus badges"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Os seus badges", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                isLoading
                                    ? "A carregar..."
                                    : "Tem ${badgesConquistados.length}/$totalBadges badges",
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MeusBadgesPage(userData: widget.userData)),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF4470AF)),
                                  SizedBox(width: 5),
                                  Text(
                                    "Ver Todos",
                                    style: TextStyle(fontSize: 12, color: Color(0xFF4470AF), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Lista de badges com tratamento de estados
                    isLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(color: Color(0xFF4470AF)),
                          )
                        : badgesConquistados.isEmpty
                            ? _estadoVazio()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: badgesConquistados.length,
                                itemBuilder: (context, index) => _badgeCard(badgesConquistados[index]),
                              ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ── HEADER FIXED ──────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
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
            ),
          ],
        ),
      ),
    );
  }

  // ── CARD DE BADGE REATIVO ─────────────────────────────────────────────────
  Widget _badgeCard(Map<String, dynamic> badge) {
    final int pontos = int.tryParse(badge['pontos']?.toString() ?? '0') ?? 0;
    final String? dataConquista = badge['data_atribuicao']?.toString();
    final String dataFormatada = _formatarData(dataConquista) ?? '—';
    final int badgeId = int.tryParse((badge['id'] ?? badge['id_badge_modelo'] ?? '0').toString()) ?? 0;

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

  Widget _outlineButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black87, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "Ainda sem badges",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
          ),
          const SizedBox(height: 4),
          Text("Completa desafios para conquistar badges.", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  String? _formatarData(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw;
    }
  }
}