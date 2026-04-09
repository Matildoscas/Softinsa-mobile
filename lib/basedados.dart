import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BaseDados {
  // Cria a instância única (Singleton) da classe para que a BD seja aberta apenas uma vez.
  static final BaseDados _instance = BaseDados._internal();
  
  // Variável privada que guarda a ligação ativa à base de dados.
  static Database? _database;

  // Construtor factory que retorna sempre a mesma instância única.
  factory BaseDados() {
    return _instance;
  }

  // Construtor privado nomeado, necessário para o padrão Singleton.
  BaseDados._internal();

  // Getter assíncrono para aceder à base de dados. 
  // Se não estiver inicializada, chama o _initDatabase.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Define o caminho no dispositivo e abre a base de dados.
  Future<Database> _initDatabase() async {
    // getDatabasesPath() devolve a pasta padrão para BDs no iOS/Android.
    String path = join(await getDatabasesPath(), 'bdpdm.db');
    
    // Abre a BD. Se a versão mudar, podes usar onUpgrade para alterar tabelas.
    return await openDatabase(
      path, 
      version: 1, 
      onCreate: _onCreate,
    );
  }

  // Método que cria as tabelas e insere dados iniciais quando a BD é criada pela primeira vez.
  Future<void> _onCreate(Database db, int version) async {
    // Executa o comando SQL para criar a tabela Utilizador.
    // NOTA: SQLite não tem tipo BOOLEAN ou DATE nativos, usamos INTEGER e TEXT.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS UTILIZADOR(
        id_utilizador INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
        nome_completo TEXT NOT NULL,
        email TEXT NOT NULL,
        password TEXT NOT NULL,
        contacto INTEGER NOT NULL,
        cargo TEXT NOT NULL,
        data_contratacao TEXT NOT NULL,
        estado INTEGER NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        aceitou_termos INTEGER NOT NULL
      )''');

    // Inserção de um utilizador inicial (Admin).
    // Usamos 1 para true e 0 para false nos campos 'estado' e 'aceitou_termos'.
    await db.rawInsert('''
      INSERT INTO UTILIZADOR (nome_completo, email, password, contacto, cargo, data_contratacao, estado, aceitou_termos)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', ['Admin', 'admin@example.com', 'password123', 999999999, 'Administrador', '2023-01-01', 1, 1]);
  }
}