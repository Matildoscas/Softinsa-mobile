import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/basededados.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.1.76:3000';
  final Basededados _dbLocal = Basededados();

  // =========================================================================
  // METODOS REATIVOS: GET COM ATUALIZAÇÃO DA BASE DE DADOS LOCAL (MIRRORING)
  // =========================================================================

  // GET utilizadores (Faz o sync do PostgreSQL para o SQFlite local)
  Future<List<Map<String, dynamic>>> getUtilizadores() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/utilizadores'));

      if (response.statusCode == 200) {
        final List<dynamic> dadosServidor = json.decode(response.body);
        
        // Espelha os dados para a tabela SQLite local
        for (var user in dadosServidor) {
          await _dbLocal.salvarRegisto('utilizador', user);
        }
      }
    } catch (e) {
      print("Modo Offline Ativo para Utilizadores: $e");
    }
    
    // Fonte Única de Verdade: Devolve SEMPRE o que está na BD local
    return await _dbLocal.listarTabela('utilizador');
  }

  // GET áreas (Faz o sync para o SQFlite local)
  Future<List<Map<String, dynamic>>> getAreas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/areas'));

      if (response.statusCode == 200) {
        final List<dynamic> dadosServidor = jsonDecode(response.body);
        
        for (var area in dadosServidor) {
          await _dbLocal.salvarRegisto('areas', area);
        }
      }
    } catch (e) {
      print("Modo Offline Ativo para Áreas: $e");
    }

    return await _dbLocal.listarTabela('areas');
  }

  // =========================================================================
  // AUTENTICAÇÃO (Sincroniza o perfil local após o sucesso na API)
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
        // Se o login correu bem, salvaguardamos os dados do utilizador na BD local
        if (data['user'] != null) {
          await _dbLocal.salvarRegisto('utilizador', data['user']);
        }
        
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
    } catch (e) {
      print("Erro de rede no Login: $e");
      // Tentativa de autenticação local básica se estiver totalmente offline (Opcional para a UC)
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
      print("ERRO NA API (REGISTER): $e");
      return false;
    }
  }

  // =========================================================================
  // DASHBOARD E BADGES (Mapeamento direto para tabelas locais correspondentes)
  // =========================================================================

  Future<Map<String, dynamic>> getDashboard(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/dashboard/$userId'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> dashboardData = jsonDecode(response.body);
        
        // Se a API enviar os dados do consultor, atualiza a tabela local
        if (dashboardData['consultor'] != null) {
          await _dbLocal.salvarRegisto('consultor', dashboardData['consultor']);
        }
        return dashboardData;
      }
    } catch (e) {
      print("Modo Offline Ativo para Dashboard: $e");
    }

    // Fallback: Recupera o perfil do consultor localmente se falhar a rede
    final List<Map<String, dynamic>> consultores = await _dbLocal.listarTabela('consultor');
    final consultorLocal = consultores.firstWhere(
      (c) => c['id_utilizador'] == userId, 
      orElse: () => {},
    );
    return {'consultor': consultorLocal, 'offline': true};
  }

  Future<List<Map<String, dynamic>>> getBadgesProgresso(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/badges/progresso/$userId'));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final List<Map<String, dynamic>> listaBadges = data.map((e) => e as Map<String, dynamic>).toList();

        for (var badge in listaBadges) {
          await _dbLocal.salvarRegisto('badge_atribuido', badge);
        }
      }
    } catch (e) {
      print("Modo Offline Ativo para Badges de Progresso: $e");
    }

    return await _dbLocal.listarTabela('badge_atribuido');
  }

  Future<List<Map<String, dynamic>>> getBadgesRecomendados(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/badges/recomendados/$userId'));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final List<Map<String, dynamic>> listaBadges = data.map((e) => e as Map<String, dynamic>).toList();

        for (var badge in listaBadges) {
          await _dbLocal.salvarRegisto('badge_modelo', badge);
        }
      }
    } catch (e) {
      print("Modo Offline Ativo para Badges Recomendados: $e");
    }

    return await _dbLocal.listarTabela('badge_modelo');
  }

  Future<Map<String, dynamic>?> getBadgeEspecial() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/badges/especial'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;

        final Map<String, dynamic> badgeEspecial = data as Map<String, dynamic>;
        await _dbLocal.salvarRegisto('badge_modelo', badgeEspecial);
        return badgeEspecial;
      }
    } catch (e) {
      print("Modo Offline Ativo para Badge Especial: $e");
    }

    // Retorna o último badge modelo guardado localmente como fallback
    final badges = await _dbLocal.listarTabela('badge_modelo');
    return badges.isNotEmpty ? badges.first : null;
  }
}