// ============================================================================
// certificado.dart
//
// Carrega todos os dados do consultor e do certificado.
//
// Fluxo:
// 1. Obtém os certificados aprovados do consultor através da API;
// 2. Seleciona o certificado pelo histórico ou pelo badge aberto;
// 3. Obtém os detalhes completos do certificado;
// 4. Obtém os dados do utilizador e do dashboard;
// 5. Normaliza os nomes dos campos;
// 6. Usa SQLite como fallback offline;
// 7. Abre certificado_page.dart com os dados completos.
// ============================================================================

import 'package:flutter/material.dart';

import '../database/basededados.dart';
import '../services/api_service.dart';
import 'certificado_page.dart';

class CertificadoPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CertificadoPage({
    super.key,
    required this.userData,
  });

  @override
  State<CertificadoPage> createState() =>
      _CertificadoPageState();
}

class _CertificadoPageState
    extends State<CertificadoPage> {
  static const Color _azul =
      Color(0xFF4470AF);

  final ApiService _apiService =
      ApiService();

  final Basededados _dbLocal =
      Basededados();

  late Future<Map<String, dynamic>?>
      _certificadoFuture;

  String? _ultimoErro;

  @override
  void initState() {
    super.initState();

    _certificadoFuture =
        _carregarDadosCertificado();
  }

  // =========================================================================
  // AUXILIARES
  // =========================================================================

  int _converterInteiro(
    dynamic valor,
  ) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(
          valor?.toString() ?? '',
        ) ??
        0;
  }

  String _primeiroTexto(
    List<dynamic> valores,
  ) {
    for (final valor in valores) {
      final texto =
          valor?.toString().trim() ??
              '';

      if (
        texto.isNotEmpty &&
        texto.toLowerCase() !=
            'null'
      ) {
        return texto;
      }
    }

    return '';
  }

  dynamic _primeiroValor(
    List<dynamic> valores,
  ) {
    for (final valor in valores) {
      if (valor == null) {
        continue;
      }

      if (valor is String) {
        final texto =
            valor.trim();

        if (
          texto.isEmpty ||
          texto.toLowerCase() ==
              'null'
        ) {
          continue;
        }
      }

      return valor;
    }

    return null;
  }

  Map<String, dynamic>
      _achatarResposta(
    Map<String, dynamic> origem,
  ) {
    final resultado =
        <String, dynamic>{
      ...origem,
    };

    const chavesInternas = [
      'certificado',
      'utilizador',
      'consultor',
      'dashboard',
      'perfil',
      'dados',
      'data',
      'user',
    ];

    for (
      final chave
      in chavesInternas
    ) {
      final interno =
          origem[chave];

      if (interno is Map) {
        resultado.addAll(
          Map<String, dynamic>.from(
            interno,
          ),
        );
      }
    }

    return resultado;
  }

  Map<String, dynamic>
      get _userDataPlano {
    return _achatarResposta(
      Map<String, dynamic>.from(
        widget.userData,
      ),
    );
  }

  int get _userId {
    final dados =
        _userDataPlano;

    return _converterInteiro(
      _primeiroValor([
        dados['id_utilizador'],
        dados['ID_UTILIZADOR'],
        dados['id'],
        dados['user_id'],
      ]),
    );
  }

  int _idHistoricoDe(
    Map<String, dynamic> dados,
  ) {
    return _converterInteiro(
      _primeiroValor([
        dados[
          'id_candidatura_historico'
        ],
        dados['id_historico'],
        dados['historico_id'],
        dados['codigo_historico'],
      ]),
    );
  }

  int _idBadgeDe(
    Map<String, dynamic> dados,
  ) {
    /*
     * Não usar dados['id'].
     *
     * Dependendo da rota, "id" pode ser
     * o ID do histórico e não o ID do
     * badge.
     */
    return _converterInteiro(
      _primeiroValor([
        dados['id_badge_modelo'],
        dados['badge_id'],
        dados['id_badge'],
      ]),
    );
  }

  DateTime _dataOrdenacao(
    Map<String, dynamic> dados,
  ) {
    final valor =
        _primeiroTexto([
      dados[
        'data_entrada_historico'
      ],
      dados['data_emissao'],
      dados['data_atribuicao'],
      dados['data_avaliacao_sll'],
      dados['data'],
    ]);

    return DateTime.tryParse(
          valor,
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
        );
  }

  // =========================================================================
  // CARREGAMENTO PRINCIPAL
  // =========================================================================

  Future<Map<String, dynamic>?>
      _carregarDadosCertificado()
      async {
    _ultimoErro = null;

    if (_userId <= 0) {
      _ultimoErro =
          'Não foi possível identificar '
          'o utilizador autenticado.';

      return null;
    }

    try {
      final dadosOnline =
          await _carregarOnline();

      if (dadosOnline != null) {
        return dadosOnline;
      }
    } catch (
      e,
      stackTrace
    ) {
      _ultimoErro =
          e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      debugPrint(
        '[CERTIFICADO] Erro online: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }

    try {
      final dadosLocais =
          await _carregarLocal();

      if (dadosLocais != null) {
        return dadosLocais;
      }
    } catch (
      e,
      stackTrace
    ) {
      _ultimoErro =
          e.toString().replaceFirst(
        'Exception: ',
        '',
      );

      debugPrint(
        '[CERTIFICADO] Erro local: $e',
      );

      debugPrint(
        '$stackTrace',
      );
    }

    return null;
  }

  // =========================================================================
  // API
  // =========================================================================

  Future<Map<String, dynamic>?>
      _carregarOnline() async {
    final certificados =
        await _apiService
            .getCertificadosDisponiveis(
      _userId,
    );

    if (certificados.isEmpty) {
      return null;
    }

    certificados.sort(
      (
        a,
        b,
      ) =>
          _dataOrdenacao(b)
              .compareTo(
        _dataOrdenacao(a),
      ),
    );

    final user =
        _userDataPlano;

    final historicoPretendido =
        _converterInteiro(
      _primeiroValor([
        user[
          'id_candidatura_historico'
        ],
        user['id_historico'],
      ]),
    );

    final badgePretendido =
        _converterInteiro(
      _primeiroValor([
        user['id_badge_modelo'],
        user['id_badge'],
        user['badge_id'],
      ]),
    );

    debugPrint(
      '========== SELEÇÃO DO CERTIFICADO ==========',
    );

    debugPrint(
      'Utilizador: $_userId',
    );

    debugPrint(
      'Histórico pretendido: '
      '$historicoPretendido',
    );

    debugPrint(
      'Badge pretendido: '
      '$badgePretendido',
    );

    for (
      final certificado
      in certificados
    ) {
      debugPrint(
        'Disponível: '
        'histórico=${_idHistoricoDe(certificado)}, '
        'badge=${_idBadgeDe(certificado)}, '
        'nível=${certificado['id_nivel']}, '
        'nome=${certificado['nome_badge']}',
      );
    }

    Map<String, dynamic>?
        certificadoSelecionado;

    /*
     * 1. O histórico é o identificador
     * mais exato do certificado.
     */
    if (historicoPretendido > 0) {
      for (
        final certificado
        in certificados
      ) {
        if (
          _idHistoricoDe(
            certificado,
          ) ==
          historicoPretendido
        ) {
          certificadoSelecionado =
              Map<String, dynamic>.from(
            certificado,
          );

          break;
        }
      }
    }

    /*
     * 2. Se não foi encontrado pelo
     * histórico, procura pelo ID exato
     * do badge.
     *
     * Não é comparado o nível porque o
     * ID do badge já identifica o badge
     * concreto e algumas respostas da
     * API não contêm id_nivel.
     */
    if (
      certificadoSelecionado == null &&
      badgePretendido > 0
    ) {
      for (
        final certificado
        in certificados
      ) {
        if (
          _idBadgeDe(
            certificado,
          ) ==
          badgePretendido
        ) {
          certificadoSelecionado =
              Map<String, dynamic>.from(
            certificado,
          );

          break;
        }
      }
    }

    /*
     * 3. Apenas abre o mais recente
     * quando a navegação não indicou
     * badge nem histórico.
     */
    if (
      certificadoSelecionado == null &&
      historicoPretendido <= 0 &&
      badgePretendido <= 0
    ) {
      certificadoSelecionado =
          Map<String, dynamic>.from(
        certificados.first,
      );
    }

    if (
      certificadoSelecionado ==
      null
    ) {
      throw Exception(
        'Não foi encontrado um '
        'certificado aprovado para o '
        'badge $badgePretendido.',
      );
    }

    final idHistorico =
        _idHistoricoDe(
      certificadoSelecionado,
    );

    if (idHistorico <= 0) {
      throw Exception(
        'O certificado selecionado '
        'não possui um ID de histórico '
        'válido.',
      );
    }

    debugPrint(
      'Certificado selecionado: '
      'histórico=$idHistorico, '
      'badge=${_idBadgeDe(certificadoSelecionado)}, '
      'nome=${certificadoSelecionado['nome_badge']}',
    );

    debugPrint(
      '=============================================',
    );

    final respostaCertificado =
        await _apiService
            .getCertificado(
      idHistorico:
          idHistorico,

      idUtilizador:
          _userId,
    );

    final detalhes =
        _achatarResposta(
      Map<String, dynamic>.from(
        respostaCertificado,
      ),
    );

    Map<String, dynamic>
        dadosUtilizador = {};

    try {
      final respostaUtilizador =
          await _apiService
              .getUtilizadorPorId(
        _userId,
      );

      dadosUtilizador =
          _achatarResposta(
        Map<String, dynamic>.from(
          respostaUtilizador,
        ),
      );
    } catch (e) {
      debugPrint(
        '[CERTIFICADO] Utilizador '
        'indisponível: $e',
      );
    }

    Map<String, dynamic>
        perfil = {};

    try {
      final respostaDashboard =
          await _apiService
              .getDashboard(
        _userId,
      );

      perfil =
          _achatarResposta(
        Map<String, dynamic>.from(
          respostaDashboard,
        ),
      );
    } catch (e) {
      debugPrint(
        '[CERTIFICADO] Dashboard '
        'indisponível: $e',
      );
    }

    return _normalizarDados(
      certificado: {
        ...detalhes,
        ...dadosUtilizador,
      },

      disponivel:
          certificadoSelecionado,

      perfil: {
        ...perfil,
        ...dadosUtilizador,
      },

      local:
          const <String, dynamic>{},
    );
  }

  // =========================================================================
  // SQLITE
  // =========================================================================

  Future<Map<String, dynamic>?>
      _carregarLocal() async {
    final db =
        await _dbLocal.database;

    final user =
        _userDataPlano;

    final historicoPretendido =
        _converterInteiro(
      _primeiroValor([
        user[
          'id_candidatura_historico'
        ],
        user['id_historico'],
      ]),
    );

    final badgePretendido =
        _converterInteiro(
      _primeiroValor([
        user['id_badge_modelo'],
        user['id_badge'],
        user['badge_id'],
      ]),
    );

    Map<String, dynamic>
        dados = {};

    try {
      final resultado =
          await db.rawQuery(
        '''
        SELECT
          u.id_utilizador,
          u.nome_completo,
          u.email,
          u.email_softinsa,
          u.contacto,
          u.estado_conta,

          c.id_areas,
          c.progresso_nivel,
          c.pontos_atuais,
          c.badges_conquistados_total,
          c.candidatura_submetidas_total,

          a.nome_area,
          a.id_serviceline,
          sl.nome_serviceline,

          cp.id_candidatura_pedido,

          bm.id_badge_modelo,
          bm.nome_badge,
          bm.descricao_badge_modelo,
          bm.pontos,
          bm.id_nivel,
          bm.imagem,

          ch.id_candidatura_historico,
          ch.data_submissao,
          ch.data_avaliacao_tm,
          ch.data_avaliacao_sll,
          ch.data_entrada_historico,
          ch.estado_final,
          ch.motivo_estado_final,
          ch.duracao_total,
          ch.numero_requisitos_completos,
          ch.numero_requisitos_faltantes

        FROM utilizador u

        INNER JOIN consultor c
          ON c.id_utilizador =
             u.id_utilizador

        LEFT JOIN areas a
          ON a.id_areas =
             c.id_areas

        LEFT JOIN serviceline sl
          ON sl.id_serviceline =
             a.id_serviceline

        LEFT JOIN candidatura_pedido cp
          ON cp.id_utilizador =
             u.id_utilizador

        LEFT JOIN badge_modelo bm
          ON bm.id_badge_modelo =
             cp.id_badge_modelo

        LEFT JOIN candidatura_tm ctm
          ON ctm.id_candidatura_pedido =
             cp.id_candidatura_pedido

        LEFT JOIN candidatura_sll csll
          ON csll.id_candidatura_tm =
             ctm.id_candidatura_tm

        LEFT JOIN candidatura_historico ch
          ON ch.id_candidatura_sll =
             csll.id_candidatura_sll

        WHERE
          u.id_utilizador = ?

          AND UPPER(
            COALESCE(
              ch.estado_final,
              ''
            )
          ) IN (
            'APROVADA',
            'APROVADO'
          )

          AND (
            ? = 0
            OR ch.id_candidatura_historico = ?
          )

          AND (
            ? = 0
            OR bm.id_badge_modelo = ?
          )

        ORDER BY
          ch.data_entrada_historico DESC,
          ch.id_candidatura_historico DESC

        LIMIT 1
        ''',
        [
          _userId,
          historicoPretendido,
          historicoPretendido,
          badgePretendido,
          badgePretendido,
        ],
      );

      if (resultado.isNotEmpty) {
        dados =
            Map<String, dynamic>.from(
          resultado.first,
        );
      }
    } catch (e) {
      debugPrint(
        '[CERTIFICADO] Consulta local '
        'completa falhou: $e',
      );
    }

    if (dados.isEmpty) {
      try {
        final resultadoBasico =
            await db.rawQuery(
          '''
          SELECT
            u.id_utilizador,
            u.nome_completo,

            c.progresso_nivel,

            bm.id_badge_modelo,
            bm.nome_badge,
            bm.descricao_badge_modelo,
            bm.pontos,
            bm.id_nivel,

            ch.id_candidatura_historico,
            ch.data_entrada_historico,
            ch.estado_final

          FROM utilizador u

          INNER JOIN consultor c
            ON c.id_utilizador =
               u.id_utilizador

          LEFT JOIN candidatura_pedido cp
            ON cp.id_utilizador =
               u.id_utilizador

          LEFT JOIN badge_modelo bm
            ON bm.id_badge_modelo =
               cp.id_badge_modelo

          LEFT JOIN candidatura_tm ctm
            ON ctm.id_candidatura_pedido =
               cp.id_candidatura_pedido

          LEFT JOIN candidatura_sll csll
            ON csll.id_candidatura_tm =
               ctm.id_candidatura_tm

          LEFT JOIN candidatura_historico ch
            ON ch.id_candidatura_sll =
               csll.id_candidatura_sll

          WHERE
            u.id_utilizador = ?

            AND UPPER(
              COALESCE(
                ch.estado_final,
                ''
              )
            ) IN (
              'APROVADA',
              'APROVADO'
            )

            AND (
              ? = 0
              OR ch.id_candidatura_historico = ?
            )

            AND (
              ? = 0
              OR bm.id_badge_modelo = ?
            )

          ORDER BY
            ch.data_entrada_historico DESC,
            ch.id_candidatura_historico DESC

          LIMIT 1
          ''',
          [
            _userId,
            historicoPretendido,
            historicoPretendido,
            badgePretendido,
            badgePretendido,
          ],
        );

        if (resultadoBasico.isEmpty) {
          return null;
        }

        dados =
            Map<String, dynamic>.from(
          resultadoBasico.first,
        );
      } catch (e) {
        debugPrint(
          '[CERTIFICADO] Consulta local '
          'básica falhou: $e',
        );

        return null;
      }
    }

    final idBadge =
        _idBadgeDe(dados);

    List<Map<String, dynamic>>
        requisitos = [];

    if (idBadge > 0) {
      try {
        final resultadoRequisitos =
            await db.rawQuery(
          '''
          SELECT
            id_badge_requisito,
            id_badge_modelo,
            nome_requisito,
            descricao_requisito

          FROM badge_requisito

          WHERE id_badge_modelo = ?

          ORDER BY id_badge_requisito ASC
          ''',
          [
            idBadge,
          ],
        );

        requisitos =
            resultadoRequisitos
                .map(
                  (
                    item,
                  ) =>
                      Map<String, dynamic>.from(
                    item,
                  ),
                )
                .toList();
      } catch (_) {
        try {
          final resultadoRequisitos =
              await db.rawQuery(
            '''
            SELECT
              id_requisitos,
              nome_requisito,
              titulo,
              descricao_requisito

            FROM requisitos

            WHERE id_badge_modelo = ?

            ORDER BY id_requisitos ASC
            ''',
            [
              idBadge,
            ],
          );

          requisitos =
              resultadoRequisitos
                  .map(
                    (
                      item,
                    ) =>
                        Map<String, dynamic>.from(
                      item,
                    ),
                  )
                  .toList();
        } catch (e) {
          debugPrint(
            '[CERTIFICADO] Requisitos '
            'locais indisponíveis: $e',
          );
        }
      }
    }

    dados['requisitos'] =
        requisitos;

    return _normalizarDados(
      certificado:
          dados,

      disponivel:
          const <String, dynamic>{},

      perfil:
          const <String, dynamic>{},

      local:
          dados,
    );
  }

  // =========================================================================
  // NORMALIZAÇÃO FINAL
  // =========================================================================

  Map<String, dynamic>
      _normalizarDados({
    required Map<String, dynamic>
        certificado,

    required Map<String, dynamic>
        disponivel,

    required Map<String, dynamic>
        perfil,

    required Map<String, dynamic>
        local,
  }) {
    final user =
        _userDataPlano;

    final nomeCompleto =
        _primeiroTexto([
      certificado['nome_completo'],
      certificado['NOME_COMPLETO'],
      certificado['nome_utilizador'],
      certificado['nome_consultor'],
      certificado['nome'],

      perfil['nome_completo'],
      perfil['NOME_COMPLETO'],
      perfil['nome_utilizador'],
      perfil['nome_consultor'],
      perfil['nome'],

      user['nome_completo'],
      user['NOME_COMPLETO'],
      user['nome_utilizador'],
      user['nome_consultor'],
      user['nome'],

      local['nome_completo'],
      local['NOME_COMPLETO'],
      local['nome'],
    ]);

    final email =
        _primeiroTexto([
      certificado['email'],
      certificado['email_consultor'],
      perfil['email'],
      user['email'],
      local['email'],
    ]);

    final emailSoftinsa =
        _primeiroTexto([
      certificado['email_softinsa'],
      certificado[
        'email_softinsa_consultor'
      ],
      perfil['email_softinsa'],
      user['email_softinsa'],
      local['email_softinsa'],
    ]);

    final contacto =
        _primeiroTexto([
      certificado['contacto'],
      certificado[
        'contacto_consultor'
      ],
      perfil['contacto'],
      user['contacto'],
      local['contacto'],
    ]);

    final nomeArea =
        _primeiroTexto([
      certificado['nome_area'],
      certificado['area'],
      perfil['nome_area'],
      perfil['area'],
      disponivel['nome_area'],
      user['nome_area'],
      user['area'],
      local['nome_area'],
    ]);

    final nomeServiceLine =
        _primeiroTexto([
      certificado[
        'nome_serviceline'
      ],
      certificado[
        'nome_service_line'
      ],
      perfil['nome_serviceline'],
      perfil['nome_service_line'],
      disponivel[
        'nome_serviceline'
      ],
      disponivel[
        'nome_service_line'
      ],
      local['nome_serviceline'],
      local['nome_service_line'],
    ]);

    final cargoRecebido =
        _primeiroTexto([
      certificado['cargo'],
      certificado[
        'cargo_consultor'
      ],
      perfil['cargo'],
      user['cargo'],
      local['cargo'],
    ]);

    final cargoFinal =
        cargoRecebido.isNotEmpty
            ? cargoRecebido
            : nomeArea.isNotEmpty
                ? 'Consultor/a - '
                    '$nomeArea'
                : 'Consultor/a';

    final nomeBadge =
        _primeiroTexto([
      certificado['nome_badge'],
      certificado['badge'],
      disponivel['nome_badge'],
      disponivel['badge'],
      local['nome_badge'],
      local['badge'],
    ]);

    final nomeNivel =
        _primeiroTexto([
      certificado['nome_nivel'],
      certificado['nivel'],
      disponivel['nome_nivel'],
      disponivel['nivel'],
      local['nome_nivel'],
      local['nivel'],
    ]);

    final idNivel =
        _converterInteiro(
      _primeiroValor([
        certificado['id_nivel'],
        disponivel['id_nivel'],
        local['id_nivel'],
        user['id_nivel'],
      ]),
    );

    final idHistorico =
        _converterInteiro(
      _primeiroValor([
        certificado[
          'id_candidatura_historico'
        ],
        disponivel[
          'id_candidatura_historico'
        ],
        local[
          'id_candidatura_historico'
        ],
      ]),
    );

    final idBadge =
        _converterInteiro(
      _primeiroValor([
        certificado['id_badge_modelo'],
        disponivel['id_badge_modelo'],
        local['id_badge_modelo'],
        user['id_badge_modelo'],
      ]),
    );

    final codigoRecebido =
        _primeiroTexto([
      certificado[
        'codigo_certificado'
      ],
      certificado[
        'codigo_verificacao'
      ],
      disponivel[
        'codigo_certificado'
      ],
      disponivel[
        'codigo_verificacao'
      ],
      local['codigo_certificado'],
      local['codigo_verificacao'],
    ]);

    final codigo =
        codigoRecebido.isNotEmpty
            ? codigoRecebido
            : 'CERT-'
                '${idHistorico > 0 ? idHistorico : 'H'}-'
                '$_userId';

    final urlRecebido =
        _primeiroTexto([
      certificado[
        'url_verificacao'
      ],
      disponivel[
        'url_verificacao'
      ],
      local['url_verificacao'],
    ]);

    final url =
        urlRecebido.isNotEmpty
            ? urlRecebido
            : 'softinsa.pt/badges/'
                '$_userId/'
                '${idBadge > 0 ? idBadge : 'badge'}';

    final requisitos =
        _primeiroValor([
      certificado['requisitos'],
      disponivel['requisitos'],
      local['requisitos'],
    ]);

    final dataEmissao =
        _primeiroValor([
      certificado['data_emissao'],
      certificado[
        'data_entrada_historico'
      ],
      certificado[
        'data_avaliacao_sll'
      ],
      disponivel['data_emissao'],
      disponivel[
        'data_entrada_historico'
      ],
      disponivel[
        'data_atribuicao'
      ],
      local[
        'data_entrada_historico'
      ],
    ]);

    final resultado =
        <String, dynamic>{
      ...user,
      ...perfil,
      ...disponivel,
      ...local,
      ...certificado,

      'id_utilizador':
          _userId,

      'nome_completo':
          nomeCompleto,

      'nome_utilizador':
          nomeCompleto,

      'nome_consultor':
          nomeCompleto,

      'nome':
          nomeCompleto,

      'email':
          email,

      'email_consultor':
          email,

      'email_softinsa':
          emailSoftinsa,

      'email_softinsa_consultor':
          emailSoftinsa,

      'contacto':
          contacto,

      'cargo':
          cargoFinal,

      'cargo_consultor':
          cargoFinal,

      'nome_area':
          nomeArea,

      'area':
          nomeArea,

      'nome_serviceline':
          nomeServiceLine,

      'nome_service_line':
          nomeServiceLine,

      'id_areas':
          _primeiroValor([
        certificado['id_areas'],
        perfil['id_areas'],
        disponivel['id_areas'],
        local['id_areas'],
      ]),

      'id_serviceline':
          _primeiroValor([
        certificado[
          'id_serviceline'
        ],
        perfil['id_serviceline'],
        disponivel[
          'id_serviceline'
        ],
        local['id_serviceline'],
      ]),

      'progresso_nivel':
          _primeiroValor([
        certificado[
          'progresso_nivel'
        ],
        perfil[
          'progresso_nivel'
        ],
        local[
          'progresso_nivel'
        ],
      ]),

      'pontos_atuais':
          _primeiroValor([
        certificado['pontos_atuais'],
        perfil['pontos_atuais'],
        local['pontos_atuais'],
      ]),

      'badges_conquistados_total':
          _primeiroValor([
        certificado[
          'badges_conquistados_total'
        ],
        perfil[
          'badges_conquistados_total'
        ],
        perfil['total_badges'],
        local[
          'badges_conquistados_total'
        ],
      ]),

      'candidatura_submetidas_total':
          _primeiroValor([
        certificado[
          'candidatura_submetidas_total'
        ],
        perfil[
          'candidatura_submetidas_total'
        ],
        local[
          'candidatura_submetidas_total'
        ],
      ]),

      'id_candidatura_historico':
          idHistorico,

      'id_badge_modelo':
          idBadge,

      'id_nivel':
          idNivel,

      'nome_badge':
          nomeBadge,

      'nome_nivel':
          nomeNivel,

      'nivel':
          nomeNivel,

      'pontos':
          _primeiroValor([
        certificado['pontos'],
        certificado['pontos_badge'],
        disponivel['pontos'],
        local['pontos'],
      ]),

      'descricao_badge_modelo':
          _primeiroTexto([
        certificado[
          'descricao_badge_modelo'
        ],
        disponivel[
          'descricao_badge_modelo'
        ],
        local[
          'descricao_badge_modelo'
        ],
      ]),

      'imagem':
          _primeiroValor([
        certificado['imagem'],
        certificado['imagem_badge'],
        disponivel['imagem'],
        local['imagem'],
      ]),

      'requisitos':
          requisitos is List
              ? requisitos
              : <dynamic>[],

      'data_emissao':
          dataEmissao,

      'codigo_certificado':
          codigo,

      'codigo_verificacao':
          codigo,

      'url_verificacao':
          url,
    };

    debugPrint(
      '========== CERTIFICADO FINAL ==========',
    );

    debugPrint(
      'ID utilizador: '
      '${resultado['id_utilizador']}',
    );

    debugPrint(
      'Nome: '
      '${resultado['nome_completo']}',
    );

    debugPrint(
      'Badge: '
      '${resultado['nome_badge']}',
    );

    debugPrint(
      'ID badge: '
      '${resultado['id_badge_modelo']}',
    );

    debugPrint(
      'Histórico: '
      '${resultado['id_candidatura_historico']}',
    );

    debugPrint(
      '=======================================',
    );

    return resultado;
  }

  // =========================================================================
  // RECARREGAR
  // =========================================================================

  Future<void> _recarregar() async {
    setState(() {
      _certificadoFuture =
          _carregarDadosCertificado();
    });

    await _certificadoFuture;
  }

  // =========================================================================
  // INTERFACE
  // =========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return FutureBuilder<
        Map<String, dynamic>?>(
      future:
          _certificadoFuture,

      builder: (
        context,
        snapshot,
      ) {
        if (
          snapshot.connectionState ==
          ConnectionState.waiting
        ) {
          return const Scaffold(
            backgroundColor:
                Color(
              0xFFF3F4F6,
            ),
            body:
                Center(
              child:
                  CircularProgressIndicator(
                color:
                    _azul,
              ),
            ),
          );
        }

        final dados =
            snapshot.data;

        if (
          snapshot.hasError ||
          dados == null
        ) {
          return Scaffold(
            backgroundColor:
                const Color(
              0xFFF3F4F6,
            ),
            appBar:
                AppBar(
              backgroundColor:
                  Colors.white,
              surfaceTintColor:
                  Colors.white,
              elevation:
                  0,
              leading:
                  IconButton(
                onPressed: () =>
                    Navigator.pop(
                  context,
                ),
                icon:
                    const Icon(
                  Icons.arrow_back,
                  color:
                      _azul,
                ),
              ),
              title:
                  Image.asset(
                'lib/img/logo.png',
                height:
                    34,
                fit:
                    BoxFit.contain,
              ),
            ),
            body:
                RefreshIndicator(
              color:
                  _azul,
              onRefresh:
                  _recarregar,
              child:
                  ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.all(
                  24,
                ),
                children: [
                  const SizedBox(
                    height:
                        100,
                  ),
                  Icon(
                    Icons
                        .workspace_premium_outlined,
                    size:
                        64,
                    color:
                        Colors.grey.shade400,
                  ),
                  const SizedBox(
                    height:
                        14,
                  ),
                  const Text(
                    'Certificado não disponível',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      fontSize:
                          18,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height:
                        7,
                  ),
                  Text(
                    'Não foi encontrado um '
                    'certificado aprovado para '
                    'este badge.',
                    textAlign:
                        TextAlign.center,
                    style:
                        TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize:
                          12,
                    ),
                  ),
                  if (
                    _ultimoErro != null
                  ) ...[
                    const SizedBox(
                      height:
                          10,
                    ),
                    Text(
                      _ultimoErro!,
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.red.shade400,
                        fontSize:
                            10,
                      ),
                    ),
                  ],
                  const SizedBox(
                    height:
                        20,
                  ),
                  Center(
                    child:
                        OutlinedButton.icon(
                      onPressed:
                          _recarregar,
                      icon:
                          const Icon(
                        Icons.refresh,
                      ),
                      label:
                          const Text(
                        'Tentar novamente',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return CertificadoCompetenciasPage(
          userData: {
            ...widget.userData,
            ...dados,
          },

          certificadoData:
              dados,
        );
      },
    );
  }
}
