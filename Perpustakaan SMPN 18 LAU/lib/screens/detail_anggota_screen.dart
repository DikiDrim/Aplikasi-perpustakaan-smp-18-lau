import 'package:flutter/material.dart';
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
      // Initialize date formatting untuk PDF
      await initializeDateFormatting('id_ID', null);
      
      final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'PERPUSTAKAAN SMPN 18 LAU',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Data Anggota Perpustakaan',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),
                // Data Siswa
                _buildInfoRow('Nama Lengkap', widget.siswa['nama'] ?? '-'),
                pw.SizedBox(height: 12),
                _buildInfoRow('NIS', widget.siswa['nis'] ?? '-'),
                pw.SizedBox(height: 12),
                _buildInfoRow('Username', widget.siswa['username'] ?? '-'),
                pw.SizedBox(height: 12),
                _buildInfoRow('Tanggal Terdaftar', _formatDateForPDF(widget.siswa['created_at'])),
                pw.SizedBox(height: 30),
                pw.Divider(),
                pw.SizedBox(height: 20),
                // Footer
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Dicetak pada: ${DateFormat('dd/MM/yyyy HH:mm', 'id_ID').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
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

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 120,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value),
        ),
      ],
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
            icon: _isPrinting
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
                        backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xFF0D47A1),
                        ),
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
                    widget.siswa['tanggal_terdaftar']
                  ),
                ),
                const SizedBox(height: 32),
                // Print Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isPrinting ? null : _printData,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print),
                    label: Text(_isPrinting ? 'Mencetak...' : 'Cetak Data Anggota'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPrinting
                          ? Colors.grey
                          : const Color(0xFF0D47A1),
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

