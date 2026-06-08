import 'dart:convert';
import 'package:http/http.dart' as http;

String? token;

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000/api';

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================================
  // METODOS PURAMENTE ONLINE (HTTP APENAS)
  // =========================================================================

  Future<List<Map<String, dynamic>>> getUtilizadores() async {
    final response = await http.get(Uri.parse('$baseUrl/utilizadores'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar utilizadores');
  }

  Future<List<Map<String, dynamic>>> getAreas() async {
    final response = await http.get(Uri.parse('$baseUrl/areas'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar áreas');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        token = data['token'];
        return {
          'success': true,
          ...data,
        };
      }

      return {
        'success': false,
        'message': data['error'] ?? 'Erro no login',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Sem ligação ao servidor para efetuar login.',
      };
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
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getDashboard(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/dashboard/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erro ao carregar dashboard');
  }

  Future<List<Map<String, dynamic>>> getBadgesProgresso(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/progresso/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar badges de progresso');
  }

  Future<List<Map<String, dynamic>>> getBadgesRecomendados(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/recomendados/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar badges recomendados');
  }

  Future<Map<String, dynamic>?> getBadgeEspecial() async {
    final response = await http.get(Uri.parse('$baseUrl/badges/especial'), headers: _headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      return data as Map<String, dynamic>;
    }
    throw Exception('Erro ao carregar badge especial');
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/notificacoes/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro notificações');
  }

  Future<List<Map<String, dynamic>>> getTodosBadges() async {
    final response = await http.get(Uri.parse('$baseUrl/badges/todos'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro ao carregar catálogo de badges');
  }

  Future<List<Map<String, dynamic>>> getBadgesConquistados(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/conquistados/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro badges conquistados');
  }

  List<Map<String, dynamic>> agruparBadgesComRequisitos(List<Map<String, dynamic>> dadosPlanos) {
    final Map<int, Map<String, dynamic>> badgesAgrupados = {};

    for (var linha in dadosPlanos) {
      final int badgeId = linha['id'] ?? 0;
      if (badgeId == 0) continue;

      if (!badgesAgrupados.containsKey(badgeId)) {
        badgesAgrupados[badgeId] = {
          'id': linha['id'],
          'nome': linha['nome'],
          'descricao': linha['descricao'],
          'pontos': linha['pontos'],
          'id_nivel': linha['id_nivel'],
          'data_atribuicao': AppDateFormatter.parseAndFormat(linha['data_atribuicao']),
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

  Future<List<dynamic>> getProgressoLearningPaths(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/learningpaths/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Erro ao carregar progresso');
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

  Future<List<Map<String, dynamic>>> getCertificadosDisponiveis(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/certificados/disponiveis/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar certificados disponíveis');
  }

  Future<Map<String, dynamic>> getCertificado({
    required int idHistorico,
    required int idUtilizador,
  }) async {
    final response = await http.get(Uri.parse('$baseUrl/certificados/$idHistorico/$idUtilizador'), headers: _headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Erro ao carregar certificado');
  }

  Future<List<Map<String, dynamic>>> getCandidaturasPendentes(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/certificados/pendentes/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }
    throw Exception('Erro ao carregar candidaturas pendentes');
  }

  Future<void> atualizarFcmToken({
    required int idUtilizador,
    required String fcmToken,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/utilizadores/fcm-token'),
      headers: _headers,
      body: jsonEncode({'id_utilizador': idUtilizador, 'fcm_token': fcmToken}),
    );
    if (response.statusCode != 200) {
      throw Exception('Erro ao guardar FCM token');
    }
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
      throw Exception('Erro ao alterar password');
    }
  }

  Future<void> desativarConta(int idUtilizador) async {
    final response = await http.put(Uri.parse('$baseUrl/utilizadores/$idUtilizador/desativar'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Erro ao desativar conta');
    }
  }
}

// Helper interno simples para formatar datas sem pacotes pesados
class AppDateFormatter {
  static String? parseAndFormat(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return null;
    try {
      final dt = DateTime.parse(raw.toString());
      return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
    } catch (_) {
      return raw.toString();
    }
  }
}