import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificacoesDropdown extends StatefulWidget {
  final int userId;
  const NotificacoesDropdown({super.key, required this.userId});

  @override
  State<NotificacoesDropdown> createState() => _NotificacoesDropdownState();
}

class _NotificacoesDropdownState extends State<NotificacoesDropdown> {
  bool _aberto = false;
  List<Map<String, dynamic>> _notificacoes = [];
  bool _loading = false;
  
  // Controladores do Overlay para flutuar sobre os ecrãs
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
    _carregarNotificacoes();
  }

  void fechar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _aberto = false);
    }
  }

  @override
  void dispose() {
    // Garante que limpa o overlay da memória se mudar de página abruptamente
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _carregarNotificacoes() async {
    setState(() => _loading = true);
    try {
      final dados = await ApiService().getNotificacoes(widget.userId);
      setState(() => _notificacoes = dados);
      // Atualiza o painel aberto para mostrar a lista nova
      _overlayEntry?.markNeedsBuild();
    } catch (e) {
      debugPrint('Erro ao carregar notificações: $e');
    } finally {
      setState(() => _loading = false);
      _overlayEntry?.markNeedsBuild();
    }
  }

  // Determina o "tipo" com base no conteúdo da notificação
  String _inferirTipo(String conteudo) {
    final c = conteudo.toLowerCase();
    if (c.contains('badge') && c.contains('valid')) return 'validado';
    if (c.contains('badge')) return 'badge';
    if (c.contains('perfil')) return 'perfil';
    return 'outro';
  }

  // Formata a data para "X horas atrás" ou "X minutos atrás"
  String _formatarTempo(String? dataEnvio) {
    if (dataEnvio == null) return '';
    try {
      final data = DateTime.parse(dataEnvio);
      final diff = DateTime.now().difference(data);
      if (diff.inMinutes < 60) return '${diff.inMinutes} minutos atrás';
      if (diff.inHours < 24) return '${diff.inHours} horas atrás';
      return '${diff.inDays} dias atrás';
    } catch (_) {
      return '';
    }
  }

  // Retorna um título legível com base no tipo da notificação
  String _inferirTitulo(String tipo, String conteudo) {
    if (tipo == 'perfil') return 'Atualizou o perfil de acesso';
    if (tipo == 'badge') return 'Recebeu um novo Badge';
    if (tipo == 'validado') return 'O seu Badge foi validado pelo\nService Line Leader';
    return conteudo;
  }

  // Retorna um nome de remetente legível
  String _inferirNomeRemetente(Map<String, dynamic> n, String tipo) {
    if (tipo == 'perfil') return 'Ana Maria';
    return 'System';
  }

  // ====== CONSTRUTOR DO PAINEL FLUTUANTE REAL ======
  OverlayEntry _criarOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Barreira Invisível: Se clicar em qualquer lado fora do painel, fecha o dropdown
          GestureDetector(
            onTap: fechar,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          
          // Seta do Dropdown alinhada dinamicamente
          Positioned(
            width: 18,
            height: 10,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(11, 44), // Centraliza a seta abaixo do sino
              child: CustomPaint(
                painter: _TrianglePainter(color: const Color(0xFF4470AF)),
              ),
            ),
          ),

          // Caixa de Conteúdo das Notificações
          Positioned(
            width: 340,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-258, 54), // Posiciona o painel alinhado à direita do sino
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                shadowColor: Colors.black26,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 420),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF4470AF), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF4470AF))),
                          )
                        : _notificacoes.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.notifications_off_outlined, size: 36, color: Colors.grey),
                                      SizedBox(height: 8),
                                      Text(
                                        'Sem notificações',
                                        style: TextStyle(color: Colors.grey, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      physics: const BouncingScrollPhysics(),
                                      itemCount: _notificacoes.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1, color: Colors.grey.shade200),
                                      itemBuilder: (context, i) {
                                        final n = _notificacoes[i];
                                        final tipo = _inferirTipo(n['conteudo'] ?? '');
                                        return _notificacaoItem(
                                          tipo: tipo,
                                          titulo: _inferirTitulo(tipo, n['conteudo'] ?? ''),
                                          descricao: n['conteudo'] ?? '',
                                          nomeRemetente: _inferirNomeRemetente(n, tipo),
                                          tempo: _formatarTempo(n['data_envio']),
                                        );
                                      },
                                    ),
                                  ),
                                  Divider(height: 1, color: Colors.grey.shade200),
                                  // ====== VER TODAS ======
                                  InkWell(
                                    onTap: () {
                                      fechar();
                                      // Coloca a tua navegação global aqui se necessário
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Center(
                                        child: Text(
                                          'Ver todas as notificações',
                                          style: TextStyle(
                                            color: const Color(0xFF4470AF),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            decoration: TextDecoration.underline,
                                            decorationColor: const Color(0xFF4470AF),
                                          ),
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
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O Target fixa as coordenadas deste botão para que o painel saiba onde se posicionar
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: toggle,
        child: Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications,
                color: Colors.white,
                size: 22,
              ),
              if (_notificacoes.isNotEmpty)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificacaoItem({
    required String tipo,
    required String titulo,
    required String descricao,
    required String nomeRemetente,
    required String tempo,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ====== AVATAR / ÍCONE ======
          Column(
            children: [
              _avatarIcone(tipo),
              const SizedBox(height: 5),
              Text(
                nomeRemetente,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                tempo,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // ====== TEXTO ======
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Colors.black,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    descricao,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarIcone(String tipo) {
    if (tipo == 'perfil') {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFDDE8F5),
        child: Icon(Icons.person, size: 30, color: Color(0xFF4470AF)),
      );
    } else if (tipo == 'badge' || tipo == 'validado') {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFF4CD964),
        child: Icon(Icons.check, size: 28, color: Colors.white),
      );
    } else {
      return const CircleAvatar(
        radius: 28,
        backgroundColor: Color(0xFFFF6B6B),
        child: Icon(Icons.priority_high, size: 26, color: Colors.white),
      );
    }
  }
}

// ====== PAINTER DA SETA ======
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