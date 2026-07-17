import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login.dart';

class AtivacaoAdminPage extends StatefulWidget {
  const AtivacaoAdminPage({super.key});

  @override
  State<AtivacaoAdminPage> createState() => _AtivacaoAdminPageState();
}

class _AtivacaoAdminPageState extends State<AtivacaoAdminPage> {
  final ApiService _apiService = ApiService();

  final TextEditingController _linkController = TextEditingController();
  final TextEditingController _passwordTemporariaController =
      TextEditingController();
  final TextEditingController _novaPasswordController =
      TextEditingController();
  final TextEditingController _confirmarPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _tokenValidado = false;
  bool _obscureTemp = true;
  bool _obscureNova = true;
  bool _obscureConfirmar = true;

  String _token = "";
  String _erro = "";
  String _mensagem = "";

  Map<String, dynamic>? _utilizador;
  List<Map<String, dynamic>> _areas = [];
  int? _areaSelecionada;

  @override
  void dispose() {
    _linkController.dispose();
    _passwordTemporariaController.dispose();
    _novaPasswordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  String _extrairToken(String valor) {
    final texto = valor.trim();

    if (texto.isEmpty) {
      return "";
    }

    final uri = Uri.tryParse(texto);

    if (uri != null && uri.queryParameters.containsKey("token")) {
      return uri.queryParameters["token"] ?? "";
    }

    return texto;
  }

  bool get _eConsultor {
    final tipo = _utilizador?["tipo_utilizador"]?.toString().toLowerCase() ?? "";
    return tipo.contains("consultor");
  }

  Future<void> _validarToken() async {
    final tokenExtraido = _extrairToken(_linkController.text);

    if (tokenExtraido.isEmpty) {
      setState(() {
        _erro = "Cola o link ou token recebido por email.";
        _mensagem = "";
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _erro = "";
        _mensagem = "";
      });

      final resposta = await _apiService.validarAtivacaoAdmin(tokenExtraido);

      final utilizador = Map<String, dynamic>.from(
        resposta["utilizador"] ?? {},
      );

      final areas = await _apiService.getAreas();

      if (!mounted) return;

      setState(() {
        _token = tokenExtraido;
        _utilizador = utilizador;
        _areas = areas;
        _tokenValidado = true;
        _mensagem = "Conta encontrada. Define agora a nova password.";
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString().replaceFirst("Exception: ", "");
        _tokenValidado = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmarAtivacao() async {
    final passwordTemp = _passwordTemporariaController.text;
    final novaPassword = _novaPasswordController.text;
    final confirmarPassword = _confirmarPasswordController.text;

    if (passwordTemp.isEmpty || novaPassword.isEmpty || confirmarPassword.isEmpty) {
      setState(() {
        _erro = "Preenche a password temporária e a nova password.";
        _mensagem = "";
      });
      return;
    }

    if (novaPassword.length < 6) {
      setState(() {
        _erro = "A nova password deve ter pelo menos 6 caracteres.";
        _mensagem = "";
      });
      return;
    }

    if (novaPassword != confirmarPassword) {
      setState(() {
        _erro = "As novas passwords não coincidem.";
        _mensagem = "";
      });
      return;
    }

    if (passwordTemp == novaPassword) {
      setState(() {
        _erro = "A nova password tem de ser diferente da password temporária.";
        _mensagem = "";
      });
      return;
    }

    if (_eConsultor && _areaSelecionada == null) {
      setState(() {
        _erro = "Seleciona a área do consultor.";
        _mensagem = "";
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _erro = "";
        _mensagem = "";
      });

      await _apiService.confirmarAtivacaoAdmin(
        tokenAtivacao: _token,
        passwordTemporaria: passwordTemp,
        novaPassword: novaPassword,
        idArea: _eConsultor ? _areaSelecionada : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Conta ativada com sucesso. Já pode iniciar sessão."),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _erro = e.toString().replaceFirst("Exception: ", "");
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _campoPassword({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azulSoftinsa = Color(0xFF4470AF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              width: double.infinity,
              child: Center(
                child: Image.asset(
                  'lib/img/logo.png',
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Ativar Conta",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: azulSoftinsa,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        "Conta criada pelo administrador",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 24),

                      if (!_tokenValidado) ...[
                        TextField(
                          controller: _linkController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: "Link ou token recebido por email",
                            prefixIcon: Icon(Icons.link),
                            filled: true,
                            fillColor: Color(0xFFF7F7F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _validarToken,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulSoftinsa,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Validar conta",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _utilizador?["nome_completo"]?.toString() ??
                                    "Utilizador",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _utilizador?["email"]?.toString() ?? "",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _utilizador?["tipo_utilizador"]?.toString() ?? "",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: azulSoftinsa,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        _campoPassword(
                          controller: _passwordTemporariaController,
                          label: "Password temporária",
                          obscure: _obscureTemp,
                          onToggle: () {
                            setState(() => _obscureTemp = !_obscureTemp);
                          },
                        ),

                        const SizedBox(height: 14),

                        _campoPassword(
                          controller: _novaPasswordController,
                          label: "Nova password",
                          obscure: _obscureNova,
                          onToggle: () {
                            setState(() => _obscureNova = !_obscureNova);
                          },
                        ),

                        const SizedBox(height: 14),

                        _campoPassword(
                          controller: _confirmarPasswordController,
                          label: "Confirmar nova password",
                          obscure: _obscureConfirmar,
                          onToggle: () {
                            setState(() => _obscureConfirmar = !_obscureConfirmar);
                          },
                        ),

                        if (_eConsultor) ...[
                          const SizedBox(height: 18),

                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: _areaSelecionada,
                            decoration: const InputDecoration(
                              labelText: "Área do consultor",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            items: _areas
                                .map((area) {
                                  final idArea = int.tryParse(
                                    area["id_areas"]?.toString() ?? "",
                                  );

                                  if (idArea == null) return null;

                                  return DropdownMenuItem<int>(
                                    value: idArea,
                                    child: Text(
                                      area["nome_area"]?.toString() ?? "Área",
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .whereType<DropdownMenuItem<int>>()
                                .toList(),
                            onChanged: (value) {
                              setState(() => _areaSelecionada = value);
                            },
                          ),
                        ],

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: _isLoading ? null : _confirmarAtivacao,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azulSoftinsa,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Ativar conta",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],

                      if (_erro.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _erro,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      if (_mensagem.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          _mensagem,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LoginPage(),
                                  ),
                                  (_) => false,
                                );
                              },
                        child: const Text(
                          "Voltar ao login",
                          style: TextStyle(
                            color: azulSoftinsa,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}