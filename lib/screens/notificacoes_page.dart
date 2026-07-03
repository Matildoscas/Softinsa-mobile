// ============================================================================
// notificacoes_page.dart
//
// Página completa das notificações.
// Permite filtrar, marcar individualmente como lida e marcar todas como lidas.
// ============================================================================

import 'package:flutter/material.dart';

import '../database/basededados.dart';
import '../models/notificacao_item.dart';
import '../services/api_service.dart';

class NotificacoesPage
    extends StatefulWidget {
  final int userId;

  const NotificacoesPage({
    super.key,
    required this.userId,
  });

  @override
  State<NotificacoesPage> createState() =>
      _NotificacoesPageState();
}

class _NotificacoesPageState
    extends State<NotificacoesPage> {
  static const Color _azul =
      Color(0xFF4470AF);

  final ApiService _apiService =
      ApiService();

  final Basededados _dbLocal =
      Basededados();

  List<AppNotificationItem>
      _notifications = [];

  bool _isLoading = true;
  bool _aMarcarTodas = false;
  String _filtro = 'TODAS';

  List<AppNotificationItem>
      get _filtradas {
    if (_filtro == 'NAO_LIDAS') {
      return _notifications
          .where(
            (item) => !item.lida,
          )
          .toList();
    }

    return _notifications;
  }

  int get _totalNaoLidas =>
      _notifications
          .where(
            (item) => !item.lida,
          )
          .length;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void>
      _loadNotifications() async {
    List<Map<String, dynamic>>
        dataRaw = [];

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      dataRaw =
          await _apiService
              .getNotifications(
        widget.userId,
      );

      for (final n in dataRaw) {
        await _guardarNaCache(n);
      }
    } catch (e) {
      debugPrint(
        'Modo offline nas notificações: $e',
      );

      dataRaw =
          await _dbLocal.listarTabela(
        'notificacoes',
      );
    }

    if (!mounted) return;

    setState(() {
      _notifications = dataRaw
          .map(
            AppNotificationItem.fromJson,
          )
          .toList();

      _isLoading = false;
    });
  }

  Future<void> _guardarNaCache(
    Map<String, dynamic> n,
  ) async {
    await _dbLocal.salvarRegisto(
      'notificacoes',
      {
        'id_notificacoes':
            n['id_notificacoes'] ??
            n['id_notificacao'] ??
            n['id'] ??
            DateTime.now()
                .millisecondsSinceEpoch,

        'tipo_notificacao':
            n['tipo_notificacao'] ??
            n['tipo'] ??
            'SISTEMA',

        'conteudo':
            n['conteudo'] ??
            n['descricao'] ??
            '',

        'data_envio':
            n['data_envio']
                ?.toString(),

        'estado_notificacao':
            n['estado_notificacao'] ??
            n['estado'] ??
            'NÃO LIDA',
      },
    );
  }

  Future<void> _marcarLida(
    AppNotificationItem item,
  ) async {
    if (item.lida || item.id <= 0) {
      return;
    }

    try {
      await _apiService
          .marcarNotificacaoComoLida(
        userId: widget.userId,
        notificationId: item.id,
      );

      final atualizado =
          item.copiarComoLida();

      await _guardarNaCache(
        atualizado.raw,
      );

      if (!mounted) return;

      setState(() {
        _notifications =
            _notifications.map(
          (atual) {
            return atual.id == item.id
                ? atualizado
                : atual;
          },
        ).toList();
      });
    } catch (e) {
      _mostrarErro(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  Future<void>
      _marcarTodasLidas() async {
    if (
      _totalNaoLidas == 0 ||
      _aMarcarTodas
    ) {
      return;
    }

    setState(() {
      _aMarcarTodas = true;
    });

    try {
      await _apiService
          .marcarTodasNotificacoesComoLidas(
        widget.userId,
      );

      final atualizadas =
          _notifications
              .map(
                (item) =>
                    item
                        .copiarComoLida(),
              )
              .toList();

      for (final item in atualizadas) {
        await _guardarNaCache(
          item.raw,
        );
      }

      if (!mounted) return;

      setState(() {
        _notifications =
            atualizadas;
      });
    } catch (e) {
      _mostrarErro(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _aMarcarTodas = false;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor:
            Colors.red.shade700,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  IconData _icone(String tipo) {
    if (tipo.contains('DESAFIO')) {
      return Icons.track_changes;
    }

    if (
      tipo.contains('REJEIT') ||
      tipo.contains('ATRAS') ||
      tipo == 'ALERTA'
    ) {
      return Icons.warning_amber_rounded;
    }

    if (
      tipo.contains('APROV') ||
      tipo.contains('ATRIBUIDO') ||
      tipo.contains('CERTIFICADO')
    ) {
      return Icons.check_circle_outline;
    }

    if (
      tipo.contains('LEMBRETE') ||
      tipo.contains('AVISO')
    ) {
      return Icons.schedule;
    }

    return Icons.notifications_none;
  }

  Color _cor(String tipo) {
    if (
      tipo.contains('REJEIT') ||
      tipo.contains('ATRAS') ||
      tipo == 'ALERTA'
    ) {
      return const Color(0xFFB91C1C);
    }

    if (
      tipo.contains('APROV') ||
      tipo.contains('ATRIBUIDO') ||
      tipo.contains('CERTIFICADO')
    ) {
      return const Color(0xFF15803D);
    }

    if (tipo.contains('DESAFIO')) {
      return const Color(0xFFD4A017);
    }

    return _azul;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor:
            Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () =>
              Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back,
            color: _azul,
          ),
        ),
        title: Image.asset(
          'lib/img/logo.png',
          height: 34,
          fit: BoxFit.contain,
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: _azul,
              ),
            )
          : RefreshIndicator(
              color: _azul,
              onRefresh:
                  _loadNotifications,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  18,
                  16,
                  28,
                ),
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Notificações',
                              style:
                                  TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(
                              height: 4,
                            ),
                            Text(
                              _totalNaoLidas == 0
                                  ? 'Não tens notificações por ler.'
                                  : 'Tens $_totalNaoLidas '
                                      '${_totalNaoLidas == 1 ? 'notificação' : 'notificações'} '
                                      'por ler.',
                              style:
                                  TextStyle(
                                fontSize: 12,
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_totalNaoLidas > 0)
                        TextButton.icon(
                          onPressed:
                              _aMarcarTodas
                                  ? null
                                  : _marcarTodasLidas,
                          icon: _aMarcarTodas
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .done_all,
                                  size: 17,
                                ),
                          label: const Text(
                            'Marcar todas',
                            style:
                                TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      ChoiceChip(
                        label:
                            const Text(
                          'Todas',
                        ),
                        selected:
                            _filtro ==
                                'TODAS',
                        selectedColor:
                            _azul,
                        labelStyle:
                            TextStyle(
                          color: _filtro ==
                                  'TODAS'
                              ? Colors.white
                              : Colors
                                  .black87,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _filtro =
                                'TODAS';
                          });
                        },
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      ChoiceChip(
                        label: Text(
                          'Não lidas '
                          '($_totalNaoLidas)',
                        ),
                        selected:
                            _filtro ==
                                'NAO_LIDAS',
                        selectedColor:
                            _azul,
                        labelStyle:
                            TextStyle(
                          color: _filtro ==
                                  'NAO_LIDAS'
                              ? Colors.white
                              : Colors
                                  .black87,
                        ),
                        onSelected: (_) {
                          setState(() {
                            _filtro =
                                'NAO_LIDAS';
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_filtradas.isEmpty)
                    _estadoVazio()
                  else
                    ..._filtradas.map(
                      _notificationCard,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _notificationCard(
    AppNotificationItem item,
  ) {
    final cor = _cor(item.tipo);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: item.lida
            ? Colors.white
            : const Color(
                0xFFF3F7FD,
              ),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: item.lida
              ? Colors.grey.shade200
              : const Color(
                  0xFFBFD4F4,
                ),
          width: item.lida ? 1 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(0.03),
            blurRadius: 5,
            offset:
                const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: item.lida
            ? null
            : () => _marcarLida(
                  item,
                ),
        borderRadius:
            BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.all(
            14,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: cor
                      .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icone(item.tipo),
                  color: cor,
                  size: 23,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.titulo,
                            style:
                                TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  item.lida
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                              color:
                                  const Color(
                                0xFF111827,
                              ),
                            ),
                          ),
                        ),
                        if (!item.lida)
                          Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              left: 8,
                            ),
                            width: 8,
                            height: 8,
                            decoration:
                                const BoxDecoration(
                              color:
                                  Color(
                                0xFF2563EB,
                              ),
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      item.descricao,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors
                            .grey.shade700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(
                      height: 9,
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons
                              .account_circle_outlined,
                          size: 13,
                          color: Colors
                              .grey.shade500,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Text(
                          item.emissor,
                          style:
                              TextStyle(
                            fontSize: 10,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          decoration:
                              BoxDecoration(
                            color: Colors
                                .grey.shade400,
                            shape:
                                BoxShape.circle,
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ),
                        Text(
                          item.tempo,
                          style:
                              TextStyle(
                            fontSize: 10,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (!item.lida) ...[
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        'Toca para marcar como lida',
                        style:
                            TextStyle(
                          fontSize: 10,
                          color: _azul,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _estadoVazio() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 42,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Icon(
            _filtro == 'NAO_LIDAS'
                ? Icons.done_all
                : Icons
                    .notifications_off_outlined,
            size: 48,
            color:
                Colors.grey.shade400,
          ),
          const SizedBox(
            height: 11,
          ),
          Text(
            _filtro == 'NAO_LIDAS'
                ? 'Tudo em dia'
                : 'Sem notificações',
            style:
                const TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            _filtro == 'NAO_LIDAS'
                ? 'Não tens notificações por ler.'
                : 'Não tens notificações de momento.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color:
                  Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
