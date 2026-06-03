import 'dart:convert';
import 'package:http/http.dart' as http;

String? token;

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000/api';
  // Android Emulator → localhost = 10.0.2.2
  

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

  Future<Map<String, dynamic>> login(String email, String password) async {
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
      token = data['token']; // 🔥 IMPORTANTE

      return {
        'success': true,
        ...data,
      };
    }

    if (response.statusCode == 403) {
      return {
        'success': false,
        'emailNaoVerificado': true,
        'message': data['error'],
      };
    }

    return {
      'success': false,
      'message': data['error'] ?? 'Erro login',
    };
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
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
      headers: _headers,
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

  //NOTIFICACOES
  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notificacoes/$userId'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro notificações');
  }


  //badges
  Future<List<Map<String, dynamic>>> getTodosBadges() async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/todos'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      
      // 🔥 AQUI ESTÁ O TRUQUE: Agrupar antes de devolver ao ecrã!
      return agruparBadgesComRequisitos(listaPlana);
    }

    throw Exception('Erro ao carregar catálogo de badges');
  }

  Future<List<Map<String, dynamic>>> getBadgesConquistados(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/badges/conquistados/$userId'),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      
      // 🔥 Agrupar também os conquistados para que os requisitos fiquem estruturados
      return agruparBadgesComRequisitos(listaPlana);
    }

    throw Exception('Erro badges conquistados');
  }

  List<Map<String, dynamic>> agruparBadgesComRequisitos(List<Map<String, dynamic>> dadosPlanos) {
  final Map<int, Map<String, dynamic>> badgesAgrupados = {};

  for (var linha in dadosPlanos) {
      final int badgeId = linha['id'];

      // Se o badge ainda não foi adicionado ao mapa, adiciona com as tipagens corretas
      if (!badgesAgrupados.containsKey(badgeId)) {
        badgesAgrupados[badgeId] = {
          'id': linha['id'],
          'nome': linha['nome'],
          'descricao': linha['descricao'],
          'pontos': linha['pontos'],
          'id_nivel': linha['id_nivel'],
          'data_atribuicao': linha['data_atribuicao'], 
          'requisitos': <Map<String, dynamic>>[], // 👈 Força a lista a ser especificamente de Maps
        };
      }

      // Se houver dados de requisito nessa linha da BD
      if (linha['nome_requisito'] != null) {
        // 👈 Fazemos o cast explícito para List para o Dart permitir o uso do .add()
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
    final response = await http.get(
      Uri.parse('$baseUrl/badges/learningpaths/$userId'),
    );

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

    request.fields['user_id'] = userId.toString();
    request.fields['badge_id'] = badgeId.toString();
    request.fields['descricao'] = descricao;

    request.files.add(
      await http.MultipartFile.fromPath(
        'ficheiro',
        ficheiroPath,
      ),
    );

    final response = await request.send();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Erro ao submeter evidência");
    }
  }

  // CERTIFICADOS DISPONÍVEIS
  Future<List<Map<String, dynamic>>> getCertificadosDisponiveis(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/certificados/disponiveis/$userId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception('Erro ao carregar certificados disponíveis');
  }

  // CERTIFICADO INDIVIDUAL
  Future<Map<String, dynamic>> getCertificado({
    required int idHistorico,
    required int idUtilizador,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/certificados/$idHistorico/$idUtilizador'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 404) {
      throw Exception('Certificado não encontrado ou ainda não aprovado');
    }

    throw Exception('Erro ao carregar certificado');
  }

  Future<List<Map<String, dynamic>>> getCandidaturasPendentes(int userId) async {
    final url = '$baseUrl/certificados/pendentes/$userId';

    final response = await http.get(
      Uri.parse(url),
      headers: _headers,
    );

    print("🔴 CANDIDATURAS PENDENTES URL: $url");
    print("🔴 STATUS: ${response.statusCode}");
    print("🔴 BODY: ${response.body}");

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => e as Map<String, dynamic>).toList();
    }

    throw Exception(
      'Erro ao carregar candidaturas pendentes: ${response.statusCode} - ${response.body}',
    );
  }

  Future<void> atualizarFcmToken({
    required int idUtilizador,
    required String fcmToken,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/utilizadores/fcm-token'),
      headers: _headers,
      body: jsonEncode({
        'id_utilizador': idUtilizador,
        'fcm_token': fcmToken,
      }),
    );

    print("FCM TOKEN STATUS: ${response.statusCode}");
    print("FCM TOKEN BODY: ${response.body}");

    if (response.statusCode != 200) {
      throw Exception('Erro ao guardar FCM token');
    }
  }
}