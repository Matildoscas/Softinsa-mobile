import 'package:flutter/material.dart';

/// ================= POPUP DE PERFIL =================
class ProfilePopup extends StatelessWidget {
  final VoidCallback? onProfile;
  final VoidCallback? onSettings;
  final VoidCallback? onLogout;

  const ProfilePopup({
    super.key,
    this.onProfile,
    this.onSettings,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
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
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : const Color(0xFF333333);

    return InkWell(
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

/// ================= BOTÃO DE PERFIL =================
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

class _ProfileButtonState extends State<ProfileButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _overlay;
  bool _open = false;

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
  }

  void _toggle() => _open ? _close() : _openPopup();

  void _openPopup() {
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlay = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _close,
        child: Stack(
          children: [
            Positioned(
              top: offset.dy + size.height + 12,
              right: 16,
              child: GestureDetector(
                onTap: () {},
                child: FadeTransition(
                  opacity: _fade,
                  child: ScaleTransition(
                    scale: _scale,
                    alignment: Alignment.topRight,
                    child: ProfilePopup(
                        onProfile: widget.onProfile != null
                            ? () {
                                _close();
                                widget.onProfile!();
                              }
                            : null,

                        onSettings: widget.onSettings != null
                            ? () {
                                _close();
                                widget.onSettings!();
                              }
                            : null,

                        onLogout: widget.onLogout != null
                            ? () {
                                _close();
                                widget.onLogout!();
                              }
                            : null,
                    ),
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
      if (mounted) setState(() => _open = false);
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
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }
}