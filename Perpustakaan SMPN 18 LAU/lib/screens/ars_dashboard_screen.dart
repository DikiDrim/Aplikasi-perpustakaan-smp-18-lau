import 'package:flutter/material.dart';
import '../services/ars_service_impl.dart';
import '../models/ars_result_model.dart';

class ArsDashboardScreen extends StatefulWidget {
  const ArsDashboardScreen({super.key});

  @override
  State<ArsDashboardScreen> createState() => _ArsDashboardScreenState();
}

class _ArsDashboardScreenState extends State<ArsDashboardScreen> {
  final ArsService _arsService = ArsService();
  bool _loading = true;
  List<ArsResultModel> _arsResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      final results = await _arsService.runArsAllKategori();
      setState(() => _arsResults = results);
    } catch (e) {
      if (!mounted) return;
      debugPrint('ARS Dashboard error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data ARS: $e'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perluPengadaan = _arsResults.where((r) => r.perluPengadaan).length;
    final stokAman = _arsResults.where((r) => !r.perluPengadaan).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'ARS Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body:
          _loading
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF0D47A1)),
                    const SizedBox(height: 16),
                    Text(
                      'Menghitung ARS...',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                color: const Color(0xFF0D47A1),
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    // ── Gradient Summary Header ──
                    Transform.translate(
                      offset: const Offset(0, -1),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(24),
                            bottomRight: Radius.circular(24),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D47A1).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _SummaryBadge(
                              icon: Icons.category_rounded,
                              value: '${_arsResults.length}',
                              label: 'Kategori',
                              bgColor: Colors.white.withOpacity(0.15),
                            ),
                            const SizedBox(width: 12),
                            _SummaryBadge(
                              icon: Icons.warning_amber_rounded,
                              value: '$perluPengadaan',
                              label: 'Perlu Restock',
                              bgColor:
                                  perluPengadaan > 0
                                      ? Colors.red.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.15),
                            ),
                            const SizedBox(width: 12),
                            _SummaryBadge(
                              icon: Icons.check_circle_outline_rounded,
                              value: '$stokAman',
                              label: 'Stok Aman',
                              bgColor: Colors.green.withOpacity(0.25),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Parameter Info ──
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3F2FD)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Parameter ARS',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'L = ${ArsService.defaultLeadTime} hari  •  '
                                  'Z = ${ArsService.defaultNilaiZ}  •  '
                                  'Observasi = ${ArsService.defaultJumlahHari} hari',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Section Header ──
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Hasil Analisis per Kategori',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // ── Empty state ──
                    if (_arsResults.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 24),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tidak ada data kategori buku',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tambahkan buku untuk memulai analisis ARS',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._arsResults.map(
                        (result) => _buildArsResultCard(result),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildArsResultCard(ArsResultModel result) {
    final bool kritis = result.perluPengadaan;
    final Color accentColor =
        kritis ? const Color(0xFFE53935) : const Color(0xFF2E7D32);
    final Color lightBg =
        kritis ? const Color(0xFFFFF5F5) : const Color(0xFFF1F8E9);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          initiallyExpanded: kritis,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    kritis
                        ? [const Color(0xFFE53935), const Color(0xFFEF5350)]
                        : [const Color(0xFF2E7D32), const Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              kritis
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          title: Text(
            result.kategori,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lightBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.statusStok,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${result.jumlahBuku} buku',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          children: [
            Container(
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // ── Peminjaman Harian ──
                  Text(
                    'Peminjaman Harian (7 hari terakhir)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildDailyChart(result.peminjamanHarian, accentColor),
                  const SizedBox(height: 18),
                  // ── Tabel Perhitungan ──
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _calcRow(
                          'Stok Saat Ini (dari DB)',
                          '${result.stokAwal} buku',
                        ),
                        _calcRow(
                          'Total Peminjaman (7 hari)',
                          '${result.totalPeminjaman} buku',
                        ),
                        const Divider(height: 14),
                        _calcRow(
                          'Rata-rata Permintaan (D̅)',
                          result.rataRataPermintaan.toStringAsFixed(4),
                        ),
                        _calcRow(
                          'Standar Deviasi (σ)',
                          result.standarDeviasi.toStringAsFixed(4),
                        ),
                        _calcRow(
                          'Safety Stock (SS)',
                          result.safetyStock.toStringAsFixed(4),
                        ),
                        _calcRow(
                          'Reorder Point (ROP)',
                          result.reorderPoint.toStringAsFixed(4),
                        ),
                        const Divider(height: 14),
                        _calcRow(
                          'Stok Akhir',
                          '${result.stokAkhir} buku',
                          valueColor: accentColor,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Status Banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors:
                            kritis
                                ? [
                                  const Color(0xFFFFF5F5),
                                  const Color(0xFFFFEBEE),
                                ]
                                : [
                                  const Color(0xFFF1F8E9),
                                  const Color(0xFFE8F5E9),
                                ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            kritis
                                ? Icons.warning_amber_rounded
                                : Icons.verified_rounded,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.statusStok,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                kritis
                                    ? 'Stok ${result.stokAkhir} ≤ ROP ${result.reorderPoint.toStringAsFixed(2)}'
                                    : 'Stok ${result.stokAkhir} > ROP ${result.reorderPoint.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: accentColor.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bar chart with gradient bars
  Widget _buildDailyChart(List<int> dailyCounts, Color accentColor) {
    final maxVal =
        dailyCounts.isEmpty ? 1 : dailyCounts.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxVal == 0 ? 1 : maxVal;

    final now = DateTime.now();
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(dailyCounts.length, (i) {
          final date = now.subtract(Duration(days: dailyCounts.length - 1 - i));
          final dayLabel = days[date.weekday - 1];
          final count = dailyCounts[i];
          final barHeight = (count / effectiveMax) * 60;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color:
                          count > 0
                              ? const Color(0xFF0D47A1)
                              : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight.clamp(4, 60).toDouble(),
                    decoration: BoxDecoration(
                      gradient:
                          count > 0
                              ? const LinearGradient(
                                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                              : null,
                      color: count > 0 ? null : Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _calcRow(
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary badge inside gradient header
class _SummaryBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color bgColor;

  const _SummaryBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
