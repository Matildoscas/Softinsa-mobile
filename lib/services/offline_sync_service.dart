import 'dart:io';

import '../database/basededados.dart';
import 'api_service.dart';

class OfflineSyncService {
  OfflineSyncService._internal();

  static final OfflineSyncService _instance = OfflineSyncService._internal();

  factory OfflineSyncService() => _instance;

  final Basededados _dbLocal = Basededados();
  final ApiService _apiService = ApiService();

  bool _emSincronizacao = false;

  Future<void> sincronizarPendenciasUtilizador(int userId) async {
    if (userId <= 0 || _emSincronizacao) {
      return;
    }

    _emSincronizacao = true;

    try {
      final db = await _dbLocal.database;
      final pendentes = await db.query(
        'candidatura_pedido',
        where: 'id_utilizador = ? AND estado_candidatura_pedido = ?',
        whereArgs: [userId, 'Aguardando Sincronização'],
        orderBy: 'data_submisao ASC',
      );

      for (final pedido in pendentes) {
        final idCandidatura = int.tryParse(
              (pedido['id_candidatura_pedido'] ?? '').toString(),
            ) ??
            0;

        final idBadge = int.tryParse(
              (pedido['id_badge_modelo'] ?? '').toString(),
            ) ??
            0;

        if (idCandidatura <= 0 || idBadge <= 0) {
          continue;
        }

        final evidenciasLocal = await db.query(
          'evidencias',
          where: 'id_candidatura_pedido = ?',
          whereArgs: [idCandidatura],
          orderBy: 'id_evidencia ASC',
        );

        if (evidenciasLocal.isEmpty) {
          continue;
        }

        final comentario = evidenciasLocal.first['descricao']?.toString() ?? '';

        final evidenciasApi = <Map<String, dynamic>>[];
        for (final evidencia in evidenciasLocal) {
          final caminho = evidencia['caminho_ficheiro']?.toString() ?? '';
          if (caminho.isEmpty) {
            continue;
          }

          evidenciasApi.add({
            'id_requisito': evidencia['id_requisitos'],
            'titulo': evidencia['nome_ficheiro']?.toString() ?? 'Evidencia',
            'nome': evidencia['nome_ficheiro']?.toString() ?? 'Evidencia',
            'caminho_ficheiro': caminho,
            'nome_ficheiro': evidencia['nome_ficheiro']?.toString() ?? 'ficheiro',
            'formato_ficheiro': evidencia['formato_ficheiro']?.toString() ?? 'file',
          });
        }

        if (evidenciasApi.isEmpty) {
          continue;
        }

        try {
          await _apiService.submeterEvidenciasPorRequisito(
            userId: userId,
            badgeId: idBadge,
            comentario: comentario,
            evidencias: evidenciasApi,
            autorizaPublicacaoBadge: false,
            linkedinPublicacaoBadge: null,
            idLembrete: null,
          );

          await db.update(
            'candidatura_pedido',
            {
              'estado_candidatura_pedido': 'Sincronizada',
              'data_validacao': DateTime.now().toIso8601String(),
            },
            where: 'id_candidatura_pedido = ?',
            whereArgs: [idCandidatura],
          );

          await db.update(
            'evidencias',
            {'estado_evidencia': 'Sincronizada'},
            where: 'id_candidatura_pedido = ?',
            whereArgs: [idCandidatura],
          );
        } on SocketException {
          break;
        } catch (_) {
          continue;
        }
      }
    } finally {
      _emSincronizacao = false;
    }
  }
}
