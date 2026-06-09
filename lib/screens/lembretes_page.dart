import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central da cache local

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
    // Tratamento seguro para parsing de datas em qualquer formato
    String dataFormatada = '—';
    if (json['data_envio'] != null) {
      try {
        final data = DateTime.parse(json['data_envio'].toString());
        dataFormatada = "${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}";
      } catch (_) {
        dataFormatada = json['data_envio'].toString();
      }
    }

    return ReminderItem(
      title: json['tipo_notificacao'] ?? 'Lembrete',
      description: json['conteudo'] ?? '',
      sender: 'System',
      timeAgo: dataFormatada,
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
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Conexão local SQLite

  List<ReminderItem> reminders = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    List<Map<String, dynamic>> dataRaw = [];

    try {
      // 1. Tenta descarregar as notificações em tempo real através da API
      dataRaw = await _apiService.getNotifications(widget.userId);

      // 2. MIRRORING: Guarda cada uma das notificações localmente no SQLite
      for (var n in dataRaw) {
        await _dbLocal.salvarRegisto('notificacoes', {
          'id_notificacoes': n['id_notificacoes'] ?? n['id'] ?? DateTime.now().millisecondsSinceEpoch,
          'tipo_notificacao': n['tipo_notificacao'] ?? 'Lembrete',
          'conteudo': n['conteudo'] ?? '',
          'data_envio': n['data_envio']?.toString(),
          'estado_notificacao': n['estado_notificacao'] ?? 'Lido',
        });
      }
    } catch (e) {
      debugPrint("Modo Offline Ativo nos Lembretes: Carregando cache local... ($e)");
      
      // 3. FALLBACK: Sem internet? Extrai as linhas salvas na tabela 'notificacoes'
      dataRaw = await _dbLocal.listarTabela('notificacoes');
    }

    if (mounted) {
      setState(() {
        // Converte os dados do mapa (sejam da rede ou do SQLite) para a lista de itens da UI
        reminders = dataRaw.map((e) => ReminderItem.fromJson(e)).toList();
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

                  // Conteúdo da Listagem
                  Expanded(
                    child: isLoading
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFF4470AF)),
                          )
                        : reminders.isEmpty
                            ? _estadoVazio()
                            : ListView.separated(
                                padding: EdgeInsets.zero,
                                itemCount: reminders.length,
                                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                                itemBuilder: (context, index) => _reminderRow(reminders[index]),
                              ),
                  ),
                ],
              ),
            ),

            // FIXED HEADER APP LOGO
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

  Widget _reminderRow(ReminderItem item) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bloco do emissor / tempo
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

          // Texto Informativo
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
          Icon(Icons.alarm_off_outlined, size: 52, color: Colors.grey.shade400),
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