// ============================================================================
// submeter_badges.dart
//
// Formulário de submissão de evidências para um badge.
// Carrega o badge, valida uma descrição mínima, permite escolher um ficheiro,
// envia a candidatura à API e guarda localmente quando não existe ligação.
//
// A lógica original foi mantida.
// Os comentários explicam:
// - Responsabilidade de cada classe e função;
// - Fluxo entre API, SQLite e interface;
// - Pesquisa, filtros, navegação e estados;
// - Tratamento de imagens, ficheiros e modo offline.
// ============================================================================

// Widgets visuais e navegação.
import 'package:flutter/material.dart';
// Plugin utilizado para selecionar ficheiros no dispositivo.
import 'package:file_picker/file_picker.dart';
// Serviço utilizado para carregar badges e enviar evidências.
import '../services/api_service.dart';
// SQLite utilizado para guardar candidaturas e evidências offline.
import '../database/basededados.dart'; // Import central para salvar evidências offline
import 'informacoes_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Página identificada pelo utilizador e pelo badge selecionado.
class SubmeterBadge extends StatefulWidget {
  final int userId;
  final int badgeId;
  final int? idLembrete;

  const SubmeterBadge({
    super.key,
    required this.userId,
    required this.badgeId,
    this.idLembrete,
  });

  @override
  State<SubmeterBadge> createState() => _SubmeterBadgeState();
}

// Estado do formulário: badge, descrição, ficheiro e submissão.
class _SubmeterBadgeState extends State<SubmeterBadge> {
  static const Color _azul = Color(0xFF4470AF);
  bool _autorizaPublicacaoBadge = false;
  bool _autorizaAnalytics = false;

  final TextEditingController _linkedinController =
      TextEditingController();

  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância local SQLite

  Map<String, dynamic>? badge;

  List<Map<String, dynamic>>
      requisitos = [];

  bool isLoading = true;

  final TextEditingController
      _descricaoController =
      TextEditingController();

  /*
  * Cada requisito tem a sua própria
  * lista de ficheiros.
  */
  final Map<
    String,
    List<PlatformFile>
  > _ficheirosPorRequisito = {};

  bool _submetido = false;

  Widget _requisitoEvidenciaCard(
    Map<String, dynamic> requisito,
    int index,
  ) {
    final String chave =
        _chaveRequisito(
      requisito,
      index,
    );

    final ficheiros =
        _ficheirosPorRequisito[
              chave
            ] ??
            const <PlatformFile>[];

    final String titulo =
        requisito['titulo']
                ?.toString() ??
            requisito['nome']
                ?.toString() ??
            'Requisito ${index + 1}';

    final String descricao =
        requisito['descricao']
                ?.toString() ??
            '';

    final String codigo =
        titulo.length <= 4
            ? titulo
            : 'R${index + 1}';

    final bool completo =
        ficheiros.isNotEmpty;

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration: BoxDecoration(
        color: completo
            ? const Color(
                0xFFF3FAF4,
              )
            : const Color(
                0xFFF8F9FA,
              ),

        borderRadius:
            BorderRadius.circular(
          12,
        ),

        border: Border.all(
          color: completo
              ? const Color(
                  0xFF2E7D32,
                ).withOpacity(
                  0.4,
                )
              : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(
                  color: completo
                      ? const Color(
                          0xFF2E7D32,
                        )
                      : _azul,
                  shape:
                      BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    codigo,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          9,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      titulo,
                      style:
                          const TextStyle(
                        fontSize:
                            13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    if (
                      descricao.isNotEmpty
                    ) ...[
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        descricao,
                        style:
                            TextStyle(
                          fontSize:
                              11,
                          color:
                              Colors.grey
                                  .shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                completo
                    ? Icons.check_circle
                    : Icons
                        .radio_button_unchecked,
                color: completo
                    ? const Color(
                        0xFF2E7D32,
                      )
                    : Colors.grey,
                size: 20,
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          InkWell(
            onTap: _submetido
                ? null
                : () =>
                    _escolherFicheirosParaRequisito(
                      index,
                    ),
            borderRadius:
                BorderRadius.circular(
              8,
            ),
            child: Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 11,
                horizontal: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  8,
                ),
                border:
                    Border.all(
                  color:
                      Colors.grey
                          .shade300,
                ),
              ),
              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Icon(
                    Icons
                        .attach_file,
                    size: 17,
                    color: _azul,
                  ),
                  SizedBox(
                    width: 5,
                  ),
                  Text(
                    'Anexar ficheiro',
                    style: TextStyle(
                      color: _azul,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (ficheiros.isNotEmpty) ...[
            const SizedBox(
              height: 9,
            ),

            ...ficheiros
                .asMap()
                .entries
                .map(
              (entry) {
                final ficheiro =
                    entry.value;

                return Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 5,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius
                            .circular(
                      8,
                    ),
                    border:
                        Border.all(
                      color:
                          Colors.grey
                              .shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons
                            .insert_drive_file_outlined,
                        size: 17,
                        color: _azul,
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      Expanded(
                        child: Text(
                          ficheiro.name,
                          maxLines:
                              1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize:
                                11,
                          ),
                        ),
                      ),

                      IconButton(
                        constraints:
                            const BoxConstraints(),
                        padding:
                            const EdgeInsets
                                .all(
                          3,
                        ),
                        onPressed:
                            _submetido
                                ? null
                                : () =>
                                    _removerFicheiro(
                                      requisitoIndex:
                                          index,
                                      ficheiroIndex:
                                          entry.key,
                                    ),
                        icon:
                            const Icon(
                          Icons.close,
                          size: 17,
                          color:
                              Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  // Carrega o badge e adiciona um listener à descrição.
  // O listener permite atualizar o contador de caracteres em tempo real.
  void initState() {
    super.initState();
    _carregarBadge();
    _descricaoController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  // =========================================================================
  // CARREGAR BADGE
  //
  // Tenta obter o catálogo pela API.
  // Em modo offline, adapta os registos da tabela badge_modelo.
  // Depois procura o badge correspondente ao badgeId recebido.
  // =========================================================================
  Future<void> _carregarBadge() async {
    List<Map<String, dynamic>> todos = [];

    try {
      todos =
          await _apiService
              .getTodosBadges();
    } catch (e) {
      debugPrint(
        'Modo Offline Ativo ao carregar '
        'badge para submissão: $e',
      );

      final localModelos =
          await _dbLocal.listarTabela(
        'badge_modelo',
      );

      final localRequisitos =
          await _dbLocal.listarTabela(
        'badge_requisito',
      );

      todos = localModelos.map(
        (modelo) {
          final int? idBadge =
              int.tryParse(
            modelo['id_badge_modelo']
                    ?.toString() ??
                '',
          );

          final requisitosBadge =
              localRequisitos
                  .where(
                    (requisito) =>
                        requisito[
                              'id_badge_modelo'
                            ]?.toString() ==
                        idBadge?.toString(),
                  )
                  .map(
                    (requisito) =>
                        <String, dynamic>{
                      'id_requisito':
                          requisito[
                                'id_requisitos'
                              ] ??
                          requisito[
                            'id_requisito'
                          ],

                      'id_requisitos':
                          requisito[
                                'id_requisitos'
                              ] ??
                          requisito[
                            'id_requisito'
                          ],

                      'nome':
                          requisito[
                                'nome_requisito'
                              ] ??
                          requisito['titulo'] ??
                          'Requisito',

                      'titulo':
                          requisito['titulo'] ??
                          requisito[
                            'nome_requisito'
                          ] ??
                          'Requisito',

                      'descricao':
                          requisito[
                                'descricao_requisito'
                              ] ??
                          '',
                    },
                  )
                  .toList();

          return <String, dynamic>{
            'id':
                modelo[
                  'id_badge_modelo'
                ],

            'id_badge_modelo':
                modelo[
                  'id_badge_modelo'
                ],

            'nome':
                modelo['nome_badge'],

            'nome_badge':
                modelo['nome_badge'],

            'descricao':
                modelo[
                  'descricao_badge_modelo'
                ],

            'descricao_badge_modelo':
                modelo[
                  'descricao_badge_modelo'
                ],

            'pontos':
                modelo['pontos'],

            'id_nivel':
                modelo['id_nivel'],

            'imagem':
                modelo['imagem'],

            'imagem_url':
                modelo['imagem_url'] ??
                modelo['imagem'],

            'url_imagem':
                modelo['url_imagem'],

            'requisitos':
                requisitosBadge,
          };
        },
      ).toList();
    }

    final encontrado =
        todos.firstWhere(
      (item) {
        final int id =
            int.tryParse(
              (
                item['id'] ??
                item[
                  'id_badge_modelo'
                ] ??
                ''
              ).toString(),
            ) ??
            -1;

        return id ==
            widget.badgeId;
      },
      orElse: () =>
          <String, dynamic>{},
    );

    final rawRequisitos =
        encontrado['requisitos'];

    final List<Map<String, dynamic>>
        listaRequisitos =
        rawRequisitos is List
            ? rawRequisitos
                .whereType<Map>()
                .map(
                  (item) =>
                      Map<String, dynamic>
                          .from(item),
                )
                .toList()
            : [];

    if (!mounted) {
      return;
    }

    setState(() {
      badge = encontrado.isNotEmpty
          ? encontrado
          : null;

      requisitos =
          listaRequisitos;

      isLoading = false;
    });
  }

  // Número atual de caracteres escritos na descrição.
  int get _charCount =>
      _descricaoController.text
          .trim()
          .length;

  bool get _descricaoValida =>
      _charCount >= 100;

  String _chaveRequisito(
    Map<String, dynamic> requisito,
    int index,
  ) {
    final dynamic id =
        requisito['id_requisito'] ??
        requisito['id_requisitos'] ??
        requisito['id'];

    if (id != null) {
      return 'requisito_$id';
    }

    return 'requisito_indice_$index';
  }

  int? _idRequisito(
    Map<String, dynamic> requisito,
  ) {
    return int.tryParse(
      (
        requisito['id_requisito'] ??
        requisito['id_requisitos'] ??
        requisito['id'] ??
        ''
      ).toString(),
    );
  }

  bool get _todosRequisitosComFicheiro {
    if (requisitos.isEmpty) {
      return false;
    }

    for (
      int index = 0;
      index < requisitos.length;
      index++
    ) {
      final chave = _chaveRequisito(
        requisitos[index],
        index,
      );

      final ficheiros =
          _ficheirosPorRequisito[chave] ??
          const <PlatformFile>[];

      if (ficheiros.isEmpty) {
        return false;
      }
    }

    return true;
  }

  bool get _podeSubmeter =>
      _descricaoValida &&
      _todosRequisitosComFicheiro;

  int get _totalFicheiros {
    return _ficheirosPorRequisito.values
        .fold<int>(
      0,
      (
        total,
        ficheiros,
      ) =>
          total + ficheiros.length,
    );
  }

  String get _mensagemValidacao {
    if (!_descricaoValida) {
      return 'A descrição necessita de ter '
          'pelo menos 100 caracteres.';
    }

    if (requisitos.isEmpty) {
      return 'Este badge não possui '
          'requisitos disponíveis.';
    }

    if (!_todosRequisitosComFicheiro) {
      return 'É necessário anexar pelo menos '
          'um ficheiro em cada requisito.';
    }

    return '';
  }

  // =========================================================================
  // ESCOLHER FICHEIRO
  //
  // Abre o seletor para PDF, DOC, DOCX, JPG ou PNG.
  // Cancela quando nenhum ficheiro é escolhido e rejeita ficheiros
  // com tamanho superior a 10 MB.
  // =========================================================================
  Future<void>
      _escolherFicheirosParaRequisito(
    int index,
  ) async {
    if (
      index < 0 ||
      index >= requisitos.length
    ) {
      return;
    }

    try {
      final result =
          await FilePicker.platform
              .pickFiles(
        type: FileType.custom,

        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'jpg',
          'jpeg',
          'png',
        ],

        allowMultiple: true,

        withData: false,
      );

      if (
        result == null ||
        result.files.isEmpty
      ) {
        return;
      }

      final List<PlatformFile>
          ficheirosValidos = [];

      for (final ficheiro in result.files) {
        final double tamanhoMb =
            ficheiro.size /
            (1024 * 1024);

        if (tamanhoMb > 10) {
          _mostrarErro(
            'O ficheiro "${ficheiro.name}" '
            'ultrapassa os 10 MB.',
          );

          continue;
        }

        if (ficheiro.path == null) {
          _mostrarErro(
            'Não foi possível aceder ao '
            'ficheiro "${ficheiro.name}".',
          );

          continue;
        }

        ficheirosValidos.add(
          ficheiro,
        );
      }

      if (ficheirosValidos.isEmpty) {
        return;
      }

      final requisito =
          requisitos[index];

      final chave =
          _chaveRequisito(
        requisito,
        index,
      );

      setState(() {
        final atuais =
            List<PlatformFile>.from(
          _ficheirosPorRequisito[
                chave
              ] ??
              const <PlatformFile>[],
        );

        for (
          final ficheiro
          in ficheirosValidos
        ) {
          final jaExiste =
              atuais.any(
            (existente) =>
                existente.name ==
                    ficheiro.name &&
                existente.size ==
                    ficheiro.size,
          );

          if (!jaExiste) {
            atuais.add(
              ficheiro,
            );
          }
        }

        _ficheirosPorRequisito[
          chave
        ] = atuais;
      });
    } catch (e) {
      _mostrarErro(
        'Erro ao selecionar ficheiro: $e',
      );
    }
  }

  void _removerFicheiro({
    required int requisitoIndex,
    required int ficheiroIndex,
  }) {
    if (
      requisitoIndex < 0 ||
      requisitoIndex >= requisitos.length
    ) {
      return;
    }

    final chave =
        _chaveRequisito(
      requisitos[requisitoIndex],
      requisitoIndex,
    );

    final ficheiros =
        List<PlatformFile>.from(
      _ficheirosPorRequisito[chave] ??
          const <PlatformFile>[],
    );

    if (
      ficheiroIndex < 0 ||
      ficheiroIndex >= ficheiros.length
    ) {
      return;
    }

    ficheiros.removeAt(
      ficheiroIndex,
    );

    setState(() {
      _ficheirosPorRequisito[chave] =
          ficheiros;
    });
  }

  // Mostra uma SnackBar vermelha com a mensagem recebida.
  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // FLUXO ASSÍNCRONO CORRIGIDO E ALINHADO COM AS COLUNAS DO BASEDEDADOS.DART
  // =========================================================================
  // SUBMETER EVIDÊNCIA
  //
  // 1. Impede submissão inválida ou repetida;
  // 2. Ativa o indicador de processamento;
  // 3. Tenta enviar texto e ficheiro para a API com timeout de 20 segundos;
  // 4. Se falhar, cria candidatura_pedido no SQLite;
  // 5. Guarda também a evidência e o caminho do ficheiro;
  // 6. Desativa sempre o indicador no bloco finally.
  // =========================================================================
  Future<void> _submeter() async {
    if (_submetido) {
      return;
    }

    if (!_podeSubmeter) {
      _mostrarErro(
        _mensagemValidacao,
      );

      return;
    }

    final String descricaoTexto =
        _descricaoController.text
            .trim();

    final List<Map<String, dynamic>>
        evidencias = [];

    /*
    * Constrói a lista de evidências
    * antes de chamar a API.
    */
    for (
      int requisitoIndex = 0;
      requisitoIndex <
          requisitos.length;
      requisitoIndex++
    ) {
      final Map<String, dynamic>
          requisito =
          requisitos[requisitoIndex];

      final int? idRequisito =
          _idRequisito(
        requisito,
      );

      if (idRequisito == null) {
        _mostrarErro(
          'O requisito '
          '"${requisito['titulo'] ?? requisito['nome'] ?? 'Requisito'}" '
          'não possui um ID válido.',
        );

        return;
      }

      final String chave =
          _chaveRequisito(
        requisito,
        requisitoIndex,
      );

      final List<PlatformFile>
          ficheiros =
          _ficheirosPorRequisito[
                chave
              ] ??
              const <PlatformFile>[];

      if (ficheiros.isEmpty) {
        _mostrarErro(
          'É necessário anexar pelo menos '
          'um ficheiro ao requisito '
          '"${requisito['titulo'] ?? requisito['nome'] ?? 'Requisito'}".',
        );

        return;
      }

      for (final ficheiro in ficheiros) {
        final String? caminho =
            ficheiro.path;

        if (
          caminho == null ||
          caminho.isEmpty
        ) {
          _mostrarErro(
            'Não foi possível aceder ao '
            'ficheiro "${ficheiro.name}".',
          );

          return;
        }

        evidencias.add({
          'id_requisito':
              idRequisito,

          'titulo':
              requisito['titulo'] ??
              requisito['nome'] ??
              'Requisito',

          'nome':
              requisito['nome'] ??
              requisito['titulo'] ??
              'Requisito',

          'caminho_ficheiro':
              caminho,

          'nome_ficheiro':
              ficheiro.name,

          'formato_ficheiro':
              ficheiro.extension ??
              'file',
        });
      }
    }

    if (evidencias.isEmpty) {
      _mostrarErro(
        'Não existem evidências para submeter.',
      );

      return;
    }

    if (!_autorizaPublicacaoBadge) {
      final continuar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Publicação não autorizada',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Podes submeter a candidatura sem autorizar a publicação. '
            'Nesse caso, o badge poderá ficar disponível apenas internamente '
            'e não será apresentado no perfil público.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _azul,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (continuar != true) {
        return;
      }
    }

    setState(() {
      _submetido = true;
    });

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        'rgpd_analytics_aceite',
        _autorizaAnalytics,
      );
      await _apiService
          .submeterEvidenciasPorRequisito(
        userId:
            widget.userId,

        badgeId:
            widget.badgeId,

        comentario:
            descricaoTexto,

        evidencias:
            evidencias,

        autorizaPublicacaoBadge:
            _autorizaPublicacaoBadge,

        linkedinPublicacaoBadge:
            _linkedinController.text.trim(),

        idLembrete:
            widget.idLembrete,
      )
          .timeout(
        const Duration(
          seconds: 30,
        ),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Evidências submetidas por '
            'requisito com sucesso!',
          ),
          backgroundColor:
              Color(
            0xFF2E7D32,
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      debugPrint(
        'Falha ao enviar evidências. '
        'A guardar localmente: $e',
      );

      try {
        final int idPedidoLocal =
            DateTime.now()
                .millisecondsSinceEpoch;

        await _dbLocal.salvarRegisto(
          'candidatura_pedido',
          {
            'id_candidatura_pedido':
                idPedidoLocal,

            'id_utilizador':
                widget.userId,

            'id_badge_modelo':
                widget.badgeId,

            'data_submisao':
                DateTime.now()
                    .toString(),

            'estado_candidatura_pedido':
                'Aguardando Sincronização',
          },
        );

        for (
          int index = 0;
          index < evidencias.length;
          index++
        ) {
          final Map<String, dynamic>
              evidencia =
              evidencias[index];

          await _dbLocal.salvarRegisto(
            'evidencias',
            {
              'id_evidencia':
                  idPedidoLocal +
                  index +
                  1,

              'id_requisitos':
                  evidencia[
                    'id_requisito'
                  ],

              'id_candidatura_pedido':
                  idPedidoLocal,

              'descricao':
                  descricaoTexto,

              'nome_ficheiro':
                  evidencia[
                    'nome_ficheiro'
                  ],

              'formato_ficheiro':
                  evidencia[
                    'formato_ficheiro'
                  ],

              'data_submissao':
                  DateTime.now()
                      .toString(),

              'estado_evidencia':
                  'Pendente',

              'caminho_ficheiro':
                  evidencia[
                    'caminho_ficheiro'
                  ],
            },
          );
        }

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Foram guardadas localmente '
              '${evidencias.length} evidências. '
              'Serão sincronizadas quando '
              'existir ligação.',
            ),
            backgroundColor:
                Colors.orange,
            duration:
                const Duration(
              seconds: 5,
            ),
          ),
        );

        Navigator.pop(
          context,
          true,
        );
      } catch (erroDb) {
        if (mounted) {
          _mostrarErro(
            'Erro ao guardar localmente: '
            '$erroDb',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _submetido = false;
        });
      }
    }
  }

  Widget _rgpdConsentimentoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _azul.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.privacy_tip_outlined,
                size: 18,
                color: _azul,
              ),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Consentimento RGPD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            'Define como os dados deste badge poderão ser usados '
            'após aprovação.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          CheckboxListTile(
            value: _autorizaPublicacaoBadge,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: _azul,
            title: const Text(
              'Autorizo a publicação deste badge no meu perfil público '
              'Softinsa e a disponibilização do respetivo certificado.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
              ),
            ),
            subtitle: const Text(
              'Podes retirar este consentimento mais tarde nas definições.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            onChanged: _submetido
                ? null
                : (value) {
                    setState(() {
                      _autorizaPublicacaoBadge = value ?? false;
                    });
                  },
          ),

          const SizedBox(height: 6),

          TextField(
            controller: _linkedinController,
            enabled: !_submetido,
            decoration: InputDecoration(
              labelText: 'LinkedIn para associação ao badge (opcional)',
              hintText: 'https://www.linkedin.com/in/...',
              hintStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F7F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 10),

          CheckboxListTile(
            value: _autorizaAnalytics,
            dense: true,
            contentPadding: EdgeInsets.zero,
            activeColor: _azul,
            title: const Text(
              'Autorizo a recolha de dados analíticos anónimos '
              'para melhorar a aplicação.',
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
              ),
            ),
            onChanged: _submetido
                ? null
                : (value) {
                    setState(() {
                      _autorizaAnalytics = value ?? false;
                    });
                  },
          ),
        ],
      ),
    );
  }

  @override
  // =========================================================================
  // BUILD
  //
  // Trata carregamento e badge inexistente.
  // Constrói o cartão do badge, nível, descrição, upload
  // e botão fixo de submissão.
  // =========================================================================
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;
    final niveisIds = [1, 2, 3, 4, 5];

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: CircularProgressIndicator(color: _azul)),
      );
    }

    if (badge == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F7F7),
        body: Center(child: Text("Badge não encontrado")),
      );
    }

    final String nome =
    badge!['nome']?.toString() ??
    badge!['nome_badge']?.toString() ??
    '';

    final String? imagemUrl =
        badge!['imagem_url']?.toString() ??
        badge!['imagem']?.toString() ??
        badge!['url_imagem']?.toString();

    debugPrint(
      '[SUBMETER BADGE] Imagem recebida: $imagemUrl',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),

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
                              Icon(Icons.arrow_back, size: 20, color: _azul),
                              SizedBox(width: 6),
                              Text("Voltar", style: TextStyle(fontSize: 15, color: _azul, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Formulário
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CARD DO BADGE
                          Center(
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                              child: Column(
                                children: [
                                  BadgeImagemSubmissao(
                                    imageUrl: imagemUrl,
                                    size: 80,
                                    zoom: 1.6,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(nome, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // NÍVEL INDICATOR
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Nível do Badge", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: niveisIds.map((id) {
                                    final letra = obterNivel(id);
                                    final isAtual = id.toString() == badge!['id_nivel']?.toString();
                                    final cor = obterCorNivel(letra);

                                    return _nivelCirculo(letra: letra, isAtual: isAtual, cor: cor);
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: Text("A - Júnior\nB - Intermédio", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                    Expanded(child: Text("C - Sénior\nD - Especialista", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                    Expanded(child: Text("E - Líder Mestre", style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4))),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // CAIXA DE TEXTO DA DESCRIÇÃO
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _azul.withOpacity(0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.description_outlined, size: 18, color: _azul),
                                    SizedBox(width: 6),
                                    Text(
                                      'Descrição da candidatura',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _descricaoController,
                                  minLines: 4,
                                  maxLines: 7,
                                  maxLength: 1000,
                                  enabled: !_submetido,
                                  decoration: InputDecoration(
                                    hintText: "Descreva de forma detalhada o projeto, tarefas executadas e de que forma aplicou os conhecimentos desta Service Line...",
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    filled: true,
                                    fillColor: const Color(0xFFF7F7F7),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.all(14),
                                  ),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Mínimo 100 caracteres ($_charCount/100)",
                                  style: TextStyle(fontSize: 12, color: _descricaoValida ? const Color(0xFF2E7D32) : Colors.orange.shade800, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // EVIDÊNCIAS POR REQUISITO
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.all(
                              16,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white,
                              borderRadius:
                                  BorderRadius.circular(
                                16,
                              ),
                              border: Border.all(
                                color:
                                    _azul.withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.fact_check_outlined,
                                      size: 18,
                                      color: _azul,
                                    ),
                                    SizedBox(
                                      width: 6,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Evidências por requisito',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 6,
                                ),

                                Text(
                                  'Anexa pelo menos um ficheiro '
                                  'comprovativo em cada requisito.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey.shade600,
                                  ),
                                ),

                                const SizedBox(
                                  height: 14,
                                ),

                                if (requisitos.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding:
                                        const EdgeInsets.all(
                                      14,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          const Color(
                                        0xFFFFF3E0,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(
                                        10,
                                      ),
                                    ),
                                    child:
                                        const Text(
                                      'Este badge não possui '
                                      'requisitos disponíveis.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.orange,
                                      ),
                                    ),
                                  )
                                else
                                  ...List.generate(
                                    requisitos.length,
                                    (index) =>
                                        _requisitoEvidenciaCard(
                                      requisitos[index],
                                      index,
                                    ),
                                  ),

                                if (requisitos.isNotEmpty) ...[
                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    'Total de ficheiros '
                                    'selecionados: '
                                    '$_totalFicheiros',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _azul,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          _rgpdConsentimentoCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTÃO FIXO DE SUBMISSÃO
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _podeSubmeter && !_submetido ? _azul : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        onPressed: _podeSubmeter && !_submetido ? _submeter : null,
                        icon: _submetido
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, size: 20),
                        label: Text(_submetido ? "A processar submissão..." : "Submeter para Validação", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (!_podeSubmeter && !_submetido) ...[
                      const SizedBox(height: 6),
                      Text(
                        _mensagemValidacao,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              Colors.orange.shade800,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // HEADER PRINCIPAL
            Positioned(
              top: 0, left: 0, right: 0, height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [Image.asset('lib/img/logo.png', height: 35, fit: BoxFit.contain)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Cria o indicador circular de cada nível.
  // O nível atual recebe fundo colorido.
  Widget _nivelCirculo({required String letra, required bool isAtual, required Color cor}) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isAtual ? cor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: isAtual ? cor : Colors.grey.shade400, width: isAtual ? 2 : 1.5),
      ),
      child: Center(
        child: Text(
          letra,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isAtual ? Colors.white : Colors.grey.shade600),
        ),
      ),
    );
  }
}

// Componente específico para mostrar a imagem do badge no formulário.
class BadgeImagemSubmissao extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double zoom;

  const BadgeImagemSubmissao({
    super.key,
    required this.imageUrl,
    this.size = 80,
    this.zoom = 1.6,
  });

  @override
  Widget build(BuildContext context) {
    final String url = imageUrl?.trim() ?? '';

    if (url.isEmpty) {
      return _fallback();
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: zoom,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          loadingBuilder: (
            context,
            child,
            loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }

            return const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4470AF),
              ),
            );
          },
          errorBuilder: (
            context,
            error,
            stackTrace,
          ) {
            debugPrint(
              '[SUBMETER BADGE] Erro ao carregar imagem: $error',
            );
            debugPrint(
              '[SUBMETER BADGE] URL: $url',
            );

            return _fallback();
          },
        ),
      ),
    );
  }

  // Imagem alternativa quando a URL está ausente ou falha.
  Widget _fallback() {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEFF6FF),
      child: Icon(
        Icons.workspace_premium,
        size: size * 0.45,
        color: Colors.amber,
      ),
    );
  }
}