// ============================================================================
// definicoes_page.dart
//
// Página principal de definições da conta do utilizador.
//
// Responsabilidades:
// - Mostrar e editar nome e contacto;
// - Enviar alterações do perfil para a API;
// - Espelhar as alterações no SQLite;
// - Alterar a password;
// - Mostrar os Termos e Serviços;
// - Terminar a sessão;
// - Pedir confirmação e desativar a conta;
// - Reutilizar componentes privados para secções, campos e opções.
// ============================================================================

// Widgets, navegação, formulários e diálogos.
import 'package:flutter/material.dart';
// Serviço utilizado para atualizar perfil, password e estado da conta.
import '../services/api_service.dart';
// Base de dados local usada para espelhar os dados atualizados do perfil.
import '../database/basededados.dart';

// StatefulWidget porque os campos, carregamento e dados do perfil mudam.
class DefinicoesPage extends StatefulWidget {
  // Dados do utilizador recebidos do ecrã anterior.
  final Map<String, dynamic> userData;

  const DefinicoesPage({
    super.key,
    required this.userData,
  });

  @override
  State<DefinicoesPage> createState() => _DefinicoesPageState();
}

class _DefinicoesPageState extends State<DefinicoesPage> {
  // Serviços utilizados para comunicação online e cache local.
  final ApiService api = ApiService();
  final Basededados _dbLocal = Basededados();

  // São late porque dependem dos dados recebidos pelo widget.
  late TextEditingController nomeController;
  late TextEditingController contactoController;

  // Controllers da secção de segurança.
  final passwordAtualController = TextEditingController();
  final novaPasswordController = TextEditingController();
  final confirmarPasswordController = TextEditingController();

  // Controla o botão e o texto durante a atualização do perfil.
  bool isSaving = false;

  // Inicializa os campos com os dados atuais do utilizador.
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

  // Liberta todos os TextEditingController quando a página fecha.
  @override
  void dispose() {
    nomeController.dispose();
    contactoController.dispose();
    passwordAtualController.dispose();
    novaPasswordController.dispose();
    confirmarPasswordController.dispose();
    super.dispose();
  }

  // Getter que converte o ID recebido para int.
  int get userId {
    return int.parse(widget.userData['id_utilizador'].toString());
  }

  // ==========================================================================
  // ATUALIZAR PERFIL
  //
  // Valida o nome, envia os dados para a API, atualiza o Map em memória
  // e guarda uma cópia no SQLite para utilização offline.
  // ==========================================================================
  Future<void> atualizarPerfil() async {
    final String nomeTrim = nomeController.text.trim();
    final String contactoTrim = contactoController.text.trim();

    // O nome é obrigatório.
    if (nomeTrim.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("O nome não pode ficar vazio.")),
      );
      return;
    }

    // Desativa o botão e apresenta "A guardar...".
    setState(() => isSaving = true);

    try {
      // 1. Envia os dados atualizados para a API
      // Fonte principal: atualiza o registo no backend.
      final utilizadorAtualizado = await api.atualizarPerfilUtilizador(
        idUtilizador: userId,
        nomeCompleto: nomeTrim,
        contacto: contactoTrim,
      );

      // 2. Atualiza a referência em memória local da App
      // Mantém os dados da sessão atual coerentes com a resposta.
      widget.userData['nome_completo'] = utilizadorAtualizado['nome_completo'] ?? nomeTrim;
      widget.userData['contacto'] = utilizadorAtualizado['contacto'] ?? contactoTrim;

      // 3. MIRRORING: Salva na tabela local do SQFlite para que a Home e Perfil tenham acesso offline
      // Espelha as alterações na cache SQLite.
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
      // É executado com sucesso ou erro, garantindo que o botão é reativado.
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ==========================================================================
  // ALTERAR PASSWORD
  //
  // Confirma se as passwords coincidem e cumprem o tamanho mínimo.
  // Depois envia a password atual e a nova password para a API.
  // ==========================================================================
  Future<void> alterarPassword() async {
    // Evita submeter duas passwords diferentes.
    if (novaPasswordController.text != confirmarPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("As passwords não coincidem.")),
      );
      return;
    }

    // Regra mínima definida para a nova password.
    if (novaPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("A nova password deve ter pelo menos 6 caracteres.")),
      );
      return;
    }

    try {
      // A alteração de password exige ligação ao backend.
      await api.alterarPassword(
        idUtilizador: userId,
        passwordAtual: passwordAtualController.text,
        novaPassword: novaPasswordController.text,
      );

      // Limpa dados sensíveis após uma alteração bem-sucedida.
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

  // ==========================================================================
  // CONFIRMAR E DESATIVAR CONTA
  //
  // Apresenta um diálogo e só chama a API se o utilizador confirmar.
  // A operação marca a conta como inativa; não a elimina fisicamente.
  // ==========================================================================
  Future<void> confirmarExcluirConta() async {
    // O diálogo devolve true, false ou null.
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

    // Cancela tanto para false como para null.
    if (confirmar != true) return;

    try {
      // Envia o pedido de desativação ao backend.
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

  // Abre o Login e remove toda a pilha de navegação anterior.
  // Nota: este método não remove diretamente token/user do SharedPreferences.
  void terminarSessao() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (_) => false,
    );
  }

  // Mostra os Termos e Serviços num AlertDialog.
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

  // Constrói as secções Dados pessoais, Segurança e Conta.
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

  // Componente privado reutilizável para os cartões de cada secção.
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

  // Componente privado que uniformiza o aspeto dos TextFields.
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

  // Linha reutilizável para Termos, Logout e Exclusão de conta.
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