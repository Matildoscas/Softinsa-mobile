import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import central para o espelhamento do SQLite

class DefinicoesPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DefinicoesPage({
    super.key,
    required this.userData,
  });

  @override
  State<DefinicoesPage> createState() => _DefinicoesPageState();
}

class _DefinicoesPageState extends State<DefinicoesPage> {
  final ApiService api = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância local para sincronização de perfil

  late TextEditingController nomeController;
  late TextEditingController contactoController;

  final passwordAtualController = TextEditingController();
  final novaPasswordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nomeController = TextEditingController(
      text: widget.userData['nome_completo'] ?? widget.userData['nome'] ?? '',
    );

    contactoController = TextEditingController(
      text: widget.userData['contacto']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    nomeController.dispose();
    contactoController.dispose();
    passwordAtualController.dispose();
    novaPasswordController.dispose();
    confirmarPasswordController.dispose();
    super.dispose();
  }

  int get userId {
    return int.parse(widget.userData['id_utilizador'].toString());
  }

  // Sincronização Inteligente: Atualiza a API e espelha em cache no SQLite
  Future<void> atualizarPerfil() async {
    final String nomeTrim = nomeController.text.trim();
    final String contactoTrim = contactoController.text.trim();

    if (nomeTrim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("O nome não pode ficar vazio.")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      // 1. Envia os dados atualizados para a API
      final utilizadorAtualizado = await api.atualizarPerfilUtilizador(
        idUtilizador: userId,
        nomeCompleto: nomeTrim,
        contacto: contactoTrim,
      );

      // 2. Atualiza a referência em memória local da App
      widget.userData['nome_completo'] = utilizadorAtualizado['nome_completo'] ?? nomeTrim;
      widget.userData['contacto'] = utilizadorAtualizado['contacto'] ?? contactoTrim;

      // 3. MIRRORING: Salva na tabela local do SQFlite para que a Home e Perfil tenham acesso offline
      await _dbLocal.salvarRegisto('utilizador', {
        'id_utilizador': userId,
        'nome_completo': widget.userData['nome_completo'],
        'contacto': widget.userData['contacto'],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dados atualizados com sucesso.")),
      );
    } catch (e) {
      // Fallback defensivo: Se falhar por falta de internet, avisa o utilizador de forma amigável
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Não foi possível atualizar no servidor. Verifique a sua ligação.")),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> alterarPassword() async {
    if (novaPasswordController.text != confirmarPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As passwords não coincidem.")),
      );
      return;
    }

    if (novaPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A nova password deve ter pelo menos 6 caracteres.")),
      );
      return;
    }

    try {
      await api.alterarPassword(
        idUtilizador: userId,
        passwordAtual: passwordAtualController.text,
        novaPassword: novaPasswordController.text,
      );

      passwordAtualController.clear();
      novaPasswordController.clear();
      confirmarPasswordController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password alterada com sucesso.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao alterar password. Operação requer estado online.")),
      );
    }
  }

  Future<void> confirmarExcluirConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Excluir conta"),
        content: const Text(
          "Tem a certeza que deseja excluir a sua conta? "
          "A conta ficará INATIVA e só o administrador poderá reativá-la.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sim, excluir"),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await api.desativarConta(userId);

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao desativar conta. Ligue-se à rede para concluir.")),
      );
    }
  }

  void terminarSessao() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (_) => false,
    );
  }

  void abrirTermos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Termos e Serviços"),
        content: const SingleChildScrollView(
          child: Text(
            "Ao utilizar esta aplicação, aceita os termos de utilização da plataforma Softinsa Badges. "
            "Os dados são utilizados para gestão de candidaturas, badges, certificados e progresso profissional. "
            "A conta pode ser desativada pelo utilizador e reativada apenas por um administrador.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF4470AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed Header
            Container(
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

            // Botão Voltar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back, color: azul, size: 20),
                        SizedBox(width: 6),
                        Text(
                          "Voltar",
                          style: TextStyle(
                            color: azul,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Painel Principal de Configurações
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // SECÇÃO: Dados Pessoais
                    _secao(
                      titulo: "Dados pessoais",
                      children: [
                        _campoTexto(
                          controller: nomeController,
                          label: "Nome",
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 12),
                        _campoTexto(
                          controller: contactoController,
                          label: "Contacto",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : atualizarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azul,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: Text(isSaving ? "A guardar..." : "Guardar alterações"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECÇÃO: Segurança
                    _secao(
                      titulo: "Segurança",
                      children: [
                        _campoTexto(
                          controller: passwordAtualController,
                          label: "Password atual",
                          icon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        _campoTexto(
                          controller: novaPasswordController,
                          label: "Nova password",
                          icon: Icons.lock_reset,
                          obscureText: true,
                        ),
                        const SizedBox(height: 12),
                        _campoTexto(
                          controller: confirmarPasswordController,
                          label: "Confirmar nova password",
                          icon: Icons.verified_user_outlined,
                          obscureText: true,
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: alterarPassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azul,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              minimumSize: const Size(double.infinity, 45),
                            ),
                            child: const Text("Alterar password"),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // SECÇÃO: Ações de Conta
                    _secao(
                      titulo: "Conta",
                      children: [
                        _opcao(
                          icon: Icons.description_outlined,
                          titulo: "Termos e Serviços",
                          subtitulo: "Rever condições de utilização",
                          onTap: abrirTermos,
                        ),
                        const Divider(),
                        _opcao(
                          icon: Icons.logout,
                          titulo: "Terminar sessão",
                          subtitulo: "Voltar à página de login",
                          onTap: terminarSessao,
                          cor: Colors.orange,
                        ),
                        const Divider(),
                        _opcao(
                          icon: Icons.delete_outline,
                          titulo: "Excluir conta",
                          subtitulo: "A conta ficará INATIVA",
                          onTap: confirmarExcluirConta,
                          cor: Colors.red,
                        ),
                      ],
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

  Widget _secao({
    required String titulo,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade100),
        ),
      ),
    );
  }

  Widget _opcao({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required VoidCallback onTap,
    Color cor = const Color(0xFF4470AF),
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cor.withOpacity(0.1),
              child: Icon(icon, color: cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}