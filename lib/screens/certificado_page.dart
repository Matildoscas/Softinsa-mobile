// ============================================================================
// certificado_page.dart
//
// Pré-visualização e exportação profissional do certificado.
// Inclui:
// - nome real do consultor;
// - cargo, área, badge, nível e requisitos;
// - logótipo Softinsa na pré-visualização, PDF e Excel;
// - PDF A4 com código QR;
// - Excel formatado com logótipo e todos os dados do certificado.
// ============================================================================

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import '../config/app_config.dart';

class CertificadoCompetenciasPage extends StatelessWidget {
  static const Color _azul = Color(0xFF4470AF);
  static const String _logoAsset = 'lib/img/logo.png';

  final Map<String, dynamic> userData;
  final Map<String, dynamic> certificadoData;

  const CertificadoCompetenciasPage({
    super.key,
    required this.userData,
    required this.certificadoData,
  });

  // =========================================================================
  // LEITURA SEGURA DOS DADOS
  // =========================================================================

  String _primeiroTexto(List<dynamic> valores) {
    for (final valor in valores) {
      final texto = valor?.toString().trim() ?? '';

      if (texto.isNotEmpty && texto.toLowerCase() != 'null') {
        return texto;
      }
    }

    return '';
  }

  int _inteiro(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();

    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }

  String _procurarNome(
    Map<String, dynamic> dados,
  ) {
    final String direto =
        _primeiroTexto([
      dados['nome_completo'],
      dados['NOME_COMPLETO'],
      dados['nome_utilizador'],
      dados['nome_consultor'],
      dados['nome'],
    ]);

    if (direto.isNotEmpty) {
      return direto;
    }

    /*
    * Procura também em objetos internos,
    * caso a API devolva:
    *
    * { utilizador: { nome_completo: ... } }
    */
    for (final String chave in [
      'utilizador',
      'user',
      'consultor',
      'perfil',
      'dados',
      'data',
      'certificado',
    ]) {
      final dynamic interno =
          dados[chave];

      if (interno is Map) {
        final String encontrado =
            _procurarNome(
          Map<String, dynamic>.from(
            interno,
          ),
        );

        if (encontrado.isNotEmpty) {
          return encontrado;
        }
      }
    }

    return '';
  }

  String get _nomeConsultor {
    final String nomeCertificado =
        _procurarNome(
      certificadoData,
    );

    if (nomeCertificado.isNotEmpty) {
      return nomeCertificado;
    }

    final String nomeUtilizador =
        _procurarNome(
      userData,
    );

    if (nomeUtilizador.isNotEmpty) {
      return nomeUtilizador;
    }

    return 'Nome do consultor indisponível';
  }

  String get _cargo {
    final cargo = _primeiroTexto([
      certificadoData['cargo'],
      certificadoData['cargo_consultor'],
      userData['cargo'],
    ]);

    return cargo.isNotEmpty ? cargo : 'Consultor/a';
  }

  String get _area {
    return _primeiroTexto([
      certificadoData['nome_area'],
      certificadoData['nome_areas'],
      certificadoData['area'],
      userData['nome_area'],
      userData['area'],
    ]);
  }

  String get _identificacaoProfissional {
    if (_area.isEmpty) {
      return '$_cargo Softinsa';
    }

    if (_cargo.toLowerCase().contains(_area.toLowerCase())) {
      return _cargo;
    }

    return '$_cargo – $_area';
  }

  String get _nomeBadge {
    final nome = _primeiroTexto([
      certificadoData['nome_badge'],
      certificadoData['nome'],
      certificadoData['badge'],
    ]);

    return nome.isNotEmpty ? nome : 'Badge Softinsa';
  }

  String get _nivel {
    final nomeNivel = _primeiroTexto([
      certificadoData['nome_nivel'],
      certificadoData['nivel'],
    ]);

    if (nomeNivel.isNotEmpty) {
      if (nomeNivel.toLowerCase().startsWith('nível') ||
          nomeNivel.toLowerCase().startsWith('nivel')) {
        return nomeNivel;
      }

      return 'Nível $nomeNivel';
    }

    switch (_inteiro(certificadoData['id_nivel'])) {
      case 1:
        return 'Nível A';
      case 2:
        return 'Nível B';
      case 3:
        return 'Nível C';
      case 4:
        return 'Nível D';
      case 5:
        return 'Nível E';
      default:
        return '';
    }
  }

  String get _requisitosTexto {
    final textoDireto = _primeiroTexto([
      certificadoData['requisitos_texto'],
      certificadoData['requisitos_certificado'],
    ]);

    if (textoDireto.isNotEmpty) {
      return textoDireto;
    }

    final raw = certificadoData['requisitos'];

    if (raw is! List) {
      return '';
    }

    final nomes = raw
        .whereType<Map>()
        .map(
          (item) => _primeiroTexto([
            item['titulo'],
            item['nome_requisito'],
            item['nome'],
          ]),
        )
        .where((texto) => texto.isNotEmpty)
        .toSet()
        .toList();

    return nomes.join(', ');
  }

  String get _badgeCompleto {
    final partes = <String>[_nomeBadge];

    if (_nivel.isNotEmpty) {
      partes.add(_nivel);
    }

    var resultado = partes.join(' – ');

    if (_requisitosTexto.isNotEmpty) {
      resultado += ' ($_requisitosTexto)';
    }

    return resultado;
  }

  String get _dataEmissao {
    final valor = _primeiroTexto([
      certificadoData['data_emissao'],
      certificadoData['data_atribuicao'],
      certificadoData['data_entrada_historico'],
      certificadoData['data'],
    ]);

    final data = DateTime.tryParse(valor)?.toLocal() ?? DateTime.now();

    const meses = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];

    return '${data.day} de ${meses[data.month - 1]} de ${data.year}';
  }

  String get _codigoVerificacao {
    final existente =
        _primeiroTexto([
      certificadoData['codigo_certificado'],
      certificadoData['codigo_verificacao'],
      certificadoData['codigo'],
    ]);

    if (existente.isNotEmpty) {
      return existente.startsWith('CERT-')
          ? existente
          : 'CERT-$existente';
    }

    final idHistorico =
        _primeiroTexto([
      certificadoData['id_candidatura_historico'],
      certificadoData['id_historico'],
      userData['id_candidatura_historico'],
    ]);

    final idUtilizador =
        _primeiroTexto([
      userData['id_utilizador'],
      userData['ID_UTILIZADOR'],
      certificadoData['id_utilizador'],
    ]);

    if (
      idHistorico.isNotEmpty &&
      idUtilizador.isNotEmpty
    ) {
      return 'CERT-$idHistorico-$idUtilizador';
    }

    return '';
  }

  String get _urlVerificacao {
    final existente =
        _primeiroTexto([
      certificadoData['url_verificacao'],
      certificadoData['url_certificado'],
    ]);

    if (existente.isNotEmpty) {
      if (
        existente.startsWith('http://') ||
        existente.startsWith('https://')
      ) {
        return existente;
      }

      return '${AppConfig.webBaseUrl}/'
          '${existente.replaceFirst(RegExp(r'^/+'), '')}';
    }

    final codigo =
        _codigoVerificacao;

    if (codigo.isEmpty) {
      return '';
    }

    return '${AppConfig.webBaseUrl}/verificar/$codigo';
  }

  int get _pontos {
    return _inteiro(
      certificadoData['pontos'] ??
          certificadoData['pontos_badge'],
    );
  }

  String _nomeFicheiroSeguro(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9áàâãéêíóôõúç]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<Uint8List> _carregarLogo() async {
    final data = await rootBundle.load(_logoAsset);

    return data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
  }

  // =========================================================================
  // PDF
  // =========================================================================

  Future<void> _gerarPDF(BuildContext context) async {
    try {
      final logoBytes = await _carregarLogo();
      final logo = pw.MemoryImage(logoBytes);

      final documento = pw.Document(
        title: 'Certificado de Competências - $_nomeConsultor',
        author: 'Softinsa',
        subject: _badgeCompleto,
        creator: 'Softinsa Badges',
      );

      const azulPdf = PdfColor.fromInt(0xFF4470AF);
      const azulClaroPdf = PdfColor.fromInt(0xFFEFF6FF);
      const cinzentoPdf = PdfColor.fromInt(0xFF6B7280);
      const cinzentoClaroPdf = PdfColor.fromInt(0xFFE5E7EB);

      documento.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (_) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                border: pw.Border.all(
                  color: azulPdf,
                  width: 2.5,
                ),
              ),
              padding: const pw.EdgeInsets.all(7),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: cinzentoClaroPdf,
                    width: 1,
                  ),
                ),
                padding: const pw.EdgeInsets.fromLTRB(
                  38,
                  30,
                  38,
                  28,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(
                      logo,
                      height: 46,
                      fit: pw.BoxFit.contain,
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      'CERTIFICADO DE COMPETÊNCIAS',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: azulPdf,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      'Programa Softinsa Badges',
                      style: const pw.TextStyle(
                        color: cinzentoPdf,
                        fontSize: 11,
                      ),
                    ),
                    pw.SizedBox(height: 36),
                    pw.Text(
                      'Certificamos que',
                      style: const pw.TextStyle(
                        color: cinzentoPdf,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      _nomeConsultor,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.black,
                        fontSize: 25,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 7),
                    pw.Text(
                      _identificacaoProfissional,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        color: cinzentoPdf,
                        fontSize: 13,
                      ),
                    ),
                    pw.SizedBox(height: 28),
                    pw.Text(
                      'concluiu com sucesso todos os requisitos necessários '
                      'para a obtenção do badge',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(
                        fontSize: 14,
                        lineSpacing: 4,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: pw.BoxDecoration(
                        color: azulClaroPdf,
                        borderRadius: pw.BorderRadius.circular(6),
                        border: pw.Border.all(
                          color: azulPdf,
                          width: 0.8,
                        ),
                      ),
                      child: pw.Text(
                        _badgeCompleto,
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          color: azulPdf,
                          fontSize: 19,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Spacer(),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment:
                                pw.CrossAxisAlignment.start,
                            children: [
                              _pdfMeta(
                                'Data de emissão',
                                _dataEmissao,
                              ),
                              pw.SizedBox(height: 10),
                              _pdfMeta(
                                'Código de verificação',
                                _codigoVerificacao,
                              ),
                              pw.SizedBox(height: 10),
                              _pdfMeta(
                                'URL de verificação',
                                _urlVerificacao,
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 22),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(
                              color: cinzentoClaroPdf,
                            ),
                          ),
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: _urlVerificacao,
                            width: 66,
                            height: 66,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 34),
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _pdfAssinatura(
                            'Service Line Leader',
                          ),
                        ),
                        pw.SizedBox(width: 48),
                        pw.Expanded(
                          child: _pdfAssinatura(
                            'Talent Manager',
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 18),
                    pw.Text(
                      'Documento emitido eletronicamente pela Softinsa.',
                      style: const pw.TextStyle(
                        color: cinzentoPdf,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        name:
            'certificado_${_nomeFicheiroSeguro(_nomeBadge)}.pdf',
        onLayout: (_) => documento.save(),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível gerar o PDF: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  pw.Widget _pdfMeta(
    String titulo,
    String valor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          titulo.toUpperCase(),
          style: pw.TextStyle(
            color: const PdfColor.fromInt(0xFF6B7280),
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          valor,
          style: const pw.TextStyle(
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  pw.Widget _pdfAssinatura(String cargo) {
    return pw.Column(
      children: [
        pw.SizedBox(height: 22),
        pw.Container(
          height: 1,
          color: const PdfColor.fromInt(0xFF374151),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          cargo,
          style: const pw.TextStyle(
            color: PdfColor.fromInt(0xFF374151),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // EXCEL COM LOGÓTIPO
  // =========================================================================

  Future<void> _gerarExcel(BuildContext context) async {
    try {
      final logoBytes = await _carregarLogo();

      final workbook = xlsio.Workbook();
      final sheet = workbook.worksheets[0];

      sheet.name = 'Certificado';
      sheet.showGridlines = false;

      sheet.getRangeByName('A1:F3').cellStyle.backColor = '#F8FAFC';
      sheet.getRangeByName('A1:F3').cellStyle.borders.bottom.lineStyle =
          xlsio.LineStyle.thin;
      sheet.getRangeByName('A1:F3').cellStyle.borders.bottom.color =
          '#D9E2EF';

      final picture = sheet.pictures.addStream(
        1,
        1,
        logoBytes,
      );

      picture.width = 145;
      picture.height = 48;

      final titleRange =
          sheet.getRangeByName('C1:F2');

      titleRange.merge();
      titleRange.setText(
        'CERTIFICADO DE COMPETÊNCIAS',
      );
      titleRange.cellStyle.fontSize = 18;
      titleRange.cellStyle.bold = true;
      titleRange.cellStyle.fontColor = '#4470AF';
      titleRange.cellStyle.hAlign =
          xlsio.HAlignType.center;
      titleRange.cellStyle.vAlign =
          xlsio.VAlignType.center;

      final subtitleRange =
          sheet.getRangeByName('C3:F3');

      subtitleRange.merge();
      subtitleRange.setText(
        'Programa Softinsa Badges',
      );
      subtitleRange.cellStyle.fontSize = 10;
      subtitleRange.cellStyle.fontColor = '#6B7280';
      subtitleRange.cellStyle.hAlign =
          xlsio.HAlignType.center;

      final personRange =
          sheet.getRangeByName('A5:F5');

      personRange.merge();
      personRange.setText(_nomeConsultor);
      personRange.cellStyle.fontSize = 17;
      personRange.cellStyle.bold = true;
      personRange.cellStyle.fontColor = '#111827';
      personRange.cellStyle.hAlign =
          xlsio.HAlignType.center;

      final roleRange =
          sheet.getRangeByName('A6:F6');

      roleRange.merge();
      roleRange.setText(_identificacaoProfissional);
      roleRange.cellStyle.fontSize = 11;
      roleRange.cellStyle.fontColor = '#6B7280';
      roleRange.cellStyle.hAlign =
          xlsio.HAlignType.center;

      final badgeRange =
          sheet.getRangeByName('A8:F9');

      badgeRange.merge();
      badgeRange.setText(_badgeCompleto);
      badgeRange.cellStyle.fontSize = 14;
      badgeRange.cellStyle.bold = true;
      badgeRange.cellStyle.fontColor = '#315E9E';
      badgeRange.cellStyle.backColor = '#EFF6FF';
      badgeRange.cellStyle.hAlign =
          xlsio.HAlignType.center;
      badgeRange.cellStyle.vAlign =
          xlsio.VAlignType.center;
      badgeRange.cellStyle.wrapText = true;
      badgeRange.cellStyle.borders.all.lineStyle =
          xlsio.LineStyle.thin;
      badgeRange.cellStyle.borders.all.color =
          '#BFD4F4';

      final dados = <MapEntry<String, String>>[
        MapEntry('Nome do consultor', _nomeConsultor),
        MapEntry('Cargo', _cargo),
        MapEntry('Área', _area.isEmpty ? '—' : _area),
        MapEntry('Badge', _nomeBadge),
        MapEntry('Nível', _nivel.isEmpty ? '—' : _nivel),
        MapEntry(
          'Requisitos',
          _requisitosTexto.isEmpty ? '—' : _requisitosTexto,
        ),
        MapEntry('Pontos', _pontos.toString()),
        MapEntry('Data de emissão', _dataEmissao),
        MapEntry(
          'Código de verificação',
          _codigoVerificacao,
        ),
        MapEntry('URL de verificação', _urlVerificacao),
      ];

      var row = 11;

      for (final dado in dados) {
        final label =
            sheet.getRangeByName('A$row:B$row');
        final value =
            sheet.getRangeByName('C$row:F$row');

        label.merge();
        value.merge();

        label.setText(dado.key);
        value.setText(dado.value);

        label.cellStyle.bold = true;
        label.cellStyle.fontColor = '#374151';
        label.cellStyle.backColor = '#F8FAFC';
        label.cellStyle.vAlign =
            xlsio.VAlignType.center;

        value.cellStyle.fontColor = '#111827';
        value.cellStyle.wrapText = true;
        value.cellStyle.vAlign =
            xlsio.VAlignType.center;

        label.cellStyle.borders.all.lineStyle =
            xlsio.LineStyle.thin;
        value.cellStyle.borders.all.lineStyle =
            xlsio.LineStyle.thin;

        label.cellStyle.borders.all.color =
            '#E5E7EB';
        value.cellStyle.borders.all.color =
            '#E5E7EB';

        row += 1;
      }

      final signatureRow = row + 2;

      final assinaturaSll = sheet.getRangeByName(
        'A$signatureRow:C$signatureRow',
      );
      final assinaturaTm = sheet.getRangeByName(
        'D$signatureRow:F$signatureRow',
      );

      assinaturaSll.merge();
      assinaturaTm.merge();

      assinaturaSll.setText(
        '____________________________\nService Line Leader',
      );
      assinaturaTm.setText(
        '____________________________\nTalent Manager',
      );

      assinaturaSll.cellStyle.hAlign =
          xlsio.HAlignType.center;
      assinaturaTm.cellStyle.hAlign =
          xlsio.HAlignType.center;
      assinaturaSll.cellStyle.wrapText = true;
      assinaturaTm.cellStyle.wrapText = true;
      assinaturaSll.cellStyle.fontColor = '#374151';
      assinaturaTm.cellStyle.fontColor = '#374151';

      sheet.getRangeByName('A1:A$row').columnWidth = 18;
      sheet.getRangeByName('B1:B$row').columnWidth = 10;
      sheet.getRangeByName('C1:F$row').columnWidth = 16;

      sheet.getRangeByName('A1:F$row').cellStyle.fontName =
          'Arial';

      final bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory =
          await getApplicationDocumentsDirectory();

      final filePath =
          '${directory.path}/certificado_'
          '${_nomeFicheiroSeguro(_nomeBadge)}.xlsx';

      final file = File(filePath);

      await file.writeAsBytes(
        bytes,
        flush: true,
      );

      final resultado =
          await OpenFilex.open(filePath);

      if (resultado.type != ResultType.done &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'O Excel foi criado, mas não foi possível '
              'abri-lo automaticamente: ${resultado.message}',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível gerar o Excel: $e',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // =========================================================================
  // INTERFACE
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    const headerHeight = 65.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  const SizedBox(height: headerHeight),

                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius:
                              BorderRadius.circular(20),
                          onTap: () =>
                              Navigator.pop(context),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(
                              Icons.arrow_back,
                              size: 21,
                              color: _azul,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Certificado de Competências',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        18,
                        16,
                        18,
                      ),
                      child: _buildCertificadoPreview(),
                    ),
                  ),

                  _buildBottomBar(context),
                ],
              ),
            ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                alignment: Alignment.centerLeft,
                child: Image.asset(
                  _logoAsset,
                  height: 35,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificadoPreview() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 760,
        minHeight: 720,
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _azul,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: const Color(0xFFD9E2EF),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          22,
          28,
          22,
          24,
        ),
        child: Column(
          children: [
            Image.asset(
              _logoAsset,
              height: 42,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 17),
            const Text(
              'CERTIFICADO DE COMPETÊNCIAS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _azul,
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Programa Softinsa Badges',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Certificamos que',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _nomeConsultor,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _identificacaoProfissional,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'concluiu com sucesso todos os requisitos necessários '
              'para a obtenção do badge',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF374151),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFBFD4F4),
                ),
              ),
              child: Text(
                _badgeCompleto,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF315E9E),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 38),
            _previewMeta(
              icon: Icons.calendar_today_outlined,
              label: 'Data de emissão',
              value: _dataEmissao,
            ),
            const SizedBox(height: 13),
            _previewMeta(
              icon: Icons.verified_outlined,
              label: 'Código de verificação',
              value: _codigoVerificacao,
            ),
            const SizedBox(height: 13),
            _previewMeta(
              icon: Icons.link_outlined,
              label: 'URL de verificação',
              value: _urlVerificacao,
              destacar: true,
            ),
            const SizedBox(height: 38),
            Row(
              children: [
                Expanded(
                  child: _previewAssinatura(
                    'Service Line Leader',
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: _previewAssinatura(
                    'Talent Manager',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text(
              'Documento emitido eletronicamente pela Softinsa.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewMeta({
    required IconData icon,
    required String label,
    required String value,
    bool destacar = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: _azul,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: destacar
                      ? _azul
                      : const Color(0xFF111827),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  decoration: destacar
                      ? TextDecoration.underline
                      : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewAssinatura(String cargo) {
    return Column(
      children: [
        Icon(
          Icons.gesture,
          size: 36,
          color: Colors.black.withOpacity(0.68),
        ),
        const SizedBox(height: 4),
        Container(
          height: 1,
          color: const Color(0xFF374151),
        ),
        const SizedBox(height: 7),
        Text(
          cargo,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        14,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _gerarPDF(context),
              icon: const Icon(
                Icons.picture_as_pdf_outlined,
                size: 18,
              ),
              label: const Text('Gerar PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(
                  color: Colors.red.shade200,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _gerarExcel(context),
              icon: const Icon(
                Icons.grid_on_outlined,
                size: 18,
              ),
              label: const Text('Gerar Excel'),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    const Color(0xFF15803D),
                side: const BorderSide(
                  color: Color(0xFFBBF7D0),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
