import 'package:flutter/material.dart'; // Importa a biblioteca principal do Flutter
import 'package:popover/popover.dart'; // Importamos o pacote
import 'Perfil.dart';

void main() {
  runApp(const MyApp()); // Inicializa a app
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove o banner de debug
      home: const HomePage(), // Define a página inicial
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7), // Cor de fundo semelhante ao Figma
      body: SafeArea( // Garante que não invade notch / status bar
        child: Column(
          children: [

            // ================= HEADER =================
            Container(
              color: Colors.white, // Fundo branco
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Espaçamento interno
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaço entre elementos
                children: [

                  // LOGO
                  const Text(
                    "SOFTINSA", // Nome (substitui SVG)
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF39639C),
                    ),
                  ),

                  // ICONES DIREITA
                  Row(
                    children: [
                      // Usar o Builder para garantir que enviamos o context correto (do botão)
                      // para o popover saber onde ancorar a seta.
                      Builder(
                        builder: (buttonContext) {
                          return GestureDetector(
                            onTap: () {
                              // Chamamos a função que cria o popup,
                              // passando o context do Builder (o botão em si)
                              _mostrarNotificacoes(buttonContext);
                            },
                            child: const CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: Icon(Icons.notifications, color: Colors.white, size: 18),
                            ),
                          );
                        }
                      ),
                      const SizedBox(width: 10), // Espaço entre ícones
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => Perfil()),
                          );
                        },
                        child: const CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, color: Colors.white, size: 18), // Utilizador
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),

            // ================= CONTEÚDO =================
            Expanded(
              child: SingleChildScrollView( // Permite scroll
                child: Column(
                  children: [

                    // ================= WELCOME CARD =================
                    Container(
                      margin: const EdgeInsets.all(16), // Margem exterior
                      padding: const EdgeInsets.all(16), // Espaçamento interno
                      decoration: BoxDecoration(
                        gradient: const LinearGradient( // Gradiente igual ao Figma
                          colors: [Color(0xFF4470AF), Color(0xFF3A5C94)],
                        ),
                        borderRadius: BorderRadius.circular(20), // Cantos arredondados
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // TEXTO
                          const Text(
                            "Bom dia, Utilizador!",
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),

                          const SizedBox(height: 20), // Espaço vertical

                          // GRID DE INFO
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [

                              // BADGES
                              buildInfoButton(
                                icon: Icons.emoji_events,
                                title: "Badges",
                                subtitle: "5 obtidos",
                                onTap: () {},
                              ),

                              // PONTOS
                              buildInfoButton(
                                icon: Icons.star,
                                title: "Pontos totais",
                                subtitle: "90 pontos",
                                onTap: () {},
                              ),

                              // LEMBRETES
                              buildInfoButton(
                                icon: Icons.note,
                                title: "Lembretes",
                                onTap: () {},
                              ),
                            ],
                          )
                        ],
                      ),
                    ),

                    // ================= BOTÃO =================
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, // Fundo branco
                        foregroundColor: Colors.black, // Texto preto
                        shape: const StadiumBorder(), // Botão arredondado
                        elevation: 4, // Sombra
                      ),
                      onPressed: () {}, // Ação do botão
                      icon: const Icon(Icons.grid_view), // Ícone
                      label: const Text("Catálogo de Badges"), // Texto
                    ),

                    const SizedBox(height: 20),

                    // ================= SECÇÃO =================
                    sectionHeader("Badges com progresso", "Tem 1 badge com progresso"),

                    badgeCard(
                      title: "The Watchtower - Nível A",
                      description: "Observability & Performance Specialist",
                      points: 10,
                      progress: 0.7,
                    ),

                    // ================= OUTRA SECÇÃO =================
                    sectionHeader("Recomendação de Badge", "O nosso sistema recomenda:"),

                    badgeCard(
                      title: "Script Initiate - Nível A",
                      description: "Automation & Deployment (CI/CD)",
                      points: 10,
                    ),

                    // ================= ESPECIAL =================
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        "Obtenha este badge em 3 dias e ganhe o dobro dos pontos",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),

                    badgeCard(
                      title: "ERP Insight Specialist - Nível D",
                      description: "Introdução ao SAP...",
                      points: 42,
                      highlight: true,
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

  // --- Função para extrair o popover (isolado por causa do Impeller) ---
  void _mostrarNotificacoes(BuildContext buttonContext) {
    showPopover(
      context: buttonContext,
      // RepaintBoundary é super importante para corrigir o bug do Flutter Impeller (SetInheritedOpacity crash)
      bodyBuilder: (context) => const RepaintBoundary(child: NotificacoesMenu()),
      direction: PopoverDirection.bottom,
      width: 300,
      height: 420,
      arrowHeight: 15,
      arrowWidth: 20,
      backgroundColor: Colors.white,
    );
  }

  // ================= BOTÃO DE INFORMAÇÃO =================
  Widget buildInfoButton({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Expanded( // Faz os 3 ocuparem espaço igual
      child: GestureDetector(
        onTap: onTap, // Permite clique
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4), // Espaço entre botões
          padding: const EdgeInsets.all(10), // Espaçamento interno
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15), // Fundo semi-transparente (igual Figma)
            borderRadius: BorderRadius.circular(16), // Cantos arredondados
          ),
          child: Row(
            children: [

              // Ícone dentro de mini caixa
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Caixa do ícone
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),

              const SizedBox(width: 8),

              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HEADER DE SECÇÃO =================
  Widget sectionHeader(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Espaçamento
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Espaço entre elementos
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), // Título
              Text(subtitle, style: const TextStyle(fontSize: 12)), // Subtítulo
            ],
          ),
          TextButton(
            onPressed: () {}, // Botão "Ver todos"
            child: const Text("Ver Todos"),
          )
        ],
      ),
    );
  }

  // ================= CARD DE BADGE =================
  Widget badgeCard({
    required String title,
    required String description,
    required int points,
    double? progress,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Margem
      padding: const EdgeInsets.all(12), // Padding interno
      decoration: BoxDecoration(
        color: Colors.white, // Fundo branco
        borderRadius: BorderRadius.circular(12), // Bordas arredondadas
        border: Border.all(color: Colors.grey.shade300), // Borda leve
      ),
      child: Row(
        children: [

          // ICONE
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.shade50,
            child: const Text("🏅", style: TextStyle(fontSize: 24)), // Emoji
          ),

          const SizedBox(width: 10),

          // TEXTO
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),

                // PROGRESS BAR (se existir)
                if (progress != null)
                  Column(
                    children: [
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: progress), // Barra de progresso
                    ],
                  )
              ],
            ),
          ),

          // PONTOS
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text("Pontos", style: TextStyle(fontSize: 10)),
                Text(
                  "$points",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: highlight ? Colors.amber : Colors.black, // Destaque amarelo
                  ),
                ),
              ],
            ),
          )
        ],
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
        crossAxisAlignment: CrossAxisAlignment.start, // Alinha texto ao topo do ícone
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
