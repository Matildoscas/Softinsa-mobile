import 'package:postgres/postgres.dart';

class DatabaseService {
  final String host = '10.0.2.2';
  final String dbName = 'basedados_softinsa';
  final String dbUser = 'postgres'; // Utilizador da BD
  final String dbPassword = 'postgres'; // Password da BD
  final int port = 5432;

  // Centralizei a criação do Endpoint para evitar repetição
  Endpoint get _endpoint => Endpoint(
        host: host,
        database: dbName,
        username: dbUser,
        password: dbPassword,
        port: port,
      );

  // No ficheiro database_service.dart
  Future<int?> registrarUtilizador({
    required String nome,
    required String email,
    required String password,
    required bool aceitouTermos,
  }) async {
    final connection = await Connection.open(_endpoint, 
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      int? idNovoUtilizador; // Variável para guardar o ID

      await connection.runTx((session) async {
        final resUtilizador = await session.execute(
          Sql.named(
            'INSERT INTO UTILIZADOR (nome_completo, email, password, aceitou_termos, cargo, estado) '
            'VALUES (@nome, @email, @pass, @termos, @cargo, @estado) RETURNING id_utilizador'
          ),
          parameters: {
            'nome': nome,
            'email': email,
            'pass': password, 
            'termos': aceitouTermos,
            'cargo': 'Consultor',
            'estado': true,
          },
        );

        // Guarda o ID retornado pelo PostgreSQL
        idNovoUtilizador = resUtilizador.first[0] as int;

        await session.execute(
          Sql.named('INSERT INTO UTILIZADOR_ROLE (id_utilizador, id_role) VALUES (@idU, (SELECT id_role FROM ROLE WHERE nome = \'Consultor\' LIMIT 1))'),
          parameters: {
            'idU': idNovoUtilizador,
          },
        );
      });

      return idNovoUtilizador; // Devolve o ID em caso de sucesso
    } catch (e) {
      print('Erro ao registrar: $e');
      return null; // Devolve null em caso de erro
    } finally {
      await connection.close();
    }
  }

  Future<List<Map<String, dynamic>>> obterAreas() async {
    final connection = await Connection.open(_endpoint, settings: ConnectionSettings(sslMode: SslMode.disable));
    try {
      final result = await connection.execute('SELECT id_area, nome FROM AREA');
      return result.map((row) => {'id': row[0], 'nome': row[1]}).toList();
    } finally {
      await connection.close();
    }
  }

  Future<bool> atualizarAreaUtilizador(int idUtilizador, int idArea) async {
    final connection = await Connection.open(_endpoint, 
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      // 1. Verificar se a linha existe e fazer o UPDATE
      // Usamos o subquery para garantir que estamos a mexer no papel de Consultor
      final result = await connection.execute(
        Sql.named(
          'UPDATE UTILIZADOR_ROLE '
          'SET id_area = @idA '
          'WHERE id_utilizador = @idU '
          'AND id_role = (SELECT id_role FROM ROLE WHERE nome = \'Consultor\' LIMIT 1)'
        ),
        parameters: {
          'idA': idArea,
          'idU': idUtilizador,
        },
      );

      // No postgres package, o result pode indicar quantas linhas foram afetadas
      print('Colunas afetadas: ${result.affectedRows}');
      
      return result.affectedRows > 0;
    } catch (e) {
      print('Erro detalhado ao atualizar área: $e');
      return false;
    } finally {
      await connection.close();
    }
  }

  Future<Map<String, dynamic>?> loginUtilizador(String email, String password) async {
    final connection = await Connection.open(_endpoint, 
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      // Procuramos o utilizador, a sua área e somamos os pontos dos badges atribuídos
      final result = await connection.execute(
        Sql.named(
          'SELECT u.id_utilizador, u.nome_completo, u.email, '
          'COALESCE(SUM(b.pontos), 0) as total_pontos, '
          'COUNT(ba.id_badge_atrib) as total_badges '
          'FROM UTILIZADOR u '
          'LEFT JOIN BADGE_ATRIBUIDO ba ON u.id_utilizador = ba.id_utilizador '
          'LEFT JOIN BADGE b ON ba.id_badge = b.id_badge '
          'WHERE u.email = @email AND u.password = @pass '
          'GROUP BY u.id_utilizador'
        ),
        parameters: {'email': email, 'pass': password},
      );

      if (result.isEmpty) return null;

      final row = result.first;
      return {
        'id': row[0],
        'nome': row[1],
        'email': row[2],
        'pontos': row[3],
        'badges': row[4],
      };
    } finally {
      await connection.close();
    }
  }

  Future<List<Map<String, dynamic>>> obterBadgesComProgresso(int idUtilizador) async {
    final connection = await Connection.open(_endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      final result = await connection.execute(
        Sql.named(
          '''
          SELECT b.nome, b.descricao, b.pontos
          FROM BADGE b
          WHERE b.id_badge NOT IN (
            SELECT id_badge FROM BADGE_ATRIBUIDO WHERE id_utilizador = @id
          )
          LIMIT 1
          '''
        ),
        parameters: {'id': idUtilizador},
      );

      return result.map((row) => {
        'nome': row[0],
        'descricao': row[1],
        'pontos': row[2],
        'progress': 0.0, // 🔥 lógica futura
      }).toList();

    } finally {
      await connection.close();
    }
  }

  Future<List<Map<String, dynamic>>> obterBadgesRecomendados(int idUtilizador) async {
    final connection = await Connection.open(_endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      final result = await connection.execute(
        Sql.named(
          '''
          SELECT b.nome, b.descricao, b.pontos
          FROM BADGE b
          JOIN NIVEL n ON b.id_nivel = n.id_nivel
          JOIN AREA a ON n.id_area = a.id_area
          JOIN UTILIZADOR u ON u.id_area = a.id_area
          WHERE u.id_utilizador = @id
          AND b.id_badge NOT IN (
            SELECT id_badge FROM BADGE_ATRIBUIDO WHERE id_utilizador = @id
          )
          LIMIT 1
          '''
        ),
        parameters: {'id': idUtilizador},
      );

      return result.map((row) => {
        'nome': row[0],
        'descricao': row[1],
        'pontos': row[2],
      }).toList();

    } finally {
      await connection.close();
    }
  }

  Future<Map<String, dynamic>?> obterBadgeEspecial() async {
    final connection = await Connection.open(_endpoint,
        settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      final result = await connection.execute(
        '''
        SELECT nome, descricao, pontos 
        FROM BADGE
        ORDER BY pontos DESC
        LIMIT 1
        '''
      );

      if (result.isEmpty) return null;

      return {
        'nome': result.first[0],
        'descricao': result.first[1],
        'pontos': ((result.first[2] as int?) ?? 0) * 2, // 🔥 dobra pontos
        'dias': 3,
      };

    } finally {
      await connection.close();
    }
  }

 //Lógica de Aprovação Dupla (TM e SLL)
  Future<void> avaliarCandidatura(int idCandidatura, int idAvaliador, String estado) async {
    final connection = await Connection.open(_endpoint, settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      await connection.runTx((session) async {
        // 1. Inserir a avaliação (SLL ou TM)
        await session.execute(
          Sql.named('INSERT INTO candidatura_avaliacao (id_candidatura, id_avaliador, estado, data_avaliacao) '
                    'VALUES (@idC, @idA, @est, CURRENT_TIMESTAMP)'),
          parameters: {'idC': idCandidatura, 'idA': idAvaliador, 'est': estado},
        );

        // 2. Verificar se já existem 2 aprovações para esta candidatura
        final res = await session.execute(
          Sql.named('SELECT COUNT(*) FROM candidatura_avaliacao WHERE id_candidatura = @idC AND estado = \'Aprovado\''),
          parameters: {'idC': idCandidatura},
        );

        int aprovacoes = res.first[0] as int;

        if (aprovacoes >= 2) {
          // 3. Atualizar estado da candidatura principal
          await session.execute(
            Sql.named('UPDATE candidatura SET estado = \'APPROVED\' WHERE id_candidatura = @idC'),
            parameters: {'idC': idCandidatura},
          );

          // 4. CRIAR O BADGE ATRIBUÍDO (O que gera o certificado na app)
          await session.execute(
            Sql.named('''
              INSERT INTO badge_atribuido (id_utilizador, id_badge, estado, data_conquista, url_publica)
              SELECT id_utilizador, id_badge, 'Ativo', CURRENT_TIMESTAMP, @url
              FROM candidatura WHERE id_candidatura = @idC
            '''),
            parameters: {
              'idC': idCandidatura,
              'url': 'softinsa.pt/badges/verificar/${idCandidatura}' // Exemplo de URL única
            },
          );
        }
      });
    } finally {
      await connection.close();
    }
  }

  //Obter Dados para o Certificado
  Future<Map<String, dynamic>?> obterDadosCertificado(int idBadgeAtribuido) async {
    final connection = await Connection.open(_endpoint, settings: ConnectionSettings(sslMode: SslMode.disable));

    try {
      final result = await connection.execute(
        Sql.named('''
          SELECT 
            u.nome_completo, 
            u.cargo, 
            b.nome as badge_nome, 
            n.nome as nivel_nome,
            ba.data_conquista,
            ba.id_badge_atrib as codigo_verificacao
          FROM badge_atribuido ba
          JOIN utilizador u ON ba.id_utilizador = u.id_utilizador
          JOIN badge b ON ba.id_badge = b.id_badge
          JOIN nivel n ON b.id_nivel = n.id_nivel
          WHERE ba.id_badge_atrib = @id
        '''),
        parameters: {'id': idBadgeAtribuido},
      );

      if (result.isEmpty) return null;
      final row = result.first;

      return {
        'nome': row[0],
        'cargo': row[1],
        'badge': row[2],
        'nivel': row[3],
        'data': row[4],
        'codigo': 'SL-${row[5]}', // Gera um código simulado como o da imagem
      };
    } finally {
      await connection.close();
    }
  }
}