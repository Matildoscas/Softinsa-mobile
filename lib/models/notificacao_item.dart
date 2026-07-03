// ============================================================================
// notificacao_item.dart
//
// Modelo partilhado pelo sino e pela página completa de notificações.
// Converte os códigos técnicos do backend em títulos claros para o utilizador.
// ============================================================================

class AppNotificationItem {
  final int id;
  final String tipo;
  final String titulo;
  final String descricao;
  final String emissor;
  final DateTime? dataEnvio;
  final bool lida;
  final Map<String, dynamic> raw;

  const AppNotificationItem({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.emissor,
    required this.dataEnvio,
    required this.lida,
    required this.raw,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final String tipo = (
      json['tipo_notificacao'] ??
      json['tipo'] ??
      'SISTEMA'
    ).toString().trim().toUpperCase();

    final String estado = (
      json['estado_notificacao'] ??
      json['estado'] ??
      'NÃO LIDA'
    ).toString().trim().toUpperCase();

    final int id = int.tryParse(
      (
        json['id_notificacoes'] ??
        json['id_notificacao'] ??
        json['id'] ??
        0
      ).toString(),
    ) ?? 0;

    DateTime? data;

    final dynamic dataRaw =
        json['data_envio'] ??
        json['data_criacao'];

    if (dataRaw != null) {
      data = DateTime.tryParse(
        dataRaw.toString(),
      )?.toLocal();
    }

    return AppNotificationItem(
      id: id,
      tipo: tipo,
      titulo: _tituloPorTipo(tipo),
      descricao: (
        json['conteudo'] ??
        json['descricao'] ??
        ''
      ).toString(),
      emissor: _emissorPorTipo(tipo),
      dataEnvio: data,
      lida: const {
        'LIDA',
        'LIDO',
        'READ',
      }.contains(estado),
      raw: Map<String, dynamic>.from(json),
    );
  }

  AppNotificationItem copiarComoLida() {
    return AppNotificationItem(
      id: id,
      tipo: tipo,
      titulo: titulo,
      descricao: descricao,
      emissor: emissor,
      dataEnvio: dataEnvio,
      lida: true,
      raw: {
        ...raw,
        'estado_notificacao': 'LIDA',
      },
    );
  }

  String get tempo {
    final data = dataEnvio;

    if (data == null) {
      return 'Data indisponível';
    }

    final diferenca =
        DateTime.now().difference(data);

    if (diferenca.inSeconds < 60) {
      return 'Agora';
    }

    if (diferenca.inMinutes < 60) {
      final minutos = diferenca.inMinutes;
      return 'Há $minutos ${minutos == 1 ? 'minuto' : 'minutos'}';
    }

    if (diferenca.inHours < 24) {
      final horas = diferenca.inHours;
      return 'Há $horas ${horas == 1 ? 'hora' : 'horas'}';
    }

    if (diferenca.inDays < 7) {
      final dias = diferenca.inDays;
      return 'Há $dias ${dias == 1 ? 'dia' : 'dias'}';
    }

    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }

  static String _tituloPorTipo(String tipo) {
    const titulos = <String, String>{
      'NOVO_DESAFIO_TM':
          'Novo desafio do Talent Manager',
      'DESAFIO_ACEITE':
          'Desafio aceite',
      'DESAFIO_RECUSADO':
          'Desafio recusado',
      'DESAFIO_CANCELADO':
          'Desafio cancelado',

      'LEMBRETE_7_DIAS':
          'O prazo está a aproximar-se',
      'AVISO_7_DIAS':
          'Falta uma semana para o prazo',
      'LEMBRETE_1_DIA':
          'O prazo termina amanhã',
      'AVISO_1_DIA':
          'O prazo termina amanhã',
      'LEMBRETE_ATRASADO':
          'Objetivo em atraso',
      'AVISO_ATRASO':
          'Objetivo em atraso',

      'CANDIDATURA_SUBMETIDA':
          'Candidatura submetida',
      'CANDIDATURA_EM_VALIDACAO':
          'Candidatura em validação',
      'CANDIDATURA_APROVADA':
          'Candidatura aprovada',
      'CANDIDATURA_REJEITADA':
          'Candidatura rejeitada',

      'APROVADA_TM':
          'Aprovação do Talent Manager',
      'CANDIDATURA_APROVADA_TM':
          'Aprovação do Talent Manager',
      'REJEITADA_TM':
          'Revisão pedida pelo Talent Manager',
      'CANDIDATURA_REJEITADA_TM':
          'Revisão pedida pelo Talent Manager',

      'APROVADA_SLL':
          'Aprovação do Service Line Leader',
      'CANDIDATURA_APROVADA_SLL':
          'Aprovação do Service Line Leader',
      'REJEITADA_SLL':
          'Candidatura rejeitada pelo Service Line Leader',
      'CANDIDATURA_REJEITADA_SLL':
          'Candidatura rejeitada pelo Service Line Leader',

      'RETIFICACAO':
          'São necessárias alterações',
      'PEDIDO_RETIFICACAO':
          'São necessárias alterações',
      'BADGE_ATRIBUIDO':
          'Novo badge conquistado',
      'CERTIFICADO_DISPONIVEL':
          'Certificado disponível',
      'BADGE_A_EXPIRAR':
          'Badge próximo da expiração',
      'BADGE_EXPIRADO':
          'Badge expirado',
      'SISTEMA':
          'Informação importante',
      'ALERTA':
          'Atenção necessária',
    };

    return titulos[tipo] ??
        _humanizarTipo(tipo);
  }

  static String _emissorPorTipo(String tipo) {
    if (
      tipo.contains('DESAFIO') ||
      tipo.contains('TM')
    ) {
      return 'Talent Manager';
    }

    if (
      tipo.contains('SLL') ||
      tipo.contains('SERVICE_LINE')
    ) {
      return 'Service Line Leader';
    }

    if (
      tipo.contains('CANDIDATURA') ||
      tipo.contains('BADGE') ||
      tipo.contains('CERTIFICADO')
    ) {
      return 'Softinsa Badges';
    }

    return 'Sistema';
  }

  static String _humanizarTipo(String tipo) {
    final texto = tipo
        .toLowerCase()
        .replaceAll('_', ' ')
        .trim();

    if (texto.isEmpty) {
      return 'Notificação';
    }

    return texto[0].toUpperCase() +
        texto.substring(1);
  }
}
