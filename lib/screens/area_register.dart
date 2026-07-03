// ============================================================================
// area_register.dart
//
// Segundo e último passo do processo de registo.
//
// Responsabilidades principais:
// - Receber nome, email, password e aceitação dos termos do ecrã anterior;
// - Carregar as áreas através do UtilizadorProvider;
// - Apresentar as áreas num DropdownButtonFormField;
// - Validar se foi escolhida uma área;
// - Enviar o registo completo para a API;
// - Mostrar o resultado ao utilizador;
// - Regressar ao Login depois de criar a conta.
//
// As áreas podem vir da API ou do SQLite, porque essa decisão é feita dentro
// do UtilizadorProvider. O registo final, contudo, necessita de ligação à API.
// ============================================================================

// Widgets visuais, navegação, formulários e mensagens SnackBar.
import 'package:flutter/material.dart';

// Permite observar e consultar o estado global da aplicação.
import 'package:provider/provider.dart';

// Serviço responsável pelo pedido HTTP de registo.
import '../services/api_service.dart';

// Provider que disponibiliza as áreas online ou através da cache local.
import '../providers/utilizador_provider.dart';

// Ecrã para o qual a aplicação regressa depois do registo.
import 'login.dart';

// StatefulWidget porque a área selecionada e o estado de gravação mudam.
class AreaRegisterPage extends StatefulWidget {
  // Dados recebidos do primeiro passo do registo.
  final String nome;
  final String email;
  final String password;
  final bool aceitouTermos;

  const AreaRegisterPage({
    super.key,
    required this.nome,
    required this.email,
    required this.password,
    required this.aceitouTermos,
  });

  @override
  // Cria o objeto que guarda o estado mutável deste ecrã.
  _AreaRegPageState createState() => _AreaRegPageState();
}

class _AreaRegPageState extends State<AreaRegisterPage> {
  // Serviço utilizado para enviar o pedido final de registo.
  final ApiService _apiService = ApiService();

  // ID da área atualmente escolhida no dropdown.
  // É nullable porque inicialmente ainda não existe nenhuma seleção.
  int? _selectedAreaId;

  // Controla o spinner e impede vários pedidos de registo simultâneos.
  bool _aGravar = false;

  // =========================================================================
  // INITSTATE
  //
  // É executado uma única vez quando o ecrã é criado.
  // Agenda o carregamento das áreas para depois do primeiro frame.
  // =========================================================================
  @override
  void initState() {
    super.initState();

    // O callback corre depois da primeira construção do ecrã, momento em que
    // o BuildContext já pode procurar o Provider de forma segura.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UtilizadorProvider>(
        context,
        // Não precisa reconstruir este método; o Consumer no build já escuta.
        listen: false,
      ).carregarAreas();
    });
  }

  // =========================================================================
  // FINALIZAR REGISTO
  //
  // 1. Confirma se foi escolhida uma área;
  // 2. Ativa o estado de gravação;
  // 3. Envia todos os dados para a API;
  // 4. Desativa o estado de gravação;
  // 5. Em caso de sucesso, regressa ao Login;
  // 6. Em caso de erro, mostra uma mensagem.
  // =========================================================================
  Future<void> _finalizarRegisto() async {
    // A área é obrigatória para concluir o processo.
    if (_selectedAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma área!')),
      );
      return;
    }

    // Reconstrói o botão, desativando-o e mostrando um spinner.
    setState(() => _aGravar = true);

    // O registo físico continua a requerer ligação ao PostgreSQL através da API.
    // widget permite aceder aos valores recebidos pelo construtor da página.
    final sucesso = await _apiService.register(
      nome: widget.nome,
      email: widget.email,
      password: widget.password,
      aceitarTermos: widget.aceitouTermos,
      // O operador ! é seguro porque o null foi tratado no início da função.
      idArea: _selectedAreaId!,
    );

    // O pedido terminou; volta a ativar o botão.
    setState(() => _aGravar = false);

    // Depois de um await, confirma que o ecrã ainda existe antes de usar context.
    if (!mounted) return;

    if (sucesso) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conta criada! Verifique o seu e-mail para ativar a conta.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Remove todos os ecrãs anteriores da pilha e deixa apenas o Login.
      // Assim, o botão voltar não regressa ao formulário já concluído.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao efetuar registo. Verifique a sua ligação.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // =========================================================================
  // BUILD
  //
  // Constrói o segundo passo do registo.
  // O Consumer reconstrói esta parte quando o Provider altera as áreas
  // ou o estado de carregamento.
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        // Consumer disponibiliza o Provider e escuta notifyListeners().
        child: Consumer<UtilizadorProvider>(
          builder: (context, provider, child) {
            // Pode conter dados vindos da API ou recuperados do SQLite.
            final listaAreas = provider.areas;

            // Enquanto carrega e ainda não existem áreas, mostra o spinner.
            return provider.estaA_Carregar && listaAreas.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF6993BE),
                    ),
                  )
                : Column(
                    children: [
                      // ================= HEADER =================
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 10,
                        ),
                        width: double.infinity,
                        child: Center(
                          child: Image.asset(
                            'lib/img/logo.png',
                            height: 70,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // ================= CONTEÚDO =================
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Área',
                                    style: TextStyle(
                                      color: Color(0xFF6993BE),
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text('Escolha a sua área de atuação'),
                                  const SizedBox(height: 30),

                                  // Dropdown reativo: os items são construídos
                                  // a partir da lista disponibilizada pelo Provider.
                                  DropdownButtonFormField<int>(
                                    isExpanded: true,
                                    initialValue: _selectedAreaId,
                                    decoration: const InputDecoration(
                                      labelText: 'Área',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: listaAreas.map((area) {
                                      // Converte o ID, que pode vir como String
                                      // da API ou como int do SQLite.
                                      final int? idArea = int.tryParse(
                                        area['id_areas']?.toString() ?? '',
                                      );

                                      // Uma área sem ID válido não pode ser selecionada.
                                      if (idArea == null) {
                                        return null;
                                      }

                                      return DropdownMenuItem<int>(
                                        value: idArea,
                                        child: Text(
                                          area['nome_area']?.toString() ??
                                              'Sem nome',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      );
                                    })
                                        // Remove os null criados por IDs inválidos.
                                        .whereType<DropdownMenuItem<int>>()
                                        .toList(),
                                    onChanged: (value) {
                                      // Guarda a seleção e reconstrói o dropdown.
                                      setState(() {
                                        _selectedAreaId = value;
                                      });
                                    },
                                  ),

                                  const SizedBox(height: 30),

                                  ElevatedButton(
                                    // null desativa o botão durante a gravação.
                                    onPressed:
                                        _aGravar ? null : _finalizarRegisto,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF6993BE),
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: _aGravar
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('Concluir registo'),
                                              SizedBox(width: 6),
                                              Icon(Icons.check),
                                            ],
                                          ),
                                  ),

                                  TextButton(
                                    // Durante o pedido também impede voltar.
                                    onPressed: _aGravar
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: const Text('Voltar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
          },
        ),
      ),
    );
  }
}
