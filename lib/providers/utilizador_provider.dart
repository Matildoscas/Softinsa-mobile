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

    // ── 1. FLUXO DAS ÁREAS ──────────────────────────────────────────
    try {
      _areas = await _apiService.getAreas();
      // Se correu bem, espelha para o SQFlite local para consultas futuras
      for (var area in _areas) {
        await _dbLocal.salvarRegisto('areas', area);
      }
    } catch (_) {
      // Falhou a rede? Carrega a cache local de imediato
      _areas = await _dbLocal.listarTabela('areas');
    }
    notifyListeners();

    // ── 2. FLUXO DO DASHBOARD (PONTOS, RANKING) ────────────────────
    try {
      _dashboard = await _apiService.getDashboard(userId);
      // Salva os dados do consultor localmente (Podes precisar de ajustar o nome da tabela 'consultor')
      await _dbLocal.salvarRegisto('consultor', {
        'id_utilizador': userId,
        'pontos': _dashboard['total_pontos'] ?? 0,
        'badges': _dashboard['total_badges'] ?? 0,
        'ranking': _dashboard['ranking'] ?? 'N/A'
      });
    } catch (_) {
      // Se falhar, monta o mapa de fallback baseado na tabela local do SQFlite
      final dadosLocais = await _dbLocal.listarTabela('consultor');
      if (dadosLocais.isNotEmpty) {
        _dashboard = {
          'total_pontos': dadosLocais.first['pontos'],
          'total_badges': dadosLocais.first['badges'],
          'ranking': dadosLocais.first['ranking'],
          'offline': true // Flag útil se quiseres meter um aviso discreto na UI
        };
      }
    }
    notifyListeners();

    // ── 3. FLUXO DOS BADGES DE PROGRESSO (Tabela 'badge_atribuido') ──
    try {
      _badgesProgresso = await _apiService.getBadgesProgresso(userId);
      for (var badge in _badgesProgresso) {
        await _dbLocal.salvarRegisto('badge_atribuido', {
          'id_badge_atribuido': badge['id_badge_atribuido'] ?? badge['id'] ?? 0,
          'id_badge_modelo': badge['id_badge_modelo'] ?? badge['id'] ?? 0,
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
        await _dbLocal.salvarRegisto('utilizador', user);
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

      // Atualiza a cache local em background
      await _dbLocal.salvarRegisto('consultor', {
        'id_utilizador': userId,
        'pontos': _dashboard['total_pontos'] ?? 0,
        'badges': _dashboard['total_badges'] ?? 0,
        'ranking': _dashboard['ranking'] ?? 'N/A'
      });
      for (var badge in _badgesProgresso) {
        await _dbLocal.salvarRegisto('badge_atribuido', badge);
      }
      
      notifyListeners();
    } catch (e) {
      print("Erro ao atualizar dados por gesto de refresh (mantendo cache ativa): $e");
    }
  }
}