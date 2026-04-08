import 'package:flutter/material.dart';
import 'package:popover/popover.dart'; // Importamos o pacote

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: HomePage());
  }
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  // Lista de cores para o header e welcome card (conforme o teu exemplo original)
  final Color primaryColor = const Color(0xFF39639C);
  final List<Color> gradientColors = [
    const Color(0xFF4470AF),
    const Color(0xFF3A5C94),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // ================= HEADER =================
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LOGO
                  Text(
                    "SOFTINSA",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),

                  // ICONES DIREITA
                  Row(
                    children: [
                      // --- ÍCONE COM O POPOVER (O PONTO CHAVE) ---
                      Builder(
                        builder: (context) {
                          return GestureDetector(
                            onTap: () {
                              // Mostra o popover quando clicado
                              showPopover(
                                context: context,
                                bodyBuilder: (context) => const RepaintBoundary(child: NotificacoesMenu()),
                                direction: PopoverDirection.bottom,
                                width: 300,
                                height: 420,
                                arrowHeight: 15,
                                arrowWidth: 20,
                                backgroundColor: Colors.white,
                              );
                            },
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: Icon(
                                Icons.notifications,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.blue,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // O Resto do teu conteúdo original aqui...
            // (Removido para simplificar o exemplo)
            const Expanded(
              child: Center(
                child: Text("Clica no sino do Header para ver o popup!"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= WIDGET DO MENU DE NOTIFICAÇÕES =================
// Este é o widget que será renderizado DENTRO do popover flutuante
class NotificacoesMenu extends StatelessWidget {
  const NotificacoesMenu({super.key});

  @override
  Widget build(BuildContext context) {
    // O Material é OBRIGATÓRIO aqui para o popup aparecer
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Ajusta o tamanho ao conteúdo
        children: [
          // Área das notificações com scroll
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 400), // Altura máxima
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              children: [
                _buildNotificacaoItem(
                  context: context,
                  iconWidget: _buildAvatarIcon(initial: "A", bgColor: Colors.grey.shade200, textColor: Colors.black54),
                  senderName: "Ana Maria",
                  timeAgo: "59 min",
                  title: "Atualizou o perfil",
                  description: "Lorem ipsum is simply dummy text of the printing...",
                ),
                const Divider(),
                _buildNotificacaoItem(
                  context: context,
                  iconWidget: _buildCheckIcon(bgColor: Colors.greenAccent),
                  senderName: "System",
                  timeAgo: "12h atrás",
                  title: "Recebeu um novo Badge",
                  description: "Parabéns! Ganhaste um novo reconhecimento.",
                ),
              ],
            ),
          ),
          
          // Rodapé
          const Divider(height: 1),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Ver todas as notificações"),
            ),
          ),
        ],
      ),
    );
  }

  // ... (mantém as funções _buildNotificacaoItem, _buildAvatarIcon e _buildCheckIcon iguais)
  // --- FUNÇÃO AUXILIAR PARA CRIAR UM ITEM DE NOTIFICAÇÃO ---
  Widget _buildNotificacaoItem({
    required BuildContext context,
    required Widget iconWidget,
    required String senderName,
    required String timeAgo,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Alinha texto ao topo do ícone
        children: [
          // ÍCONE ESQUERDA + INFORMAÇÕES ABAIXO
          SizedBox(
            width: 70, // Largura fixa para esta coluna da esquerda
            child: Column(
              children: [
                iconWidget, // O ícone (avatar ou check)
                const SizedBox(height: 6),
                Text(
                  senderName,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12), // Espaço entre ícone e texto
          // TEXTO DIREITA
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Funções para criar os ícones específicos
  Widget _buildAvatarIcon({
    required String initial,
    required Color bgColor,
    required Color textColor,
  }) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: bgColor,
      child: Text(
        initial,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildCheckIcon({required Color bgColor}) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: bgColor,
      child: const Icon(
        Icons.check,
        color: Colors.black,
        size: 22,
      ), // Checkmark preto como na imagem
    );
  }
}
