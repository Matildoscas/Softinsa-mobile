import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReminderItem {
  final String title;
  final String description;
  final String sender;
  final String timeAgo;

  ReminderItem({
    required this.title,
    required this.description,
    required this.sender,
    required this.timeAgo,
  });

  factory ReminderItem.fromJson(Map<String, dynamic> json) {
    final data = DateTime.parse(json['data_envio']);

    return ReminderItem(
      title: json['tipo_notificacao'] ?? 'Lembrete',
      description: json['conteudo'] ?? '',
      sender: 'System',
      timeAgo:
          "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}",
    );
  }
}

class LembretesPage extends StatefulWidget {
  final int userId;

  const LembretesPage({super.key, required this.userId});

  @override
  State<LembretesPage> createState() => _LembretesPageState();
}

class _LembretesPageState extends State<LembretesPage> {
  List<ReminderItem> reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    try {
      final api = ApiService();
      final data = await api.getNotifications(widget.userId);
      setState(() {
        reminders = data.map((e) => ReminderItem.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Erro lembretes: $e");
      setState(() => isLoading = false);
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
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: headerHeight),

                  // Voltar — igual ao NotificacoesPage
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back,
                                  size: 20, color: Color(0xFF4470AF)),
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

                  // Divider direto — sem título/contagem
                  Divider(height: 1, color: Colors.grey.shade200),

                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF4470AF)),
                          )
                        : reminders.isEmpty
                            ? _estadoVazio()
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: reminders.length,
                                separatorBuilder: (_, _) => Divider(
                                  height: 1,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) =>
                                    _reminderRow(reminders[index]),
                              ),
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
                    horizontal: 16, vertical: 10),
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

  Widget _reminderRow(ReminderItem item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar — igual ao NotificacoesPage (sem letterSpacing)
          SizedBox(
            width: 80,
            child: Column(
              children: [
                _buildAvatar(),
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

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sem letterSpacing: 3
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Avatar fixo vermelho — lembretes são sempre alertas
  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEF5350),
      ),
      child: const Icon(Icons.priority_high, color: Colors.white, size: 34),
    );
  }

  Widget _estadoVazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_off_outlined,
              size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            "Sem lembretes",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Não tens lembretes de momento.",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}