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

  // Converter JSON → Objeto
  factory Utilizador.fromJson(Map<String, dynamic> json) {
    return Utilizador(
      id: json['id_utilizador'] as int,
      nome: json['nome_completo'] ?? '',
      email: json['email'] ?? '',
      contacto: json['contacto'] ?? '',
      estadoConta: json['estado_conta'] ?? '',
      password: json['password'] ?? '', // ✅ null safety adicionado
      dataCriacao: json['data_criacao'] != null
          ? DateTime.tryParse(json['data_criacao'].toString())
          : null,
      aceitarTermos: json['aceitar_termos'] == true || json['aceitar_termos'] == 1,
    );
  }

  // Converter Objeto → JSON
  Map<String, dynamic> toJson() {
    return {
      'id_utilizador': id,
      'nome_completo': nome,
      'email': email,
      'contacto': contacto,
      'estado_conta': estadoConta,
      'password': password,
      'data_criacao': dataCriacao?.toIso8601String(),
      'aceitar_termos': aceitarTermos,
    };
  }
}