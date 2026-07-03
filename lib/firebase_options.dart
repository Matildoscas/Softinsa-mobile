// ============================================================
// firebase_options.dart
// Ficheiro GERADO AUTOMATICAMENTE pelo FlutterFire CLI.
// NÃO deve ser editado manualmente.
//
// Contém as configurações específicas de cada plataforma para
// ligar esta app ao projeto Firebase "pint-b0c13".
// Cada plataforma tem chaves diferentes porque cada uma é
// registada separadamente na consola do Firebase.
// ============================================================

// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


class DefaultFirebaseOptions {

  // ============================================================
  // GETTER DE PLATAFORMA
  // Deteta em tempo de execução qual a plataforma onde a app
  // está a correr e devolve as FirebaseOptions correspondentes.
  // É chamado em main.dart: DefaultFirebaseOptions.currentPlatform
  // ============================================================
  static FirebaseOptions get currentPlatform {
    // kIsWeb é true quando compila para browser (Flutter Web).
    // Tem de ser verificado antes do switch porque nas Web
    // não existe um TargetPlatform correspondente.
    if (kIsWeb) {
      return web;
    }

    // Para plataformas nativas, usa o enum TargetPlatform para
    // selecionar as opções corretas.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        // Linux não está configurado neste projeto.
        // Lançar erro em vez de retornar null garante que o
        // desenvolvedor é avisado explicitamente.
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }


  // ============================================================
  // CONFIGURAÇÕES WEB
  // Usadas quando a app corre no browser (Flutter Web).
  // Inclui measurementId para integração com Google Analytics.
  // ============================================================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDkL134vEf_b3fIdY0xxRGCJrrTDAiJd9k',
    appId: '1:522600619451:web:3fe7b341bc39821030f89e',
    messagingSenderId: '522600619451', // ID do projeto para Firebase Messaging (FCM)
    projectId: 'pint-b0c13',          // Identificador único do projeto Firebase
    authDomain: 'pint-b0c13.firebaseapp.com', // Domínio para autenticação OAuth
    storageBucket: 'pint-b0c13.firebasestorage.app', // Firebase Storage (ficheiros)
    measurementId: 'G-SJEXJX6JSF',   // ID do Google Analytics associado
  );


  // ============================================================
  // CONFIGURAÇÕES ANDROID
  // A apiKey e appId do Android são diferentes das da Web —
  // cada plataforma tem o seu próprio registo no Firebase.
  // Não tem measurementId porque o Analytics no Android
  // é configurado via google-services.json.
  // ============================================================
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDu0Fc9RR2pYVKQCPYsEC5gb2-49-7tDo8',
    appId: '1:522600619451:android:f6d5cf0eec3ee9a530f89e',
    messagingSenderId: '522600619451',
    projectId: 'pint-b0c13',
    storageBucket: 'pint-b0c13.firebasestorage.app',
  );


  // ============================================================
  // CONFIGURAÇÕES iOS
  // Inclui iosBundleId que identifica a app na App Store
  // e nos serviços Apple (APNs para notificações push).
  // ============================================================
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD68E1woqNuC3IoKGqRr-FIQXyYTLuh9Ds',
    appId: '1:522600619451:ios:e0246a64a0307e7030f89e',
    messagingSenderId: '522600619451',
    projectId: 'pint-b0c13',
    storageBucket: 'pint-b0c13.firebasestorage.app',
    iosBundleId: 'com.example.softinsaMobile', // Bundle ID da app no ecossistema Apple
  );


  // ============================================================
  // CONFIGURAÇÕES macOS
  // Usa as mesmas credenciais do iOS porque o Firebase trata
  // macOS e iOS como parte do mesmo ecossistema Apple.
  // ============================================================
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD68E1woqNuC3IoKGqRr-FIQXyYTLuh9Ds',
    appId: '1:522600619451:ios:e0246a64a0307e7030f89e',
    messagingSenderId: '522600619451',
    projectId: 'pint-b0c13',
    storageBucket: 'pint-b0c13.firebasestorage.app',
    iosBundleId: 'com.example.softinsaMobile',
  );


  // ============================================================
  // CONFIGURAÇÕES WINDOWS
  // Usa as mesmas chaves da Web porque no Firebase, Windows
  // é tratado como cliente web (sem SDK nativo para desktop).
  // Tem measurementId próprio para distinguir as sessões
  // Windows das sessões Web no Analytics.
  // ============================================================
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDkL134vEf_b3fIdY0xxRGCJrrTDAiJd9k',
    appId: '1:522600619451:web:409dad46ae65dffe30f89e',
    messagingSenderId: '522600619451',
    projectId: 'pint-b0c13',
    authDomain: 'pint-b0c13.firebaseapp.com',
    storageBucket: 'pint-b0c13.firebasestorage.app',
    measurementId: 'G-6EF12GWNSK', // measurementId diferente do Web para separar métricas
  );
}
