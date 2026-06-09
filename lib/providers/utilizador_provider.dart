import 'dart:io';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../database/basededados.dart'; // Import da tua classe SQFlite

class UtilizadorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final Basededados _dbLocal = Basededados(); // Instância do teu motor SQFlite

  // Estados locais em memória para a UI consumir
  List<Map<String, dynamic>> _utilizadores = [];
  List<Map<String, dynamic>> _areas = [];
  Map<String, dynamic> _dashboard = {};
  List<Map<String, dynamic>> _badgesProgresso = [];
  
  bool _estaA_Carregar = false;

  // Getters para os ecrãs lerem os dados
  List<Map<String, dynamic>> get utilizadores => _utilizadores;
  List<Map<String, dynamic>> get areas => _areas;
  Map<String, dynamic> get dashboard => _dashboard;
  List<Map<String, dynamic>> get badgesProgresso => _badgesProgresso;
  bool get estaA_Carregar => _estaA_Carregar;

  // Sincroniza e carrega os dados globais da aplicação (Foco Offline-First)
  Future<void> inicializarDados(int userId) async {
    _estaA_Carregar = true;
    notifyListeners(); // Mostra o loading inicial na UI

    // ── 1. FLUXO DAS ÁREAS (CORRIGIDO) ──────────────────────────────────
    try {
      final dadosAreasRaw = await _apiService.getAreas();
      _areas = List<Map<String, dynamic>>.from(dadosAreasRaw);
      
      // Se correu bem, espelha para o SQFlite local normalizando os IDs
      for (var area in _areas) {
        final Map<String, dynamic> areaNormalizada = {
          'id_areas': int.tryParse((area['id_areas'] ?? area['id'] ?? '0').toString()) ?? 0,
          'id_serviceline': area['id_serviceline'] != null ? int.tryParse(area['id_serviceline'].toString()) : null,
          'nome_area': area['nome_area'] ?? area['nome'] ?? 'Área Sem Nome',
          'descricao_area': area['descricao_area'] ?? area['descricao'] ?? '',
          'data_criacao': area['data_criacao']?.toString(),
          'numero_consultores': int.tryParse((area['numero_consultores'] ?? '0').toString()) ?? 0,
        };

        await _dbLocal.salvarRegisto('areas', areaNormalizada);
      }
    } catch (_) {
      // Falhou a rede? Carrega a cache local de imediato
      _areas = await _dbLocal.listarTabela('areas');
    }
    notifyListeners();

    // ── 2. FLUXO DO DASHBOARD (Mapeado com base no basededados.dart) ──
    try {
      _dashboard = await _apiService.getDashboard(userId);
      
      // Ajustado com base nas colunas da tabela 'consultor' do teu SQLite
      await _dbLocal.salvarRegisto('consultor', {
        'id_utilizador': userId,
        'id_areas': _dashboard['id_areas'],
        'pontos_atuais': int.tryParse((_dashboard['total_pontos'] ?? _dashboard['pontos_atuais'] ?? '0').toString()) ?? 0,
        'badges_conquistas_total': int.tryParse((_dashboard['total_badges'] ?? _dashboard['badges_conquistas_total'] ?? '0').toString()) ?? 0,
        'progresso_nivel': _dashboard['ranking'] ?? _dashboard['progresso_nivel'] ?? 'N/A',
        'ultima_atualizacao_perfil': DateTime.now().toString(),
      });
    } catch (_) {
      // Se falhar, monta o mapa de fallback baseado na tabela local do SQFlite
      final dadosLocais = await _dbLocal.listarTabela('consultor');
      if (dadosLocais.isNotEmpty) {
        final meuConsultor = dadosLocais.firstWhere(
          (c) => c['id_utilizador'].toString() == userId.toString(),
          orElse: () => dadosLocais.first,
        );
        _dashboard = {
          'total_pontos': meuConsultor['pontos_atuais'] ?? 0,
          'total_badges': meuConsultor['badges_conquistas_total'] ?? 0,
          'ranking': meuConsultor['progresso_nivel'] ?? 'N/A',
          'id_areas': meuConsultor['id_areas'],
          'offline': true
        };
      }
    }
    notifyListeners();

    // ── 3. FLUXO DOS BADGES DE PROGRESSO (Tabela 'badge_atribuido') ──
    try {
      _badgesProgresso = await _apiService.getBadgesProgresso(userId);
      for (var badge in _badgesProgresso) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': int.tryParse((badge['id_badge_atribuido'] ?? badge['id'] ?? '0').toString()) ?? 0,
          'id_badge_modelo': int.tryParse((badge['id_badge_modelo'] ?? badge['id_modelo'] ?? '0').toString()) ?? 0,
          'data_atribuicao': badge['data_atribuicao']?.toString(),
          'data_validade': badge['data_validade']?.toString(),
          'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? 'Em Progresso',
        });
      }
    } catch (_) {
      final dadosLocais = await _dbLocal.listarTabela('badge_atribuido');
      _badgesProgresso = List<Map<String, dynamic>>.from(dadosLocais);
    }

    // ── 4. LISTA GERAL DE UTILIZADORES ──────────────────────────────
    try {
      final dadosRaw = await _apiService.getUtilizadores();
      _utilizadores = List<Map<String, dynamic>>.from(dadosRaw);
      for (var user in _utilizadores) {
        // Mapeamento defensivo para bater 100% certo com as colunas do SQLite
        final Map<String, dynamic> userLocal = {
          'id_utilizador': int.tryParse((user['id_utilizador'] ?? user['id'] ?? '0').toString()) ?? 0,
          'nome_completo': user['nome_completo'] ?? user['nome'] ?? '',
          'email': user['email'] ?? '',
          'contacto': user['contacto'] ?? '',
          'estado_conta': user['estado_conta'] ?? 'Ativo',
          'password': user['password'] ?? '',
          'aceitou_termos': (user['aceitou_termos'] == true || user['aceitou_termos'] == 1 || user['aceitar_termos'] == 1) ? 1 : 0,
        };
        await _dbLocal.salvarRegisto('utilizador', userLocal);
      }
    } catch (_) {
      _utilizadores = await _dbLocal.listarTabela('utilizador');
    }

    _estaA_Carregar = false;
    notifyListeners(); // Desliga o loading global
  }

  // Método auxiliar para Swipe-to-Refresh (Tenta forçar rede, senão mantém a cache)
  Future<void> atualizarDashboard(int userId) async {
    try {
      final d = await _apiService.getDashboard(userId);
      final p = await _apiService.getBadgesProgresso(userId);
      
      _dashboard = d;
      _badgesProgresso = p;

      // Atualiza a cache local em background respeitando os campos mapeados
      await _dbLocal.salvarRegisto('consultor', {
        'id_utilizador': userId,
        'id_areas': _dashboard['id_areas'],
        'pontos_atuais': int.tryParse((_dashboard['total_pontos'] ?? _dashboard['pontos_atuais'] ?? '0').toString()) ?? 0,
        'badges_conquistas_total': int.tryParse((_dashboard['total_badges'] ?? _dashboard['badges_conquistas_total'] ?? '0').toString()) ?? 0,
        'progresso_nivel': _dashboard['ranking'] ?? _dashboard['progresso_nivel'] ?? 'N/A',
        'ultima_atualizacao_perfil': DateTime.now().toString(),
      });

      for (var badge in _badgesProgresso) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': int.tryParse((badge['id_badge_atribuido'] ?? badge['id'] ?? '0').toString()) ?? 0,
          'id_badge_modelo': int.tryParse((badge['id_badge_modelo'] ?? badge['id_modelo'] ?? '0').toString()) ?? 0,
          'data_atribuicao': badge['data_atribuicao']?.toString(),
          'data_validade': badge['data_validade']?.toString(),
          'estado_badge_atribuido': badge['estado_badge_atribuido'] ?? 'Em Progresso',
        });
      }
      
      notifyListeners();
    } catch (e) {
      print("Erro ao atualizar dados por gesto de refresh (mantendo cache ativa): $e");
    }
  }
}