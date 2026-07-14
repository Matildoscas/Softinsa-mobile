import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../screens/informacoes_badge.dart';

class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance =
      DeepLinkService._();

  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  Future<void> inicializar({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    try {
      final Uri? initialUri =
          await _appLinks.getInitialLink();

      if (initialUri != null) {
        _tratarUri(
          initialUri,
          navigatorKey,
        );
      }

      _subscription =
          _appLinks.uriLinkStream.listen(
        (uri) {
          _tratarUri(
            uri,
            navigatorKey,
          );
        },
      );
    } catch (e) {
      debugPrint(
        '[DEEP LINK] Erro ao inicializar: $e',
      );
    }
  }

  void dispose() {
    _subscription?.cancel();
  }

  void _tratarUri(
    Uri uri,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    debugPrint(
      '[DEEP LINK] Recebido: $uri',
    );

    final segments =
        uri.pathSegments;

    if (segments.isEmpty) {
      return;
    }

    /*
    * Aceita links como:
    * /badges/22/7
    * /galeria-badges/22/7
    * /badge/22/7
    */
    final bool rotaBadge =
        segments.first == 'badges' ||
        segments.first == 'badge' ||
        segments.first == 'galeria-badges';

    if (!rotaBadge) {
      return;
    }

    if (segments.length < 3) {
      return;
    }

    final int? userId =
        int.tryParse(
      segments[1],
    );

    final int? badgeId =
        int.tryParse(
      segments[2],
    );

    if (
      userId == null ||
      badgeId == null
    ) {
      return;
    }

    final context =
        navigatorKey.currentContext;

    if (context == null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BadgeDetalhe(
          userId: userId,
          badgeId: badgeId,
        ),
      ),
    );
  }
}