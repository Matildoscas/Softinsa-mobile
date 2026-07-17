import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/basededados.dart';
import '../services/api_service.dart';
import 'status_candidatura_detalhe_page.dart';

class StatusCandidaturasPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StatusCandidaturasPage({super.key, required this.userData});

  @override
  State<StatusCandidaturasPage> createState() => _StatusCandidaturasPageState();
}

class _StatusCandidaturasPageState extends State<StatusCandidaturasPage> {
  final ApiService _api = ApiService();
  final Basededados _dbLocal = Basededados();

  bool _loading = true;
  List<Map<String, dynamic>> _lista = [];

  String _removerAcentos(String texto) {
    return texto
        .replaceAll('Á', 'A')
        .replaceAll('À', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Ä', 'A')
        .replaceAll('É', 'E')
        .replaceAll('È', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ë', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ì', 'I')
        .replaceAll('Î', 'I')
        .replaceAll('Ï', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ò', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ö', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ù', 'U')
        .replaceAll('Û', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ç', 'C');
  }

  String _normalizarEstado(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) {
      return '';
    }

    return _removerAcentos(texto.toUpperCase()).replaceAll(' ', '_');
  }

  String _formatarEstadoHumano(String? valor) {
    final estado = _normalizarEstado(valor);
    if (estado.isEmpty) {
      return 'Sem estado';
    }

    const mapa = <String, String>{
      'EM_VALIDACAO_TM': 'Talent Manager a validar',
      'EM_VALIDACAO_SLL': 'Service Line Leader a validar',
      'AGUARDA_VALIDACAO_TM': 'A aguardar validação do Talent Manager',
      'AGUARDA_VALIDACAO_SLL': 'A aguardar validação do Service Line Leader',
      'AGUARDANDO_TM': 'A aguardar avaliação do Talent Manager',
      'AGUARDANDO_SLL': 'A aguardar avaliação do Service Line Leader',
      'EM_VALIDACAO': 'Em validação',
      'PENDENTE': 'Pendente',
      'APROVADO': 'Aprovado',
      'APROVADA': 'Aprovada',
      'APROVADO_FINAL': 'Aprovado em definitivo',
      'REJEITADO': 'Rejeitado',
      'REJEITADA': 'Rejeitada',
      'REJEITADO_TM': 'Candidatura rejeitada',
      'REJEITADO_SLL': 'Candidatura rejeitada',
      'RECUSADO': 'Recusado',
      'DESISTIDA': 'Desistida',
      'DESISTIDO': 'Desistida',
      'CANCELADO': 'Cancelado',
      'FINALIZADO': 'Concluído',
      'CONCLUIDO': 'Concluído',
      'HISTORICO': 'Concluído',
    };

    if (mapa.containsKey(estado)) {
      return mapa[estado]!;
    }

    final textoBase = (valor ?? estado).replaceAll('_', ' ').trim();
    if (textoBase.isEmpty) {
      return 'Sem estado';
    }

    return textoBase[0].toUpperCase() + textoBase.substring(1).toLowerCase();
  }

  Map<String, Color> _coresEstado(String? estado) {
    final valor = _normalizarEstado(estado);

    if (valor.contains('APROV')) {
      return {
        'fundo': const Color(0xFFDCFCE7),
        'texto': const Color(0xFF166534),
        'borda': const Color(0xFFBBF7D0),
      };
    }

    if (valor.contains('REJEIT') ||
        valor.contains('RECUS') ||
        valor.contains('CANCEL') ||
        valor.contains('DESIST')) {
      return {
        'fundo': const Color(0xFFFEE2E2),
        'texto': const Color(0xFF991B1B),
        'borda': const Color(0xFFFECACA),
      };
    }

    if (valor.contains('AGUARDA') ||
        valor.contains('PEND') ||
        valor.contains('VALID')) {
      return {
        'fundo': const Color(0xFFFEF3C7),
        'texto': const Color(0xFF92400E),
        'borda': const Color(0xFFFDE68A),
      };
    }

    return {
      'fundo': const Color(0xFFE5E7EB),
      'texto': const Color(0xFF475569),
      'borda': const Color(0xFFCBD5E1),
    };
  }

  bool _candidaturaTemRejeicaoEmEvidencias(Map<String, dynamic> item) {
    return (int.tryParse((item['evidencias_rejeitadas_tm'] ?? 0).toString()) ??
                0) >
            0 ||
        (int.tryParse((item['evidencias_rejeitadas_sll'] ?? 0).toString()) ??
                0) >
            0;
  }

  bool _candidaturaEstaDesistida(Map<String, dynamic> item) {
    final estado = _normalizarEstado(
      item['estado_geral']?.toString() ?? item['estado_final']?.toString(),
    );
    final fase = _normalizarEstado(item['fase_geral']?.toString());

    return estado.contains('DESIST') ||
        fase.contains('DESIST') ||
        estado.contains('CANCEL') ||
        fase.contains('CANCEL');
  }

  bool _candidaturaEstaRejeitada(Map<String, dynamic> item) {
    if (_candidaturaEstaDesistida(item)) {
      return false;
    }

    if (_candidaturaTemRejeicaoEmEvidencias(item)) {
      return true;
    }

    final estado = _normalizarEstado(
      item['estado_geral']?.toString() ?? item['estado_final']?.toString(),
    );
    final fase = _normalizarEstado(item['fase_geral']?.toString());

    return estado.contains('REJEIT') ||
        estado.contains('RECUS') ||
        fase.contains('REJEIT') ||
        fase.contains('RECUS');
  }

  bool _candidaturaEstaObtida(Map<String, dynamic> item) {
    if (_candidaturaEstaDesistida(item) || _candidaturaEstaRejeitada(item)) {
      return false;
    }

    final estado = _normalizarEstado(
      item['estado_geral']?.toString() ?? item['estado_final']?.toString(),
    );
    final fase = _normalizarEstado(item['fase_geral']?.toString());

    return estado.contains('APROV') &&
        (estado.contains('FINAL') ||
            fase.contains('HISTORICO') ||
            fase.contains('FINALIZ') ||
            fase.contains('CONCLUID'));
  }

  bool _candidaturaEstaFinalizada(Map<String, dynamic> item) {
    return _candidaturaEstaDesistida(item) ||
        _candidaturaEstaRejeitada(item) ||
        _candidaturaEstaObtida(item);
  }

  String _estadoGeralVisivel(Map<String, dynamic> item) {
    if (_candidaturaEstaRejeitada(item)) {
      return 'REJEITADA';
    }

    if (_candidaturaEstaObtida(item)) {
      return 'APROVADA';
    }

    if (_candidaturaEstaDesistida(item)) {
      return 'DESISTIDA';
    }

    return item['estado_geral']?.toString() ??
        item['estado_final']?.toString() ??
        '-';
  }

  String _faseGeralVisivel(Map<String, dynamic> item) {
    if (_candidaturaEstaRejeitada(item)) {
      return 'REJEITADA';
    }

    if (_candidaturaEstaObtida(item)) {
      return 'HISTORICO';
    }

    if (_candidaturaEstaDesistida(item)) {
      return 'DESISTIDA';
    }

    return item['fase_geral']?.toString() ?? '-';
  }

  Future<void> _ensureTabelaStatus() async {
    final db = await _dbLocal.database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_status_candidaturas (
        id_utilizador INTEGER,
        id_candidatura_pedido INTEGER,
        id_badge_modelo INTEGER,
        estado_geral TEXT,
        fase_geral TEXT,
        estado_final TEXT,
        estado_candidatura_pedido TEXT,
        data_submissao TEXT,
        PRIMARY KEY (id_utilizador, id_candidatura_pedido, id_badge_modelo)
      )
    ''');
  }

  Future<void> _guardarStatusCache(
    int userId,
    List<Map<String, dynamic>> candidaturas,
  ) async {
    await _ensureTabelaStatus();
    final db = await _dbLocal.database;

    await db.delete(
      'cache_status_candidaturas',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
    );

    for (int idx = 0; idx < candidaturas.length; idx++) {
      final c = candidaturas[idx];
      final idBadge =
          int.tryParse((c['id_badge_modelo'] ?? c['id'] ?? 0).toString()) ?? 0;
      if (idBadge <= 0) {
        continue;
      }

      final idCandidatura =
          int.tryParse((c['id_candidatura_pedido'] ?? '').toString()) ??
          (idx + 1);

      await db.insert('cache_status_candidaturas', {
        'id_utilizador': userId,
        'id_candidatura_pedido': idCandidatura,
        'id_badge_modelo': idBadge,
        'estado_geral':
            c['estado_geral']?.toString() ?? c['estado_validacao']?.toString(),
        'fase_geral': c['fase_geral']?.toString(),
        'estado_final': c['estado_final']?.toString(),
        'estado_candidatura_pedido': c['estado_candidatura_pedido']?.toString(),
        'data_submissao':
            c['data_submissao']?.toString() ?? c['data_submisao']?.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, dynamic>>> _carregarStatusCache(int userId) async {
    await _ensureTabelaStatus();
    final db = await _dbLocal.database;

    final badgesModelo = await _dbLocal.listarTabela('badge_modelo');
    final nomesBadge = <String, String>{
      for (final b in badgesModelo)
        (b['id_badge_modelo'] ?? '').toString(): (b['nome_badge'] ?? 'Badge')
            .toString(),
    };

    final rows = await db.query(
      'cache_status_candidaturas',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
      orderBy: 'data_submissao DESC',
    );

    if (rows.isNotEmpty) {
      return rows.map((row) {
        final idBadge = row['id_badge_modelo']?.toString() ?? '';
        return <String, dynamic>{
          'id_candidatura_pedido': row['id_candidatura_pedido'],
          'id_badge_modelo': row['id_badge_modelo'],
          'id': row['id_badge_modelo'],
          'nome_badge': nomesBadge[idBadge] ?? 'Badge #$idBadge',
          'estado_geral': row['estado_geral'],
          'fase_geral': row['fase_geral'],
          'estado_final': row['estado_final'],
          'estado_candidatura_pedido': row['estado_candidatura_pedido'],
          'data_submissao': row['data_submissao'],
          'offline': true,
        };
      }).toList();
    }

    final fallbackPedido = await db.query(
      'candidatura_pedido',
      where: 'id_utilizador = ?',
      whereArgs: [userId],
      orderBy: 'data_submisao DESC',
    );

    return fallbackPedido.map((row) {
      final idBadge = row['id_badge_modelo']?.toString() ?? '';
      return <String, dynamic>{
        'id_candidatura_pedido': row['id_candidatura_pedido'],
        'id_badge_modelo': row['id_badge_modelo'],
        'id': row['id_badge_modelo'],
        'nome_badge': nomesBadge[idBadge] ?? 'Badge #$idBadge',
        'estado_geral': row['estado_candidatura_pedido'],
        'estado_candidatura_pedido': row['estado_candidatura_pedido'],
        'data_submissao': row['data_submisao'],
        'offline': true,
      };
    }).toList();
  }

  Future<void> _carregar() async {
    final int userId =
        int.tryParse(widget.userData['id_utilizador']?.toString() ?? '') ?? 0;

    if (userId <= 0) {
      if (!mounted) {
        return;
      }

      setState(() {
        _lista = [];
        _loading = false;
      });
      return;
    }

    List<Map<String, dynamic>> lista = [];

    try {
      lista = await _api.getStatusCandidaturasConsultor(userId);
      await _guardarStatusCache(userId, lista);
    } catch (_) {
      lista = await _carregarStatusCache(userId);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _lista = lista;
      _loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _formatarData(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }

    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return '-';
    }

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Status de Candidaturas',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4470AF)),
            )
          : _lista.isEmpty
          ? const Center(
              child: Text(
                'Sem candidaturas para apresentar.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _lista.length,
                itemBuilder: (context, index) {
                  final item = _lista[index];
                  final nome = (item['nome_badge'] ?? item['nome'] ?? 'Badge')
                      .toString();

                  final estadoRaw = _estadoGeralVisivel(item);
                  final faseRaw = _faseGeralVisivel(item);
                  final bool rejeitada = _candidaturaEstaRejeitada(item);
                  final bool desistida = _candidaturaEstaDesistida(item);
                  final bool obtida = _candidaturaEstaObtida(item);
                  final bool finalizada = _candidaturaEstaFinalizada(item);
                  final cores = _coresEstado(estadoRaw);

                  final Color cardBorder = obtida
                      ? const Color(0xFF2E7D32).withOpacity(0.35)
                      : rejeitada
                      ? const Color(0xFF991B1B).withOpacity(0.28)
                      : desistida
                      ? const Color(0xFF475569).withOpacity(0.25)
                      : const Color(0xFF4470AF).withOpacity(0.18);

                  final Color cardBackground = obtida
                      ? const Color(0xFFF0FDF4)
                      : rejeitada
                      ? const Color(0xFFFFF7F7)
                      : desistida
                      ? const Color(0xFFF8FAFC)
                      : Colors.white;

                  final String resumoEstado = obtida
                      ? 'Concluída'
                      : rejeitada
                      ? 'Rejeitada'
                      : desistida
                      ? 'Desistida'
                      : finalizada
                      ? 'Finalizada'
                      : 'Em processo';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatusCandidaturaDetalhePage(
                                userData: widget.userData,
                                candidatura: item,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nome,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          resumoEstado,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: cores['texto'],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.chevron_right,
                                    color:
                                        cores['texto'] ??
                                        const Color(0xFF4470AF),
                                    size: 22,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cores['fundo'],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            cores['borda'] ??
                                            Colors.transparent,
                                      ),
                                    ),
                                    child: Text(
                                      _formatarEstadoHumano(estadoRaw),
                                      style: TextStyle(
                                        color: cores['texto'],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (faseRaw != '-')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: obtida
                                            ? const Color(0xFFF0FDF4)
                                            : rejeitada
                                            ? const Color(0xFFFFF1F2)
                                            : desistida
                                            ? const Color(0xFFF8FAFC)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: obtida
                                              ? const Color(0xFFBBF7D0)
                                              : rejeitada
                                              ? const Color(0xFFFECACA)
                                              : desistida
                                              ? const Color(0xFFE2E8F0)
                                              : const Color(0xFFDBEAFE),
                                        ),
                                      ),
                                      child: Text(
                                        faseRaw,
                                        style: TextStyle(
                                          color: obtida
                                              ? const Color(0xFF166534)
                                              : rejeitada
                                              ? const Color(0xFF991B1B)
                                              : desistida
                                              ? const Color(0xFF475569)
                                              : const Color(0xFF1D4ED8),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Submetida em ${_formatarData(item['data_submissao']?.toString())}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                              if (finalizada) ...[
                                const SizedBox(height: 6),
                                Text(
                                  rejeitada
                                      ? 'A candidatura foi rejeitada e pode ter sido reaberta noutra submissão.'
                                      : obtida
                                      ? 'A candidatura terminou com aprovação final.'
                                      : 'A candidatura já não está em processo ativo.',
                                  style: TextStyle(
                                    color: cores['texto'],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StatusCandidaturaDetalhePage(
                                              userData: widget.userData,
                                              candidatura: item,
                                            ),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF4470AF),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Ver detalhe',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
