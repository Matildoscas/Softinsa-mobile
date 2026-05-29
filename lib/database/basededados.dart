import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Basededados {
  static final Basededados _instance = Basededados._internal();
  static Database? _database;

  factory Basededados() => _instance;

  Basededados._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'softinsa.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE utilizador (
        id_utilizador INTEGER PRIMARY KEY,
        nome_completo TEXT,
        email TEXT,
        contacto TEXT,
        data_criacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        estado_conta TEXT,
        password TEXT,
        aceitar_termos INTEGER DEFAULT 0,
        id_area INTEGER
      )
    ''');
    // ✅ aceitar_termos: BOOLEAN → INTEGER (SQLite não tem BOOLEAN nativo)
    // ✅ id_area adicionado para consistência com o registo
  }

  // INSERT
  Future<int> inserirUtilizador(Map<String, dynamic> user) async {
    final db = await database;
    // ✅ Converte bool → int antes de guardar (SQLite não suporta bool)
    final userParaGuardar = Map<String, dynamic>.from(user);
    if (userParaGuardar['aceitar_termos'] is bool) {
      userParaGuardar['aceitar_termos'] = userParaGuardar['aceitar_termos'] ? 1 : 0;
    }
    return await db.insert('utilizador', userParaGuardar);
  }

  // GET
  Future<List<Map<String, dynamic>>> listarUtilizadores() async {
    final db = await database;
    return await db.query('utilizador');
  }

  // DELETE
  Future<int> eliminarUtilizador(int id) async {
    final db = await database;
    return await db.delete(
      'utilizador',
      where: 'id_utilizador = ?',
      whereArgs: [id],
    );
  }

  // UPDATE
  Future<int> atualizarUtilizador(Map<String, dynamic> user) async {
    final db = await database;
    // ✅ Converte bool → int antes de atualizar
    final userParaAtualizar = Map<String, dynamic>.from(user);
    if (userParaAtualizar['aceitar_termos'] is bool) {
      userParaAtualizar['aceitar_termos'] = userParaAtualizar['aceitar_termos'] ? 1 : 0;
    }
    return await db.update(
      'utilizador',
      userParaAtualizar,
      where: 'id_utilizador = ?',
      whereArgs: [userParaAtualizar['id_utilizador']],
    );
  }
}