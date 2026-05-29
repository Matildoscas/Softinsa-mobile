import 'package:flutter/material.dart';

class PerfilDropdown extends StatefulWidget {
  final VoidCallback onVerPerfil;
  final VoidCallback onTerminarSessao;

  const PerfilDropdown({
    super.key,
    required this.onVerPerfil,
    required this.onTerminarSessao,
  });

  @override
  State<PerfilDropdown> createState() => _PerfilDropdownState();
}

class _PerfilDropdownState extends State<PerfilDropdown> {
  bool _aberto = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  void toggle() {
    if (_aberto) {
      fechar();
    } else {
      abrir();
    }
  }

  void abrir() {
    _overlayEntry = _criarOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _aberto = true);
  }

  void fechar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _aberto = false);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  OverlayEntry _criarOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Fecha o menu se clicar em qualquer lado fora dele
          GestureDetector(
            onTap: fechar,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          
          // ====== SETA DO DROPDOWN (ALINHADA COM O PERFIL) ======
          Positioned(
            width: 18,
            height: 10,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(11, 44), // Centraliza a seta exatamente abaixo do ícone de perfil
              child: CustomPaint(
                painter: _TrianglePainter(color: const Color(0xFF4470AF)),
              ),
            ),
          ),

          // ====== CORPO DO DROPDOWN ======
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-142, 54), // Alinha a caixa do menu perfeitamente à direita
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                shadowColor: Colors.black26,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF4470AF), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botão: Ver Perfil
                        InkWell(
                          onTap: () {
                            fechar();
                            widget.onVerPerfil();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.account_circle_outlined, color: Colors.black87, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Ver Perfil', 
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        Divider(height: 1, color: Colors.grey.shade200),
                        
                        // Botão: Terminar Sessão
                        InkWell(
                          onTap: () {
                            fechar();
                            widget.onTerminarSessao();
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.logout, color: Colors.redAccent, size: 20),
                                SizedBox(width: 12),
                                Text(
                                  'Terminar Sessão', 
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: toggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.person, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ====== PAINTER DA SETA DO DROPDOWN ======
class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}