import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../database/basededados.dart';
import '../services/api_service.dart';
import 'informacoes_badge.dart';
import 'submeter_badges.dart';

class StatusCandidaturaDetalhePage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> candidatura;
  final Future<Map<String, dynamic>?> _detalheFuture;

  StatusCandidaturaDetalhePage({
    super.key,
    required this.userData,
    required this.candidatura,
  }) : _detalheFuture = _carregarDetalheOnlineOuOffline(userData, candidatura);

  static Future<Map<String, dynamic>?> _carregarDetalheOnlineOuOffline(
    Map<String, dynamic> userData,
    Map<String, dynamic> candidatura,
  ) async {
    final int idUtilizador =
        int.tryParse(
          (userData['id_utilizador'] ??
                  userData['ID_UTILIZADOR'] ??
                  userData['id'] ??
                  '')
              .toString(),
        ) ??
        0;

    final int idCandidatura =
        int.tryParse((candidatura['id_candidatura_pedido'] ?? '').toString()) ??
        0;

    if (idUtilizador <= 0 || idCandidatura <= 0) {
      return null;
    }

    try {
      final api = ApiService();
      final detalheApi = await api.getStatusCandidaturaDetalheConsultor(
        idUtilizador,
        idCandidatura,
      );

      if (detalheApi != null) {
        return detalheApi;
      }

      return {
        'candidatura': candidatura,
        'requisitos': const <Map<String, dynamic>>[],
      };
    } on SocketException {
      final db = await Basededados().database;

      final pedidoRows = await db.query(
        'candidatura_pedido',
        where: 'id_candidatura_pedido = ? AND id_utilizador = ?',
        whereArgs: [idCandidatura, idUtilizador],
        limit: 1,
      );

      if (pedidoRows.isEmpty) {
        return {
          'candidatura': candidatura,
          'requisitos': const <Map<String, dynamic>>[],
        };
      }

      final pedido = Map<String, dynamic>.from(pedidoRows.first);
      final int idBadge =
          int.tryParse(
            (pedido['id_badge_modelo'] ?? candidatura['id_badge_modelo'] ?? 0)
                .toString(),
          ) ??
          0;

      Map<String, dynamic> cache = <String, dynamic>{};
      try {
        final cacheRows = await db.query(
          'cache_status_candidaturas',
          where: 'id_utilizador = ? AND id_candidatura_pedido = ?',
          whereArgs: [idUtilizador, idCandidatura],
          limit: 1,
        );
        if (cacheRows.isNotEmpty) {
          cache = Map<String, dynamic>.from(cacheRows.first);
        }
      } catch (_) {}

      final tmRows = await db.query(
        'candidatura_tm',
        where: 'id_candidatura_pedido = ?',
        whereArgs: [idCandidatura],
        orderBy: 'id_candidatura_tm DESC',
        limit: 1,
      );
      final tm = tmRows.isNotEmpty
          ? Map<String, dynamic>.from(tmRows.first)
          : <String, dynamic>{};

      Map<String, dynamic> sll = <String, dynamic>{};
      final idTm = tm['id_candidatura_tm'];
      if (idTm != null) {
        final sllRows = await db.query(
          'candidatura_sll',
          where: 'id_candidatura_tm = ?',
          whereArgs: [idTm],
          orderBy: 'id_candidatura_sll DESC',
          limit: 1,
        );
        if (sllRows.isNotEmpty) {
          sll = Map<String, dynamic>.from(sllRows.first);
        }
      }

      Map<String, dynamic> historico = <String, dynamic>{};
      final idSll = sll['id_candidatura_sll'];
      if (idSll != null) {
        final historicoRows = await db.query(
          'candidatura_historico',
          where: 'id_candidatura_sll = ?',
          whereArgs: [idSll],
          orderBy: 'id_candidatura_historico DESC',
          limit: 1,
        );
        if (historicoRows.isNotEmpty) {
          historico = Map<String, dynamic>.from(historicoRows.first);
        }
      }

      final evidenciasCount =
          Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) as total FROM evidencias WHERE id_candidatura_pedido = ?',
              [idCandidatura],
            ),
          ) ??
          0;

      Map<String, dynamic> badge = <String, dynamic>{};
      if (idBadge > 0) {
        final badgeRows = await db.query(
          'badge_modelo',
          where: 'id_badge_modelo = ?',
          whereArgs: [idBadge],
          limit: 1,
        );
        if (badgeRows.isNotEmpty) {
          badge = Map<String, dynamic>.from(badgeRows.first);
        }
      }

      List<Map<String, dynamic>> requisitos = <Map<String, dynamic>>[];
      if (idBadge > 0) {
        final reqRows = await db.query(
          'requisitos',
          where: 'id_badge_modelo = ?',
          whereArgs: [idBadge],
          orderBy: 'id_requisitos ASC',
        );
        requisitos = reqRows.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final candidaturaOffline = <String, dynamic>{
        ...candidatura,
        ...pedido,
        ...cache,
        'id_candidatura_pedido': idCandidatura,
        'id_badge_modelo': idBadge > 0
            ? idBadge
            : candidatura['id_badge_modelo'],
        'id_utilizador': idUtilizador,
        'nome_badge':
            cache['nome_badge'] ??
            badge['nome_badge'] ??
            candidatura['nome_badge'] ??
            candidatura['nome'],
        'data_submissao':
            pedido['data_submisao'] ??
            pedido['data_submissao'] ??
            candidatura['data_submissao'],
        'estado_candidatura_pedido':
            pedido['estado_candidatura_pedido'] ??
            candidatura['estado_candidatura_pedido'],
        'estado_geral':
            cache['estado_geral'] ??
            candidatura['estado_geral'] ??
            pedido['estado_candidatura_pedido'],
        'fase_geral': cache['fase_geral'] ?? candidatura['fase_geral'],
        'estado_final':
            historico['estado_final'] ??
            cache['estado_final'] ??
            candidatura['estado_final'],
        'data_rececao_tm': tm['data_rececao_tm'],
        'data_conclusao_tm': tm['data_conclusao_tm'],
        'comentarios_tm': cache['comentarios_tm'] ?? tm['comentarios_tm'],
        'data_rececao_sll': sll['data_rececao_sll'],
        'data_conclusao_sll':
            sll['data_conclusao_sll'] ?? sll['data_concluao_sll'],
        'comentarios_sll': cache['comentarios_sll'] ?? sll['comentarios_sll'],
        'data_avaliacao_sll': historico['data_avaliacao_sll'],
        'data_entrada_historico': historico['data_entrada_historico'],
        'motivo_estado_final':
            cache['motivo_estado_final'] ?? historico['motivo_estado_final'],
        'total_evidencias':
            int.tryParse(
              (cache['total_evidencias'] ?? evidenciasCount).toString(),
            ) ??
            evidenciasCount,
        'evidencias_decididas_tm':
            int.tryParse((cache['evidencias_decididas_tm'] ?? 0).toString()) ??
            0,
        'evidencias_decididas_sll':
            int.tryParse((cache['evidencias_decididas_sll'] ?? 0).toString()) ??
            0,
        'evidencias_rejeitadas_tm':
            int.tryParse((cache['evidencias_rejeitadas_tm'] ?? 0).toString()) ??
            0,
        'evidencias_rejeitadas_sll':
            int.tryParse(
              (cache['evidencias_rejeitadas_sll'] ?? 0).toString(),
            ) ??
            0,
        'offline': true,
      };

      return {'candidatura': candidaturaOffline, 'requisitos': requisitos};
    }
  }

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

    return textoBase
        .replaceAll(RegExp(r'\bTM\b'), 'Talent Manager')
        .replaceAll(RegExp(r'\bSLL\b'), 'Service Line Leader')
        .toLowerCase()
        .replaceFirstMapped(
          RegExp(r'^\w'),
          (match) => match.group(0)!.toUpperCase(),
        );
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

  bool _candidaturaEstaFinalizada(Map<String, dynamic> item) =>
      _candidaturaEstaDesistida(item) ||
      _candidaturaEstaRejeitada(item) ||
      _candidaturaEstaObtida(item);

  int _etapaCandidatura(Map<String, dynamic> item) {
    final estado = _normalizarEstado(
      item['estado_geral']?.toString() ??
          item['estado_final']?.toString() ??
          item['estado_candidatura_pedido']?.toString(),
    );
    final fase = _normalizarEstado(item['fase_geral']?.toString());

    if (estado.contains('REJEIT') ||
        estado.contains('RECUS') ||
        estado.contains('APROV') ||
        fase.contains('CONCLUID') ||
        fase.contains('HISTORICO')) {
      return 4;
    }

    if (fase.contains('SLL') ||
        estado.contains('EM_VALIDACAO_SLL') ||
        estado.contains('AGUARDA_VALIDACAO_SLL') ||
        estado.contains('AGUARDANDO_SLL')) {
      return 3;
    }

    if (fase.contains('TM') ||
        estado.contains('EM_VALIDACAO_TM') ||
        estado.contains('AGUARDA_VALIDACAO_TM') ||
        estado.contains('AGUARDANDO_TM')) {
      return 2;
    }

    return 1;
  }

  String _formatarData(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '-';
    }

    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return raw;
    }

    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  int _valorContagem(List<dynamic> candidatos) {
    for (final valor in candidatos) {
      final numero = int.tryParse((valor ?? '').toString());
      if (numero != null && numero >= 0) {
        return numero;
      }
    }

    return 0;
  }

  String _motivoRejeicaoTexto(Map<String, dynamic> item) {
    final texto =
        [
              item['comentarios_tm'],
              item['motivo_estado_final'],
              item['comentarios_sll'],
            ]
            .map((e) => e?.toString().trim() ?? '')
            .firstWhere((e) => e.isNotEmpty, orElse: () => '');

    return texto.isNotEmpty ? texto : 'Sem motivo registado.';
  }

  int? _idBadge() {
    return int.tryParse(
      (candidatura['id_badge_modelo'] ?? candidatura['id'] ?? '').toString(),
    );
  }

  int? _idCandidatura() {
    return int.tryParse(
      (candidatura['id_candidatura_pedido'] ?? '').toString(),
    );
  }

  int _idUtilizador() {
    return int.tryParse(
          (userData['id_utilizador'] ??
                  userData['ID_UTILIZADOR'] ??
                  userData['id'] ??
                  '')
              .toString(),
        ) ??
        0;
  }

  Widget _buildChip(String label, Color fundo, Color texto, Color borda) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borda),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: texto,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _linhaInfo(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              titulo,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaTimeline(String titulo, String? valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatarData(valor),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _stepper(Map<String, dynamic> item) {
    final etapaAtiva = _etapaCandidatura(item);
    final bool finalRejeitada = _candidaturaEstaRejeitada(item);
    final bool finalAprovada = _candidaturaEstaObtida(item);

    final passos = [
      (
        'Candidatura iniciada',
        'O consultor iniciou a candidatura.',
        const Color(0xFF2563EB),
      ),
      (
        'TM a avaliar',
        'Talent Manager a analisar evidências.',
        const Color(0xFF2563EB),
      ),
      (
        'SLL a avaliar',
        'Service Line Leader em validação final.',
        const Color(0xFF2563EB),
      ),
      (
        finalRejeitada ? 'Rejeitada' : 'Concluída',
        finalRejeitada
            ? 'A candidatura foi rejeitada.'
            : finalAprovada
            ? 'A candidatura foi aprovada.'
            : 'A candidatura terminou.',
        finalRejeitada ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    ];

    return Column(
      children: passos.asMap().entries.map((entry) {
        final index = entry.key;
        final passoNumero = index + 1;
        final passo = entry.value;
        final ativo = etapaAtiva == passoNumero;
        final concluido =
            etapaAtiva > passoNumero ||
            (passoNumero == 4 && _candidaturaEstaFinalizada(item));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: concluido || ativo ? passo.$3 : Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: concluido || ativo
                          ? passo.$3
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$passoNumero',
                      style: TextStyle(
                        color: concluido || ativo
                            ? Colors.white
                            : Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (passoNumero < passos.length)
                  Container(
                    width: 2,
                    height: 34,
                    color: concluido || _candidaturaEstaFinalizada(item)
                        ? passo.$3.withOpacity(0.5)
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: concluido || ativo
                      ? passo.$3.withOpacity(0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: concluido || ativo
                        ? passo.$3.withOpacity(0.25)
                        : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passo.$1,
                      style: TextStyle(
                        color: concluido || ativo
                            ? passo.$3
                            : const Color(0xFF475569),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      passo.$2,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _detalheFuture,
      builder: (context, snapshot) {
        final detalhe = snapshot.data;
        final candidaturaDetalhe = <String, dynamic>{
          ...candidatura,
          if (detalhe != null && detalhe['candidatura'] is Map)
            ...Map<String, dynamic>.from(detalhe['candidatura'] as Map),
        };
        final requisitos = detalhe != null && detalhe['requisitos'] is List
            ? (detalhe['requisitos'] as List)
            : const [];
        final nome =
            candidaturaDetalhe['nome_badge']?.toString() ??
            candidaturaDetalhe['nome']?.toString() ??
            'Badge';
        final estadoRaw =
            candidaturaDetalhe['estado_geral']?.toString() ??
            candidaturaDetalhe['estado_final']?.toString() ??
            candidaturaDetalhe['estado_candidatura_pedido']?.toString() ??
            '-';
        final faseRaw = candidaturaDetalhe['fase_geral']?.toString() ?? '-';
        final coresEstado = _coresEstado(estadoRaw);
        final idBadge = int.tryParse(
          (candidaturaDetalhe['id_badge_modelo'] ??
                  candidaturaDetalhe['id'] ??
                  '')
              .toString(),
        );
        final idCandidatura = int.tryParse(
          (candidaturaDetalhe['id_candidatura_pedido'] ?? '').toString(),
        );
        final idUtilizador = _idUtilizador();
        final int totalEvidencias = _valorContagem([
          candidaturaDetalhe['total_evidencias'],
          requisitos.length,
          candidaturaDetalhe['numero_requisitos'],
          candidaturaDetalhe['requisitos'] is List
              ? (candidaturaDetalhe['requisitos'] as List).length
              : null,
        ]);
        final int evidenciasTm = _valorContagem([
          candidaturaDetalhe['evidencias_decididas_tm'],
        ]);
        final int evidenciasSll = _valorContagem([
          candidaturaDetalhe['evidencias_decididas_sll'],
        ]);
        final bool podeContinuar =
            !_candidaturaEstaFinalizada(candidaturaDetalhe) &&
            idUtilizador > 0 &&
            idBadge != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 20,
                          color: Color(0xFF4470AF),
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Voltar',
                          style: TextStyle(
                            color: Color(0xFF4470AF),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4470AF).withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip(
                              _formatarEstadoHumano(estadoRaw),
                              coresEstado['fundo'] ?? const Color(0xFFE5E7EB),
                              coresEstado['texto'] ?? const Color(0xFF475569),
                              coresEstado['borda'] ?? Colors.transparent,
                            ),
                            if (faseRaw != '-')
                              _buildChip(
                                faseRaw,
                                const Color(0xFFEFF6FF),
                                const Color(0xFF1D4ED8),
                                const Color(0xFFDBEAFE),
                              ),
                            if (_candidaturaEstaFinalizada(candidaturaDetalhe))
                              _buildChip(
                                _candidaturaEstaRejeitada(candidaturaDetalhe)
                                    ? 'Finalizada por rejeição'
                                    : _candidaturaEstaObtida(candidaturaDetalhe)
                                    ? 'Finalizada com aprovação'
                                    : 'Finalizada',
                                _candidaturaEstaRejeitada(candidaturaDetalhe)
                                    ? const Color(0xFFFEE2E2)
                                    : const Color(0xFFDCFCE7),
                                _candidaturaEstaRejeitada(candidaturaDetalhe)
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF166534),
                                _candidaturaEstaRejeitada(candidaturaDetalhe)
                                    ? const Color(0xFFFECACA)
                                    : const Color(0xFFBBF7D0),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _linhaInfo(
                          'ID da candidatura',
                          idCandidatura?.toString() ?? '-',
                        ),
                        _linhaInfo('ID do badge', idBadge?.toString() ?? '-'),
                        _linhaInfo(
                          'Submissão',
                          _formatarData(
                            candidaturaDetalhe['data_submissao']?.toString(),
                          ),
                        ),
                        _linhaInfo('Estado geral', estadoRaw),
                        _linhaInfo('Fase geral', faseRaw),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4470AF).withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado da candidatura',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _stepper(candidaturaDetalhe),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4470AF).withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Linha temporal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _linhaTimeline(
                          'Submissão',
                          candidaturaDetalhe['data_submissao']?.toString(),
                        ),
                        _linhaTimeline(
                          'Receção pelo Talent Manager',
                          candidaturaDetalhe['data_rececao_tm']?.toString(),
                        ),
                        _linhaTimeline(
                          'Conclusão pelo Talent Manager',
                          candidaturaDetalhe['data_conclusao_tm']?.toString(),
                        ),
                        _linhaTimeline(
                          'Receção pelo Service Line Leader',
                          candidaturaDetalhe['data_rececao_sll']?.toString(),
                        ),
                        _linhaTimeline(
                          'Conclusão pelo Service Line Leader',
                          candidaturaDetalhe['data_conclusao_sll']?.toString(),
                        ),
                        _linhaTimeline(
                          'Avaliação final pelo Service Line Leader',
                          candidaturaDetalhe['data_avaliacao_sll']?.toString(),
                        ),
                        _linhaTimeline(
                          'Entrada em histórico',
                          candidaturaDetalhe['data_entrada_historico']
                              ?.toString(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF4470AF).withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumo dos requisitos',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _linhaInfo(
                          'Evidências TM',
                          '$evidenciasTm/${totalEvidencias > 0 ? totalEvidencias : '-'}',
                        ),
                        _linhaInfo(
                          'Evidências SLL',
                          '$evidenciasSll/${totalEvidencias > 0 ? totalEvidencias : '-'}',
                        ),
                      ],
                    ),
                  ),
                  if (_candidaturaEstaRejeitada(candidaturaDetalhe)) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Motivo da rejeição',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _motivoRejeicaoTexto(candidaturaDetalhe),
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: Color(0xFF7F1D1D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4470AF),
                            side: const BorderSide(
                              color: Color(0xFF4470AF),
                              width: 1.4,
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: idBadge == null || idUtilizador <= 0
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BadgeDetalhe(
                                        userId: idUtilizador,
                                        badgeId: idBadge,
                                      ),
                                    ),
                                  );
                                },
                          icon: const Icon(
                            Icons.workspace_premium_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Ver badge',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _candidaturaEstaRejeitada(candidaturaDetalhe)
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF4470AF),
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            elevation: 0,
                          ),
                          onPressed: podeContinuar
                              ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SubmeterBadge(
                                        userId: idUtilizador,
                                        badgeId: idBadge,
                                      ),
                                    ),
                                  );

                                  if (context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StatusCandidaturaDetalhePage(
                                              userData: userData,
                                              candidatura: candidaturaDetalhe,
                                            ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: Text(
                            _candidaturaEstaRejeitada(candidaturaDetalhe)
                                ? 'Reabrir'
                                : 'Continuar',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
