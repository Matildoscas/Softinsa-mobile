
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'submeter_badges.dart';

class LembreteItem {
  final Map<String, dynamic> data;
  const LembreteItem(this.data);

  int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v == 1;
    return {'true', 't', '1', 'sim', 'yes'}
        .contains('${v ?? ''}'.trim().toLowerCase());
  }

  int get id => _int(data['id_lembrete']) ?? 0;
  int? get idBadge => _int(data['id_badge_modelo']);
  int? get idCandidatura => _int(data['id_candidatura_pedido']);
  String get titulo => '${data['titulo'] ?? 'Lembrete'}';
  String get descricao => '${data['descricao'] ?? ''}';
  String get tipo =>
      _textoNormalizado(
        data['tipo_lembrete'] ??
        data['tipo'] ??
        data['tipo_objetivo'] ??
        'PESSOAL',
      );

  String get origem =>
      _textoNormalizado(
        data['origem'] ??
        data['origem_lembrete'] ??
        data['tipo_criador'] ??
        data['criado_por_tipo'] ??
        '',
      );

  String get estado =>
      _textoNormalizado(
        data['estado_lembrete'] ??
        data['estado'] ??
        data['status'] ??
        '',
      );
  String? get dataLimite => data['data_limite']?.toString();
  int? get diasRestantes => _int(data['dias_restantes']);
  String get nomeCriador => '${data['nome_criador'] ?? 'Talent Manager'}';
  String get nomeBadge => '${data['nome_badge'] ?? ''}';
  String? get imagemBadge => data['imagem_badge']?.toString();
  int get pontosBadge => _int(data['pontos_badge']) ?? 0;
  int get pontosBonus => _int(data['pontos_bonus']) ?? 0;
  int get multiplicador => _int(data['multiplicador_pontos']) ?? 1;
  bool get premioAtribuido => _bool(data['premio_atribuido']);
  String get motivoRecusa => '${data['motivo_recusa'] ?? ''}';

  bool get isDesafio =>
    tipo == 'DESAFIO_TM' ||
    tipo == 'DESAFIO_TALENT_MANAGER';

  bool get criadoPeloConsultor =>
      origem == 'CONSULTOR' ||
      origem == 'CONSULTANT';

  bool get criadoPeloTm {
    return origem == 'TM' ||
        origem == 'TALENT_MANAGER' ||
        origem.contains(
          'TALENT',
        ) ||
        (
          isDesafio &&
          !criadoPeloConsultor
        );
  }

  bool get aguardaAceitacao {
    return {
      'AGUARDA_ACEITACAO',
      'AGUARDANDO_ACEITACAO',
      'PENDENTE_ACEITACAO',
      'AGUARDA_RESPOSTA',
      'AGUARDANDO_RESPOSTA',
      'PROPOSTA',
    }.contains(
      estado,
    );
  }

  bool get isProposta {
    return isDesafio &&
        criadoPeloTm &&
        aguardaAceitacao;
  }
  bool get podeEditar =>
      criadoPeloConsultor && estado == 'PENDENTE' && idCandidatura == null;
  bool get podeEliminar =>
      criadoPeloConsultor && {'PENDENTE', 'ATRASADO'}.contains(estado);
  bool get podeConcluir => {'PENDENTE', 'ATRASADO'}.contains(estado);
  int get totalPossivel => isDesafio
      ? pontosBadge * (multiplicador < 2 ? 2 : multiplicador)
      : pontosBadge;
}

String _textoNormalizado(
  dynamic valor,
) {
  return '${valor ?? ''}'
      .trim()
      .toUpperCase()
      .replaceAll('Á', 'A')
      .replaceAll('À', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('Ã', 'A')
      .replaceAll('É', 'E')
      .replaceAll('Ê', 'E')
      .replaceAll('Í', 'I')
      .replaceAll('Ó', 'O')
      .replaceAll('Ô', 'O')
      .replaceAll('Õ', 'O')
      .replaceAll('Ú', 'U')
      .replaceAll('Ç', 'C')
      .replaceAll(
        RegExp(r'[\s-]+'),
        '_',
      );
}

class LembretesPage extends StatefulWidget {
  final int userId;
  const LembretesPage({super.key, required this.userId});

  @override
  State<LembretesPage> createState() => _LembretesPageState();
}

class _LembretesPageState extends State<LembretesPage> {
  static const _azul = Color(0xFF4470AF);
  final ApiService _api = ApiService();

  List<LembreteItem> _lembretes = [];
  List<Map<String, dynamic>> _badges = [];
  bool _loading = true;
  bool _saving = false;
  int? _acaoId;
  String _filtro = 'TODOS';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  List<LembreteItem> get _propostas =>
      _lembretes.where((e) => e.isProposta).toList();

  List<LembreteItem> get _normais =>
      _lembretes.where((e) => !e.isProposta).toList();

  List<LembreteItem> get _filtrados {
    switch (_filtro) {
      case 'PENDENTES':
        return _normais
            .where((e) => {'PENDENTE', 'EM_VALIDACAO'}.contains(e.estado))
            .toList();
      case 'CONCLUIDOS':
        return _normais
            .where((e) =>
                {'CONCLUIDO', 'CONCLUIDO_SEM_PREMIO'}.contains(e.estado))
            .toList();
      case 'ATRASADOS':
        return _normais.where((e) => e.estado == 'ATRASADO').toList();
      case 'RECUSADOS':
        return _normais
            .where((e) =>
                {'RECUSADO', 'REJEITADO_VALIDACAO'}.contains(e.estado))
            .toList();
      default:
        return _normais;
    }
  }

  int _prioridadeEstadoLembrete(
    LembreteItem item,
  ) {
    switch (item.estado) {
      case 'CONCLUIDO':
      case 'CONCLUIDO_SEM_PREMIO':
      case 'RECUSADO':
      case 'REJEITADO_VALIDACAO':
      case 'CANCELADO':
        return 5;

      case 'EM_VALIDACAO':
        return 4;

      case 'PENDENTE':
      case 'ATRASADO':
        return 3;

      case 'AGUARDA_ACEITACAO':
      case 'AGUARDANDO_ACEITACAO':
      case 'PENDENTE_ACEITACAO':
      case 'AGUARDA_RESPOSTA':
        return 2;

      default:
        return 1;
    }
  }

  String _chaveLembrete(
    LembreteItem item,
  ) {
    if (item.id > 0) {
      return 'lembrete_${item.id}';
    }

    /*
    * Fallback para registos antigos
    * sem id_lembrete válido.
    */
    return [
      item.tipo,
      item.idBadge ?? 0,
      item.idCandidatura ?? 0,
      item.titulo.trim().toLowerCase(),
      item.dataLimite ?? '',
    ].join('|');
  }

  List<LembreteItem>
      _normalizarLembretes(
    List<Map<String, dynamic>> dados,
  ) {
    final mapa =
        <String, LembreteItem>{};

    for (final linha in dados) {
      final item =
          LembreteItem(
        Map<String, dynamic>.from(
          linha,
        ),
      );

      final chave =
          _chaveLembrete(
        item,
      );

      final existente =
          mapa[chave];

      if (existente == null) {
        mapa[chave] =
            item;

        continue;
      }

      /*
      * Se existirem duas versões do mesmo
      * lembrete, mantém o estado mais
      * avançado. Isto impede que um desafio
      * já aceite continue contado como
      * proposta.
      */
      if (
        _prioridadeEstadoLembrete(
          item,
        ) >
        _prioridadeEstadoLembrete(
          existente,
        )
      ) {
        mapa[chave] =
            item;
      }
    }

    final resultado =
        mapa.values.toList();

    resultado.sort(
      (a, b) {
        final dataA =
            DateTime.tryParse(
          a.dataLimite ?? '',
        );

        final dataB =
            DateTime.tryParse(
          b.dataLimite ?? '',
        );

        if (
          dataA == null &&
          dataB == null
        ) {
          return b.id.compareTo(
            a.id,
          );
        }

        if (dataA == null) {
          return 1;
        }

        if (dataB == null) {
          return -1;
        }

        return dataA.compareTo(
          dataB,
        );
      },
    );

    return resultado;
  }

  Future<void> _carregar() async {
    setState(() => _loading = true);
    try {
      final resultados = await Future.wait([
        _api.getLembretesConsultor(widget.userId),
        _api.getBadgesLembretes(),
      ]);

      if (!mounted) return;
        setState(() {
          final dadosLembretes =
        List<Map<String, dynamic>>.from(
          resultados[0],
        );

        _lembretes =
            _normalizarLembretes(
          dadosLembretes,
        );

        for (final item in _lembretes) {
          debugPrint(
            '[LEMBRETES] '
            'id=${item.id}, '
            'tipo=${item.tipo}, '
            'origem=${item.origem}, '
            'estado=${item.estado}, '
            'proposta=${item.isProposta}',
          );
        }
        _badges = List<Map<String, dynamic>>.from(
          resultados[1],
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _erro(e);
    }
  }

  void _erro(Object e) {
    final texto = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sucesso(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _apiData(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _data(String? raw) {
    final d = DateTime.tryParse(raw ?? '');
    if (d == null) return 'Sem prazo';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _prazo(LembreteItem item) {
    int? dias = item.diasRestantes;
    if (dias == null) {
      final fim = DateTime.tryParse(item.dataLimite ?? '');
      if (fim != null) {
        final agora = DateTime.now();
        dias = DateTime(fim.year, fim.month, fim.day)
            .difference(DateTime(agora.year, agora.month, agora.day))
            .inDays;
      }
    }
    if (dias == null) return 'Sem prazo';
    if (dias < 0) return '${dias.abs()} dias em atraso';
    if (dias == 0) return 'Termina hoje';
    if (dias == 1) return 'Falta 1 dia';
    return 'Faltam $dias dias';
  }

  Future<void> _criar() async {
    final titulo = TextEditingController();
    final descricao = TextEditingController();
    String tipo = 'PESSOAL';
    int? badgeId;
    int semanas = 3;
    DateTime? limite;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, modalSetState) {
          Future<void> escolherData() async {
            final hoje = DateTime.now();
            final escolhida = await showDatePicker(
              context: context,
              initialDate: limite ?? hoje.add(const Duration(days: 1)),
              firstDate: hoje.add(const Duration(days: 1)),
              lastDate: DateTime(hoje.year + 5),
            );
            if (escolhida != null) {
              modalSetState(() => limite = escolhida);
            }
          }

          Future<void> guardar() async {
            if (tipo == 'PESSOAL' && titulo.text.trim().isEmpty) {
              _erro(Exception('O título é obrigatório.'));
              return;
            }
            if (tipo == 'PESSOAL' && limite == null) {
              _erro(Exception('Define uma data limite.'));
              return;
            }
            if (tipo == 'OBJETIVO_BADGE' && badgeId == null) {
              _erro(Exception('Seleciona um badge.'));
              return;
            }

            Navigator.pop(dialogContext);
            setState(() => _saving = true);

            try {
              final payload = tipo == 'PESSOAL'
                  ? <String, dynamic>{
                      'tipo_lembrete': 'PESSOAL',
                      'titulo': titulo.text.trim(),
                      'descricao': descricao.text.trim(),
                      'data_limite': _apiData(limite!),
                    }
                  : <String, dynamic>{
                      'tipo_lembrete': 'OBJETIVO_BADGE',
                      'id_badge_modelo': badgeId,
                      'prazo_semanas': semanas,
                      if (titulo.text.trim().isNotEmpty)
                        'titulo': titulo.text.trim(),
                      if (descricao.text.trim().isNotEmpty)
                        'descricao': descricao.text.trim(),
                    };

              await _api.criarLembreteConsultor(
                userId: widget.userId,
                dados: payload,
              );
              _sucesso(tipo == 'PESSOAL'
                  ? 'Lembrete criado com sucesso.'
                  : 'Objetivo de badge criado com sucesso.');
              await _carregar();
            } catch (e) {
              _erro(e);
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          }

          return AlertDialog(
            title: const Text('Adicionar lembrete'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'PESSOAL',
                          label: Text('Pessoal'),
                          icon: Icon(Icons.calendar_month_outlined),
                        ),
                        ButtonSegment(
                          value: 'OBJETIVO_BADGE',
                          label: Text('Badge'),
                          icon: Icon(Icons.workspace_premium_outlined),
                        ),
                      ],
                      selected: {tipo},
                      onSelectionChanged: (v) =>
                          modalSetState(() => tipo = v.first),
                    ),
                    const SizedBox(height: 16),
                    if (tipo == 'OBJETIVO_BADGE') ...[
                      DropdownButtonFormField<int>(
                        initialValue: badgeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Badge a concluir',
                          border: OutlineInputBorder(),
                        ),
                        items: _badges
                            .map((b) {
                              final id = int.tryParse(
                                  '${b['id_badge_modelo'] ?? ''}');
                              if (id == null) return null;
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${b['nome_badge'] ?? 'Badge'} — '
                                  '${b['pontos'] ?? 0} pontos',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            })
                            .whereType<DropdownMenuItem<int>>()
                            .toList(),
                        onChanged: (v) => modalSetState(() => badgeId = v),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: semanas,
                        decoration: const InputDecoration(
                          labelText: 'Prazo',
                          border: OutlineInputBorder(),
                        ),
                        items: const [1, 2, 3, 4, 6, 8, 12]
                            .map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                      '$v ${v == 1 ? 'semana' : 'semanas'}'),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) modalSetState(() => semanas = v);
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titulo,
                      maxLength: 200,
                      decoration: InputDecoration(
                        labelText: tipo == 'PESSOAL'
                            ? 'Título'
                            : 'Título personalizado — opcional',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descricao,
                      minLines: 3,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (tipo == 'PESSOAL') ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: escolherData,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data limite',
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(),
                          ),
                          child: Text(
                            limite == null
                                ? 'Selecionar data'
                                : _data(limite!.toIso8601String()),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: guardar,
                child: const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );

    titulo.dispose();
    descricao.dispose();
  }

  Future<void> _editar(LembreteItem item) async {
    final titulo = TextEditingController(text: item.titulo);
    final descricao = TextEditingController(text: item.descricao);
    final hoje = DateTime.now();
    final atual = DateTime.tryParse(item.dataLimite ?? '');
    DateTime limite = atual != null && atual.isAfter(hoje)
        ? atual
        : hoje.add(const Duration(days: 1));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, modalSetState) {
          Future<void> guardar() async {
            if (titulo.text.trim().isEmpty) {
              _erro(Exception('O título é obrigatório.'));
              return;
            }

            Navigator.pop(dialogContext);
            setState(() => _acaoId = item.id);

            try {
              await _api.editarLembreteConsultor(
                userId: widget.userId,
                lembreteId: item.id,
                dados: {
                  'titulo': titulo.text.trim(),
                  'descricao': descricao.text.trim(),
                  'data_limite': _apiData(limite),
                },
              );
              _sucesso('Lembrete atualizado com sucesso.');
              await _carregar();
            } catch (e) {
              _erro(e);
            } finally {
              if (mounted) setState(() => _acaoId = null);
            }
          }

          return AlertDialog(
            title: const Text('Editar lembrete'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titulo,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descricao,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final v = await showDatePicker(
                        context: context,
                        initialDate: limite,
                        firstDate: hoje.add(const Duration(days: 1)),
                        lastDate: DateTime(hoje.year + 5),
                      );
                      if (v != null) modalSetState(() => limite = v);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Data limite',
                        suffixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_data(limite.toIso8601String())),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: guardar,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    titulo.dispose();
    descricao.dispose();
  }

  Future<void> _executar(
    LembreteItem item,
    Future<dynamic> Function() acao,
    String sucesso,
  ) async {
    setState(() => _acaoId = item.id);
    try {
      await acao();
      _sucesso(sucesso);
      await _carregar();
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _acaoId = null);
    }
  }

  Future<void> _aceitar(LembreteItem item) => _executar(
        item,
        () => _api.aceitarDesafioLembrete(
          userId: widget.userId,
          lembreteId: item.id,
        ),
        'Desafio aceite. Foi adicionado aos teus lembretes.',
      );

  Future<void> _recusar(LembreteItem item) async {
    final motivo = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Recusar desafio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: motivo,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Motivo — opcional',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _executar(
        item,
        () => _api.recusarDesafioLembrete(
          userId: widget.userId,
          lembreteId: item.id,
          motivo: motivo.text.trim(),
        ),
        'Desafio recusado.',
      );
    }
    motivo.dispose();
  }

  Future<void> _eliminar(LembreteItem item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar lembrete'),
        content: Text('Eliminar "${item.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _executar(
        item,
        () => _api.eliminarLembreteConsultor(
          userId: widget.userId,
          lembreteId: item.id,
        ),
        'Lembrete eliminado com sucesso.',
      );
    }
  }

  Future<void> _concluir(LembreteItem item) async {
    setState(() => _acaoId = item.id);
    try {
      final r = await _api.concluirLembreteConsultor(
        userId: widget.userId,
        lembreteId: item.id,
      );

      if (r['necessita_candidatura'] == true) {
        final badgeId =
            int.tryParse('${r['id_badge_modelo'] ?? item.idBadge ?? ''}');
        final lembreteId =
            int.tryParse('${r['id_lembrete'] ?? item.id}');

        if (badgeId == null || lembreteId == null) {
          throw Exception('Não foi possível identificar o badge.');
        }

        if (!mounted) return;
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => SubmeterBadge(
              userId: widget.userId,
              badgeId: badgeId,
              idLembrete: lembreteId,
            ),
          ),
        );
        await _carregar();
      } else {
        _sucesso('Lembrete concluído com sucesso.');
        await _carregar();
      }
    } catch (e) {
      _erro(e);
    } finally {
      if (mounted) setState(() => _acaoId = null);
    }
  }

  Map<String, dynamic> _estadoVisual(String estado) {
    const valores = {
      'AGUARDA_ACEITACAO': ['Aguarda resposta', Color(0xFFFEF3C7), Color(0xFF92400E)],
      'PENDENTE': ['Pendente', Color(0xFFDBEAFE), Color(0xFF1D4ED8)],
      'EM_VALIDACAO': ['Em validação', Color(0xFFEDE9FE), Color(0xFF6D28D9)],
      'CONCLUIDO': ['Concluído', Color(0xFFDCFCE7), Color(0xFF15803D)],
      'CONCLUIDO_SEM_PREMIO': ['Concluído sem bónus', Color(0xFFFEF3C7), Color(0xFF92400E)],
      'ATRASADO': ['Atrasado', Color(0xFFFEE2E2), Color(0xFFB91C1C)],
      'RECUSADO': ['Recusado', Color(0xFFF1F5F9), Color(0xFF475569)],
      'REJEITADO_VALIDACAO': ['Candidatura rejeitada', Color(0xFFFEE2E2), Color(0xFFB91C1C)],
    };
    final v = valores[estado] ?? [estado.isEmpty ? 'Sem estado' : estado, const Color(0xFFF1F5F9), const Color(0xFF475569)];
    return {'texto': v[0], 'fundo': v[1], 'cor': v[2]};
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = _normais
        .where((e) => {'PENDENTE', 'EM_VALIDACAO'}.contains(e.estado))
        .length;
    final concluidos = _normais
        .where((e) => {'CONCLUIDO', 'CONCLUIDO_SEM_PREMIO'}.contains(e.estado))
        .length;
    final atrasados = _normais.where((e) => e.estado == 'ATRASADO').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: _azul),
        ),
        title: Image.asset('lib/img/logo.png', height: 34),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _criar,
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _azul))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                children: [
                  const Text(
                    'Lembretes e Objetivos',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organiza os teus objetivos, acompanha prazos e aceita desafios do Talent Manager.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _resumo('Pendentes', pendentes, Icons.schedule),
                      _resumo('Propostas do TM', _propostas.length, Icons.track_changes),
                      _resumo('Concluídos', concluidos, Icons.check_circle_outline),
                      _resumo('Atrasados', atrasados, Icons.event_busy_outlined),
                    ],
                  ),
                  if (_propostas.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'Propostas do Talent Manager',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._propostas.map((e) => _card(e, proposta: true)),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Os meus lembretes',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: {
                        'TODOS': 'Todos',
                        'PENDENTES': 'Pendentes',
                        'CONCLUIDOS': 'Concluídos',
                        'ATRASADOS': 'Atrasados',
                        'RECUSADOS': 'Rejeitados',
                      }.entries.map((e) {
                        final ativo = _filtro == e.key;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: ativo,
                            selectedColor: _azul,
                            labelStyle: TextStyle(
                              fontSize: 11,
                              color: ativo ? Colors.white : Colors.black87,
                            ),
                            onSelected: (_) => setState(() => _filtro = e.key),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_filtrados.isEmpty)
                    _vazio()
                  else
                    ..._filtrados.map(_card),
                ],
              ),
            ),
    );
  }

  Widget _resumo(String label, int valor, IconData icon) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 40) / 2,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: _azul),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$valor', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(LembreteItem item, {bool proposta = false}) {
    final visual = _estadoVisual(item.estado);
    final emAcao = _acaoId == item.id;
    final url = item.imagemBadge?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: item.isDesafio ? const Color(0xFFFFFDF4) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isDesafio ? const Color(0xFFD4A017) : Colors.grey.shade200,
          width: item.isDesafio ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Icon(
                  item.isDesafio
                      ? Icons.track_changes
                      : item.idBadge != null
                          ? Icons.workspace_premium_outlined
                          : Icons.calendar_month_outlined,
                  size: 17,
                  color: item.isDesafio ? const Color(0xFF9A6B00) : _azul,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.isDesafio
                        ? 'Desafio do TM'
                        : item.idBadge != null
                            ? 'Objetivo de badge'
                            : 'Lembrete pessoal',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: item.isDesafio ? const Color(0xFF9A6B00) : _azul,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: visual['fundo'] as Color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visual['texto'] as String,
                    style: TextStyle(
                      fontSize: 9,
                      color: visual['cor'] as Color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: item.isDesafio
                        ? const Color(0xFFFFF7D6)
                        : const Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: url.isNotEmpty
                      ? Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            item.isDesafio ? Icons.track_changes : Icons.calendar_month_outlined,
                            color: item.isDesafio ? const Color(0xFFD4A017) : _azul,
                          ),
                        )
                      : Icon(
                          item.isDesafio
                              ? Icons.track_changes
                              : item.idBadge != null
                                  ? Icons.workspace_premium
                                  : Icons.calendar_month_outlined,
                          color: item.isDesafio ? const Color(0xFFD4A017) : _azul,
                        ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      if (item.descricao.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(item.descricao, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      ],
                      const SizedBox(height: 8),
                      _meta(Icons.calendar_today_outlined, 'Prazo: ${_data(item.dataLimite)}'),
                      _meta(Icons.schedule, _prazo(item)),
                      _meta(
                        Icons.person_outline,
                        item.criadoPeloConsultor ? 'Criado por ti' : 'Criado por ${item.nomeCriador}',
                      ),
                      if (item.nomeBadge.isNotEmpty)
                        _meta(Icons.workspace_premium_outlined, item.nomeBadge),
                      if (item.nomeBadge.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: item.isDesafio
                                ? const Color(0xFFFFF7D6)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.isDesafio
                                ? '${item.pontosBadge} pontos + ${item.pontosBadge} de bónus = ${item.totalPossivel} pontos'
                                : '${item.pontosBadge} pontos após aprovação do TM e SLL.',
                            style: TextStyle(
                              fontSize: 10,
                              color: item.isDesafio
                                  ? const Color(0xFF8A6116)
                                  : const Color(0xFF315E9E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      if (item.pontosBonus > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            'Recebeste ${item.pontosBonus} pontos extra.',
                            style: const TextStyle(
                              color: Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (item.estado == 'EM_VALIDACAO')
                        const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: Text(
                            'A candidatura está a ser avaliada pelo TM e pelo SLL.',
                            style: TextStyle(color: Color(0xFF6D28D9), fontSize: 10),
                          ),
                        ),
                      if (item.motivoRecusa.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Text(
                            'Motivo: ${item.motivoRecusa}',
                            style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (proposta || item.podeEditar || item.podeConcluir || item.podeEliminar)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: emAcao
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _azul),
                      ),
                    )
                  : Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (proposta) ...[
                          OutlinedButton.icon(
                            onPressed: () => _recusar(item),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Recusar'),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                          ),
                          FilledButton.icon(
                            onPressed: () => _aceitar(item),
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: const Text('Aceitar'),
                          ),
                        ] else ...[
                          if (item.podeEditar)
                            OutlinedButton.icon(
                              onPressed: () => _editar(item),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Editar'),
                            ),
                          if (item.podeConcluir)
                            FilledButton.icon(
                              onPressed: () => _concluir(item),
                              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: Text(item.idBadge != null ? 'Concluir e submeter' : 'Concluir'),
                            ),
                          if (item.podeEliminar)
                            OutlinedButton.icon(
                              onPressed: () => _eliminar(item),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Eliminar'),
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                            ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade600),
          const SizedBox(width: 5),
          Expanded(
            child: Text(texto, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  Widget _vazio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 42, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          const Text(
            'Não existem lembretes nesta categoria',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
