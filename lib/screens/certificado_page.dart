import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import 'package:flutter/material.dart';

class CertificadoCompetenciasPage extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, dynamic> certificadoData;

  const CertificadoCompetenciasPage({
    super.key,
    required this.userData,
    required this.certificadoData,
  });

  Future<void> _gerarPDF(BuildContext context) async {
    final pdf = pw.Document();

    final nomeUtilizador =
        certificadoData['nome_utilizador'] ?? certificadoData['nome'] ?? userData['nome'] ?? 'Utilizador';

    final nomeBadge =
        certificadoData['nome_badge'] ?? 'Badge sem nome';

    final dataEmissao =
        certificadoData['data_emissao']?.toString() ?? DateTime.now().toString();

    final codigo =
        certificadoData['codigo_certificado'] ??
        certificadoData['codigo_verificacao'] ??
        'CERT-${certificadoData['id_candidatura_historico'] ?? ''}-${userData['id_utilizador'] ?? ''}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  'Certificado de Competências',
                  style: pw.TextStyle(
                    fontSize: 26,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Text('Certificamos que:', style: const pw.TextStyle(fontSize: 16)),
                pw.SizedBox(height: 16),
                pw.Text(
                  nomeUtilizador,
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Concluiu com sucesso o badge:',
                  style: const pw.TextStyle(fontSize: 16),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  nomeBadge,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 40),
                pw.Divider(),
                pw.SizedBox(height: 20),
                pw.Text('Data de emissão: $dataEmissao'),
                pw.SizedBox(height: 8),
                pw.Text('Código de verificação: $codigo'),
                pw.Spacer(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Service Line Leader'),
                    pw.Text('Talent Manager'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _gerarExcel(BuildContext context) async {
    final workbook = excel.Excel.createExcel();

    final sheet = workbook['Certificado'];

    sheet.appendRow([
      excel.TextCellValue('Campo'),
      excel.TextCellValue('Valor'),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Nome do utilizador'),
      excel.TextCellValue(
        certificadoData['nome_utilizador']?.toString() ??
            certificadoData['nome']?.toString() ??
            userData['nome']?.toString() ??
            '',
      ),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Badge'),
      excel.TextCellValue(certificadoData['nome_badge']?.toString() ?? ''),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Descrição'),
      excel.TextCellValue(certificadoData['descricao_badge_modelo']?.toString() ?? ''),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Pontos'),
      excel.TextCellValue(certificadoData['pontos']?.toString() ?? ''),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Estado final'),
      excel.TextCellValue(certificadoData['estado_final']?.toString() ?? ''),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Data de emissão'),
      excel.TextCellValue(certificadoData['data_emissao']?.toString() ?? DateTime.now().toString()),
    ]);

    sheet.appendRow([
      excel.TextCellValue('Código certificado'),
      excel.TextCellValue(
        certificadoData['codigo_certificado']?.toString() ??
            certificadoData['codigo_verificacao']?.toString() ??
            '',
      ),
    ]);

    final bytes = workbook.encode();

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao gerar Excel')),
      );
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final filePath =
        '${directory.path}/certificado_${certificadoData['id_candidatura_historico'] ?? 'badge'}.xlsx';

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await OpenFilex.open(filePath);
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 65.0;

    // Dados do certificado (com fallback para demonstração)
    final String nomeUtilizador =
      certificadoData['nome_utilizador'] ??
      certificadoData['nome'] ??
      userData['nome'] ??
      'Utilizador';

    final String cargo =
        certificadoData['cargo'] ?? 'Consultor/a';
    final String nomeBadge =
        certificadoData['nome_badge'] ?? 'SAP Explorer – Nível Júnior (A1, A2, A3)';
    final String dataEmissao =
        certificadoData['data_emissao'] ?? '3 de Fevereiro de 2025';
    final String codigoVerificacao =
      certificadoData['codigo_certificado'] ??
      certificadoData['codigo_verificacao'] ??
      'CERT-${certificadoData['id_candidatura_historico'] ?? ''}-${userData['id_utilizador'] ?? ''}';
      
    final String urlVerificacao =
        certificadoData['url_verificacao'] ??
            'softinsa.pt/badges/.../out-a';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: SafeArea(
        child: Stack(
          children: [
            // ── CONTEÚDO ────────────────────────────────────────────────
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: headerHeight),

                  // Voltar + título
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back,
                              size: 22, color: Color(0xFF4470AF)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Voltar",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Corpo do certificado
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Cabeçalho do certificado
                            _buildCertificadoHeader(),

                            // Corpo com os dados
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // "Certificamos que:"
                                  const Text(
                                    "Certificamos que:",
                                    style: TextStyle(fontSize: 14),
                                  ),

                                  const SizedBox(height: 16),

                                  // Nome + cargo
                                  Text(
                                    "$nomeUtilizador , $cargo",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "Concluiu com sucesso o badge:",
                                    style: TextStyle(fontSize: 14),
                                  ),

                                  const SizedBox(height: 16),

                                  // Nome do badge — centrado, destaque
                                  Center(
                                    child: Text(
                                      nomeBadge,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  Divider(color: Colors.grey.shade100),
                                  const SizedBox(height: 16),

                                  // Data de emissão
                                  _buildInfoRow(
                                    icon: Icons.calendar_today_outlined,
                                    label: "Data de emissão",
                                    value: dataEmissao,
                                  ),

                                  const SizedBox(height: 14),

                                  // Código único
                                  _buildInfoRow(
                                    icon: Icons.qr_code_outlined,
                                    label: "Código único de Verificação",
                                    value: codigoVerificacao,
                                  ),

                                  const SizedBox(height: 14),

                                  // URL de verificação
                                  _buildInfoRow(
                                    icon: Icons.link_outlined,
                                    label: "URL de Verificação",
                                    value: urlVerificacao,
                                    isLink: true,
                                  ),

                                  const SizedBox(height: 28),
                                  Divider(color: Colors.grey.shade200),
                                  const SizedBox(height: 20),

                                  // Assinaturas
                                  _buildAssinaturas(),

                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bottom bar — Gerar PDF / Gerar Excel
                  _buildBottomBar(context),
                ],
              ),
            ),

            // ── HEADER DA APP ────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: headerHeight,
              child: Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'lib/img/logo.png',
                      height: 35,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cabeçalho do certificado (título + logo Softinsa) ──────────────────────
  Widget _buildCertificadoHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          const Text(
            "Certificado de Competências",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Logo Softinsa em destaque
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Image.asset(
              'lib/img/logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  // ── Linha de informação (ícone + label + valor) ────────────────────────────
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLink = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4470AF)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      isLink ? const Color(0xFF4470AF) : Colors.black87,
                  decoration:
                      isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bloco de assinaturas ───────────────────────────────────────────────────
  Widget _buildAssinaturas() {
    return Row(
      children: [
        Expanded(child: _buildAssinatura("Service Line Leader")),
        const SizedBox(width: 24),
        Expanded(child: _buildAssinatura("Talent Manager")),
      ],
    );
  }

  Widget _buildAssinatura(String cargo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linha de assinatura simulada
        Stack(
          clipBehavior: Clip.none,
          children: [
            // "x" à esquerda
            const Positioned(
              left: 0,
              bottom: 4,
              child: Text(
                "x",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),
            // Traço cursivo decorativo
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Text(
                "𝓁",
                style: TextStyle(
                  fontSize: 44,
                  fontFamily: 'serif',
                  color: Colors.black87,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Pontos da linha de assinatura
        Row(
          children: List.generate(
            5,
            (_) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 4),
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.rectangle,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          cargo,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── Botão de ícone do header ───────────────────────────────────────────────
  Widget _headerIconButton(IconData icon) {
    return Container(
      width: 38,
      height: 38,
      decoration: const BoxDecoration(
        color: Color(0xFF4470AF),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  // ── Bottom bar: Gerar PDF + Gerar Excel ───────────────────────────────────
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _bottomBarButton(
              icon: Icons.picture_as_pdf_outlined,
              label: "Gerar PDF",
              onTap: () {
                _gerarPDF(context);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bottomBarButton(
              icon: Icons.grid_on_outlined,
              label: "Gerar Excel",
              onTap: () {
                _gerarExcel(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.black87, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}