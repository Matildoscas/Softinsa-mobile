class Utilizador {
  final int id;
  final String nome;
  final String email;
  final String contacto;
  final DateTime? dataCriacao;
  final String estadoConta;
  final String password;
  final bool aceitarTermos; 

  Utilizador({
    required this.id,
    required this.nome,
    required this.email,
    required this.contacto,
    required this.dataCriacao,
    required this.estadoConta,
    required this.password, 
    this.aceitarTermos = false, 
  });

  // Converter JSON ou Linha do SQFlite → Objeto Utilizador (Parsing Seguro)
  factory Utilizador.fromJson(Map<String, dynamic> json) {
    return Utilizador(
      id: json['id_utilizador'] as int,
      nome: json['nome_completo'] ?? '',
      email: json['email'] ?? '',
      contacto: json['contacto'] ?? '',
      estadoConta: json['estado_conta'] ?? '',
      password: json['password'] ?? '',
      
      // Tratamento robusto para datas vindas como String do pgAdmin ou SQLite
      dataCriacao: json['data_criacao_conta'] != null 
          ? DateTime.tryParse(json['data_criacao_conta'].toString()) 
          : (json['data_criacao'] != null 
              ? DateTime.tryParse(json['data_criacao'].toString()) 
              : null),
              
      // REESCRITA OFFLINE-FIRST: Suporta true/false da API e 1/0 (INTEGER) do SQFlite
      aceitarTermos: json['aceitou_termos'] == true || 
                     json['aceitou_termos'] == 1 || 
                     json['aceitar_termos'] == true || 
                     json['aceitar_termos'] == 1,
    );
  }

  // Converter Objeto Utilizador → Mapa/JSON (Pronto para o SQFlite ou para enviar via API)
  Map<String, dynamic> toJson() {
    return {
      'id_utilizador': id,
      'nome_completo': nome,
      'email': email,
      'contacto': contacto,
      'estado_conta': estadoConta,
      'password': password,
      'data_criacao_conta': dataCriacao?.toIso8601String(),
      // Armazena como numérico no SQLite (Padrão 1 para verdadeiro, 0 para falso)
      'aceitou_termos': aceitarTermos ? 1 : 0,
    };
  }
}