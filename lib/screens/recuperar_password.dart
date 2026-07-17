import 'package:flutter/material.dart';

import '../services/api_service.dart';

class RecuperarPasswordPage extends StatefulWidget {
  const RecuperarPasswordPage({super.key});

  @override
  State<RecuperarPasswordPage> createState() => _RecuperarPasswordPageState();
}

class _RecuperarPasswordPageState extends State<RecuperarPasswordPage> {
  static const Color azulFocado = Color(0xFF4470AF);

  final ApiService _apiService = ApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _novaPasswordController = TextEditingController();
  final TextEditingController _confirmarPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _codigoEnviado = false;
  bool _codigoValidado = false;
  bool _obscureNova = true;
  bool _obscureConfirmar = true;

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _novaPasswordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pedirCodigo() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduz um email válido.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final resposta = await _apiService.pedirCodigoRecuperacaoPassword(email);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      if (resposta['success'] == true) {
        _codigoEnviado = true;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resposta['message']?.toString() ?? 'Operação concluída.')),
    );
  }

  Future<void> _validarCodigo() async {
    final email = _emailController.text.trim().toLowerCase();
    final codigo = _codigoController.text.trim();

    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Introduz o código recebido por email.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final resposta = await _apiService.validarCodigoRecuperacaoPassword(
      email: email,
      codigo: codigo,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _codigoValidado = resposta['success'] == true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resposta['message']?.toString() ?? 'Operação concluída.')),
    );
  }

  Future<void> _redefinirPassword() async {
    final email = _emailController.text.trim().toLowerCase();
    final codigo = _codigoController.text.trim();
    final novaPassword = _novaPasswordController.text;
    final confirmar = _confirmarPasswordController.text;

    if (novaPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A nova password deve ter pelo menos 6 caracteres.')),
      );
      return;
    }

    if (novaPassword != confirmar) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A confirmação da password não coincide.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final resposta = await _apiService.redefinirPasswordComCodigo(
      email: email,
      codigo: codigo,
      novaPassword: novaPassword,
    );
    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(resposta['message']?.toString() ?? 'Operação concluída.')),
    );

    if (resposta['success'] == true) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Recuperar Password'),
      ),
      body: SafeArea(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esqueci-me da password',
                  style: TextStyle(
                    color: azulFocado,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pede um código por email, valida-o e define a nova password.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_codigoValidado,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Color(0xFFF7F7F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading || _codigoValidado ? null : _pedirCodigo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: azulFocado,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enviar código'),
                  ),
                ),
                if (_codigoEnviado) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _codigoController,
                    enabled: !_codigoValidado,
                    decoration: const InputDecoration(
                      labelText: 'Código recebido por email',
                      prefixIcon: Icon(Icons.pin_outlined),
                      filled: true,
                      fillColor: Color(0xFFF7F7F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading || _codigoValidado ? null : _validarCodigo,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: azulFocado),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Validar código'),
                    ),
                  ),
                ],
                if (_codigoValidado) ...[
                  const SizedBox(height: 18),
                  TextField(
                    controller: _novaPasswordController,
                    obscureText: _obscureNova,
                    decoration: InputDecoration(
                      labelText: 'Nova password',
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNova ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureNova = !_obscureNova);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmarPasswordController,
                    obscureText: _obscureConfirmar,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nova password',
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmar
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirmar = !_obscureConfirmar);
                        },
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF7F7F7),
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _redefinirPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: azulFocado,
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
                              'Redefinir password',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
