// ============================================================
// model.dart
// Define o modelo de dados Utilizador — a entidade central
// da aplicação. Serve de contrato entre três camadas:
//   - API REST (JSON do backend Node.js)
//   - Base de dados local SQLite (via SQFlite)
//   - Widgets Flutter (objetos tipados em Dart)
// ============================================================


class Utilizador {
  // Campos com 'final' porque um objeto Utilizador é imutável
  // após ser criado — para alterar dados, cria-se um novo objeto.
  final int id;
  final String nome;
  final String email;
  final String contacto;
  final DateTime? dataCriacao; // Nullable: pode não vir preenchida da API
  final String estadoConta;
  final String password;
  final bool aceitarTermos;


  // ============================================================
  // CONSTRUTOR PRINCIPAL
  // Todos os campos são obrigatórios exceto aceitarTermos,
  // que tem valor por defeito false para contextos onde
  // a informação não é relevante (ex: leitura offline).
  // ============================================================
  Utilizador({
    required this.id,
    required this.nome,
    required this.email,
    required this.contacto,
    required this.dataCriacao,
    required this.estadoConta,
    required this.password,
    this.aceitarTermos = false, // Valor por defeito: false
  });


  // ============================================================
  // FACTORY CONSTRUCTOR: fromJson
  // Converte um Map<String, dynamic> num objeto Utilizador.
  // Suporta simultaneamente duas origens de dados diferentes:
  //   - API REST: chaves como 'aceitar_termos' (boolean)
  //   - SQLite local: chaves como 'aceitou_termos' (integer 0/1)
  //
  // O operador '??' (null-coalescing) garante valores por defeito
  // se uma chave não existir ou for null no mapa recebido.
  // ============================================================
  factory Utilizador.fromJson(Map<String, dynamic> json) {
    return Utilizador(
      // 'as int' garante que o id é sempre um inteiro tipado.
      id: json['id_utilizador'] as int,

      nome:       json['nome_completo'] ?? '',
      email:      json['email']         ?? '',
      contacto:   json['contacto']      ?? '',
      estadoConta: json['estado_conta'] ?? '',
      password:   json['password']      ?? '',

      // DateTime.tryParse converte a string ISO 8601 da API/SQLite
      // para DateTime. Se a string for inválida, devolve null
      // em vez de lançar uma exceção.
      dataCriacao: json['data_criacao'] != null
          ? DateTime.tryParse(json['data_criacao'].toString())
          : null,

      // Mapeamento defensivo para os termos:
      // A API pode enviar true (boolean) ou 1 (integer).
      // O SQLite guarda sempre como integer (0 ou 1).
      // Esta tripla condição garante compatibilidade com ambas as origens.
      aceitarTermos: json['aceitar_termos'] == true  ||
                     json['aceitar_termos'] == 1     ||
                     json['aceitou_termos'] == 1,
    );
  }


  // ============================================================
  // MÉTODO: toJson
  // Converte o objeto Utilizador para um Map<String, dynamic>,
  // normalizado para inserção direta nas tabelas do SQLite.
  //
  // Diferença importante em relação ao formato da API:
  //   - A API usa 'aceitar_termos' com boolean
  //   - O SQLite usa 'aceitou_termos' com integer (0 ou 1)
  //     porque o SQLite não tem tipo booleano nativo.
  // ============================================================
  Map<String, dynamic> toJson() {
    return {
      'id_utilizador': id,
      'nome_completo': nome,
      'email':         email,
      'contacto':      contacto,
      'estado_conta':  estadoConta,
      'password':      password,

      // toIso8601String() converte DateTime para string normalizada
      // ex: "2025-03-15T10:30:00.000". O operador ?. evita erro
      // se dataCriacao for null.
      'data_criacao':  dataCriacao?.toIso8601String(),

      // Conversão bool → integer para compatibilidade com SQLite.
      // true → 1, false → 0
      'aceitou_termos': aceitarTermos ? 1 : 0,
    };
  }
}
