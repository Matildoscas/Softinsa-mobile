import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import da base de dados local SQFlite

// ── MODELO ────────────────────────────────────────────────────────────────────
class NotificationItem {
  final String title;
  final String description;
  final String sender;
  final String timeAgo;
  final NotificationAvatarType avatarType;
  final String? imageUrl;

  NotificationItem({
    required this.title,
    required this.description,
    required this.sender,
    required this.timeAgo,
    required this.avatarType,
    this.imageUrl,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    String dataFormatada = '—';
    if (json['data_envio'] != null) {
      try {
        final data = DateTime.parse(json['data_envio'].toString());
        dataFormatada = "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
      } catch (_) {
        dataFormatada = json['data_envio'].toString();
      }
    }

    NotificationAvatarType avatarType;
    switch (json['tipo_notificacao']?.toString()) {
      case 'Alerta':
        avatarType = NotificationAvatarType.error;
        break;
      case 'Sistema':
        avatarType = NotificationAvatarType.system;
        break;
      default:
        avatarType = NotificationAvatarType.system;
    }

    return NotificationItem(
      title: json['tipo_notificacao'] ?? 'Notificação',
      description: json['conteudo'] ?? '',
      sender: 'System',
      timeAgo: dataFormatada,
      avatarType: avatarType,
    );
  }
}

enum NotificationAvatarType { user, system, error }

// ── PÁGINA ────────────────────────────────────────────────────────────────────
class NotificacoesPage extends StatefulWidget {
  final int userId;

  const NotificacoesPage({super.key, required this.userId});

  @override
  State<NotificacoesPage> createState() => _NotificacoesPageState();
}

class _NotificacoesPageState extends State<NotificacoesPage> {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local SQLite

  List<NotificationItem> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    List<Map<String, dynamic>> dataRaw = [];

    try {
      // 1. Tenta carregar as notificações frescas a partir do servidor
      dataRaw = await _apiService.getNotifications(widget.userId);

      // 2. MIRRORING: Atualiza a cache local gravando os dados no SQFlite (Upsert)
      for (var n in dataRaw) {
        await _dbLocal.salvarRegisto('notificacoes', {
          'id_notificacoes': n['id_notificacoes'] ?? n['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'tipo_notificacao': n['tipo_notificacao'] ?? 'Notificação',
          'conteudo': n['conteudo'] ?? '',
          'data_envio': n['data_envio']?.toString(),
          'estado_notificacao': n['estado_notificacao'] ?? 'Lido',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo nas Notificações: Lendo do SQFlite... ($e)");
      
      // 3. FALLBACK: Em caso de erro de rede, consome as notificações guardadas localmente
      dataRaw = await _dbLocal.listarTabela('notificacoes');
    }

    if (mounted) {
      setState(() {
        notifications = dataRaw.map((e) => NotificationItem.fromJson(e)).toList();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO SCROLLÁVEL ─────────────────────────────────
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: headerHeight),

                  // Botão Voltar
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back, size: 20, color: Color(0xFF4470AF)),
                              SizedBox(width: 8),
                              Text(
                                "Voltar",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF4470AF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: Colors.grey.shade200),

                  // Listagem Dinâmica
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF4470AF)),
                          )
                        : notifications.isEmpty
                            ? _estadoVazio()
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: notifications.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) =>
                                    _notificationRow(notifications[index]),
                              ),
                  ),
                ],
              ),
            ),

            // ── FIXED HEADER LOGO ────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Image.asset(
                      'lib/img/logo.png',
                      height: 35,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationRow(NotificationItem item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloco Lateral de Metadados (Avatar + Emissor + Tempo)
          SizedBox(
            width: 80,
            child: Column(
              children: [
                _buildAvatar(item),
                const SizedBox(height: 6),
                Text(
                  item.sender,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF222222),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  item.timeAgo,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Bloco Central Informativo (Conteúdo)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(NotificationItem item) {
    switch (item.avatarType) {
      case NotificationAvatarType.system:
        return Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF4CAF50),
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 34),
        );

      case NotificationAvatarType.error:
        return Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFEF5350),
          ),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 34),
        );

      case NotificationAvatarType.user:
        if (item.imageUrl != null) {
          return CircleAvatar(
            radius: 32,
            backgroundImage: NetworkImage(item.imageUrl!),
          );
        }
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade200,
          ),
          child: Icon(Icons.person, color: Colors.grey.shade400, size: 34),
        );
    }
  }

  Widget _estadoVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "Sem notificações",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Não tens notificações de momento.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}