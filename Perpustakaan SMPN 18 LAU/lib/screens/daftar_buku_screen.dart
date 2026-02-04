import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import 'detail_buku_screen.dart';
import '../widgets/buku_card.dart';

class DaftarBukuScreen extends StatefulWidget {
  const DaftarBukuScreen({super.key});

  @override
  State<DaftarBukuScreen> createState() => _DaftarBukuScreenState();
}

class _DaftarBukuScreenState extends State<DaftarBukuScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<BukuModel> _allBukuList = [];
  List<BukuModel> _filteredBukuList = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBuku();
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuku() async {
    try {
      final bukuList = await _firestoreService.getBuku();

      // Ambil daftar kategori unik
      final categories = bukuList.map((b) => b.kategori).toSet().toList();
      categories.sort();

      setState(() {
        _allBukuList = bukuList;
        _filteredBukuList = bukuList;
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredBukuList =
          _allBukuList.where((buku) {
            final matchSearch =
                query.isEmpty ||
                buku.judul.toLowerCase().contains(query) ||
                buku.pengarang.toLowerCase().contains(query);

            final matchCategory =
                _selectedCategory == null || buku.kategori == _selectedCategory;

            return matchSearch && matchCategory;
          }).toList();
    });
  }

  /// Cetak Laporan PDF Total Buku
  Future<void> _cetakLaporanPDF() async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');
    final tanggalCetak = dateFormat.format(now);

    // Hitung statistik
    final totalBuku = _allBukuList.length;
    final totalStok = _allBukuList.fold<int>(0, (sum, b) => sum + b.stok);

    // Hitung per kategori
    final Map<String, int> kategoriCount = {};
    final Map<String, int> kategoriStok = {};
    for (final buku in _allBukuList) {
      kategoriCount[buku.kategori] = (kategoriCount[buku.kategori] ?? 0) + 1;
      kategoriStok[buku.kategori] =
          (kategoriStok[buku.kategori] ?? 0) + buku.stok;
    }

    // Sortir buku berdasarkan kategori lalu judul
    final sortedBuku = List<BukuModel>.from(_allBukuList)..sort((a, b) {
      final katCompare = a.kategori.compareTo(b.kategori);
      if (katCompare != 0) return katCompare;
      return a.judul.compareTo(b.judul);
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header:
            (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'PERPUSTAKAAN SMPN 18 LAU',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'LAPORAN DATA BUKU',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 8),
              ],
            ),
        footer:
            (context) => pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
        build:
            (context) => [
              // Info tanggal cetak
              pw.Text(
                'Tanggal Cetak: $tanggalCetak',
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 16),

              // Ringkasan
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RINGKASAN',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Judul Buku:'),
                        pw.Text(
                          '$totalBuku judul',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Total Stok Buku:'),
                        pw.Text(
                          '$totalStok eksemplar',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Jumlah Kategori:'),
                        pw.Text(
                          '${kategoriCount.length} kategori',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Tabel per kategori
              pw.Text(
                'RINGKASAN PER KATEGORI',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Kategori',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Jumlah Judul',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Total Stok',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  ...kategoriCount.entries.map(
                    (e) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(e.key),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${e.value}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${kategoriStok[e.key]}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Tabel daftar buku
              pw.Text(
                'DAFTAR BUKU',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(3),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(50),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'No',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Judul Buku',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Penerbit',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Kategori',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Stok',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  ...sortedBuku.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final buku = entry.value;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${idx + 1}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(buku.judul),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(buku.pengarang),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(buku.kategori),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            '${buku.stok}',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
      ),
    );

    // Tampilkan preview dan opsi cetak
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Laporan_Buku_Perpustakaan_${DateFormat('yyyyMMdd').format(now)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daftar Buku',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            tooltip: 'Cetak Laporan PDF',
            onPressed: _allBukuList.isEmpty ? null : _cetakLaporanPDF,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari judul atau penerbit...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        )
                        : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Category Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: DropdownButton<String?>(
                isExpanded: true,
                underline: const SizedBox(),
                value: _selectedCategory == null ? 'Semua' : _selectedCategory,
                items: [
                  const DropdownMenuItem(
                    value: 'Semua',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Semua Kategori',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  ..._categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          category,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value == 'Semua' ? null : value;
                    _filterBooks();
                  });
                },
                dropdownColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          // Books List
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF87CEEB),
                      ),
                    )
                    : _filteredBukuList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedCategory != null
                                ? 'Tidak ada buku yang sesuai'
                                : 'Belum ada buku tersedia',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _selectedCategory != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _selectedCategory = null);
                                _filterBooks();
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Reset Filter'),
                            ),
                          ],
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadBuku,
                      color: const Color(0xFF87CEEB),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredBukuList.length,
                        cacheExtent: 500,
                        itemExtent: null,
                        itemBuilder: (context, index) {
                          final buku = _filteredBukuList[index];
                          return BukuCard(
                            key: ValueKey(buku.id),
                            buku: buku,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => DetailBukuScreen(buku: buku),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
