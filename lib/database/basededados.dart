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
    // 1. UTILIZADOR
    await db.execute('''
      CREATE TABLE utilizador (
        id_utilizador INTEGER PRIMARY KEY,
        nome_completo TEXT,
        email TEXT UNIQUE,
        contacto TEXT,
        data_criacao_conta TEXT DEFAULT CURRENT_TIMESTAMP,
        estado_conta TEXT,
        ultimo_login TEXT,
        aceitou_termos INTEGER DEFAULT 0,
        password TEXT,
        email_softinsa TEXT,
        token_verificacao TEXT,
        email_verificado INTEGER DEFAULT 0
      )
    ''');

    // 2. ADMINISTRADOR
    await db.execute('''
      CREATE TABLE administrador (
        id_utilizador INTEGER PRIMARY KEY,
        entidades_geridas TEXT,
        entervencoes INTEGER,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');

    // 3. LEARNINGPATHS
    await db.execute('''
      CREATE TABLE learningpaths (
        id_learningpaths INTEGER PRIMARY KEY,
        nome_learningpaths TEXT,
        descricao_learningpaths TEXT,
        data_criacao TEXT,
        estado_learningpath TEXT,
        numero_servicelines INTEGER
      )
    ''');

    // 4. SERVICELINELEADER
    await db.execute('''
      CREATE TABLE servicelineleader (
        id_utilizador INTEGER PRIMARY KEY,
        estado_sll TEXT,
        espicializacoes TEXT,
        certificacoes TEXT,
        aprovacoes_realizadas INTEGER,
        rejeicoes_realizadas INTEGER,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');

    // 5. SERVICELINE
    await db.execute('''
      CREATE TABLE serviceline (
        id_serviceline INTEGER PRIMARY KEY,
        id_learningpaths INTEGER,
        id_utilizador INTEGER,
        nome_serviceline TEXT,
        descricao_serviceline TEXT,
        estado_serviceline TEXT,
        tipo_serviceline TEXT,
        data_criacao TEXT,
        numero_areas INTEGER,
        FOREIGN KEY (id_learningpaths) REFERENCES learningpaths (id_learningpaths) ON DELETE SET NULL,
        FOREIGN KEY (id_utilizador) REFERENCES servicelineleader (id_utilizador) ON DELETE SET NULL
      )
    ''');

    // 6. AREAS
    await db.execute('''
      CREATE TABLE areas (
        id_areas INTEGER PRIMARY KEY,
        id_serviceline INTEGER,
        nome_area TEXT,
        descricao_area TEXT,
        data_criacao TEXT,
        numero_consultores INTEGER,
        imagem BLOB,
        FOREIGN KEY (id_serviceline) REFERENCES serviceline (id_serviceline) ON DELETE CASCADE
      )
    ''');

    // 7. NIVEIS
    await db.execute('''
      CREATE TABLE niveis (
        id_nivel INTEGER PRIMARY KEY,
        id_areas INTEGER,
        nome_nivel TEXT,
        estado_nivel TEXT,
        data_criacao TEXT,
        FOREIGN KEY (id_areas) REFERENCES areas (id_areas) ON DELETE CASCADE
      )
    ''');

    // 8. BADGE_MODELO
    await db.execute('''
      CREATE TABLE badge_modelo (
        id_badge_modelo INTEGER PRIMARY KEY,
        id_serviceline INTEGER,
        id_areas INTEGER,
        id_nivel INTEGER,
        id_utilizador INTEGER,
        nome_badge TEXT,
        descricao_badge_modelo TEXT,
        data_criacao_badge_modelo TEXT,
        estado_badge_modelo TEXT,
        numero_requisitos INTEGER,
        pontos INTEGER,
        tempo_expiracao TEXT,
        imagem BLOB,
        FOREIGN KEY (id_nivel) REFERENCES niveis (id_nivel) ON DELETE SET NULL,
        FOREIGN KEY (id_utilizador) REFERENCES administrador (id_utilizador) ON DELETE SET NULL,
        FOREIGN KEY (id_serviceline) REFERENCES serviceline (id_serviceline) ON DELETE SET NULL,
        FOREIGN KEY (id_areas) REFERENCES areas (id_areas) ON DELETE SET NULL
      )
    ''');

    // 9. BADGE_ATRIBUIDO
    await db.execute('''
      CREATE TABLE badge_atribuido (
        id_badge_atribuido INTEGER PRIMARY KEY,
        id_badge_modelo INTEGER,
        data_atribuicao TEXT,
        data_validade TEXT,
        estado_badge_atribuido TEXT,
        FOREIGN KEY (id_badge_modelo) REFERENCES badge_modelo (id_badge_modelo) ON DELETE CASCADE
      )
    ''');

    // 10. CONSULTOR
    await db.execute('''
      CREATE TABLE consultor (
        id_utilizador INTEGER PRIMARY KEY,
        id_areas INTEGER,
        data_entrada_empresa INTEGER,
        data_entrada_area TEXT,
        progresso_nivel TEXT,
        candidatura_submetidas_total INTEGER,
        badges_conquistas_total INTEGER,
        pontos_atuais INTEGER,
        requisitos_pendentes INTEGER,
        ultima_atualizacao_perfil TEXT,
        estado_utilizador TEXT,
        foto BLOB,
        FOREIGN KEY (id_areas) REFERENCES areas (id_areas) ON DELETE SET NULL,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');

    // 11. CANDIDATURA_PEDIDO
    await db.execute('''
      CREATE TABLE candidatura_pedido (
        id_candidatura_pedido INTEGER PRIMARY KEY,
        id_badge_modelo INTEGER,
        id_utilizador INTEGER,
        data_submisao TEXT,
        data_validacao TEXT,
        estado_candidatura_pedido TEXT,
        FOREIGN KEY (id_utilizador) REFERENCES consultor (id_utilizador) ON DELETE CASCADE,
        FOREIGN KEY (id_badge_modelo) REFERENCES badge_modelo (id_badge_modelo) ON DELETE CASCADE
      )
    ''');

    // 12. TALENTMANAGER
    await db.execute('''
      CREATE TABLE talentmanager (
        id_utilizador INTEGER PRIMARY KEY,
        estado_tm TEXT,
        numero_consultores_acompanhados INTEGER,
        especializacao_tm TEXT,
        candidaturas_avaliadas INTEGER,
        candidaturas_aprovadas INTEGER,
        candidaturas_rejeitadas INTEGER,
        pedidos_imformacao_emitidos TEXT,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');

    // 13. CANDIDATURA_TM
    await db.execute('''
      CREATE TABLE candidatura_tm (
        id_candidatura_tm INTEGER PRIMARY KEY,
        id_candidatura_pedido INTEGER,
        id_utilizador INTEGER,
        data_rececao_tm TEXT,
        data_conclusao_tm TEXT,
        estado_candidaturatm TEXT,
        comentarios_tm TEXT,
        FOREIGN KEY (id_candidatura_pedido) REFERENCES candidatura_pedido (id_candidatura_pedido) ON DELETE CASCADE,
        FOREIGN KEY (id_utilizador) REFERENCES talentmanager (id_utilizador) ON DELETE SET NULL
      )
    ''');

    // 14. CANDIDATURA_SLL
    await db.execute('''
      CREATE TABLE candidatura_sll (
        id_candidatura_sll INTEGER PRIMARY KEY,
        id_candidatura_tm INTEGER,
        id_utilizador INTEGER,
        data_rececao_sll TEXT,
        data_concluao_sll TEXT,
        estado_candidaturasll TEXT,
        comentarios_sll TEXT,
        FOREIGN KEY (id_candidatura_tm) REFERENCES candidatura_tm (id_candidatura_tm) ON DELETE CASCADE,
        FOREIGN KEY (id_utilizador) REFERENCES servicelineleader (id_utilizador) ON DELETE SET NULL
      )
    ''');

    // 15. CANDIDATURA_HISTORICO
    await db.execute('''
      CREATE TABLE candidatura_historico (
        id_candidatura_historico INTEGER PRIMARY KEY,
        id_candidatura_sll INTEGER,
        data_submissao TEXT,
        data_avaliacao_tm TEXT,
        data_avaliacao_sll TEXT,
        data_entrada_historico TEXT,
        estado_final TEXT,
        motivo_estado_final TEXT,
        duracao_total TEXT,
        numero_requisitos_completos INTEGER,
        numero_requisitos_faltantes INTEGER,
        FOREIGN KEY (id_candidatura_sll) REFERENCES candidatura_sll (id_candidatura_sll) ON DELETE CASCADE
      )
    ''');

    // 16. REQUISITOS
    await db.execute('''
      CREATE TABLE requisitos (
        id_requisitos INTEGER PRIMARY KEY,
        id_badge_modelo INTEGER,
        id_utilizador INTEGER,
        nome_requisito TEXT,
        titulo TEXT,
        descricao_requisito TEXT,
        tipo_requisito TEXT,
        FOREIGN KEY (id_utilizador) REFERENCES administrador (id_utilizador) ON DELETE SET NULL,
        FOREIGN KEY (id_badge_modelo) REFERENCES badge_modelo (id_badge_modelo) ON DELETE CASCADE
      )
    ''');

    // 17. EVIDENCIAS
    await db.execute('''
      CREATE TABLE evidencias (
        id_evidencia INTEGER PRIMARY KEY,
        id_requisitos INTEGER,
        id_candidatura_pedido INTEGER,
        descricao TEXT,
        nome_ficheiro TEXT,
        formato_ficheiro TEXT,
        data_submissao TEXT,
        estado_evidencia TEXT,
        caminho_ficheiro TEXT,
        FOREIGN KEY (id_requisitos) REFERENCES requisitos (id_requisitos) ON DELETE CASCADE,
        FOREIGN KEY (id_candidatura_pedido) REFERENCES candidatura_pedido (id_candidatura_pedido) ON DELETE CASCADE
      )
    ''');

    // 18. LINKS
    await db.execute('''
      CREATE TABLE links (
        id_link INTEGER PRIMARY KEY,
        id_requisitos INTEGER,
        url TEXT,
        FOREIGN KEY (id_requisitos) REFERENCES requisitos (id_requisitos) ON DELETE CASCADE
      )
    ''');

    // 19. NOTIFICACOES
    await db.execute('''
      CREATE TABLE notificacoes (
        id_notificacoes INTEGER PRIMARY KEY,
        tipo_notificacao TEXT,
        conteudo TEXT,
        data_envio TEXT,
        estado_notificacao TEXT
      )
    ''');

    // 20. OBTEM (Tabela Intermédia N:M)
    await db.execute('''
      CREATE TABLE obtem (
        id_utilizador INTEGER,
        id_badge_atribuido INTEGER,
        PRIMARY KEY (id_utilizador, id_badge_atribuido),
        FOREIGN KEY (id_utilizador) REFERENCES consultor (id_utilizador) ON DELETE CASCADE,
        FOREIGN KEY (id_badge_atribuido) REFERENCES badge_atribuido (id_badge_atribuido) ON DELETE CASCADE
      )
    ''');

    // 21. RECEBIDO (Tabela Intermédia N:M)
    await db.execute('''
      CREATE TABLE recebido (
        id_notificacoes INTEGER,
        id_utilizador INTEGER,
        PRIMARY KEY (id_notificacoes, id_utilizador),
        FOREIGN KEY (id_notificacoes) REFERENCES notificacoes (id_notificacoes) ON DELETE CASCADE,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');
  }

  // ==========================================
  // MÉTODOS DE UPSERT GENÉRICOS (MUITO ÚTEIS)
  // ==========================================

  // Guarda ou atualiza qualquer registo numa tabela especificada
  Future<void> salvarRegisto(String tabela, Map<String, dynamic> dados) async {
    final db = await database;
    await db.insert(
      tabela,
      dados,
      conflictAlgorithm: ConflictAlgorithm.replace, // Transforma a inserção em Upsert automático
    );
  }

  // Lista todos os registos de uma determinada tabela
  Future<List<Map<String, dynamic>>> listarTabela(String tabela) async {
    final db = await database;
    return await db.query(tabela);
  }

  // Elimina um registo específico de uma tabela usando a chave primária fornecida
  Future<int> eliminarRegisto(String tabela, String nomeChaveId, int id) async {
    final db = await database;
    return await db.delete(
      tabela,
      where: '$nomeChaveId = ?',
      whereArgs: [id],
    );
  }
}