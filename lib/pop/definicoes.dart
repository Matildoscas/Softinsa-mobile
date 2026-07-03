// ============================================================================
// definicoes.dart
//
// Componentes reutilizáveis do menu de perfil apresentado no cabeçalho.
//
// Este ficheiro contém:
// - ProfilePopup: caixa com as opções Perfil, Definições e Terminar sessão;
// - _ProfileMenuItem: linha reutilizável de cada opção;
// - ProfileButton: botão circular que abre e fecha o popup;
// - Animações de aparecimento através de FadeTransition e ScaleTransition;
// - Limpeza da sessão guardada no SharedPreferences durante o logout.
// ============================================================================

// Widgets, animações, Overlay e componentes visuais do Flutter.
import 'package:flutter/material.dart';

// Armazenamento local utilizado para remover token e utilizador no logout.
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// POPUP DE PERFIL
//
// StatelessWidget porque apenas recebe callbacks e desenha as opções.
// Não possui estado próprio que precise de ser alterado.
// ============================================================================
class ProfilePopup extends StatelessWidget {
  // Função executada quando o utilizador escolhe "Ir para perfil".
  final VoidCallback? onProfile;

  // Função executada quando o utilizador escolhe "Definições".
  final VoidCallback? onSettings;

  // Função executada quando o utilizador escolhe "Terminar sessão".
  final VoidCallback? onLogout;

  const ProfilePopup({
    super.key,
    this.onProfile,
    this.onSettings,
    this.onLogout,
  });

  // Constrói a caixa branca com as três opções do menu.
  @override
  Widget build(BuildContext context) {
    return Material(
      // Transparente para o Container controlar o aspeto visual.
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          // Ocupa apenas a altura necessária para as opções.
          mainAxisSize: MainAxisSize.min,
          children: [
            _ProfileMenuItem(
              icon: Icons.person_outline,
              label: 'Ir para perfil',
              onTap: onProfile,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ProfileMenuItem(
              icon: Icons.settings_outlined,
              label: 'Definições',
              onTap: onSettings,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            _ProfileMenuItem(
              icon: Icons.logout,
              label: 'Terminar sessão',
              onTap: onLogout,
              // Esta opção é apresentada a vermelho.
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ITEM DO MENU
//
// Widget privado reutilizado pelas três opções do popup.
// ============================================================================
class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  // Quando true, o texto e o ícone ficam vermelhos.
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Escolhe a cor normal ou destrutiva.
    final color = isDestructive ? Colors.red : const Color(0xFF333333);

    return InkWell(
      // Callback recebido pelo componente pai.
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOTÃO DE PERFIL
//
// StatefulWidget porque precisa de controlar:
// - se o popup está aberto;
// - a referência do OverlayEntry;
// - o progresso das animações.
// ============================================================================
class ProfileButton extends StatefulWidget {
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  const ProfileButton({
    super.key,
    this.onProfile,
    this.onSettings,
    this.onLogout,
  });

  @override
  State<ProfileButton> createState() => _ProfileButtonState();
}

// SingleTickerProviderStateMixin fornece o vsync usado pelo AnimationController.
class _ProfileButtonState extends State<ProfileButton>
    with SingleTickerProviderStateMixin {
  // Referência ao popup inserido por cima da árvore normal de widgets.
  OverlayEntry? _overlay;

  // Guarda se o popup está atualmente aberto.
  bool _open = false;

  // Controlador principal das animações.
  late AnimationController _controller;

  // Animação de aumento da escala.
  late Animation<double> _scale;

  // Animação de transparência.
  late Animation<double> _fade;

  // Executado uma vez quando o botão é criado.
  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      // Sincroniza a animação com os frames do ecrã.
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // easeOutBack cria um pequeno efeito elástico ao abrir.
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    // easeOut torna o aparecimento da opacidade suave.
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
  }

  // Abre se estiver fechado e fecha se estiver aberto.
  void _toggle() => _open ? _close() : _openPopup();

  // ========================================================================== 
  // ABRIR POPUP
  //
  // Calcula a posição do botão, cria um OverlayEntry e apresenta o menu
  // imediatamente abaixo do botão de perfil.
  // ========================================================================== 
  void _openPopup() {
    // RenderBox permite descobrir a posição e o tamanho reais do botão.
    final renderBox = context.findRenderObject() as RenderBox;

    // Converte a posição local do botão para coordenadas globais do ecrã.
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (context) => GestureDetector(
        // Permite detetar toques mesmo nas áreas transparentes.
        behavior: HitTestBehavior.translucent,

        // Um toque fora do menu fecha o popup.
        onTap: _close,
        child: Stack(
          children: [
            Positioned(
              // Coloca o menu abaixo do botão.
              top: offset.dy + size.height + 12,
              right: 16,
              child: GestureDetector(
                // Impede que um toque dentro do popup chegue ao GestureDetector exterior.
                onTap: () {},
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topRight,
                    child: ProfilePopup(
                      onProfile: widget.onProfile != null
                          ? () {
                              // Fecha primeiro o popup e depois abre o perfil.
                              _close();
                              widget.onProfile!();
                            }
                          : null,
                      onSettings: widget.onSettings != null
                          ? () {
                              // Fecha primeiro o popup e depois abre as definições.
                              _close();
                              widget.onSettings!();
                            }
                          : null,
                      onLogout: () async {
                        // Fecha imediatamente o popup.
                        _close();

                        // Remove a sessão persistida no dispositivo.
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('token');
                        await prefs.remove('user');

                        if (widget.onLogout != null) {
                          // Usa o comportamento fornecido pelo ecrã pai.
                          widget.onLogout!();
                        } else {
                          // Fallback: abre o Login e elimina as rotas anteriores.
                          if (mounted) {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/login',
                              (_) => false,
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Insere o popup na camada de Overlay da aplicação.
    Overlay.of(context).insert(_overlay!);

    // Inicia as animações de abertura.
    _controller.forward();

    // Guarda o estado aberto para o próximo toque executar _close().
    setState(() => _open = true);
  }

  // ========================================================================== 
  // FECHAR POPUP
  //
  // Reproduz a animação ao contrário e só depois remove o OverlayEntry.
  // ========================================================================== 
  void _close() {
    _controller.reverse().then((_) {
      _overlay?.remove();
      _overlay = null;

      if (mounted) {
        setState(() => _open = false);
      }
    });
  }

  // Liberta o AnimationController e remove um popup que ainda esteja aberto.
  @override
  void dispose() {
    _controller.dispose();
    _overlay?.remove();
    super.dispose();
  }

  // Constrói o botão circular apresentado no cabeçalho.
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: 35,
        height: 35,
        decoration: const BoxDecoration(
          color: Color(0xFF4470AF),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
