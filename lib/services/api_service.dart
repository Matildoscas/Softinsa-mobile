import 'dart:convert';
import 'dart:io'; // Para capturar erros de falta de rede (SocketException)
import 'package:http/http.dart' as http;

String? token;

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000/api';

  // Getter centralizado de cabeçalhos com Token JWT
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================================
  // AUTENTICAÇÃO E UTILIZADORES
  // =========================================================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        token = data['token'];
        return {'success': true, ...data};
      }

      if (response.statusCode == 403) {
        return {'success': false, 'emailNaoVerificado': true, 'message': data['error']};
      }

      return {'success': false, 'message': data['error'] ?? 'Erro login'};
    } catch (_) {
      // Se não houver internet no ecrã de Login, avisa a UI de forma amigável
      return {'success': false, 'message': 'Sem ligação ao servidor local.'};
    }
  }

  Future<bool> register({
    required String nome,
    required String email,
    required String password,
    required bool aceitarTermos,
    required int idArea,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'email': email,
          'password': password,
          'aceitar_termos': aceitarTermos,
          'id_area': idArea,
        }),
      );
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/areas'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro ao carregar áreas');
    } on SocketException {
      throw const SocketException('Sem internet');
    }
  }

  // =========================================================================
  // FLUXO PRINCIPAL (PREPARADO PARA CACHE NO PROVIDER)
  // =========================================================================

  Future<Map<String, dynamic>> getDashboard(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/dashboard/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Erro status ${response.statusCode}');
    } on SocketException {
      throw const SocketException('offline'); // O Provider vai apanhar isto!
    }
  }

  Future<List<Map<String, dynamic>>> getBadgesProgresso(int userId) async {
    try {
      // CORREÇÃO: Adicionado os headers que faltavam no código dela
      final response = await http.get(Uri.parse('$baseUrl/badges/progresso/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro badges progresso');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  Future<List<Map<String, dynamic>>> getBadgesRecomendados(int userId) async {
    try {
      // CORREÇÃO: Adicionado os headers que faltavam no código dela
      final response = await http.get(Uri.parse('$baseUrl/badges/recomendados/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro badges recomendados');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  Future<Map<String, dynamic>?> getBadgeEspecial() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/badges/especial'), headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        return data as Map<String, dynamic>;
      }
      throw Exception('Erro badge especial');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  // =========================================================================
  // NOTIFICAÇÕES E MÉTODOS COMPLEMENTARES
  // =========================================================================

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/notificacoes/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro notificações');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  Future<List<Map<String, dynamic>>> getTodosBadges() async {
    final response = await http.get(Uri.parse('$baseUrl/badges/todos'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro catálogo');
  }

  Future<List<Map<String, dynamic>>> getBadgesConquistados(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/conquistados/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro conquistados');
  }

  List<Map<String, dynamic>> agruparBadgesComRequisitos(List<Map<String, dynamic>> dadosPlanos) {
    final Map<int, Map<String, dynamic>> badgesAgrupados = {};

    for (var linha in dadosPlanos) {
      final int? badgeId = int.tryParse(linha['id']?.toString() ?? '');
      if (badgeId == null) continue;

      if (!badgesAgrupados.containsKey(badgeId)) {
        badgesAgrupados[badgeId] = {
          'id': linha['id'],
          'nome': linha['nome'],
          'descricao': linha['descricao'],
          'pontos': linha['pontos'],
          'id_nivel': linha['id_nivel'],
          'data_atribuicao': linha['data_atribuicao'],
          'data_validade': linha['data_validade'],
          'estado_badge_atribuido': linha['estado_badge_atribuido'],
          'requisitos': <Map<String, dynamic>>[],
        };
      }

      if (linha['nome_requisito'] != null) {
        final listaRequisitos = badgesAgrupados[badgeId]?['requisitos'] as List<Map<String, dynamic>>;
        listaRequisitos.add({
          'nome': linha['nome_requisito'],
          'titulo': linha['titulo'],
          'descricao': linha['descricao_requisito'],
        });
      }
    }
    return badgesAgrupados.values.toList();
  }

  Future<void> submeterEvidencia({
    required int userId,
    required int badgeId,
    required String descricao,
    required String ficheiroPath,
  }) async {
    final uri = Uri.parse("$baseUrl/evidencias/submeter");
    final request = http.MultipartRequest("POST", uri);

    request.headers.addAll(_headers);
    request.fields['user_id'] = userId.toString();
    request.fields['badge_id'] = badgeId.toString();
    request.fields['descricao'] = descricao;

    request.files.add(await http.MultipartFile.fromPath('ficheiro', ficheiroPath));
    final response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Erro ao submeter evidência");
    }
  }

  // =========================================================================
  // GESTÃO DE PERFIL E SEGURANÇA
  // =========================================================================

  Future<void> atualizarFcmToken({required int idUtilizador, required String fcmToken}) async {
    await http.put(
      Uri.parse('$baseUrl/utilizadores/fcm-token'),
      headers: _headers,
      body: jsonEncode({'id_utilizador': idUtilizador, 'fcm_token': fcmToken}),
    );
  }

  Future<Map<String, dynamic>> atualizarPerfilUtilizador({
    required int idUtilizador,
    required String nomeCompleto,
    required String contacto,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/utilizadores/$idUtilizador/perfil'),
      headers: _headers,
      body: jsonEncode({'nome_completo': nomeCompleto, 'contacto': contacto}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['utilizador'];
    }
    throw Exception('Erro ao atualizar perfil');
  }

  Future<void> alterarPassword({
    required int idUtilizador,
    required String passwordAtual,
    required String novaPassword,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/utilizadores/$idUtilizador/password'),
      headers: _headers,
      body: jsonEncode({'password_atual': passwordAtual, 'nova_password': novaPassword}),
    );

    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception(data['error'] ?? 'Erro ao alterar password');
    }
  }

  Future<void> desativarConta(int idUtilizador) async {
    final response = await http.put(Uri.parse('$baseUrl/utilizadores/$idUtilizador/desativar'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Erro ao desativar conta');
    }
  }
}