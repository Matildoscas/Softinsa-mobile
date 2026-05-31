import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../screens/notificacoes_page.dart';

/// ================= MODELO =================
class NotificationItem {
  final String title;
  final String description;
  final String sender;
  final String timeAgo;
  final bool isSystem;
  final String? imageUrl;

  NotificationItem({
    required this.title,
    required this.description,
    required this.sender,
    required this.timeAgo,
    required this.isSystem,
    this.imageUrl,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    print("tipo_notificacao = ${json['tipo_notificacao']}");
    final data = DateTime.parse(json['data_envio']);

    return NotificationItem(
      title: json['tipo_notificacao'] ?? 'Notificação',
      description: json['conteudo'] ?? '',
      sender: 'System',
      timeAgo: "${data.day}/${data.month}/${data.year}",
      isSystem: json['tipo_notificacao'] != 'Alerta',
      imageUrl: null,
    );
  }
}

/// ================= POPUP =================
class NotificationsPopup extends StatelessWidget {
  final List<NotificationItem> notifications;
  final VoidCallback? onViewAll;
  final int userId;

  const NotificationsPopup({
    super.key,
    required this.notifications,
    required this.userId,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Estado vazio ──────────────────────────────────────
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: const [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Sem notificações',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF555555),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Não tens notificações de momento.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Lista de notificações ─────────────────────────────
            if (notifications.isNotEmpty)
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return ListTile(
                    leading: item.isSystem
                      ? const CircleAvatar(
                          backgroundColor: Color(0xFF4CAF50),
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                          ),
                        )
                      : const CircleAvatar(
                          backgroundColor: Color(0xFFEF5350),
                          child: Icon(
                            Icons.priority_high,
                            color: Colors.white,
                          ),
                        ),
                    title: Text(
                      item.title.isEmpty ? "TÍTULO VAZIO" : item.title,
                      style: const TextStyle(color: Colors.black),
                    ),
                    subtitle: Text(
                      item.description.isEmpty
                          ? "DESCRIÇÃO VAZIA"
                          : item.description,
                      style: const TextStyle(color: Colors.black),
                    ),
                  );
                },
              ),

            const Divider(height: 1),

            TextButton(
              onPressed: () {
                onViewAll?.call();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NotificacoesPage(
                      userId: userId,
                    ),
                  ),
                );
              },
              child: const Text("Ver todas as notificações"),
            ),
          ],
        ),
      ),
    );
  }
}

/// ================= BELL + API =================
class NotificationBell extends StatefulWidget {
  final int userId;

  const NotificationBell({
    super.key,
    required this.userId,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  bool _open = false;
  List<NotificationItem> notifications = [];

  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final api = ApiService();
      final data = await api.getNotifications(widget.userId);


      print(data);
      print(data.first);

      
      setState(() {
        notifications =
            data.map((e) => NotificationItem.fromJson(e)).toList();

            for (var n in notifications) {
              print("${n.title} -> isSystem = ${n.isSystem}");
            }
      });
    } catch (e) {
      debugPrint("Erro notificações: $e");
    }
  }

  void _toggle() {
    if (_open) {
      _close();
    } else {
      _openPopup();
    }
  }

  void _openPopup() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _close,
        child: Stack(
          children: [
            Positioned(
              top: offset.dy + size.height + 12,
              right: 16,
              child: FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: NotificationsPopup(
                    notifications: notifications,
                    userId: widget.userId,
                    onViewAll: () {
                      _close();
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    _controller.forward();
    setState(() => _open = true);
  }

  void _close() {
    _controller.reverse().then((_) {
      _overlay?.remove();
      _overlay = null;
      setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _overlay?.remove();
    super.dispose();
  }

  @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 35,
          height: 35,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 24,
              ),

              if (notifications.isNotEmpty)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }
}