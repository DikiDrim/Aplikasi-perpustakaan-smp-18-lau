import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Utility untuk mencetak laporan riwayat peminjaman sebagai PDF
class PeminjamanReportPrinter {
  /// Print semua data peminjaman yang diberikan
  static Future<void> printLaporan({
    required List<Map<String, dynamic>> dataList,
    String? filterStatus, // null = semua, 'dipinjam', 'dikembalikan'
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');
    final dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
    final now = DateTime.now();

    // Filter data jika perlu
    final filtered =
        filterStatus != null
            ? dataList
                .where(
                  (d) =>
                      (d['status'] ?? '').toString().toLowerCase() ==
                      filterStatus.toLowerCase(),
                )
                .toList()
            : dataList;

    // Hitung statistik
    final totalDipinjam =
        filtered
            .where(
              (d) =>
                  (d['status'] ?? '').toString().toLowerCase() !=
                  'dikembalikan',
            )
            .length;
    final totalDikembalikan =
        filtered
            .where(
              (d) =>
                  (d['status'] ?? '').toString().toLowerCase() ==
                  'dikembalikan',
            )
            .length;
    final totalKondisiBuruk =
        filtered.where((d) {
          final k = (d['kondisi_buku'] ?? '').toString();
          return k == 'Rusak' || k == 'Hilang';
        }).length;

    // Buat tabel data
    final tableHeaders = [
      'No',
      'Judul Buku',
      'Peminjam',
      'Kelas',
      'Tgl Pinjam',
      'Tgl Kembali',
      'Jatuh Tempo',
      'Status',
      'Kondisi',
    ];

    final tableData = <List<String>>[];
    for (int i = 0; i < filtered.length; i++) {
      final d = filtered[i];
      final status = (d['status'] ?? '').toString();

      // Parse tanggal pinjam
      String tglPinjam = '-';
      if (d['tanggal_pinjam'] != null) {
        try {
          final ts = d['tanggal_pinjam'];
          final dt =
              ts is DateTime
                  ? ts
                  : (ts.toDate != null ? ts.toDate() : DateTime.now());
          tglPinjam = dateFormat.format(dt);
        } catch (_) {
          tglPinjam = '-';
        }
      }

      // Parse tanggal kembali
      String tglKembali = '-';
      if (d['tanggal_kembali'] != null) {
        try {
          final ts = d['tanggal_kembali'];
          final dt =
              ts is DateTime
                  ? ts
                  : (ts.toDate != null ? ts.toDate() : DateTime.now());
          tglKembali = dateFormat.format(dt);
        } catch (_) {
          tglKembali = '-';
        }
      }

      // Parse jatuh tempo
      String jatuhTempo = '-';
      if (d['tanggal_jatuh_tempo'] != null) {
        try {
          final ts = d['tanggal_jatuh_tempo'];
          final dt =
              ts is DateTime
                  ? ts
                  : (ts.toDate != null ? ts.toDate() : DateTime.now());
          jatuhTempo = dateFormat.format(dt);
        } catch (_) {
          jatuhTempo = '-';
        }
      }

      String statusText =
          status == 'dikembalikan' ? 'Dikembalikan' : 'Dipinjam';

      // Kondisi buku
      final kondisiBuku = (d['kondisi_buku'] ?? '').toString();
      final kondisiText = kondisiBuku.isNotEmpty ? kondisiBuku : '-';

      tableData.add([
        '${i + 1}',
        d['judul_buku'] ?? '-',
        d['nama_peminjam'] ?? '-',
        d['kelas'] ?? '-',
        tglPinjam,
        tglKembali,
        jatuhTempo,
        statusText,
        kondisiText,
      ]);
    }

    // Bagi data ke halaman (maks ~25 baris per halaman agar tidak overflow)
    const rowsPerPage = 25;
    final totalPages = (tableData.length / rowsPerPage).ceil().clamp(1, 999);

    for (int page = 0; page < totalPages; page++) {
      final startIdx = page * rowsPerPage;
      final endIdx = (startIdx + rowsPerPage).clamp(0, tableData.length);
      final pageData = tableData.sublist(startIdx, endIdx);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header - hanya di halaman pertama
                if (page == 0) ...[
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'LAPORAN PEMINJAMAN BUKU',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('#0D47A1'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Perpustakaan SMPN 18 LAU',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Dicetak: ${dateTimeFormat.format(now)}',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  // Statistik
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F5F9FF'),
                      border: pw.Border.all(
                        color: PdfColor.fromHex('#0D47A1'),
                        width: 0.5,
                      ),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatBox(
                          'Total Data',
                          '${filtered.length}',
                          PdfColors.blue800,
                        ),
                        _buildStatBox(
                          'Sedang Dipinjam',
                          '$totalDipinjam',
                          PdfColors.orange,
                        ),
                        _buildStatBox(
                          'Dikembalikan',
                          '$totalDikembalikan',
                          PdfColors.green,
                        ),
                        if (totalKondisiBuruk > 0)
                          _buildStatBox(
                            'Rusak/Hilang',
                            '$totalKondisiBuruk',
                            PdfColors.red,
                          ),
                        if (filterStatus != null)
                          _buildStatBox(
                            'Filter',
                            filterStatus == 'dipinjam'
                                ? 'Dipinjam'
                                : 'Dikembalikan',
                            PdfColors.purple,
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],
                // Tabel
                pw.Expanded(
                  child: pw.TableHelper.fromTextArray(
                    context: context,
                    headers: tableHeaders,
                    data: pageData,
                    border: pw.TableBorder.all(
                      color: PdfColors.grey400,
                      width: 0.5,
                    ),
                    headerStyle: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#0D47A1'),
                    ),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    cellHeight: 22,
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.centerLeft,
                      2: pw.Alignment.centerLeft,
                      3: pw.Alignment.center,
                      4: pw.Alignment.center,
                      5: pw.Alignment.center,
                      6: pw.Alignment.center,
                      7: pw.Alignment.center,
                      8: pw.Alignment.center,
                    },
                    columnWidths: {
                      0: const pw.FixedColumnWidth(25), // No
                      1: const pw.FlexColumnWidth(3), // Judul
                      2: const pw.FlexColumnWidth(2), // Peminjam
                      3: const pw.FixedColumnWidth(45), // Kelas
                      4: const pw.FixedColumnWidth(60), // Tgl Pinjam
                      5: const pw.FixedColumnWidth(60), // Tgl Kembali
                      6: const pw.FixedColumnWidth(60), // Jatuh Tempo
                      7: const pw.FixedColumnWidth(62), // Status
                      8: const pw.FixedColumnWidth(50), // Kondisi
                    },
                    oddCellStyle: const pw.TextStyle(fontSize: 8),
                    oddRowDecoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8F9FA'),
                    ),
                  ),
                ),
                // Footer
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Halaman ${page + 1} dari $totalPages',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Perpustakaan SMPN 18 LAU - Sistem Informasi Perpustakaan',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    // Jika tidak ada data, buat halaman kosong
    if (filtered.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (context) {
            return pw.Center(
              child: pw.Text(
                'Tidak ada data peminjaman untuk dicetak.',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey,
                ),
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      name:
          'Laporan_Peminjaman_${dateFormat.format(now).replaceAll('/', '-')}.pdf',
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ],
    );
  }
}
