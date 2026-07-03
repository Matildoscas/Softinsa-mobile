// ============================================================================
// notification_service.dart
//
// Serviço responsável por iniciar as notificações push através do
// Firebase Cloud Messaging (FCM).
//
// Neste ficheiro concreto são realizadas duas tarefas:
// 1. Pedir autorização ao utilizador para apresentar notificações;
// 2. Obter o token FCM único deste dispositivo.
//
// Os handlers de mensagens em background são registados no main.dart.
// ============================================================================

import 'package:firebase_messaging/firebase_messaging.dart';

// Classe que concentra a configuração inicial do Firebase Messaging.
class NotificationService {
  // Obtém a instância única do FirebaseMessaging criada pelo plugin.
  // Através desta instância é possível pedir permissões e obter o token FCM.
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // =========================================================================
  // INICIAR NOTIFICAÇÕES
  //
  // Pede autorização para:
  // - alert: mostrar banners/alertas;
  // - badge: mostrar um contador no ícone da app;
  // - sound: reproduzir som.
  //
  // Retorno:
  // - String com o token FCM, quando é possível obtê-lo;
  // - null, quando a permissão é recusada ou não existe token.
  // =========================================================================
  Future<String?> iniciarNotificacoes() async {
    // requestPermission abre o pedido de autorização do sistema operativo.
    // Como é uma operação assíncrona, é necessário utilizar await.
    final NotificationSettings settings =
        await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // authorizationStatus informa o resultado do pedido.
    // Se o utilizador recusar, a função termina e não tenta obter o token.
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('Permissão de notificações negada');
      return null;
    }

    // Obtém o token FCM que identifica esta instalação da aplicação.
    // O backend guarda este valor para enviar notificações a este dispositivo.
    final String? token = await _firebaseMessaging.getToken();

    // Mostra o token apenas para testes durante o desenvolvimento.
    print('FCM TOKEN:');
    print(token);

    // Devolve o token ao ecrã de login.
    // Depois, ApiService.atualizarFcmToken() envia-o para o backend.
    return token;
  }
}
