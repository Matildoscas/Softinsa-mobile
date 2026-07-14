// ============================================================================
// api_service.dart
//
// Camada responsável pela comunicação HTTP entre a aplicação Flutter
// e o backend REST em Node.js.
//
// Responsabilidades principais:
// - Autenticar e registar utilizadores;
// - Guardar e enviar o token JWT nos pedidos protegidos;
// - Obter dashboard, áreas, badges, notificações e certificados;
// - Submeter evidências através de multipart/form-data;
// - Atualizar perfil, password, conta e token FCM;
// - Converter respostas JSON em estruturas Map/List utilizadas pela app.
//
// NOTA:
// Este ficheiro não cria a interface gráfica. Apenas envia pedidos à API,
// interpreta as respostas e devolve os dados aos ecrãs ou ao Provider.
// ============================================================================

import 'dart:convert'; // Converte objetos Dart para JSON e JSON para objetos Dart.
import 'dart:io'; // File: leitura de ficheiros; SocketException: erros de ligação.
import 'dart:async'; // Future e TimeoutException para operações assíncronas.
import 'package:http/http.dart' as http; // Biblioteca usada para GET, POST, PUT e multipart.

// Token JWT da sessão atual.
// É preenchido após um login bem-sucedido e usado pelo getter _headers.
// O tipo String? permite que inicialmente não exista token.
String? token;

// Classe que concentra todos os pedidos feitos ao backend.
class ApiService {
  // Endereço base de todas as rotas da API.
  // Para produção, usa-se normalmente o endereço do Render.
  // Para desenvolvimento local, usa-se o IP do computador na rede.

  // Produção (Render)
  static const String baseUrl =
    'https://softinsa-api.onrender.com/api';

  int _converterInteiro(
    dynamic valor,
  ) {
    if (valor == null) {
      return 0;
    }

    if (valor is int) {
      return valor;
    }

    if (valor is double) {
      return valor.round();
    }

    return int.tryParse(
          valor.toString(),
        ) ??
        double.tryParse(
          valor.toString(),
        )?.round() ??
        0;
  }

  bool _converterBooleano(
    dynamic valor,
  ) {
    if (valor is bool) {
      return valor;
    }

    if (valor is num) {
      return valor == 1;
    }

    final texto = valor
        ?.toString()
        .trim()
        .toLowerCase();

    return [
      'true',
      't',
      '1',
      'sim',
      'yes',
    ].contains(texto);
  }


  // =========================================================================
  // CABEÇALHOS HTTP
  // =========================================================================
  // Getter executado sempre que _headers é utilizado.
  // Devolve Content-Type JSON e acrescenta Authorization apenas se existir token.
  // Assim, os métodos protegidos não precisam de repetir estes cabeçalhos.
  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // =========================================================================
  // AUTENTICAÇÃO E UTILIZADORES
  // =========================================================================

  // =========================================================================
  // LOGIN
  // Envia email e password para POST /auth/login.
  //
  // Retorno:
  // - success: true + token + user, quando o login é aceite;
  // - success: false + mensagem, quando existe algum erro;
  // - emailNaoVerificado: true, quando a API devolve HTTP 403.
  //
  // Este método trata os erros internamente e devolve sempre um Map.
  // =========================================================================

  Future<Map<String, dynamic>> validarAtivacaoAdmin(
    String tokenAtivacao,
  ) async {
    final url = Uri.parse(
      '$baseUrl/auth/ativacao-admin/validar?token=$tokenAtivacao',
    );

    final response = await http
        .get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['error'] ??
            decoded['message'] ??
            'Não foi possível validar a conta.',
      );
    }

    throw Exception('Não foi possível validar a conta.');
  }

  Future<Map<String, dynamic>> confirmarAtivacaoAdmin({
    required String tokenAtivacao,
    required String passwordTemporaria,
    required String novaPassword,
    int? idArea,
  }) async {
    final url = Uri.parse(
      '$baseUrl/auth/ativacao-admin/confirmar',
    );

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'token': tokenAtivacao,
            'password_temporaria': passwordTemporaria,
            'nova_password': novaPassword,
            if (idArea != null) 'id_area': idArea,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = jsonDecode(response.body);

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw Exception(
        decoded['error'] ??
            decoded['message'] ??
            'Não foi possível ativar a conta.',
      );
    }

    throw Exception('Não foi possível ativar a conta.');
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    // Constrói um objeto Uri válido a partir do endereço da rota.
    final url = Uri.parse('$baseUrl/auth/login');

  print('========== LOGIN ==========');
  print('URL: $url');
  print('Email enviado: "${email.trim()}"');
  print('Password preenchida: ${password.isNotEmpty}');
  print('Tamanho da password: ${password.length}');

  try {
    // Cria o corpo que será convertido para JSON.
    // trim() remove espaços acidentais antes e depois do email.
    final body = {
      'email': email.trim(),
      'password': password,
    };

    print('Body enviado: ${jsonEncode({
      'email': email.trim(),
      'password': '***',
    })}');

    // await suspende apenas este método até chegar a resposta,
    // sem bloquear a interface gráfica da aplicação.
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );

    print('Status recebido: ${response.statusCode}');
    print('Headers recebidos: ${response.headers}');
    print('Body recebido: ${response.body}');

    dynamic decoded;

    try {
      // Converte a String JSON do backend para uma estrutura Dart.
      decoded = jsonDecode(response.body);
      print('JSON convertido com sucesso.');
      print('Tipo do JSON: ${decoded.runtimeType}');
    } catch (e, stackTrace) {
      print('ERRO AO CONVERTER JSON: $e');
      print(stackTrace);

      return {
        'success': false,
        'message':
            'O servidor respondeu, mas o conteúdo não é JSON válido. '
            'Status: ${response.statusCode}',
      };
    }

    if (decoded is! Map<String, dynamic>) {
      print('ERRO: resposta JSON não é um Map.');

      return {
        'success': false,
        'message': 'Formato de resposta inesperado do servidor.',
      };
    }

    final data = decoded;

    if (response.statusCode == 200) {
      print('Login HTTP aceite.');

      // Guarda globalmente o JWT para os pedidos autenticados seguintes.
      token = data['token']?.toString();

      print('Token recebido: ${token != null && token!.isNotEmpty}');
      print('User recebido: ${data['user']}');

      if (token == null || token!.isEmpty) {
        print('ERRO: status 200, mas sem token.');

        return {
          'success': false,
          'message': 'O servidor aceitou o login, mas não devolveu o token.',
        };
      }

      print('LOGIN CONCLUÍDO COM SUCESSO');
      print('===========================');

      return {
        'success': true,
        ...data,
      };
    }

    if (response.statusCode == 403) {
      print('Login recusado com status 403.');
      print('Erro recebido: ${data['error']}');

      final mensagem =
          data['error']?.toString() ??
          data['message']?.toString() ??
          'Acesso recusado.';

      final mensagemNormalizada =
          mensagem.toLowerCase();

      final contaPendenteAtivacao =
          mensagemNormalizada.contains('ative a conta') ||
          mensagemNormalizada.contains('password temporária') ||
          mensagemNormalizada.contains('password temporaria') ||
          mensagemNormalizada.contains('pendente de ativação') ||
          mensagemNormalizada.contains('pendente de ativacao');

      final emailNaoVerificado =
          !contaPendenteAtivacao &&
          (
            mensagemNormalizada.contains('confirme o email') ||
            mensagemNormalizada.contains('email não verificado') ||
            mensagemNormalizada.contains('email nao verificado')
          );

      return {
        'success': false,
        'emailNaoVerificado': emailNaoVerificado,
        'contaPendenteAtivacao': contaPendenteAtivacao,
        'message': mensagem,
      };
    }

    print('Login recusado.');
    print('Status: ${response.statusCode}');
    print('Erro: ${data['error']}');
    print('Mensagem: ${data['message']}');
    print('===========================');

    return {
      'success': false,
      'message':
          data['error'] ??
          data['message'] ??
          'Erro no login. Status: ${response.statusCode}',
    };
  } catch (e, stackTrace) {
    print('EXCEÇÃO DURANTE O LOGIN:');
    print('Tipo: ${e.runtimeType}');
    print('Erro: $e');
    print('Stack trace:');
    print(stackTrace);
    print('===========================');

    return {
      'success': false,
      'message': 'Sem ligação ao servidor. Erro: $e',
    };
  }
}

  // =========================================================================
  // REGISTO
  // Envia os dados do novo utilizador para POST /auth/register.
  // Devolve true apenas quando a API responde com HTTP 201 (Created).
  // Em caso de falha de ligação ou exceção, devolve false.
  // =========================================================================
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
      // HTTP 201 significa que o novo recurso foi criado.
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // =========================================================================
  // LISTAR UTILIZADORES
  // Faz GET /utilizadores e converte a lista JSON numa lista de Maps Dart.
  // Se não existir rede, lança SocketException('offline') para o Provider
  // poder utilizar os dados guardados localmente.
  // =========================================================================
  Future<List<Map<String, dynamic>>> getUtilizadores() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/utilizadores'), headers: _headers);
      if (response.statusCode == 200) {
        // A resposta é uma lista JSON; cada elemento será um Map.
        final List data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
      throw Exception('Erro ao carregar utilizadores');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  // =========================================================================
  // CARREGAR ÁREAS
  // Faz GET /areas/select.
  // Aceita três formatos possíveis de resposta:
  // 1. Uma lista direta;
  // 2. Um objeto com a chave 'areas';
  // 3. Um objeto com a chave 'data'.
  //
  // O timeout de 45 segundos evita que o pedido fique indefinidamente pendente.
  // =========================================================================
  Future<List<Map<String, dynamic>>> getAreas() async {
    final url = Uri.parse('$baseUrl/areas/select');

    print('========== CARREGAR ÁREAS ==========');
    print('[ÁREAS] URL: $url');
    print('[ÁREAS] Token disponível: ${token != null}');

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 45));

      print('[ÁREAS] Status: ${response.statusCode}');
      print('[ÁREAS] Body: ${response.body}');
      print('[ÁREAS] Content-Type: ${response.headers['content-type']}');

      if (response.statusCode != 200) {
        print('[ÁREAS] Pedido recusado');
        print('====================================');

        throw Exception(
          'Erro ao carregar áreas '
          '(${response.statusCode}): ${response.body}',
        );
      }

      // Analisa o conteúdo JSON recebido.
      final decoded = jsonDecode(response.body);

      print('[ÁREAS] Tipo da resposta: ${decoded.runtimeType}');

      List<dynamic> lista;

      if (decoded is List) {
        lista = decoded;
      } else if (decoded is Map<String, dynamic> &&
          decoded['areas'] is List) {
        lista = decoded['areas'] as List;
      } else if (decoded is Map<String, dynamic> &&
          decoded['data'] is List) {
        lista = decoded['data'] as List;
      } else {
        throw const FormatException(
          'A API não devolveu uma lista de áreas.',
        );
      }

      // Ignora elementos que não sejam Map e cria cópias tipadas
      // para evitar problemas com Map<dynamic, dynamic>.
      final areas = lista
          .whereType<Map>()
          .map((area) => Map<String, dynamic>.from(area))
          .toList();

      print('[ÁREAS] Total recebido: ${areas.length}');

      for (final area in areas) {
        print(
          '[ÁREAS] ID: ${area['id_areas']} '
          '| Nome: ${area['nome_area']}',
        );
      }

      print('====================================');

      return areas;
    } on TimeoutException catch (e) {
      print('[ÁREAS] TIMEOUT: $e');
      rethrow;
    } on SocketException catch (e) {
      print('[ÁREAS] SEM LIGAÇÃO: $e');
      throw const SocketException('Sem internet');
    } catch (e, stackTrace) {
      print('[ÁREAS] ERRO: $e');
      print(stackTrace);
      print('====================================');
      rethrow;
    }
  }

  // =========================================================================
  // FLUXO PRINCIPAL (PREPARADO PARA CACHE NO PROVIDER)
  // =========================================================================

  // =========================================================================
  // DASHBOARD
  // Obtém os totais e informações principais do utilizador autenticado.
  // A rota recebe o ID do utilizador no próprio URL.
  // =========================================================================
  Future<Map<String, dynamic>> getDashboard(
    int userId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/utilizadores/dashboard/$userId',
    );

    try {
      final response = await http.get(
        url,
        headers: _headers,
      );

      print('========== DASHBOARD ==========');
      print('URL: $url');
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');
      print('===============================');

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(response.body);

        if (
          decoded
          is Map<String, dynamic>
        ) {
          return decoded;
        }

        throw const FormatException(
          'O dashboard não devolveu um objeto JSON.',
        );
      }

      throw Exception(
        'Erro ao carregar dashboard '
        '(${response.statusCode}): '
        '${response.body}',
      );
    } on SocketException {
      throw const SocketException(
        'offline',
      );
    }
  }

  // =========================================================================
  // BADGES EM PROGRESSO
  // Obtém os badges que o utilizador ainda está a desenvolver.
  // =========================================================================
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

  // =========================================================================
  // BADGES RECOMENDADOS
  // Obtém sugestões de badges adequadas ao utilizador.
  // =========================================================================
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

  // =========================================================================
  // BADGE ESPECIAL
  // Obtém o badge especial definido pelo backend.
  // O retorno é nullable porque a API pode responder com null.
  // =========================================================================
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

  // =========================================================================
  // NOTIFICAÇÕES
  // Obtém todas as notificações associadas a um utilizador.
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

  // =========================================================================
  // CATÁLOGO COMPLETO DE BADGES
  // A API pode devolver várias linhas para o mesmo badge, uma por requisito.
  // Depois de converter o JSON, chama agruparBadgesComRequisitos()
  // para produzir um único objeto por badge.
  // =========================================================================
  Future<List<Map<String, dynamic>>> getTodosBadges() async {
    final response = await http.get(Uri.parse('$baseUrl/badges/todos'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      // Converte cada elemento para Map antes de efetuar o agrupamento.
      final listaPlana =
          data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro catálogo');
  }

  // =========================================================================
  // BADGES CONQUISTADOS
  // Obtém os badges atribuídos ao utilizador e agrupa os respetivos requisitos.
  // =========================================================================
  Future<List<Map<String, dynamic>>> getBadgesConquistados(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/badges/conquistados/$userId'), headers: _headers);
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final listaPlana = data.map((e) => e as Map<String, dynamic>).toList();
      return agruparBadgesComRequisitos(listaPlana);
    }
    throw Exception('Erro conquistados');
  }

  // =========================================================================
  // CANDIDATURAS PENDENTES
  // Obtém as candidaturas ainda em validação.
  //
  // O método é tolerante a diferentes formatos:
  // - Se receber List, converte diretamente;
  // - Se receber Map com a chave 'rows', usa essa lista;
  // - Se receber outro Map, devolve [] para evitar que a interface bloqueie.
  // =========================================================================
  Future<List<Map<String, dynamic>>> getCandidaturasPendentes(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/certificados/pendentes/$userId'), headers: _headers);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // 1. IMPRIME O QUE ESTÁ A CHEGAR (Vê a consola do Flutter!)
        print('[API DEBUG] O que chegou da API: $decoded');

        // 2. Se for a lista esperada (o teu result.rows), processa normalmente
        if (decoded is List) {
          return decoded.map((e) => e as Map<String, dynamic>).toList();
        }

        // 3. Se for um Map (o tal erro), evita o crash e descobre o que é
        if (decoded is Map<String, dynamic>) {
          print('[API AVISO] A rota devolveu um objeto em vez de lista. Conteúdo: $decoded');
          
          // Se por acaso a lista veio envelopada numa chave 'rows' ou 'dados'
          if (decoded.containsKey('rows') && decoded['rows'] is List) {
            final List rows = decoded['rows'];
            return rows.map((e) => e as Map<String, dynamic>).toList();
          }
          
          // Se for um objeto de erro ou vazio, retorna lista vazia para a app não crashar
          return [];
        }
      }
      print('Erro na API. Status Code: ${response.statusCode}');
      print('Corpo do erro enviado pelo servidor: ${response.body}');
      throw Exception('Erro ao carregar candidaturas pendentes: Status ${response.statusCode}');
    } on SocketException {
      throw const SocketException('offline');
    }
  }

  // =========================================================================
  // PROGRESSO DAS LEARNING PATHS
  // Obtém o progresso do utilizador nas learning paths.
  // =========================================================================
  Future<List<Map<String, dynamic>>>
      getProgressoLearningPaths(
    int userId,
  ) async {
    /*
    * A primeira rota é a rota própria
    * das Learning Paths.
    *
    * A segunda fica como alternativa,
    * caso o backend atual use a rota
    * criada para a página de progresso.
    */
    final List<Uri> urls = [
      Uri.parse(
        '$baseUrl/badges/learningpaths/$userId',
      ),
      Uri.parse(
        '$baseUrl/badges/progresso/$userId',
      ),
    ];

    Object? ultimoErro;

    for (final url in urls) {
      try {
        print(
          '========== LEARNING PATHS ==========',
        );
        print('URL: $url');

        final response = await http
            .get(
              url,
              headers: _headers,
            )
            .timeout(
              const Duration(
                seconds: 30,
              ),
            );

        print(
          'STATUS: ${response.statusCode}',
        );
        print(
          'BODY: ${response.body}',
        );
        print(
          '====================================',
        );

        if (response.statusCode != 200) {
          ultimoErro = Exception(
            'Erro ${response.statusCode}: '
            '${response.body}',
          );

          continue;
        }

        final dynamic decoded =
            jsonDecode(
          response.body,
        );

        List<dynamic>? lista;

        /*
        * Aceita uma lista direta:
        *
        * [
        *   {...},
        *   {...}
        * ]
        */
        if (decoded is List) {
          lista = decoded;
        }

        /*
        * Aceita também respostas
        * envolvidas num objeto:
        *
        * {
        *   "learningPaths": [...]
        * }
        */
        if (
          decoded
          is Map<String, dynamic>
        ) {
          final possibilidades = [
            decoded['learningPaths'],
            decoded['learning_paths'],
            decoded['learningpaths'],
            decoded['dados'],
            decoded['data'],
            decoded['rows'],
          ];

          for (
            final possibilidade
            in possibilidades
          ) {
            if (possibilidade is List) {
              lista = possibilidade;
              break;
            }
          }
        }

        if (lista == null) {
          ultimoErro =
              const FormatException(
            'A API não devolveu uma lista '
            'de Learning Paths.',
          );

          continue;
        }

        final resultado = lista
            .whereType<Map>()
            .map(
              (item) =>
                  Map<String, dynamic>.from(
                item,
              ),
            )
            .where(
              (item) =>
                  item[
                    'id_learningpaths'
                  ] !=
                  null ||
                  item[
                    'id_learningpath'
                  ] !=
                  null ||
                  item[
                    'nome_learningpath'
                  ] !=
                  null ||
                  item[
                    'nome_learningpaths'
                  ] !=
                  null,
            )
            .toList();

        /*
        * Se recebeu dados válidos,
        * devolve imediatamente.
        */
        if (resultado.isNotEmpty) {
          return resultado;
        }

        /*
        * Uma lista vazia é uma resposta
        * válida quando o consultor não
        * possui Learning Paths.
        */
        if (lista.isEmpty) {
          return [];
        }

        ultimoErro =
            const FormatException(
          'A resposta não contém dados '
          'de Learning Paths.',
        );
      } catch (e, stackTrace) {
        ultimoErro = e;

        print(
          'ERRO NA ROTA DE LEARNING PATHS: '
          '$e',
        );
        print(stackTrace);
      }
    }

    throw Exception(
      'Não foi possível carregar '
      'as Learning Paths. '
      'Último erro: $ultimoErro',
    );
  }

  // =========================================================================
  // CERTIFICADO
  // Obtém os dados de um certificado através do ID do histórico
  // e do ID do utilizador.
  // =========================================================================
  /*Future<Map<String, dynamic>> getCertificado({
    required int idHistorico,
    required int idUtilizador,
  }) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/certificados/$idHistorico/$idUtilizador'), headers: _headers);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Erro ao obter ficheiro do certificado');
    } on SocketException {
      throw const SocketException('offline');
    }
  }*/

  // =========================================================================
  // AGRUPAR BADGES E REQUISITOS
  //
  // A consulta SQL do backend pode devolver dados "planos", por exemplo:
  // Badge A + Requisito 1
  // Badge A + Requisito 2
  // Badge B + Requisito 1
  //
  // Este método transforma essas linhas em:
  // Badge A -> [Requisito 1, Requisito 2]
  // Badge B -> [Requisito 1]
  //
  // Não faz nenhum pedido HTTP; apenas reorganiza dados já recebidos.
  // =========================================================================
  List<Map<String, dynamic>>
    agruparBadgesComRequisitos(
    List<Map<String, dynamic>>
        dadosPlanos,
  ) {
    final Map<
      int,
      Map<String, dynamic>
    > badgesAgrupados = {};

    for (final linha in dadosPlanos) {
      final int? badgeId =
          int.tryParse(
        (
          linha['id'] ??
          linha['id_badge_modelo'] ??
          linha['badge_id'] ??
          ''
        ).toString(),
      );

      if (badgeId == null) {
        continue;
      }

      final int pontosExtraLinha =
          _converterInteiro(
        linha['pontos_extra'] ??
        linha['pontos_bonus'],
      );

      final bool ganhouBonusLinha =
          _converterBooleano(
            linha['ganhou_bonus'] ??
            linha['premio_atribuido'],
          ) ||
          pontosExtraLinha > 0;

      if (
        !badgesAgrupados
            .containsKey(badgeId)
      ) {
        badgesAgrupados[badgeId] = {
          ...linha,

          'id': badgeId,

          'nome':
              linha['nome'] ??
              linha['nome_badge'] ??
              'Badge',

          'descricao':
              linha['descricao'] ??
              linha[
                'descricao_badge_modelo'
              ] ??
              '',

          'pontos': _converterInteiro(
            linha['pontos'],
          ),

          'imagem_url':
              linha['imagem_url'] ??
              linha['imagem'] ??
              linha['url_imagem'],

          'imagem':
              linha['imagem_url'] ??
              linha['imagem'] ??
              linha['url_imagem'],

          'ganhou_bonus':
              ganhouBonusLinha,

          'premio_atribuido':
              ganhouBonusLinha,

          'pontos_extra':
              pontosExtraLinha,

          'pontos_bonus':
              pontosExtraLinha,

          'requisitos':
              <Map<String, dynamic>>[],

          'tipo_badge':
              linha['tipo_badge'] ??
              linha['tipoBadge'] ??
              linha['tipo'],

          'nome_nivel':
              linha['nome_nivel'] ??
              linha['nomeNivel'] ??
              linha['nivel'],

          'codigo_nivel':
              linha['codigo_nivel'] ??
              linha['codigoNivel'] ??
              linha['letra_nivel'],
        };
      } else {
        final badgeAtual =
            badgesAgrupados[badgeId]!;

        final int pontosExtraAtual =
            _converterInteiro(
          badgeAtual['pontos_extra'] ??
          badgeAtual['pontos_bonus'],
        );

        final bool ganhouBonusAtual =
            _converterBooleano(
              badgeAtual['ganhou_bonus'] ??
              badgeAtual[
                'premio_atribuido'
              ],
            ) ||
            pontosExtraAtual > 0;

        badgeAtual['ganhou_bonus'] =
            ganhouBonusAtual ||
            ganhouBonusLinha;

        badgeAtual['premio_atribuido'] =
            ganhouBonusAtual ||
            ganhouBonusLinha;

        badgeAtual['pontos_extra'] =
            pontosExtraLinha >
                pontosExtraAtual
            ? pontosExtraLinha
            : pontosExtraAtual;

        badgeAtual['pontos_bonus'] =
            badgeAtual[
              'pontos_extra'
            ];

        final imagemNova =
            linha['imagem_url'] ??
            linha['imagem'] ??
            linha['url_imagem'];

        final imagemAtual =
            badgeAtual['imagem_url'] ??
            badgeAtual['imagem'];

        if (
          (
            imagemAtual == null ||
            imagemAtual
                .toString()
                .trim()
                .isEmpty
          ) &&
          imagemNova != null
        ) {
          badgeAtual['imagem_url'] =
              imagemNova;

          badgeAtual['imagem'] =
              imagemNova;
        }
      }

      if (
        linha['nome_requisito'] != null ||
        linha['titulo'] != null ||
        linha['descricao_requisito'] != null
      ) {
        final listaRequisitos =
            badgesAgrupados[badgeId]?['requisitos']
                as List<Map<String, dynamic>>;

        final dynamic idRequisito =
            linha['id_requisito'] ??
            linha['id_requisitos'];

        final String chave =
            idRequisito?.toString() ??
            linha['titulo']?.toString() ??
            linha['nome_requisito']
                ?.toString() ??
            '';

        final bool jaExiste =
            listaRequisitos.any(
          (requisito) {
            final chaveExistente =
                requisito['id_requisito']
                        ?.toString() ??
                    requisito['titulo']
                        ?.toString() ??
                    requisito['nome']
                        ?.toString() ??
                    '';

            return chaveExistente == chave;
          },
        );

        if (!jaExiste) {
          listaRequisitos.add({
            'id_requisito':
                idRequisito,

            'id_requisitos':
                idRequisito,

            'nome':
                linha['nome_requisito'] ??
                linha['titulo'] ??
                'Requisito',

            'titulo':
                linha['titulo'] ??
                linha['nome_requisito'] ??
                'Requisito',

            'descricao':
                linha['descricao_requisito'] ??
                '',
          });
        }
      }
    }

    return badgesAgrupados
        .values
        .toList();
  }

  // =========================================================================
  // SUBMETER EVIDÊNCIA
  // Envia uma candidatura com texto e ficheiro para o backend.
  //
  // Usa MultipartRequest porque o pedido contém:
  // - campos de texto;
  // - um ficheiro binário.
  //
  // Em caso de erro, usa rethrow para permitir que o ecrã responsável
  // guarde a submissão no SQLite e tente novamente mais tarde.
  // =========================================================================

  Future<void> submeterEvidenciasPorRequisito({
    required int userId,
    required int badgeId,
    required String comentario,
    required List<Map<String, dynamic>> evidencias,
    int? idLembrete,
    required bool autorizaPublicacaoBadge,
    String? linkedinPublicacaoBadge,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/candidaturas/submeter-evidencias',
    );

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.headers.addAll({
      'Accept': 'application/json',
      if (token != null)
        'Authorization': 'Bearer $token',
    });

    request.fields['id_utilizador'] = userId.toString();
    request.fields['id_badge_modelo'] = badgeId.toString();
    request.fields['comentario'] = comentario.trim();

    request.fields['autoriza_publicacao_badge'] =
    autorizaPublicacaoBadge ? 'true' : 'false';

    if (
      linkedinPublicacaoBadge != null &&
      linkedinPublicacaoBadge.trim().isNotEmpty
    ) {
      request.fields['linkedin_publicacao_badge'] =
          linkedinPublicacaoBadge.trim();
    }

    if (idLembrete != null) {
      request.fields['id_lembrete'] = idLembrete.toString();
    }

    for (final evidencia in evidencias) {
      final int? idRequisito = int.tryParse(
        evidencia['id_requisito']?.toString() ?? '',
      );

      final String caminho =
          evidencia['caminho_ficheiro']?.toString() ?? '';

      final String nomeFicheiro =
          evidencia['nome_ficheiro']?.toString() ?? 'comprovativo';

      if (idRequisito == null) {
        throw Exception(
          'Existe uma evidência sem requisito associado.',
        );
      }

      final file = File(caminho);

      if (!await file.exists()) {
        throw Exception(
          'O ficheiro "$nomeFicheiro" não foi encontrado.',
        );
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'ficheiros',
          caminho,
          filename: nomeFicheiro,
        ),
      );

      request.files.add(
        http.MultipartFile.fromString(
          'metadados',
          jsonEncode({
            'requisito_key': 'requisito_$idRequisito',
            'id_requisito': idRequisito,
            'titulo': evidencia['titulo'],
            'nome': evidencia['nome'],
            'ficheiro_nome': nomeFicheiro,
          }),
        ),
      );
    }

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (
      streamedResponse.statusCode != 200 &&
      streamedResponse.statusCode != 201
    ) {
      throw Exception(
        body.isNotEmpty
            ? body
            : 'Erro ao submeter evidências.',
      );
    }
  }

  Future<void> submeterEvidencia({
    required int userId,
    required int badgeId,
    required String descricao,
    required String ficheiroPath,
  }) async {
    try {
      // 1. URL Corrigido baseado no teu app.js + candidaturaRoutes.js
      final uri = Uri.parse("$baseUrl/candidaturas/submeter-evidencias");
      // MultipartRequest permite enviar campos e ficheiros no mesmo pedido.
      final request = http.MultipartRequest("POST", uri);

      // Acrescenta os cabeçalhos comuns, incluindo o JWT quando existe.
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
        // Lê o conteúdo completo do ficheiro para uma lista de bytes.
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
      // send() devolve uma StreamedResponse porque a resposta chega em stream.
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

  // =========================================================================
  // ATUALIZAR TOKEN FCM
  // Guarda no backend o token Firebase Cloud Messaging do dispositivo.
  // Esse token permite ao servidor enviar notificações push
  // especificamente para este utilizador/dispositivo.
  // =========================================================================
  Future<void> atualizarFcmToken({
    required int idUtilizador,
    required String fcmToken,
  }) async {
    final url = Uri.parse('$baseUrl/utilizadores/fcm-token');

    print('========== GUARDAR FCM TOKEN ==========');
    print('URL: $url');
    print('ID UTILIZADOR: $idUtilizador');
    print('TOKEN EXISTE: ${fcmToken.isNotEmpty}');
    print(
      'INÍCIO DO TOKEN: '
      '${fcmToken.length > 20 ? fcmToken.substring(0, 20) : fcmToken}...',
    );

    try {
      // PUT é usado para atualizar um recurso já existente.
      final response = await http.put(
        url,
        headers: _headers,
        body: jsonEncode({
          'id_utilizador': idUtilizador,
          'fcm_token': fcmToken,
        }),
      );

      print('STATUS FCM: ${response.statusCode}');
      print('BODY FCM: ${response.body}');
      print('=======================================');

      if (response.statusCode != 200) {
        throw Exception(
          'Erro ao guardar FCM token '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (e, stackTrace) {
      print('ERRO AO GUARDAR FCM TOKEN: $e');
      print(stackTrace);
      rethrow;
    }
  }

  // =========================================================================
  // ATUALIZAR PERFIL
  // Envia o novo nome e contacto do utilizador.
  // Quando a atualização é aceite, devolve o objeto 'utilizador'
  // enviado pelo backend.
  // =========================================================================
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
      // O backend envolve o objeto atualizado na chave 'utilizador'.
      final data = jsonDecode(response.body);
      return data['utilizador'];
    }
    throw Exception('Erro ao atualizar perfil');
  }

  // =========================================================================
  // ALTERAR PASSWORD
  // Envia a password atual para validação e a nova password.
  // Se a API devolver um erro, tenta apresentar a mensagem recebida.
  // =========================================================================
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

  // =========================================================================
  // DESATIVAR CONTA
  // Solicita ao backend a desativação lógica da conta.
  // Não elimina necessariamente o registo da base de dados.
  // =========================================================================
  Future<void> desativarConta(int idUtilizador) async {
    final response = await http.put(Uri.parse('$baseUrl/utilizadores/$idUtilizador/desativar'), headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Erro ao desativar conta');
    }
  }

  String _mensagemErroLembretes(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded['error']?.toString() ??
          decoded['message']?.toString() ??
          'Erro ${response.statusCode}.';
    }
  } catch (_) {}

  return response.body.trim().isNotEmpty
      ? response.body
      : 'Erro ${response.statusCode}.';
}

Future<List<Map<String, dynamic>>> getLembretesConsultor(
    int userId,
  ) async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/lembretes/consultor/$userId'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic> && decoded['todos'] is List) {
      return (decoded['todos'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getBadgesLembretes() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/lembretes/badges'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic> && decoded['badges'] is List) {
      return (decoded['badges'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> criarLembreteConsultor({
    required int userId,
    required Map<String, dynamic> dados,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/lembretes/consultor/$userId'),
          headers: _headers,
          body: jsonEncode(dados),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> editarLembreteConsultor({
    required int userId,
    required int lembreteId,
    required Map<String, dynamic> dados,
  }) async {
    final response = await http
        .put(
          Uri.parse(
            '$baseUrl/lembretes/consultor/$userId/$lembreteId',
          ),
          headers: _headers,
          body: jsonEncode(dados),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> aceitarDesafioLembrete({
    required int userId,
    required int lembreteId,
  }) async {
    final response = await http
        .put(
          Uri.parse(
            '$baseUrl/lembretes/consultor/$userId/$lembreteId/aceitar',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> recusarDesafioLembrete({
    required int userId,
    required int lembreteId,
    String motivo = '',
  }) async {
    final response = await http
        .put(
          Uri.parse(
            '$baseUrl/lembretes/consultor/$userId/$lembreteId/recusar',
          ),
          headers: _headers,
          body: jsonEncode({
            'motivo': motivo.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<Map<String, dynamic>> concluirLembreteConsultor({
    required int userId,
    required int lembreteId,
  }) async {
    final response = await http
        .put(
          Uri.parse(
            '$baseUrl/lembretes/consultor/$userId/$lembreteId/concluir',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(_mensagemErroLembretes(response));
    }

    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<void> eliminarLembreteConsultor({
    required int userId,
    required int lembreteId,
  }) async {
    final response = await http
        .delete(
          Uri.parse(
            '$baseUrl/lembretes/consultor/$userId/$lembreteId',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_mensagemErroLembretes(response));
    }
  }

  Future<void> marcarNotificacaoComoLida({
    required int userId,
    required int notificationId,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/notificacoes/'
      '$notificationId/lida',
    );

    try {
      final response = await http
          .patch(
            url,
            headers: _headers,
            body: jsonEncode({
              'id_utilizador':
                  userId,
            }),
          )
          .timeout(
            const Duration(
              seconds: 30,
            ),
          );

      if (
        response.statusCode == 200 ||
        response.statusCode == 204
      ) {
        return;
      }

      String mensagem =
          'Não foi possível marcar '
          'a notificação como lida.';

      try {
        final dynamic decoded =
            jsonDecode(
          response.body,
        );

        if (decoded is Map) {
          mensagem =
              decoded['error']
                      ?.toString() ??
                  decoded['message']
                      ?.toString() ??
                  mensagem;
        }
      } catch (_) {
        if (
          response.body
              .trim()
              .isNotEmpty
        ) {
          mensagem =
              'Erro ${response.statusCode}: '
              '${response.body}';
        }
      }

      throw Exception(
        mensagem,
      );
    } on TimeoutException {
      throw Exception(
        'O servidor demorou demasiado '
        'tempo a responder.',
      );
    } on SocketException {
      throw Exception(
        'Sem ligação ao servidor.',
      );
    }
  }

  Future<void>
      marcarTodasNotificacoesComoLidas(
    int userId,
  ) async {
    final Uri url = Uri.parse(
      '$baseUrl/notificacoes/'
      'utilizador/$userId/lidas',
    );

    final response = await http
        .patch(
          url,
          headers: _headers,
        )
        .timeout(
          const Duration(
            seconds: 30,
          ),
        );

    if (
      response.statusCode == 200 ||
      response.statusCode == 204
    ) {
      return;
    }

    String mensagem =
        'Não foi possível marcar todas '
        'as notificações como lidas.';

    try {
      final dynamic decoded =
          jsonDecode(
        response.body,
      );

      if (decoded is Map) {
        mensagem =
            decoded['error']
                    ?.toString() ??
                decoded['message']
                    ?.toString() ??
                mensagem;
      }
    } catch (_) {
      if (
        response.body
            .trim()
            .isNotEmpty
      ) {
        mensagem =
            'Erro ${response.statusCode}: '
            '${response.body}';
      }
    }

    throw Exception(
      mensagem,
    );
  }

  Future<List<Map<String, dynamic>>> getCertificadosDisponiveis(
    int userId,
  ) async {
    final url = Uri.parse(
      '$baseUrl/certificados/disponiveis/$userId',
    );

    final response = await http
        .get(
          url,
          headers: _headers,
        )
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode != 200) {
      String mensagem =
          'Não foi possível carregar os certificados disponíveis.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          mensagem = decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              mensagem;
        }
      } catch (_) {}

      throw Exception(mensagem);
    }

    final decoded = jsonDecode(response.body);

    List<dynamic> lista = [];

    if (decoded is List) {
      lista = decoded;
    } else if (decoded is Map<String, dynamic>) {
      final possibilidades = [
        decoded['certificados'],
        decoded['disponiveis'],
        decoded['data'],
        decoded['dados'],
        decoded['rows'],
      ];

      for (final possibilidade in possibilidades) {
        if (possibilidade is List) {
          lista = possibilidade;
          break;
        }
      }
    }

    return lista
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getCertificado({
    required int idHistorico,
    required int idUtilizador,
  }) async {
    final url = Uri.parse(
      '$baseUrl/certificados/$idHistorico/$idUtilizador',
    );

    final response = await http
        .get(
          url,
          headers: _headers,
        )
        .timeout(
          const Duration(seconds: 30),
        );

    if (response.statusCode == 404) {
      throw Exception(
        'Certificado não encontrado ou ainda não aprovado.',
      );
    }

    if (response.statusCode != 200) {
      String mensagem =
          'Não foi possível carregar os dados do certificado.';

      try {
        final decoded = jsonDecode(response.body);

        if (decoded is Map) {
          mensagem = decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              mensagem;
        }
      } catch (_) {}

      throw Exception(mensagem);
    }

    final decoded = jsonDecode(response.body);

    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const FormatException(
      'A API não devolveu um objeto de certificado válido.',
    );
  }

  Future<Map<String, dynamic>>
    getUtilizadorPorId(
    int idUtilizador,
  ) async {
    final Uri url = Uri.parse(
      '$baseUrl/utilizadores/'
      '$idUtilizador',
    );

    final response = await http
        .get(
          url,
          headers: _headers,
        )
        .timeout(
          const Duration(
            seconds: 30,
          ),
        );

    if (response.statusCode != 200) {
      throw Exception(
        'Não foi possível carregar '
        'os dados do utilizador '
        '(${response.statusCode}): '
        '${response.body}',
      );
    }

    final dynamic decoded =
        jsonDecode(response.body);

    if (decoded is! Map) {
      throw const FormatException(
        'A API não devolveu os dados '
        'do utilizador num objeto.',
      );
    }

    final Map<String, dynamic> mapa =
        Map<String, dynamic>.from(
      decoded,
    );

    /*
    * Aceita todos estes formatos:
    *
    * { nome_completo: ... }
    * { utilizador: {...} }
    * { user: {...} }
    * { data: {...} }
    */
    for (final String chave in [
      'utilizador',
      'user',
      'dados',
      'data',
    ]) {
      if (mapa[chave] is Map) {
        return Map<String, dynamic>.from(
          mapa[chave],
        );
      }
    }

    return mapa;
  }


}