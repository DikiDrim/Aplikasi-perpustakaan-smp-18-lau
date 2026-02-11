import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/buku_model.dart';

/// Utility untuk mencetak laporan buku rusak/hilang sebagai PDF
class KondisiBukuReportPrinter {
  /// Cetak laporan buku rusak/hilang
  static Future<void> printLaporan({
    required List<BukuModel> bukuList,
    String? filterStatus, // null = semua, 'Rusak', 'Hilang'
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final now = DateTime.now();

    // Filter data jika perlu
    final filtered =
        filterStatus != null
            ? bukuList.where((b) => b.statusKondisi == filterStatus).toList()
            : bukuList;

    // Hitung statistik
    final totalRusak = filtered.fold<int>(
      0,
      (sum, b) => sum + b.effectiveJumlahRusak,
    );
    final totalHilang = filtered.fold<int>(
      0,
      (sum, b) => sum + b.effectiveJumlahHilang,
    );

    // Buat tabel data
    final tableHeaders = [
      'No',
      'Judul Buku',
      'Pengarang',
      'Kategori',
      'Status',
      'Jml Rusak',
      'Jml Hilang',
      'Stok',
      'Tanggal',
      'Catatan',
    ];

    final tableData = <List<String>>[];
    for (int i = 0; i < filtered.length; i++) {
      final b = filtered[i];
      String tglStatus = '-';
      if (b.tanggalStatusKondisi != null) {
        tglStatus = dateFormat.format(b.tanggalStatusKondisi!);
      }

      tableData.add([
        '${i + 1}',
        b.judul,
        b.pengarang,
        b.kategori,
        b.statusKondisi,
        '${b.effectiveJumlahRusak}',
        '${b.effectiveJumlahHilang}',
        '${b.stok}',
        tglStatus,
        b.catatanKondisi ?? '-',
      ]);
    }

    // Build pages
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PERPUSTAKAAN SMPN 18 LAU',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Laporan Buku Rusak / Hilang',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Tanggal cetak: ${dateFormat.format(now)}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      if (filterStatus != null)
                        pw.Text(
                          'Filter: $filterStatus',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 4),
              pw.Row(
                children: [
                  pw.Text(
                    'Total: ${filtered.length} buku',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text(
                    'Rusak: $totalRusak eksemplar',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Text(
                    'Hilang: $totalHilang eksemplar',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (context) {
          if (tableData.isEmpty) {
            return [
              pw.Center(
                child: pw.Text(
                  'Tidak ada buku rusak/hilang.',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ),
            ];
          }
          return [
            pw.TableHelper.fromTextArray(
              context: context,
              headers: tableHeaders,
              data: tableData,
              border: pw.TableBorder.all(width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FixedColumnWidth(25), // No
                1: const pw.FlexColumnWidth(3), // Judul
                2: const pw.FlexColumnWidth(2), // Pengarang
                3: const pw.FlexColumnWidth(1.5), // Kategori
                4: const pw.FixedColumnWidth(45), // Status
                5: const pw.FixedColumnWidth(45), // Jml Rusak
                6: const pw.FixedColumnWidth(45), // Jml Hilang
                7: const pw.FixedColumnWidth(35), // Stok
                8: const pw.FixedColumnWidth(60), // Tanggal
                9: const pw.FlexColumnWidth(2), // Catatan
              },
            ),
          ];
        },
        footer: (context) {
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dicetak oleh: Sistem Perpustakaan SMPN 18 LAU',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          );
        },
      ),
    );

    // Print / preview
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Buku_Rusak_Hilang_${DateFormat('yyyyMMdd').format(now)}',
    );
  }
}
