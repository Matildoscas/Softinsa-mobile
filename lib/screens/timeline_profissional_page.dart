import 'package:flutter/material.dart';

import '../services/api_service.dart';

class TimelineProfissionalPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const TimelineProfissionalPage({
    super.key,
    required this.userData,
  });

  @override
  State<TimelineProfissionalPage> createState() =>
      _TimelineProfissionalPageState();
}

class _TimelineEvento {
  final String titulo;
  final String descricao;
  final String categoria;
  final DateTime data;
  final IconData icone;
  final Color cor;

  const _TimelineEvento({
    required this.titulo,
    required this.descricao,
    required this.categoria,
    required this.data,
    required this.icone,
    required this.cor,
  });
}

class _TimelineProfissionalPageState
    extends State<TimelineProfissionalPage> {
  static const Color _azul = Color(0xFF4470AF);

  final ApiService _apiService = ApiService();

  bool isLoading = true;
  String? erro;

  List<_TimelineEvento> eventos = [];

  @override
  void initState() {
    super.initState();
    _carregarTimeline();
  }

  int _obterUserId() {
    return int.tryParse(
          widget.userData['id_utilizador']?.toString() ?? '',
        ) ??
        0;
  }

  String _primeiroTexto(List<dynamic> valores) {
    for (final valor in valores) {
      final texto = valor?.toString().trim() ?? '';

      if (texto.isNotEmpty && texto.toLowerCase() != 'null') {
        return texto;
      }
    }

    return '';
  }

  int _inteiro(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  String _normalizar(dynamic valor) {
    return valor
            ?.toString()
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
            .replaceAll('Ç', 'C') ??
        '';
  }

  DateTime? _converterData(dynamic valor) {
    final texto = valor?.toString().trim() ?? '';

    if (texto.isEmpty || texto.toLowerCase() == 'null') {
      return null;
    }

    final direta = DateTime.tryParse(texto);

    if (direta != null) {
      return direta.toLocal();
    }

    /*
    * Aceita também datas tipo:
    * 14/07/2026
    */
    final match = RegExp(
      r'^(\d{1,2})\/(\d{1,2})\/(\d{4})$',
    ).firstMatch(texto);

    if (match != null) {
      final dia = int.tryParse(match.group(1) ?? '');
      final mes = int.tryParse(match.group(2) ?? '');
      final ano = int.tryParse(match.group(3) ?? '');

      if (dia != null && mes != null && ano != null) {
        return DateTime(ano, mes, dia);
      }
    }

    return null;
  }

  String _formatarData(DateTime data) {
    const meses = [
      'jan',
      'fev',
      'mar',
      'abr',
      'mai',
      'jun',
      'jul',
      'ago',
      'set',
      'out',
      'nov',
      'dez',
    ];

    return '${data.day} ${meses[data.month - 1]} ${data.year}';
  }

  String _formatarDataCurta(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  void _adicionarEvento(
    List<_TimelineEvento> lista, {
    required String titulo,
    required String descricao,
    required String categoria,
    required DateTime? data,
    required IconData icone,
    required Color cor,
  }) {
    if (data == null) {
      return;
    }

    lista.add(
      _TimelineEvento(
        titulo: titulo,
        descricao: descricao,
        categoria: categoria,
        data: data,
        icone: icone,
        cor: cor,
      ),
    );
  }

  String _chaveCandidatura(
    Map<String, dynamic> candidatura,
  ) {
    final int idCandidatura =
        _inteiro(
      candidatura[
        'id_candidatura_pedido'
      ] ??
          candidatura[
            'id_candidatura'
          ],
    );

    if (idCandidatura > 0) {
      return 'candidatura_$idCandidatura';
    }

    /*
    * Fallback para registos antigos que
    * possam não possuir ID da candidatura.
    *
    * Incluímos a data para não juntar duas
    * tentativas diferentes para o mesmo badge.
    */
    final int idBadge =
        _inteiro(
      candidatura[
        'id_badge_modelo'
      ] ??
          candidatura[
            'id_badge'
          ] ??
          candidatura['id'],
    );

    final String data =
        _primeiroTexto([
      candidatura['data_submissao'],
      candidatura['data_candidatura'],
      candidatura['created_at'],
    ]);

    return 'badge_${idBadge}_$data';
  }

  DateTime _dataMaisRecenteCandidatura(
    Map<String, dynamic> candidatura,
  ) {
    final possibilidades = [
      candidatura[
        'data_entrada_historico'
      ],
      candidatura[
        'data_avaliacao_sll'
      ],
      candidatura[
        'data_avaliacao_tm'
      ],
      candidatura['data_validacao'],
      candidatura['data_atualizacao'],
      candidatura['updated_at'],
      candidatura['data_submissao'],
      candidatura['data_candidatura'],
      candidatura['created_at'],
    ];

    for (final valor in possibilidades) {
      final data =
          _converterData(valor);

      if (data != null) {
        return data;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(
      0,
    );
  }

  List<Map<String, dynamic>>
      _removerCandidaturasDuplicadas(
    List<Map<String, dynamic>> lista,
  ) {
    final mapa =
        <String, Map<String, dynamic>>{};

    for (final candidatura in lista) {
      final chave =
          _chaveCandidatura(
        candidatura,
      );

      final existente =
          mapa[chave];

      if (existente == null) {
        mapa[chave] =
            Map<String, dynamic>.from(
          candidatura,
        );

        continue;
      }

      /*
      * Quando a API devolve várias linhas
      * da mesma candidatura, conserva a
      * que possui os dados mais recentes.
      */
      final dataNova =
          _dataMaisRecenteCandidatura(
        candidatura,
      );

      final dataExistente =
          _dataMaisRecenteCandidatura(
        existente,
      );

      if (
        dataNova.isAfter(
          dataExistente,
        )
      ) {
        mapa[chave] =
            Map<String, dynamic>.from(
          candidatura,
        );
      }
    }

    return mapa.values.toList();
  }

  Future<void> _carregarTimeline() async {
    final userId = _obterUserId();

    if (userId == 0) {
      setState(() {
        isLoading = false;
        erro = 'Utilizador inválido.';
      });

      return;
    }

    try {
      final List<_TimelineEvento> lista = [];

      Map<String, dynamic> dashboard = {};
      List<Map<String, dynamic>> badgesConquistados = [];
      List<Map<String, dynamic>> candidaturas = [];
      List<Map<String, dynamic>> learningPaths = [];

      try {
        dashboard = await _apiService.getDashboard(userId);
      } catch (e) {
        debugPrint('[TIMELINE] Erro dashboard: $e');
      }

      try {
        badgesConquistados =
            await _apiService.getBadgesConquistados(userId);
      } catch (e) {
        debugPrint('[TIMELINE] Erro badges conquistados: $e');
      }

      try {
        candidaturas =
            await _apiService.getStatusCandidaturasConsultor(
          userId,
        );

        candidaturas =
            _removerCandidaturasDuplicadas(
          candidaturas,
        );
      } catch (e) {
        debugPrint('[TIMELINE] Erro candidaturas: $e');
      }

      try {
        learningPaths =
            await _apiService.getProgressoLearningPaths(userId);
      } catch (e) {
        debugPrint('[TIMELINE] Erro learning paths: $e');
      }

      /*
      * 1. Conta criada / entrada na plataforma
      */
      final dataConta = _converterData(
        _primeiroTexto([
          widget.userData['data_criacao'],
          widget.userData['created_at'],
          widget.userData['data_registo'],
          dashboard['data_criacao'],
          dashboard['data_registo'],
        ]),
      );

      _adicionarEvento(
        lista,
        titulo: 'Entrada na Softinsa Academy',
        descricao:
            'Início do percurso profissional e de certificação na plataforma.',
        categoria: 'Perfil',
        data: dataConta,
        icone: Icons.person_add_alt_1_outlined,
        cor: _azul,
      );

      /*
      * 2. Badges conquistados
      */
      for (final badge in badgesConquistados) {
        final nomeBadge = _primeiroTexto([
          badge['nome'],
          badge['nome_badge'],
          badge['titulo'],
        ]);

        final nivel = _primeiroTexto([
          badge['nome_nivel'],
          badge['nivel'],
          badge['codigo_nivel'],
        ]);

        final pontos = _inteiro(
          badge['pontos_total'] ??
              badge['total_pontos'] ??
              badge['pontos'],
        );

        final data = _converterData(
          _primeiroTexto([
            badge['data_atribuicao'],
            badge['data_conquista'],
            badge['data_entrada_historico'],
            badge['data_validacao'],
            badge['data_emissao'],
            badge['created_at'],
          ]),
        );

        final tipo = _normalizar(
          badge['tipo_badge'] ??
              badge['tipo'] ??
              badge['nome_nivel'] ??
              badge['nivel'],
        );

        final bool especial =
            tipo.contains('ESPECIAL') ||
                tipo.contains('LIDER') ||
                tipo == 'E';

        _adicionarEvento(
          lista,
          titulo: especial
              ? 'Badge especial conquistado'
              : 'Badge conquistado',
          descricao:
              '${nomeBadge.isEmpty ? 'Badge Softinsa' : nomeBadge}'
              '${nivel.isNotEmpty ? ' • $nivel' : ''}'
              '${pontos > 0 ? ' • $pontos pontos' : ''}',
          categoria: 'Badge',
          data: data,
          icone: especial
              ? Icons.workspace_premium
              : Icons.emoji_events_outlined,
          cor: especial
              ? const Color(0xFFD4A017)
              : const Color(0xFF15803D),
        );
      }

      /*
      * 3. Candidaturas / validações
      */
      for (final candidatura in candidaturas) {
        final nomeBadge = _primeiroTexto([
          candidatura['nome_badge'],
          candidatura['nome'],
          candidatura['badge'],
          candidatura['titulo'],
        ]);

        final estadoOriginal =
          _primeiroTexto([
        /*
        * Os estados agregados representam
        * melhor a situação atual.
        */
        candidatura['estado_geral'],
        candidatura['estado_final'],
        candidatura['fase_geral'],

        candidatura[
          'estado_candidatura_sll'
        ],

        candidatura[
          'estado_candidatura_tm'
        ],

        candidatura[
          'estado_candidatura_pedido'
        ],

        candidatura['estado'],
      ]);

        final estado = _normalizar(estadoOriginal);

        final DateTime? data =
            _dataMaisRecenteCandidatura(
          candidatura,
        );

        final dataFinal =
            data != null &&
                data.millisecondsSinceEpoch > 0
            ? data
            : null;

        String titulo = 'Candidatura submetida';
        IconData icone = Icons.upload_file_outlined;
        Color cor = _azul;

        if (estado.contains('APROV')) {
          titulo = 'Candidatura aprovada';
          icone = Icons.check_circle_outline;
          cor = const Color(0xFF15803D);
        } else if (
          estado.contains('REJEIT') ||
          estado.contains('RECUS')
        ) {
          titulo = 'Candidatura rejeitada';
          icone = Icons.cancel_outlined;
          cor = const Color(0xFFB91C1C);
        } else if (
          estado.contains('VALID') ||
          estado.contains('PEND') ||
          estado.contains('AGUARD')
        ) {
          titulo = 'Candidatura em validação';
          icone = Icons.hourglass_top_outlined;
          cor = const Color(0xFFD4A017);
        }

        _adicionarEvento(
          lista,
          titulo: titulo,
          descricao:
              '${nomeBadge.isEmpty ? 'Badge Softinsa' : nomeBadge}'
              '${estadoOriginal.isNotEmpty ? ' • $estadoOriginal' : ''}',
          categoria: 'Candidatura',
          data: dataFinal,
          icone: icone,
          cor: cor,
        );
      }

      /*
      * 4. Learning Paths
      */
      for (final learningPath in learningPaths) {
        final nome = _primeiroTexto([
          learningPath['nome_learningpath'],
          learningPath['nome_learningpaths'],
          learningPath['nome'],
          learningPath['titulo'],
        ]);

        final progresso = _inteiro(
          learningPath['percentagem'] ??
              learningPath['percentagem_concluida'] ??
              learningPath['progresso'] ??
              learningPath['progresso_percentagem'],
        );

        final data = _converterData(
          _primeiroTexto([
            learningPath['data_inicio'],
            learningPath['data_inscricao'],
            learningPath['data_criacao'],
            learningPath['data_atualizacao'],
            learningPath['updated_at'],
            learningPath['created_at'],
          ]),
        );

        _adicionarEvento(
          lista,
          titulo: progresso >= 100
              ? 'Learning Path concluída'
              : 'Learning Path em progresso',
          descricao:
              '${nome.isEmpty ? 'Learning Path Softinsa' : nome}'
              '${progresso > 0 ? ' • $progresso%' : ''}',
          categoria: 'Learning Path',
          data: data,
          icone: Icons.route_outlined,
          cor: progresso >= 100
              ? const Color(0xFF15803D)
              : const Color(0xFF4470AF),
        );
      }

      /*
      * Ordena do evento mais recente para o mais antigo.
      */
      lista.sort(
        (a, b) => b.data.compareTo(a.data),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        eventos = lista;
        isLoading = false;
        erro = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        erro = 'Não foi possível carregar a timeline: $e';
      });
    }
  }

  int get _totalBadges {
    return eventos
        .where((evento) => evento.categoria == 'Badge')
        .length;
  }

  int get _totalCandidaturas {
    return eventos
        .where((evento) => evento.categoria == 'Candidatura')
        .length;
  }

  int get _totalLearningPaths {
    return eventos
        .where((evento) => evento.categoria == 'Learning Path')
        .length;
  }

  @override
  Widget build(BuildContext context) {
    const headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),

                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.arrow_back,
                              size: 21,
                              color: _azul,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Expanded(
                          child: Text(
                            'Timeline profissional',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _carregarTimeline,
                          icon: const Icon(
                            Icons.refresh,
                            color: _azul,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: _buildBody(),
                  ),
                ],
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  'lib/img/logo.png',
                  height: 35,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _azul,
        ),
      );
    }

    if (erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            erro!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    if (eventos.isEmpty) {
      return RefreshIndicator(
        color: _azul,
        onRefresh: _carregarTimeline,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.timeline,
              size: 58,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ainda não existe timeline profissional.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quando existirem badges conquistados, candidaturas ou learning paths com data, eles aparecem aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _azul,
      onRefresh: _carregarTimeline,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24,
        ),
        children: [
          _resumoCard(),
          const SizedBox(height: 18),
          const Text(
            'Percurso cronológico',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Histórico dos principais momentos do teu desenvolvimento profissional.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...eventos.asMap().entries.map(
            (entry) {
              final index = entry.key;
              final evento = entry.value;

              return _timelineItem(
                evento: evento,
                primeiro: index == 0,
                ultimo: index == eventos.length - 1,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _resumoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4470AF),
            Color(0xFF3A5C94),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _azul.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.timeline,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Evolução profissional',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Resumo visual do percurso do consultor na Softinsa Academy.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _miniResumo(
                valor: eventos.length.toString(),
                label: 'eventos',
              ),
              _miniResumo(
                valor: _totalBadges.toString(),
                label: 'badges',
              ),
              _miniResumo(
                valor: _totalCandidaturas.toString(),
                label: 'candidaturas',
              ),
              _miniResumo(
                valor: _totalLearningPaths.toString(),
                label: 'paths',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniResumo({
    required String valor,
    required String label,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timelineItem({
    required _TimelineEvento evento,
    required bool primeiro,
    required bool ultimo,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _formatarDataCurta(evento.data),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              if (!primeiro)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFD9E2EF),
                  ),
                )
              else
                const SizedBox(height: 14),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: evento.cor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: evento.cor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  evento.icone,
                  color: evento.cor,
                  size: 18,
                ),
              ),
              if (!ultimo)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFD9E2EF),
                  ),
                )
              else
                const SizedBox(height: 18),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: evento.cor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          evento.categoria,
                          style: TextStyle(
                            fontSize: 10,
                            color: evento.cor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatarData(evento.data),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    evento.titulo,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    evento.descricao,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}