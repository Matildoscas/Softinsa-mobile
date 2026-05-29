import 'package:flutter/material.dart';

class NotificacoesDropdown extends StatefulWidget {
  const NotificacoesDropdown({super.key});

  @override
  State<NotificacoesDropdown> createState() => _NotificacoesDropdownState();
}

class _NotificacoesDropdownState extends State<NotificacoesDropdown> {
  bool _aberto = false;

  final List<Map<String, dynamic>> _notificacoes = [
    {
      "tipo": "perfil",
      "titulo": "Atualizou o perfil de acesso",
      "descricao": "Lorem Ipsum is simply dummy text of the printing and typesetting industry.....",
      "remetente": "Ana Maria",
      "tempo": "59 minutos atrás",
    },
    {
      "tipo": "badge",
      "titulo": "Recebeu um novo Badge",
      "descricao": "Lorem Ipsum is simply dummy text of the printing and typesetting industry.....",
      "remetente": "System",
      "tempo": "12 horas atrás",
    },
    {
      "tipo": "validado",
      "titulo": "O seu Badge foi validado pelo Service Line Leader",
      "descricao": "Lorem Ipsum is simply dummy text of the printing and typesetting industry.....",
      "remetente": "System",
      "tempo": "12 horas atrás",
    },
  ];

  void toggle() => setState(() => _aberto = !_aberto);
  void fechar() => setState(() => _aberto = false);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ====== BOTÃO SINO ======
        GestureDetector(
          onTap: toggle,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _aberto ? Colors.white : Color(0xFF4470AF),
              shape: BoxShape.circle,
              border: _aberto
                  ? Border.all(color: Color(0xFF4470AF), width: 1.5)
                  : null,
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: _aberto ? Color(0xFF4470AF) : Colors.white,
              size: 20,
            ),
          ),
        ),

        // ====== PAINEL DROPDOWN ======
        if (_aberto)
          Positioned(
            top: 46,
            right: -8,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              color: Colors.transparent,
              child: Container(
                width: 340,
                decoration: BoxDecoration(
                  color: Color(0xFF4470AF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  margin: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Itens de notificação
                      ..._notificacoes.asMap().entries.map((entry) {
                        final i = entry.key;
                        final n = entry.value;
                        return Column(
                          children: [
                            _notificacaoItem(n),
                            if (i < _notificacoes.length - 1)
                              Divider(height: 1, color: Colors.grey.shade200),
                          ],
                        );
                      }).toList(),

                      // Link "Ver todas as notificações"
                      Divider(height: 1, color: Colors.grey.shade200),
                      InkWell(
                        onTap: () {
                          fechar();
                          // Navegar para página completa de notificações:
                          // Navigator.push(context, MaterialPageRoute(builder: (_) => const Notificacoes()));
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            "Ver todas as notificações",
                            style: TextStyle(
                              color: Color(0xFF39639C),
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _notificacaoItem(Map<String, dynamic> n) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + nome + tempo
          Column(
            children: [
              _avatarIcone(n["tipo"]),
              SizedBox(height: 4),
              Text(
                n["remetente"],
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
              Text(
                n["tempo"],
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(width: 12),
          // Título + descrição
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n["titulo"],
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  n["descricao"],
                  style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarIcone(String tipo) {
    if (tipo == "perfil") {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFDDE8F5),
        child: Icon(Icons.person, size: 32, color: Color(0xFF5B7FA6)),
      );
    } else if (tipo == "badge" || tipo == "validado") {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.green.shade400,
        child: Icon(Icons.check, size: 28, color: Colors.black87),
      );
    } else {
      return CircleAvatar(
        radius: 28,
        backgroundColor: Colors.red.shade400,
        child: Icon(Icons.priority_high, size: 28, color: Colors.white),
      );
    }
  }
}