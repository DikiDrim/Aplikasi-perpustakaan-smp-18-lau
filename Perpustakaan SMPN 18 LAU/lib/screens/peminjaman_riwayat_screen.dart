import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../utils/peminjaman_report_printer.dart';

class PeminjamanRiwayatScreen extends StatefulWidget {
  const PeminjamanRiwayatScreen({super.key});

  @override
  State<PeminjamanRiwayatScreen> createState() =>
      _PeminjamanRiwayatScreenState();
}

class _PeminjamanRiwayatScreenState extends State<PeminjamanRiwayatScreen> {
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  final ScrollController _scrollController = ScrollController();
  String _filterStatus = 'Semua'; // 'Semua', 'Dipinjam', 'Dikembalikan'
  List<Map<String, dynamic>> _allDocsData = []; // untuk PDF

  // Search & month filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _filterMonth; // 1-12
  int? _filterYear;

  // Bulan dalam bahasa Indonesia
  static const _bulanIndo = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _monthYearLabel(DateTime d) => '${_bulanIndo[d.month]} ${d.year}';

  void _pickMonth() {
    final now = DateTime.now();
    int tempMonth = _filterMonth ?? now.month;
    int tempYear = _filterYear ?? now.year;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Bulan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed:
                              tempYear > 2020
                                  ? () => setModalState(() => tempYear--)
                                  : null,
                        ),
                        Text(
                          '$tempYear',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              tempYear < now.year
                                  ? () => setModalState(() => tempYear++)
                                  : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Month grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 2.2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: 12,
                      itemBuilder: (context, i) {
                        final m = i + 1;
                        final isSelected = m == tempMonth;
                        final isFuture = tempYear == now.year && m > now.month;
                        return Material(
                          color:
                              isSelected
                                  ? const Color(0xFF0D47A1)
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap:
                                isFuture
                                    ? null
                                    : () => setModalState(() => tempMonth = m),
                            child: Center(
                              child: Text(
                                _bulanIndo[m].substring(0, 3),
                                style: TextStyle(
                                  color:
                                      isFuture
                                          ? Colors.grey[400]
                                          : isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _filterMonth = null;
                                _filterYear = null;
                              });
                            },
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _filterMonth = tempMonth;
                                _filterYear = tempYear;
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0D47A1),
                            ),
                            child: const Text('Terapkan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Peminjaman'),
        actions: [
          // Tombol filter bulan
          IconButton(
            tooltip: 'Filter bulan',
            icon: Badge(
              isLabelVisible: _filterMonth != null,
              smallSize: 8,
              child: const Icon(Icons.calendar_month),
            ),
            onPressed: _pickMonth,
          ),
          // Tombol filter status
          PopupMenuButton<String>(
            tooltip: 'Filter status',
            icon: Badge(
              isLabelVisible: _filterStatus != 'Semua',
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
            onSelected: (value) {
              setState(() => _filterStatus = value);
            },
            itemBuilder:
                (_) => [
                  PopupMenuItem(
                    value: 'Semua',
                    child: Row(
                      children: [
                        Icon(
                          Icons.list,
                          color:
                              _filterStatus == 'Semua'
                                  ? Colors.blue
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Semua'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Dipinjam',
                    child: Row(
                      children: [
                        Icon(
                          Icons.book,
                          color:
                              _filterStatus == 'Dipinjam'
                                  ? Colors.orange
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Sedang Dipinjam'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'Dikembalikan',
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color:
                              _filterStatus == 'Dikembalikan'
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        const Text('Dikembalikan'),
                      ],
                    ),
                  ),
                ],
          ),
          // Tombol cetak PDF
          IconButton(
            tooltip: 'Cetak Laporan PDF',
            icon: const Icon(Icons.print),
            onPressed: () {
              if (_allDocsData.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tidak ada data untuk dicetak')),
                );
                return;
              }
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder:
                    (ctx) => SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cetak Laporan Peminjaman',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total data: ${_allDocsData.length} peminjaman',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              leading: const Icon(
                                Icons.list_alt,
                                color: Color(0xFF0D47A1),
                              ),
                              title: const Text('Cetak Semua Data'),
                              subtitle: Text(
                                '${_allDocsData.length} peminjaman',
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                PeminjamanReportPrinter.printLaporan(
                                  dataList: _allDocsData,
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.book,
                                color: Colors.orange,
                              ),
                              title: const Text('Cetak Sedang Dipinjam'),
                              subtitle: Text(
                                '${_allDocsData.where((d) => (d['status'] ?? '') != 'dikembalikan').length} peminjaman',
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                PeminjamanReportPrinter.printLaporan(
                                  dataList: _allDocsData,
                                  filterStatus: 'dipinjam',
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              title: const Text('Cetak Yang Dikembalikan'),
                              subtitle: Text(
                                '${_allDocsData.where((d) => (d['status'] ?? '') == 'dikembalikan').length} peminjaman',
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                PeminjamanReportPrinter.printLaporan(
                                  dataList: _allDocsData,
                                  filterStatus: 'dikembalikan',
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('peminjaman')
                .orderBy('tanggal_pinjam', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Belum ada riwayat.'));
          }
          final allDocs = snapshot.data!.docs;
          // Simpan semua data untuk PDF export
          _allDocsData = allDocs.map((doc) => doc.data()).toList();

          // Filter berdasarkan status
          var filteredDocs =
              _filterStatus == 'Semua'
                  ? allDocs.toList()
                  : allDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '').toString();
                    if (_filterStatus == 'Dipinjam')
                      return status != 'dikembalikan';
                    if (_filterStatus == 'Dikembalikan')
                      return status == 'dikembalikan';
                    return true;
                  }).toList();

          // Filter berdasarkan bulan
          if (_filterMonth != null && _filterYear != null) {
            filteredDocs =
                filteredDocs.where((doc) {
                  final ts = doc.data()['tanggal_pinjam'];
                  if (ts == null) return false;
                  final date = (ts as Timestamp).toDate();
                  return date.month == _filterMonth && date.year == _filterYear;
                }).toList();
          }

          // Filter berdasarkan search query
          final docs =
              _searchQuery.isEmpty
                  ? filteredDocs
                  : filteredDocs.where((doc) {
                    final d = doc.data();
                    final judul =
                        (d['judul_buku'] ?? '').toString().toLowerCase();
                    final nama =
                        (d['nama_peminjam'] ?? '').toString().toLowerCase();
                    final kelas = (d['kelas'] ?? '').toString().toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    return judul.contains(q) ||
                        nama.contains(q) ||
                        kelas.contains(q);
                  }).toList();

          // Notifikasi sederhana bila ada yang terlambat (sekali per menit)
          final now = DateTime.now();
          if (now.difference(_lastNotify).inMinutes >= 1) {
            final overdueCount =
                allDocs.where((doc) {
                  final d = doc.data();
                  final status = (d['status'] ?? '').toString();
                  final ts = d['tanggal_jatuh_tempo'];
                  if (status == 'dikembalikan' || ts == null) return false;
                  final due = (ts as Timestamp).toDate();
                  return now.isAfter(due);
                }).length;
            if (overdueCount > 0) {
              _lastNotify = now;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$overdueCount peminjaman sudah lewat jatuh tempo',
                    ),
                  ),
                );
              });
            }
          }

          // Bangun daftar item dengan header bulan
          final listItems = <_ListItem>[];
          String? lastMonthLabel;
          for (final doc in docs) {
            final d = doc.data();
            final ts = d['tanggal_pinjam'] as Timestamp?;
            final date = ts?.toDate();
            final label =
                date != null ? _monthYearLabel(date) : 'Tidak Diketahui';
            if (label != lastMonthLabel) {
              listItems.add(_ListItem(isHeader: true, headerLabel: label));
              lastMonthLabel = label;
            }
            listItems.add(_ListItem(isHeader: false, doc: doc));
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari judul buku, peminjam, kelas...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              // Active filters chips
              if (_filterStatus != 'Semua' || _filterMonth != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_filterStatus != 'Semua')
                        Chip(
                          avatar: Icon(
                            _filterStatus == 'Dipinjam'
                                ? Icons.book
                                : Icons.check_circle,
                            size: 16,
                            color:
                                _filterStatus == 'Dipinjam'
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          label: Text(
                            _filterStatus,
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted:
                              () => setState(() => _filterStatus = 'Semua'),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (_filterMonth != null)
                        Chip(
                          avatar: const Icon(
                            Icons.calendar_month,
                            size: 16,
                            color: Color(0xFF0D47A1),
                          ),
                          label: Text(
                            '${_bulanIndo[_filterMonth!]} $_filterYear',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted:
                              () => setState(() {
                                _filterMonth = null;
                                _filterYear = null;
                              }),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      Text(
                        '${docs.length} data',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Empty state
              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ditemukan "$_searchQuery"'
                              : 'Tidak ada data dengan filter ini',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filterStatus = 'Semua';
                              _filterMonth = null;
                              _filterYear = null;
                            });
                          },
                          child: const Text('Reset Semua Filter'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: listItems.length,
                    itemBuilder: (context, index) {
                      final item = listItems[index];

                      // Header bulan
                      if (item.isHeader) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 4 : 20,
                            bottom: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D47A1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.headerLabel!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[300],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Card riwayat
                      final d = item.doc!.data();
                      final status = (d['status'] ?? '').toString();
                      final due =
                          d['tanggal_jatuh_tempo'] != null
                              ? (d['tanggal_jatuh_tempo'] as Timestamp).toDate()
                              : null;
                      final isOverdue =
                          status != 'dikembalikan' &&
                          due != null &&
                          now.isAfter(
                            DateTime(due.year, due.month, due.day, 23, 59),
                          );
                      final daysLeft =
                          due != null
                              ? due
                                  .difference(
                                    DateTime(now.year, now.month, now.day),
                                  )
                                  .inDays
                              : null;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: 12,
                                    top: 2,
                                  ),
                                  child: Icon(
                                    Icons.book,
                                    color:
                                        status == 'dikembalikan'
                                            ? Colors.green
                                            : Colors.orange,
                                    size: 32,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['judul_buku'] ?? '-',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                            'Peminjam: ${d['nama_peminjam'] ?? '-'}',
                                          ),
                                          if (d['kelas'] != null)
                                            Text('Kelas: ${d['kelas']}'),
                                          if (d['jumlah'] != null)
                                            Text('Jumlah: ${d['jumlah']} buku'),
                                          if (d['kondisi_buku'] != null &&
                                              d['kondisi_buku']
                                                  .toString()
                                                  .isNotEmpty &&
                                              d['kondisi_buku'].toString() !=
                                                  'Baik')
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    d['kondisi_buku'] == 'Rusak'
                                                        ? Colors.orange
                                                            .withOpacity(0.15)
                                                        : Colors.red
                                                            .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color:
                                                      d['kondisi_buku'] ==
                                                              'Rusak'
                                                          ? Colors.orange
                                                          : Colors.red,
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    d['kondisi_buku'] == 'Rusak'
                                                        ? Icons
                                                            .warning_amber_rounded
                                                        : Icons.error,
                                                    size: 12,
                                                    color:
                                                        d['kondisi_buku'] ==
                                                                'Rusak'
                                                            ? Colors.orange
                                                            : Colors.red,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${d['kondisi_buku']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          d['kondisi_buku'] ==
                                                                  'Rusak'
                                                              ? Colors
                                                                  .orange[800]
                                                              : Colors.red[800],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (d['tanggal_pinjam'] != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.login,
                                              size: 14,
                                              color: Colors.blueGrey,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Dipinjam: ${_fmt((d['tanggal_pinjam'] as Timestamp).toDate())}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blueGrey,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (status == 'dikembalikan' &&
                                          d['tanggal_kembali'] != null)
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.logout,
                                              size: 14,
                                              color: Colors.green,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                'Dikembalikan: ${_fmt((d['tanggal_kembali'] as Timestamp).toDate())}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (due != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              isOverdue
                                                  ? Icons.warning_amber
                                                  : Icons.schedule,
                                              size: 18,
                                              color:
                                                  isOverdue
                                                      ? Colors.red
                                                      : Colors.blueGrey,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                isOverdue
                                                    ? 'Terlambat (jatuh tempo: ${_fmt(due)})'
                                                    : 'Jatuh tempo: ${_fmt(due)}${daysLeft != null ? ' \u2022 $daysLeft hari' : ''}',
                                                style: TextStyle(
                                                  color:
                                                      isOverdue
                                                          ? Colors.red
                                                          : Colors.black87,
                                                  fontWeight:
                                                      isOverdue
                                                          ? FontWeight.bold
                                                          : null,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 72,
                                    maxWidth: 120,
                                  ),
                                  child: Text(
                                    status == 'dikembalikan'
                                        ? 'DIKEMBALIKAN'
                                        : 'DIPINJAM',
                                    style: TextStyle(
                                      color:
                                          status == 'dikembalikan'
                                              ? Colors.green
                                              : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Helper class untuk list item (header bulan atau data card)
class _ListItem {
  final bool isHeader;
  final String? headerLabel;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  _ListItem({required this.isHeader, this.headerLabel, this.doc});
}
