import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetailAnggotaScreen extends StatefulWidget {
  final Map<String, dynamic> siswa;

  const DetailAnggotaScreen({super.key, required this.siswa});

  @override
  State<DetailAnggotaScreen> createState() => _DetailAnggotaScreenState();
}

class _DetailAnggotaScreenState extends State<DetailAnggotaScreen> {
  bool _isPrinting = false;

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      // Coba ambil dari field lain jika created_at tidak ada
      return 'Belum tersedia';
    }
    try {
      DateTime? date;

      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        if (timestamp.isNotEmpty) {
          date = DateTime.parse(timestamp);
        }
      } else if (timestamp is DateTime) {
        date = timestamp;
      }

      if (date != null) {
        // Format sederhana: dd/MM/yyyy
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        final year = date.year.toString();
        return '$day/$month/$year';
      }
    } catch (e) {
      print('Error formatting date: $e, timestamp: $timestamp');
    }
    return 'Belum tersedia';
  }

  String _formatDateForPDF(dynamic timestamp) {
    // Sama dengan _formatDate untuk konsistensi
    return _formatDate(timestamp);
  }

  Future<void> _printData() async {
    if (_isPrinting) return;

    setState(() => _isPrinting = true);

    try {
      await initializeDateFormatting('id_ID', null);

      final pdf = pw.Document();
      final primaryColor = PdfColor.fromHex('#0D47A1');
      final lightBlue = PdfColor.fromHex('#E3F2FD');
      final now = DateTime.now();
      final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(now);
      final formattedTime = DateFormat('HH:mm').format(now);

      // Try to load school logo
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load(
          'assets/images/perpustakaan1.jpeg',
        );
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      // Get peminjaman stats for this student
      int totalPinjaman = 0;
      int pinjamanAktif = 0;
      int dikembalikan = 0;
      try {
        final uid = widget.siswa['uid'] ?? '';
        if (uid.toString().isNotEmpty) {
          final peminjamanSnap =
              await FirebaseFirestore.instance
                  .collection('peminjaman')
                  .where('uid_siswa', isEqualTo: uid)
                  .get();
          for (final doc in peminjamanSnap.docs) {
            final status =
                (doc.data()['status'] ?? '').toString().toLowerCase();
            totalPinjaman++;
            if (status == 'dipinjam') pinjamanAktif++;
            if (status == 'dikembalikan') dikembalikan++;
          }
        }
      } catch (_) {}

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // === HEADER ===
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: primaryColor, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 60,
                          height: 60,
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        ),
                      if (logoImage != null) pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'PERPUSTAKAAN SMPN 18 LAU',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'KARTU DATA ANGGOTA PERPUSTAKAAN',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              height: 2,
                              width: 200,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // === DATA ANGGOTA TABLE ===
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      // Table header
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(3),
                            topRight: pw.Radius.circular(3),
                          ),
                        ),
                        child: pw.Text(
                          'DATA PRIBADI ANGGOTA',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      _buildPdfTableRow(
                        'Nama Lengkap',
                        widget.siswa['nama'] ?? '-',
                        false,
                      ),
                      _buildPdfTableRow(
                        'NIS',
                        widget.siswa['nis'] ?? '-',
                        true,
                      ),
                      _buildPdfTableRow(
                        'Kelas',
                        (widget.siswa['kelas'] != null &&
                                widget.siswa['kelas'].toString().isNotEmpty)
                            ? widget.siswa['kelas']
                            : '-',
                        false,
                      ),
                      _buildPdfTableRow(
                        'Username',
                        widget.siswa['username'] ?? '-',
                        true,
                      ),
                      _buildPdfTableRow(
                        'Tanggal Terdaftar',
                        _formatDateForPDF(widget.siswa['created_at']),
                        false,
                      ),
                      _buildPdfTableRow('Status', 'Anggota Aktif', true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // === STATISTIK PEMINJAMAN ===
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#388E3C'),
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(3),
                            topRight: pw.Radius.circular(3),
                          ),
                        ),
                        child: pw.Text(
                          'STATISTIK PEMINJAMAN',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      _buildPdfTableRow(
                        'Total Peminjaman',
                        '$totalPinjaman buku',
                        false,
                      ),
                      _buildPdfTableRow(
                        'Sedang Dipinjam',
                        '$pinjamanAktif buku',
                        true,
                      ),
                      _buildPdfTableRow(
                        'Sudah Dikembalikan',
                        '$dikembalikan buku',
                        false,
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // === CATATAN ===
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBlue,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#90CAF9')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Catatan:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '• Kartu ini merupakan bukti keanggotaan perpustakaan SMPN 18 LAU.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '• Kartu ini bersifat pribadi dan tidak dapat dipindahtangankan.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '• Data statistik peminjaman diambil berdasarkan data terkini.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // === FOOTER: TTD + Tanggal ===
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Dicetak pada:',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          '$formattedDate, $formattedTime WIB',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Mengetahui,',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Petugas Perpustakaan',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 50),
                        pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(width: 1)),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'NIP. .............................',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibuat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  pw.Widget _buildPdfTableRow(String label, String value, bool isShaded) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: isShaded ? PdfColor.fromHex('#F5F5F5') : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 160,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Anggota'),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon:
                _isPrinting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.print),
            onPressed: _isPrinting ? null : _printData,
            tooltip: 'Cetak Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(
                          0xFF0D47A1,
                        ).withOpacity(0.1),
                        backgroundImage:
                            (widget.siswa['photo_url'] != null &&
                                    widget.siswa['photo_url']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(widget.siswa['photo_url'])
                                : null,
                        child:
                            (widget.siswa['photo_url'] == null ||
                                    widget.siswa['photo_url']
                                        .toString()
                                        .isEmpty)
                                ? const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Color(0xFF0D47A1),
                                )
                                : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.siswa['nama'] ?? '-',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 20),
                // Info
                _buildInfoTile(
                  context,
                  Icons.badge,
                  'NIS',
                  widget.siswa['nis'] ?? '-',
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  context,
                  Icons.class_,
                  'Kelas',
                  (widget.siswa['kelas'] != null &&
                          widget.siswa['kelas'].toString().isNotEmpty)
                      ? widget.siswa['kelas']
                      : 'Belum diatur',
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  context,
                  Icons.person,
                  'Username',
                  widget.siswa['username'] ?? '-',
                ),
                const SizedBox(height: 16),
                _buildInfoTile(
                  context,
                  Icons.calendar_today,
                  'Tanggal Terdaftar',
                  _formatDate(
                    widget.siswa['created_at'] ??
                        widget.siswa['createdAt'] ??
                        widget.siswa['tanggal_terdaftar'],
                  ),
                ),
                const SizedBox(height: 32),
                // Print Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _printData,
                    icon:
                        _isPrinting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.print),
                    label: Text(
                      _isPrinting ? 'Mencetak...' : 'Cetak Data Anggota',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isPrinting ? Colors.grey : const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D47A1)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
