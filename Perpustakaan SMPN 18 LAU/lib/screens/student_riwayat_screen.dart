import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentRiwayatScreen extends StatefulWidget {
  const StudentRiwayatScreen({super.key});

  @override
  State<StudentRiwayatScreen> createState() => _StudentRiwayatScreenState();
}

class _StudentRiwayatScreenState extends State<StudentRiwayatScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'Semua'; // 'Semua', 'Dipinjam', 'Dikembalikan'

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

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _monthYearLabel(DateTime d) => '${_bulanIndo[d.month]} ${d.year}';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Saya')),
        body: const Center(child: Text('Anda belum login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Saya',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter status',
            icon: Badge(
              isLabelVisible: _filterStatus != 'Semua',
              smallSize: 8,
              child: const Icon(Icons.filter_list, color: Colors.white),
            ),
            onSelected: (value) => setState(() => _filterStatus = value),
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
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('peminjaman')
                .where('uid_siswa', isEqualTo: _currentUser.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];
          // Sort by tanggal_pinjam descending (newest first)
          final sortedDocs =
              allDocs.toList()..sort((a, b) {
                final aDate =
                    (a.data()['tanggal_pinjam'] as Timestamp?)?.toDate();
                final bDate =
                    (b.data()['tanggal_pinjam'] as Timestamp?)?.toDate();
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });

          // Filter status
          var filteredDocs =
              _filterStatus == 'Semua'
                  ? sortedDocs
                  : sortedDocs.where((doc) {
                    final status = (doc.data()['status'] ?? '').toString();
                    if (_filterStatus == 'Dipinjam')
                      return status != 'dikembalikan';
                    if (_filterStatus == 'Dikembalikan')
                      return status == 'dikembalikan';
                    return true;
                  }).toList();

          // Filter search
          final docs =
              _searchQuery.isEmpty
                  ? filteredDocs
                  : filteredDocs.where((doc) {
                    final d = doc.data();
                    final judul =
                        (d['judul_buku'] ?? '').toString().toLowerCase();
                    return judul.contains(_searchQuery.toLowerCase());
                  }).toList();

          // Bangun list items dengan header bulan
          final listItems = <_StudentListItem>[];
          String? lastMonthLabel;
          for (final doc in docs) {
            final d = doc.data();
            final ts = d['tanggal_pinjam'] as Timestamp?;
            final date = ts?.toDate();
            final label =
                date != null ? _monthYearLabel(date) : 'Tidak Diketahui';
            if (label != lastMonthLabel) {
              listItems.add(
                _StudentListItem(isHeader: true, headerLabel: label),
              );
              lastMonthLabel = label;
            }
            listItems.add(_StudentListItem(isHeader: false, doc: doc));
          }

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari judul buku...',
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

              // Active filter chips
              if (_filterStatus != 'Semua')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${docs.length} data',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              if (docs.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Tidak ditemukan "$_searchQuery"'
                              : 'Belum ada riwayat peminjaman',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (_searchQuery.isNotEmpty ||
                            _filterStatus != 'Semua') ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _filterStatus = 'Semua';
                              });
                            },
                            child: const Text('Reset Filter'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
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
                      final tanggalPinjam = d['tanggal_pinjam'] as Timestamp?;
                      final tanggalKembali = d['tanggal_kembali'] as Timestamp?;
                      final tanggalJatuhTempo =
                          d['tanggal_jatuh_tempo'] as Timestamp?;

                      final isOverdue =
                          tanggalJatuhTempo != null &&
                          status == 'dipinjam' &&
                          tanggalJatuhTempo.toDate().isBefore(DateTime.now());

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    status == 'dikembalikan'
                                        ? Colors.green.withOpacity(0.1)
                                        : isOverdue
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                status == 'dikembalikan'
                                    ? Icons.check_circle
                                    : Icons.book,
                                color:
                                    status == 'dikembalikan'
                                        ? Colors.green
                                        : isOverdue
                                        ? Colors.red
                                        : Colors.orange,
                              ),
                            ),
                            title: Text(
                              d['judul_buku'] ?? '-',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Jumlah: ${d['jumlah'] ?? 1} buku'),
                                Text(
                                  'Pinjam: ${_formatDate(tanggalPinjam?.toDate())}',
                                ),
                                if (tanggalKembali != null)
                                  Text(
                                    'Kembali: ${_formatDate(tanggalKembali.toDate())}',
                                  )
                                else if (tanggalJatuhTempo != null)
                                  Text(
                                    'Jatuh tempo: ${_formatDate(tanggalJatuhTempo.toDate())}',
                                    style: TextStyle(
                                      color:
                                          isOverdue
                                              ? Colors.red
                                              : Colors.grey[600],
                                      fontWeight:
                                          isOverdue
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                    ),
                                  ),
                                if (isOverdue) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Peringatan: Segera kembalikan buku ke perpustakaan',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    status == 'dikembalikan'
                                        ? Colors.green.withOpacity(0.1)
                                        : isOverdue
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status == 'dikembalikan'
                                    ? 'SELESAI'
                                    : isOverdue
                                    ? 'TERLAMBAT'
                                    : 'DIPINJAM',
                                style: TextStyle(
                                  color:
                                      status == 'dikembalikan'
                                          ? Colors.green
                                          : isOverdue
                                          ? Colors.red
                                          : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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

class _StudentListItem {
  final bool isHeader;
  final String? headerLabel;
  final QueryDocumentSnapshot<Map<String, dynamic>>? doc;

  _StudentListItem({required this.isHeader, this.headerLabel, this.doc});
}
