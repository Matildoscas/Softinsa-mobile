import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000';
  

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

    // LOGIN OK
    if (response.statusCode == 200) {

      return {
        'success': true,
        ...data,
      };
    }

    // EMAIL NÃO VERIFICADO
    if (response.statusCode == 403) {

      return {
        'success': false,
        'emailNaoVerificado': true,
        'message': data['error'],
      };
    }

    // OUTROS ERROS
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

      print("Resposta do Servidor: ${response.statusCode}");
      print("Corpo da Resposta: ${response.body}");

      // O status 201 é o que o seu auth.js envia quando corre bem
      return response.statusCode == 201;
      
    } catch (e) {
      print("ERRO NA API (REGISTER): $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAreas() async {
    final response = await http.get(Uri.parse('$baseUrl/areas'));

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
      Uri.parse('$baseUrl/badges/progresso/$userId'),
    );

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
}