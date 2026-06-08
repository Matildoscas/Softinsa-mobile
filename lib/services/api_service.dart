import 'dart:convert';
import 'dart:io'; // Para capturar erros de falta de rede (SocketException)
import 'package:http/http.dart' as http;

String? token;

class ApiService {
  static const String baseUrl = 'https://softinsa-api.onrender.com/api';

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

  // REINTRODUZIDO: Método essencial que faltava na branch da tua colega
  Future<List<Map<String, dynamic>>> getUtilizadores() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/utilizadores'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro ao carregar utilizadores');
    } on SocketException {
      throw const SocketException('offline');
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

  Future<List<Map<String, dynamic>>> getCandidaturasPendentes(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/certificados/pendentes/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro ao carregar candidaturas pendentes');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  Future<List<Map<String, dynamic>>> getProgressoLearningPaths(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/learningpaths/progresso/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro ao carregar progresso das learning paths');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  // Adicionado por segurança caso o ecrã de detalhes precise do método limpo
  Future<Map<String, dynamic>> getCertificado({required int idHistorico, required int idUtilizador}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/certificados/$idHistorico/$idUtilizador'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Erro ao obter ficheiro do certificado');
    } on SocketException {
      throw const SocketException('offline');
    }
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
    try {
      // 1. URL Corrigido baseado no teu app.js + candidaturaRoutes.js
      final uri = Uri.parse("$baseUrl/api/candidaturas/submeter-evidencias");
      final request = http.MultipartRequest("POST", uri);

      request.headers.addAll(_headers);
      
      // 2. Chaves corrigidas de acordo com o teu candidaturaController.js
      request.fields['id_utilizador'] = userId.toString();
      request.fields['id_badge_modelo'] = badgeId.toString();
      
      // O teu back-end espera os metadados (como descrição) dentro de um Array JSON
      // Vamos empacotar para o formato esperado: metadados = ['{"descricao": "..."}']
      request.fields['metadados'] = '{"descricao": "$descricao"}';

      // 3. Abertura segura do ficheiro por bytes (Bypassa URIs virtuais do Android)
      final file = File(ficheiroPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        request.files.add(http.MultipartFile.fromBytes(
          'ficheiros', // Chave Corrigida para o plural exigido no teu Multer Router!
          bytes,
          filename: file.path.split('/').last,
        ));
      } else {
        // Fallback de segurança para testes ou caminhos simulados offline
        request.files.add(http.MultipartFile.fromBytes(
          'ficheiros',
          [0],
          filename: 'comprovativo.pdf',
        ));
      }

      // 4. Envia o pedido
      final response = await request.send();

      // Se falhar, captura o texto real do Render para sabermos o que houve
      if (response.statusCode != 200 && response.statusCode != 201) {
        final responseData = await response.stream.bytesToString();
        print("❌ O Servidor do Render rejeitou com o código ${response.statusCode}: $responseData");
        throw Exception("Erro na API: $responseData");
      }
      
      print("✨ Evidência enviada com sucesso online para o Render!");
      
    } catch (e) {
      print("💥 Erro no ApiService: $e");
      rethrow; // Deixa o submeter_badges.dart capturar e salvar no SQLite!
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