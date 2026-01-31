import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/ars_notification_model.dart';

/// Utility untuk mencetak notifikasi ARS sebagai PDF
/// Fokus pada rekomendasi pengadaan ulang (bukan perintah pembelian otomatis).
class ArsNotificationPrinter {
  static Future<void> printNotification(
    ArsNotificationModel notification,
  ) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final tanggal = dateFormat.format(notification.tanggalNotifikasi);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rekomendasi Pengadaan Ulang Buku',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#0D47A1'),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Tanggal: $tanggal'),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F5F9FF'),
                  border: pw.Border.all(color: PdfColor.fromHex('#0D47A1')),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildRow('Judul Buku', notification.judulBuku),
                    _buildRow('Stok Awal', '${notification.stokAwal} buku'),
                    _buildRow(
                      'Total Peminjaman',
                      '${notification.totalPeminjaman} buku',
                    ),
                    _buildRow(
                      'Stok Akhir (Perkiraan)',
                      '${notification.stokAkhir} buku',
                    ),
                    _buildRow(
                      'Safety Stock',
                      '${notification.safetyStock} buku',
                    ),
                    _buildRow(
                      'Rekomendasi Pengadaan',
                      '${notification.jumlahPengadaan} buku',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Catatan Penting:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Bullet(
                text:
                    'Ini adalah rekomendasi pengadaan ulang, bukan instruksi pembelian otomatis.',
              ),
              pw.Bullet(
                text:
                    'Mohon evaluasi stok fisik dan anggaran sebelum melakukan pemesanan.',
              ),
              pw.Bullet(
                text:
                    'Jumlah rekomendasi dihitung dari safety stock dan stok akhir saat ini.',
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Rumus Singkat',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Stok Akhir = Stok Awal - Total Peminjaman'),
              pw.Text(
                'Jumlah Rekomendasi = Safety Stock - Stok Akhir = ${notification.safetyStock} - ${notification.stokAkhir} = ${notification.jumlahPengadaan}',
              ),
              if (notification.detailPeminjaman.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text(
                  'Ringkasan Peminjaman',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children:
                      notification.detailPeminjaman.map((detail) {
                        final jam = detail['jam'] ?? detail['tanggal'] ?? '-';
                        final jumlah = detail['jumlah'] ?? 0;
                        return pw.Text('• $jam : $jumlah buku');
                      }).toList(),
                ),
              ],
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Rekomendasi_Pengadaan_${notification.judulBuku}.pdf',
      onLayout: (format) async => pdf.save(),
    );
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
