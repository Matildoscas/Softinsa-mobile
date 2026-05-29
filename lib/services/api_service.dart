import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000/api';

  // GET utilizadores
  Future<List<dynamic>> getUtilizadores() async {
    final response = await http.get(Uri.parse('$baseUrl/utilizadores'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Erro ao carregar utilizadores');
    }
  }

  // POST utilizador
  Future<void> criarUtilizador(Map<String, dynamic> user) async {
    final response = await http.post(
      Uri.parse('$baseUrl/utilizadores'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(user),
    );

    if (response.statusCode != 201) {
      throw Exception('Erro ao criar utilizador');
    }
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        'success': true,
        ...data,
      };
    }

    return {
      'success': false,
      'message': data['error'] ?? 'Erro login',
    };
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

  // NOTIFICAÇÕES
  Future<List<Map<String, dynamic>>> getNotificacoes(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificacoes/$userId'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro ao carregar notificações');
  }

  Future<List<Map<String, dynamic>>> getAreas() async {
    print("URL:");
    print('$baseUrl/areas');

    final response = await http.get(Uri.parse('$baseUrl/areas'));

    print("STATUS:");
    print(response.statusCode);

    print("BODY:");
    print(response.body);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Erro ao carregar áreas');
    }
  }

  // DASHBOARD
  Future<Map<String, dynamic>> getDashboard(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/dashboard/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Erro dashboard');
  }

  // BADGES PROGRESSO
  Future<List<Map<String, dynamic>>> getBadgesProgresso(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/conquistados/$userId'),
    );

    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro badges progresso');
  }

  // BADGES RECOMENDADOS
  Future<List<Map<String, dynamic>>> getBadgesRecomendados(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/recomendados/$userId'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro badges');
  }

  // BADGE ESPECIAL
  Future<Map<String, dynamic>?> getBadgeEspecial() async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/especial'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data == null) return null;
      return data as Map<String, dynamic>;
    }

    throw Exception('Erro badge especial');
  }

  // CATÁLOGO — TODOS OS BADGES
  Future<List<Map<String, dynamic>>> getTodosBadges() async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges'),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print(data.runtimeType);

      final List lista = data;
      return lista.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro ao carregar catálogo de badges');
  }

  // CATÁLOGO — BADGES OBTIDOS PELO UTILIZADOR
  Future<List<Map<String, dynamic>>> getBadgesObtidos(int userId) async {
  final response = await http.get(
    Uri.parse('$baseUrl/badges/conquistados/$userId'),
  );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro ao carregar badges obtidos');
  }

  Future<Map<String, dynamic>> getBadgeById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/$id'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Erro ao carregar badge');
  }
}