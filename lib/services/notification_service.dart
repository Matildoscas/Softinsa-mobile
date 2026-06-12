import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<String?> iniciarNotificacoes() async {
    NotificationSettings settings =
        await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print("Permissão de notificações negada");
      return null;
    }

    final token = await _firebaseMessaging.getToken();

    print("FCM TOKEN:");
    print(token);

    return token;
  }
}