import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../utils/kondisi_buku_report_printer.dart';
import 'ubah_kondisi_buku_screen.dart';

/// Module 3: Reporting — Laporan Buku Rusak / Hilang
class LaporanBukuRusakHilangScreen extends StatefulWidget {
  const LaporanBukuRusakHilangScreen({super.key});

  @override
  State<LaporanBukuRusakHilangScreen> createState() =>
      _LaporanBukuRusakHilangScreenState();
}

class _LaporanBukuRusakHilangScreenState
    extends State<LaporanBukuRusakHilangScreen>
    with SingleTickerProviderStateMixin {
  final _firestoreService = FirestoreService();
  late TabController _tabController;

  List<BukuModel> _bukuRusakHilang = [];
  List<Map<String, dynamic>> _riwayatKondisi = [];
  bool _loading = true;
  String? _error;

  String _filterStatus = 'Semua';

  // Palette warna konsisten — netral + aksen lembut
  static const _kPrimary = Color(0xFF455A64);
  static const _kRusak = Color(0xFFE65100);
  static const _kHilang = Color(0xFFC62828);
  static const _kSurface = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _firestoreService.getBukuRusakHilang(),
        _firestoreService.getRiwayatKondisiBuku(),
      ]);
      setState(() {
        _bukuRusakHilang = results[0] as List<BukuModel>;
        _riwayatKondisi = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<BukuModel> get _filteredBuku {
    if (_filterStatus == 'Semua') return _bukuRusakHilang;
    return _bukuRusakHilang
        .where((b) => b.statusKondisi == _filterStatus)
        .toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Rusak':
        return _kRusak;
      case 'Hilang':
        return _kHilang;
      default:
        return _kPrimary;
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return '-';
    DateTime dt;
    if (val is Timestamp) {
      dt = val.toDate();
    } else if (val is DateTime) {
      dt = val;
    } else {
      return val.toString();
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        title: const Text('Laporan Kondisi Buku'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Cetak Laporan',
            onPressed:
                _filteredBuku.isEmpty
                    ? null
                    : () {
                      KondisiBukuReportPrinter.printLaporan(
                        bukuList: _filteredBuku,
                        filterStatus:
                            _filterStatus == 'Semua' ? null : _filterStatus,
                      );
                    },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'Buku Saat Ini'),
            Tab(text: 'Riwayat Perubahan'),
          ],
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : TabBarView(
                controller: _tabController,
                children: [_buildBukuTab(), _buildRiwayatTab()],
              ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_error',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: BUKU SAAT INI ─────────────────────────────
  Widget _buildBukuTab() {
    final totalRusak = _bukuRusakHilang.fold<int>(
      0,
      (s, b) => s + b.effectiveJumlahRusak,
    );
    final totalHilang = _bukuRusakHilang.fold<int>(
      0,
      (s, b) => s + b.effectiveJumlahHilang,
    );

    return Column(
      children: [
        // Stats + Filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            children: [
              // Stats row
              Row(
                children: [
                  _buildStatChip(
                    '${_bukuRusakHilang.length}',
                    'Judul',
                    _kPrimary,
                  ),
                  const SizedBox(width: 10),
                  _buildStatChip('$totalRusak', 'Rusak', _kRusak),
                  const SizedBox(width: 10),
                  _buildStatChip('$totalHilang', 'Hilang', _kHilang),
                ],
              ),
              const SizedBox(height: 14),
              // Filter row
              Row(
                children: [
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...['Semua', 'Rusak', 'Hilang'].map((f) {
                    final selected = _filterStatus == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          f,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? Colors.white : Colors.grey[700],
                          ),
                        ),
                        selected: selected,
                        selectedColor: _kPrimary,
                        backgroundColor: Colors.grey[100],
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => setState(() => _filterStatus = f),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child:
              _filteredBuku.isEmpty
                  ? _buildEmptyState(
                    Icons.verified_outlined,
                    'Semua buku dalam kondisi baik',
                    'Tidak ada buku rusak atau hilang saat ini.',
                  )
                  : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _filteredBuku.length,
                      itemBuilder:
                          (context, index) =>
                              _buildBukuItem(_filteredBuku[index]),
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildBukuItem(BukuModel buku) {
    final rusakCount = buku.effectiveJumlahRusak;
    final hilangCount = buku.effectiveJumlahHilang;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final changed = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => UbahKondisiBukuScreen(buku: buku),
              ),
            );
            if (changed == true) _loadData();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: dot + title + status tag
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor(buku.statusKondisi),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            buku.judul,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            buku.pengarang,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusTag(buku.statusKondisi),
                  ],
                ),

                const SizedBox(height: 10),

                // Row 2: Info bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      if (rusakCount > 0) ...[
                        _buildInfoPill('Rusak', '$rusakCount', _kRusak),
                        const SizedBox(width: 14),
                      ],
                      if (hilangCount > 0) ...[
                        _buildInfoPill('Hilang', '$hilangCount', _kHilang),
                        const SizedBox(width: 14),
                      ],
                      _buildInfoPill('Stok', '${buku.stok}', _kPrimary),
                      const Spacer(),
                      Text(
                        _formatDate(buku.tanggalStatusKondisi),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),

                // Row 3: Catatan
                if (buku.catatanKondisi != null &&
                    buku.catatanKondisi!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          buku.catatanKondisi!,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ─── TAB 2: RIWAYAT PERUBAHAN ─────────────────────────
  Widget _buildRiwayatTab() {
    if (_riwayatKondisi.isEmpty) {
      return _buildEmptyState(
        Icons.history_toggle_off_rounded,
        'Belum ada riwayat',
        'Riwayat perubahan kondisi buku akan muncul di sini.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: _riwayatKondisi.length,
        itemBuilder: (context, index) {
          final r = _riwayatKondisi[index];
          final statusBefore = r['status_sebelum'] ?? '-';
          final statusAfter = r['status_sesudah'] ?? '-';
          final jumlah = r['jumlah'] as int? ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Date
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r['judul_buku'] ?? '-',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      _formatDate(r['tanggal']),
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Status change
                Row(
                  children: [
                    _buildStatusTag(statusBefore),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ),
                    _buildStatusTag(statusAfter),
                    if (jumlah > 0) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$jumlah eks',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (r['catatan'] != null &&
                    r['catatan'].toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    r['catatan'],
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusTag(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  // ─── SHARED ───────────────────────────────────────────
  Widget _buildStatChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}
