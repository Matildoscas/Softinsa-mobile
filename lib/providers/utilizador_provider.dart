import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UtilizadorProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

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

  // Sincroniza e carrega os dados globais da aplicação
  Future<void> inicializarDados(int userId) async {
    _estaA_Carregar = true;
    notifyListeners(); // Avisa a UI para mostrar o loading

    try {
      // 1. Carrega as Áreas (Útil para o ecrã area_register ou Perfil)
      _areas = await _apiService.getAreas();
      notifyListeners();

      // 2. Carrega o Dashboard do Utilizador (Dados do Consultor Offline-First)
      _dashboard = await _apiService.getDashboard(userId);
      notifyListeners();

      // 3. Carrega os Badges de Progresso do Consultor
      _badgesProgresso = await _apiService.getBadgesProgresso(userId);
      notifyListeners();

      // 4. Atualiza a lista geral de utilizadores se for necessário
      _utilizadores = await _apiService.getUtilizadores();
    } catch (e) {
      print("Erro ao alimentar o Provider: $e");
    } finally {
      _estaA_Carregar = false;
      notifyListeners(); // Remove o estado de loading na UI
    }
  }

  // Método auxiliar para atualizar os dados manualmente (ex: Pull-to-Refresh)
  Future<void> atualizarDashboard(int userId) async {
    try {
      _dashboard = await _apiService.getDashboard(userId);
      _badgesProgresso = await _apiService.getBadgesProgresso(userId);
      notifyListeners();
    } catch (e) {
      print("Erro ao atualizar dados: $e");
    }
  }
}