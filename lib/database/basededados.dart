// ============================================================
// basededados.dart
// Camada de persistência local da app — base de dados SQLite
// gerida pela biblioteca SQFlite.
//
// Responsabilidades:
//   - Criar e manter o esquema local com 21 tabelas
//   - Fornecer métodos genéricos de leitura, escrita e remoção
//   - Servir de cache offline quando a API não está disponível
//
// Padrão de design: Singleton — uma única ligação à BD em toda a app.
// ============================================================

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class Basededados {

  // ============================================================
  // PADRÃO SINGLETON
  // _instance é a única instância desta classe em toda a app.
  // _database é a ligação efetiva ao ficheiro SQLite no dispositivo.
  // Ambos são static: partilhados por todas as referências à classe.
  // ============================================================
  static final Basededados _instance = Basededados._internal();
  static Database? _database;

  // ============================================================
  // FACTORY CONSTRUCTOR
  // Sempre que se escreve Basededados() em qualquer parte da app,
  // este factory devolve sempre a mesma instância _instance
  // em vez de criar uma nova. Garante que só existe uma ligação
  // à base de dados ao mesmo tempo.
  // ============================================================
  factory Basededados() => _instance;

  // Construtor privado — só pode ser chamado dentro desta classe,
  // na linha de inicialização de _instance acima.
  Basededados._internal();


  // ============================================================
  // GETTER: database
  // Ponto de acesso à base de dados em toda a app.
  // Implementa lazy initialization: só abre a BD na primeira
  // vez que é pedida, e depois reutiliza sempre a mesma ligação.
  // ============================================================
  Future<Database> get database async {
    // Se a BD já foi aberta anteriormente, devolve-a diretamente.
    if (_database != null) return _database!;
    // Primeira vez: inicializa e guarda a referência.
    _database = await _initDatabase();
    return _database!;
  }


  // ============================================================
  // MÉTODO PRIVADO: _initDatabase
  // Determina o caminho físico do ficheiro no dispositivo e
  // abre (ou cria, se não existir) a base de dados SQLite.
  // ============================================================
  Future<Database> _initDatabase() async {
    // getDatabasesPath() devolve a pasta de dados da app no dispositivo.
    // join() constrói o caminho completo: ex. "/data/user/0/.../softinsa.db"
    String path = join(await getDatabasesPath(), 'softinsa.db');

    return await openDatabase(
      path,
      version: 1,        // Versão do esquema — usada para migrações futuras
      onCreate: _onCreate, // Callback chamado apenas na primeira instalação
    );
  }


  // ============================================================
  // MÉTODO PRIVADO: _onCreate
  // Cria as 21 tabelas do esquema local.
  // Só é executado uma única vez: quando a app é instalada pela
  // primeira vez e o ficheiro softinsa.db ainda não existe.
  //
  // O esquema replica a estrutura do PostgreSQL do backend para
  // permitir modo offline completo. As chaves estrangeiras definem
  // o comportamento em cascata quando registos pai são eliminados.
  // ============================================================
  Future<void> _onCreate(Database db, int version) async {

    // ── TABELA 1: UTILIZADOR ──────────────────────────────────
    // Guarda os dados de autenticação e perfil do utilizador.
    // email é UNIQUE para impedir duplicados locais.
    // aceitou_termos e email_verificado são INTEGER (0/1)
    // porque SQLite não tem tipo BOOLEAN nativo.
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

    // ── TABELA 2: ADMINISTRADOR ───────────────────────────────
    // Extensão da tabela utilizador para o papel de Administrador.
    // ON DELETE CASCADE: se o utilizador pai for eliminado,
    // o registo de administrador é eliminado automaticamente.
    await db.execute('''
      CREATE TABLE administrador (
        id_utilizador INTEGER PRIMARY KEY,
        entidades_geridas TEXT,
        entervencoes INTEGER,
        FOREIGN KEY (id_utilizador) REFERENCES utilizador (id_utilizador) ON DELETE CASCADE
      )
    ''');

    // ── TABELA 3: LEARNINGPATHS ───────────────────────────────
    // Percursos de aprendizagem que agrupam várias Service Lines.
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

    // ── TABELA 4: SERVICELINELEADER ───────────────────────────
    // Extensão do utilizador para o papel de Service Line Leader.
    // Guarda estatísticas de aprovações/rejeições realizadas.
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

    // ── TABELA 5: SERVICELINE ─────────────────────────────────
    // Uma área de negócio/tecnologia dentro de um Learning Path.
    // ON DELETE SET NULL: se o learning path ou o líder forem
    // eliminados, a Service Line não é apagada — apenas perde
    // a referência (fica com NULL).
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

    // ── TABELA 6: AREAS ───────────────────────────────────────
    // Sub-divisão de uma Service Line. É a área de especialização
    // onde o consultor se enquadra (ex: SAP, Cloud, Data).
    // imagem BLOB: guarda a imagem em binário diretamente na BD.
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

    // ── TABELA 7: NIVEIS ──────────────────────────────────────
    // Níveis de progressão dentro de uma Área (ex: A, B, C, D, E).
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

    // ── TABELA 8: BADGE_MODELO ────────────────────────────────
    // Template/modelo de um badge — define o que é o badge,
    // quantos pontos vale, quando expira, e a que nível pertence.
    // É diferente do badge_atribuido (que é a instância concreta
    // de um modelo dado a um consultor específico).
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

    // ── TABELA 9: BADGE_ATRIBUIDO ─────────────────────────────
    // Instância concreta de um badge_modelo atribuída a um consultor.
    // Guarda a data de atribuição, validade e estado atual.
    // A relação com o consultor é feita através da tabela OBTEM (N:M).
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

    // ── TABELA 10: CONSULTOR ──────────────────────────────────
    // Extensão do utilizador para o papel de Consultor.
    // Guarda o progresso, pontos acumulados e estatísticas.
    // foto BLOB: foto de perfil em binário.
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

    // ── TABELA 11: CANDIDATURA_PEDIDO ─────────────────────────
    // Submissão de um consultor a um badge.
    // É o primeiro passo do fluxo de validação:
    // Consultor → Talent Manager → Service Line Leader → Histórico
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

    // ── TABELA 12: TALENTMANAGER ──────────────────────────────
    // Extensão do utilizador para o papel de Talent Manager.
    // Guarda estatísticas de avaliação de candidaturas.
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

    // ── TABELA 13: CANDIDATURA_TM ─────────────────────────────
    // Segunda fase do fluxo: avaliação pelo Talent Manager.
    // Ligada à candidatura_pedido original.
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

    // ── TABELA 14: CANDIDATURA_SLL ────────────────────────────
    // Terceira fase do fluxo: avaliação pelo Service Line Leader.
    // Ligada à avaliação do TM.
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

    // ── TABELA 15: CANDIDATURA_HISTORICO ──────────────────────
    // Resultado final do fluxo de validação.
    // Guarda o estado final (APROVADO/REJEITADO), durações,
    // e contagem de requisitos cumpridos vs em falta.
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

    // ── TABELA 16: REQUISITOS ─────────────────────────────────
    // Lista de requisitos que um consultor tem de cumprir
    // para conquistar um determinado badge_modelo.
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

    // ── TABELA 17: EVIDENCIAS ─────────────────────────────────
    // Ficheiros ou descrições submetidas pelo consultor para
    // comprovar que cumpriu cada requisito de uma candidatura.
    // caminho_ficheiro: path local ou URL do ficheiro submetido.
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

    // ── TABELA 18: LINKS ──────────────────────────────────────
    // URLs de recursos externos associados a requisitos.
    // Ex: link para certificação online que comprova um requisito.
    await db.execute('''
      CREATE TABLE links (
        id_link INTEGER PRIMARY KEY,
        id_requisitos INTEGER,
        url TEXT,
        FOREIGN KEY (id_requisitos) REFERENCES requisitos (id_requisitos) ON DELETE CASCADE
      )
    ''');

    // ── TABELA 19: NOTIFICACOES ───────────────────────────────
    // Cache local das notificações recebidas pelo utilizador.
    // Permite consultar notificações em modo offline.
    await db.execute('''
      CREATE TABLE notificacoes (
        id_notificacoes INTEGER PRIMARY KEY,
        tipo_notificacao TEXT,
        conteudo TEXT,
        data_envio TEXT,
        estado_notificacao TEXT
      )
    ''');

    // ── TABELA 20: OBTEM (Relação N:M) ────────────────────────
    // Tabela intermédia que liga consultores a badges atribuídos.
    // Um consultor pode ter muitos badges; um badge pode ser
    // atribuído a muitos consultores. A chave primária composta
    // (id_utilizador, id_badge_atribuido) garante unicidade.
    await db.execute('''
      CREATE TABLE obtem (
        id_utilizador INTEGER,
        id_badge_atribuido INTEGER,
        PRIMARY KEY (id_utilizador, id_badge_atribuido),
        FOREIGN KEY (id_utilizador) REFERENCES consultor (id_utilizador) ON DELETE CASCADE,
        FOREIGN KEY (id_badge_atribuido) REFERENCES badge_atribuido (id_badge_atribuido) ON DELETE CASCADE
      )
    ''');

    // ── TABELA 21: RECEBIDO (Relação N:M) ─────────────────────
    // Tabela intermédia que liga notificações a utilizadores.
    // Uma notificação pode ser enviada a vários utilizadores;
    // um utilizador pode receber várias notificações.
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


  // ============================================================
  // MÉTODO GENÉRICO: salvarRegisto (UPSERT)
  // Insere um novo registo ou substitui um existente com a
  // mesma chave primária (ConflictAlgorithm.replace).
  // Usado pelo Provider e pelos ecrãs para sincronizar dados
  // da API para o SQLite local (mirroring/cache).
  //
  // Parâmetros:
  //   tabela — nome da tabela (ex: 'utilizador', 'badge_atribuido')
  //   dados  — mapa com os campos e valores a guardar
  // ============================================================
  Future<void> salvarRegisto(String tabela, Map<String, dynamic> dados) async {
    final db = await database;
    await db.insert(
      tabela,
      dados,
      // replace: se já existir um registo com a mesma PRIMARY KEY,
      // apaga-o e insere o novo — comportamento de UPSERT.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }


  // ============================================================
  // MÉTODO GENÉRICO: listarTabela (SELECT *)
  // Devolve todos os registos de uma tabela como lista de mapas.
  // Usado como fallback offline quando a API não está disponível:
  // os ecrãs leem os dados que ficaram em cache no último sync.
  //
  // Parâmetros:
  //   tabela — nome da tabela a consultar
  // ============================================================
  Future<List<Map<String, dynamic>>> listarTabela(String tabela) async {
    final db = await database;
    return await db.query(tabela); // Equivalente a SELECT * FROM tabela
  }


  // ============================================================
  // MÉTODO GENÉRICO: eliminarRegisto (DELETE por chave)
  // Remove um registo específico de qualquer tabela.
  // Genérico para funcionar com qualquer entidade — basta
  // passar o nome do campo chave e o valor a eliminar.
  //
  // Parâmetros:
  //   tabela      — nome da tabela (ex: 'notificacoes')
  //   nomeChaveId — nome do campo chave (ex: 'id_notificacoes')
  //   id          — valor da chave do registo a eliminar
  //
  // Devolve o número de linhas afetadas (0 se não encontrou).
  // ============================================================
  Future<int> eliminarRegisto(String tabela, String nomeChaveId, int id) async {
    final db = await database;
    return await db.delete(
      tabela,
      where: '$nomeChaveId = ?', // Condição parametrizada (previne SQL injection)
      whereArgs: [id],           // Valor substituído no placeholder '?'
    );
  }
}
