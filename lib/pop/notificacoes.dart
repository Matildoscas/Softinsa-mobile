// ============================================================================
// notificacoes.dart
//
// Sino e popup de notificações.
// O indicador apresenta apenas notificações não lidas.
// Ao tocar numa notificação, esta é marcada como lida no backend.
// ============================================================================

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/notificacao_item.dart';
import '../screens/notificacoes_page.dart';
import '../services/api_service.dart';

class NotificationsPopup extends StatelessWidget {
  final List<AppNotificationItem> notifications;
  final int totalNaoLidas;
  final Future<void> Function(
    AppNotificationItem item,
  ) onMarcarLida;
  final Future<void> Function()
      onMarcarTodasLidas;
  final VoidCallback onViewAll;

  const NotificationsPopup({
    super.key,
    required this.notifications,
    required this.totalNaoLidas,
    required this.onMarcarLida,
    required this.onMarcarTodasLidas,
    required this.onViewAll,
  });

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

    if (tipo.contains('LEMBRETE')) {
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

    return const Color(0xFF4470AF);
  }

  @override
  Widget build(BuildContext context) {
    final recentes =
        notifications.take(5).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 350,
        constraints: const BoxConstraints(
          maxHeight: 500,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(0.16),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                14,
                10,
                10,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notificações',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                  if (totalNaoLidas > 0)
                    TextButton(
                      onPressed:
                          onMarcarTodasLidas,
                      child: const Text(
                        'Marcar todas como lidas',
                        style: TextStyle(
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (recentes.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.symmetric(
                  vertical: 34,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons
                          .notifications_off_outlined,
                      size: 44,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Sem notificações',
                      style: TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Não tens notificações de momento.',
                      textAlign:
                          TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount:
                      recentes.length,
                  separatorBuilder:
                      (_, _) =>
                          const Divider(
                    height: 1,
                  ),
                  itemBuilder:
                      (context, index) {
                    final item =
                        recentes[index];
                    final cor =
                        _cor(item.tipo);

                    return Material(
                      color: item.lida
                          ? Colors.white
                          : const Color(
                              0xFFF3F7FD,
                            ),
                      child: InkWell(
                        onTap: item.lida
                            ? null
                            : () =>
                                onMarcarLida(
                                  item,
                                ),
                        child: Padding(
                          padding:
                              const EdgeInsets
                                  .all(12),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration:
                                    BoxDecoration(
                                  color: cor
                                      .withOpacity(
                                    0.12,
                                  ),
                                  shape:
                                      BoxShape.circle,
                                ),
                                child: Icon(
                                  _icone(
                                    item.tipo,
                                  ),
                                  color: cor,
                                  size: 20,
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
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.titulo,
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  12,
                                              fontWeight:
                                                  item.lida
                                                      ? FontWeight.w600
                                                      : FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (!item.lida)
                                          Container(
                                            width: 7,
                                            height: 7,
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
                                      height: 3,
                                    ),
                                    Text(
                                      item.descricao,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          TextStyle(
                                        fontSize: 11,
                                        height: 1.35,
                                        color: Colors
                                            .grey
                                            .shade700,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 4,
                                    ),
                                    Text(
                                      '${item.emissor} • ${item.tempo}',
                                      style:
                                          TextStyle(
                                        fontSize: 9,
                                        color: Colors
                                            .grey
                                            .shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            const Divider(height: 1),
            TextButton(
              onPressed: onViewAll,
              child: const Text(
                'Ver todas as notificações',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  color: Color(
                    0xFF4470AF,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationBell
    extends StatefulWidget {
  final int userId;

  const NotificationBell({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationBell> createState() =>
      _NotificationBellState();
}

class _NotificationBellState
    extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService =
      ApiService();

  OverlayEntry? _overlay;
  bool _open = false;

  List<AppNotificationItem>
      notifications = [];

  StreamSubscription<RemoteMessage>?
      _onMessageSubscription;

  StreamSubscription<RemoteMessage>?
      _onMessageOpenedSubscription;

  late AnimationController
      _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  int get _totalNaoLidas =>
      notifications
          .where(
            (item) => !item.lida,
          )
          .length;

  @override
  void initState() {
    super.initState();

    _controller =
        AnimationController(
      vsync: this,
      duration:
          const Duration(
        milliseconds: 200,
      ),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _loadNotifications();

    _onMessageSubscription =
        FirebaseMessaging.onMessage
            .listen(
      (_) => _loadNotifications(),
    );

    _onMessageOpenedSubscription =
        FirebaseMessaging
            .onMessageOpenedApp
            .listen(
      (_) => _loadNotifications(),
    );
  }

  Future<void>
      _loadNotifications() async {
    if (widget.userId <= 0) {
      return;
    }

    try {
      final data =
          await _apiService
              .getNotifications(
        widget.userId,
      );

      if (!mounted) return;

      setState(() {
        notifications = data
            .map(
              AppNotificationItem
                  .fromJson,
            )
            .toList();
      });

      _overlay?.markNeedsBuild();
    } catch (e) {
      debugPrint(
        'Erro ao carregar o sino '
        'de notificações: $e',
      );
    }
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

      if (!mounted) return;

      setState(() {
        notifications =
            notifications.map(
          (atual) {
            return atual.id == item.id
                ? atual.copiarComoLida()
                : atual;
          },
        ).toList();
      });

      _overlay?.markNeedsBuild();
    } catch (e) {
      debugPrint(
        'Erro ao marcar notificação '
        'como lida: $e',
      );
    }
  }

  Future<void>
      _marcarTodasLidas() async {
    if (_totalNaoLidas == 0) {
      return;
    }

    try {
      await _apiService
          .marcarTodasNotificacoesComoLidas(
        widget.userId,
      );

      if (!mounted) return;

      setState(() {
        notifications =
            notifications
                .map(
                  (item) =>
                      item
                          .copiarComoLida(),
                )
                .toList();
      });

      _overlay?.markNeedsBuild();
    } catch (e) {
      debugPrint(
        'Erro ao marcar todas as '
        'notificações como lidas: $e',
      );
    }
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _loadNotifications();
      _openPopup();
    }
  }

  void _openPopup() {
    final renderBox =
        context.findRenderObject()
            as RenderBox;

    final offset =
        renderBox.localToGlobal(
      Offset.zero,
    );

    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior:
                    HitTestBehavior
                        .translucent,
                onTap: _close,
                child:
                    const SizedBox.expand(),
              ),
            ),
            Positioned(
              top: offset.dy +
                  size.height +
                  12,
              right: 16,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  alignment:
                      Alignment.topRight,
                  child:
                      NotificationsPopup(
                    notifications:
                        notifications,
                    totalNaoLidas:
                        _totalNaoLidas,
                    onMarcarLida:
                        _marcarLida,
                    onMarcarTodasLidas:
                        _marcarTodasLidas,
                    onViewAll:
                        _abrirPaginaCompleta,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(
      _overlay!,
    );

    _controller.forward();

    setState(() {
      _open = true;
    });
  }

  void _close() {
    if (!_open) return;

    _controller.reverse().then(
      (_) {
        _overlay?.remove();
        _overlay = null;

        if (mounted) {
          setState(() {
            _open = false;
          });
        }
      },
    );
  }

  Future<void>
      _abrirPaginaCompleta() async {
    _close();

    await Future<void>.delayed(
      const Duration(
        milliseconds: 220,
      ),
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            NotificacoesPage(
          userId: widget.userId,
        ),
      ),
    );

    await _loadNotifications();
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlay?.remove();
    _onMessageSubscription?.cancel();
    _onMessageOpenedSubscription
        ?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalNaoLidas;

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration:
            const BoxDecoration(
          color: Color(
            0xFF4470AF,
          ),
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications,
              color: Colors.white,
              size: 20,
            ),
            if (total > 0)
              Positioned(
                right: -7,
                top: -7,
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 4,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.red.shade700,
                    borderRadius:
                        BorderRadius
                            .circular(
                      20,
                    ),
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      total > 9
                          ? '9+'
                          : '$total',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 9,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
