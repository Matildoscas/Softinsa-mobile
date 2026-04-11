import 'package:postgres/postgres.dart';

class DatabaseService {
  final String host = '10.0.2.2';
  final String dbName = 'softinsa_database';
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
}