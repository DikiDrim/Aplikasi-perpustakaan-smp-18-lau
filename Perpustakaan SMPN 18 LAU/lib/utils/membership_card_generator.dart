import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MembershipCardGenerator {
  /// Generate PDF kartu anggota perpustakaan
  static Future<void> generateAndPrintCard({
    required String nama,
    required String nis,
    required String kelas,
    required String? photoUrl,
    required String schoolName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          85 * PdfPageFormat.mm, // Width: 85mm (credit card size)
          54 * PdfPageFormat.mm, // Height: 54mm
        ),
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // Background
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0D47A1), // Dark blue background
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
              ),
              // Front side content
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Header dengan logo/nama sekolah
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'KARTU ANGGOTA',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              schoolName,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                        // Photo placeholder atau icon
                        pw.Container(
                          width: 18,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                              color: PdfColors.white,
                              width: 0.5,
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'FOTO',
                              style: const pw.TextStyle(
                                fontSize: 4,
                                color: PdfColors.grey,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Data siswa
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          nama.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              'NIS: $nis',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                            ),
                            pw.Spacer(),
                            pw.Text(
                              kelas,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Footer
                    pw.Divider(color: PdfColors.white, height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Berlaku seumur hidup',
                          style: const pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          '© SMPN 18 LAU',
                          style: const pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Print atau save PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Kartu_Anggota_$nis.pdf',
    );
  }

  /// Generate simple membership card untuk share/preview
  static Future<Uint8List> generateCardBytes({
    required String nama,
    required String nis,
    required String kelas,
    required String schoolName,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          85 * PdfPageFormat.mm,
          54 * PdfPageFormat.mm,
        ),
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0D47A1),
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(4),
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'KARTU ANGGOTA',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              schoolName,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                        pw.Container(
                          width: 18,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            border: pw.Border.all(
                              color: PdfColors.white,
                              width: 0.5,
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'FOTO',
                              style: const pw.TextStyle(
                                fontSize: 4,
                                color: PdfColors.grey,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          nama.toUpperCase(),
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          maxLines: 1,
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              'NIS: $nis',
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                            ),
                            pw.Spacer(),
                            pw.Text(
                              kelas,
                              style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Divider(color: PdfColors.white, height: 1),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Berlaku seumur hidup',
                          style: const pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          '© SMPN 18 LAU',
                          style: const pw.TextStyle(
                            fontSize: 5,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
