import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ars_notification_model.dart';
import '../services/ars_service_impl.dart';
import '../utils/async_action.dart';
import '../utils/ars_notification_printer.dart';
import 'ars_dashboard_screen.dart';

class ArsNotificationsScreen extends StatefulWidget {
  const ArsNotificationsScreen({super.key});

  @override
  State<ArsNotificationsScreen> createState() => _ArsNotificationsScreenState();
}

class _ArsNotificationsScreenState extends State<ArsNotificationsScreen> {
  final ArsService _arsService = ArsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Notifikasi ARS',
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
        actions: [
          Tooltip(
            message: 'Dashboard ARS',
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.dashboard_rounded, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ArsDashboardScreen(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<ArsNotificationModel>>(
        stream: _arsService.getUnreadNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0D47A1)),
                  const SizedBox(height: 16),
                  Text(
                    'Memuat notifikasi...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.red[400],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal memuat notifikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }
          final notifications = snapshot.data ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: Colors.green[400],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Semua Stok Aman!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada notifikasi ARS yang perlu\nditindaklanjuti saat ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ArsDashboardScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.dashboard_rounded, size: 18),
                      label: const Text('Lihat Dashboard ARS'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0D47A1),
                        side: const BorderSide(color: Color(0xFF0D47A1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              return _buildNotificationCard(notifications[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(ArsNotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final bool hasArsData = notification.reorderPoint != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetailDialog(notification),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Icon with gradient
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFEF5350)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Book title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.judulBuku,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (notification.kategori != null &&
                            notification.kategori!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                notification.kategori!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Actions
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      if (value == 'read') {
                        if (notification.id != null) {
                          try {
                            await _arsService.markNotificationAsRead(
                              notification.id!,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Notifikasi dikonfirmasi',
                                  ),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(getFriendlyErrorMessage(e)),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      } else if (value == 'print') {
                        try {
                          await ArsNotificationPrinter.printNotification(
                            notification,
                          );
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Gagal mencetak: ${getFriendlyErrorMessage(e)}',
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      } else if (value == 'delete') {
                        _confirmDelete(notification);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'read',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text('Konfirmasi'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'print',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.print_rounded,
                                  size: 18,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text('Cetak'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Info chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stok: ${notification.stokAkhir}',
                    color: Colors.orange,
                  ),
                  _InfoChip(
                    icon: Icons.shield_outlined,
                    label: 'SS: ${notification.safetyStock}',
                    color: Colors.blue,
                  ),
                  if (hasArsData)
                    _InfoChip(
                      icon: Icons.pin_outlined,
                      label:
                          'ROP: ${notification.reorderPoint!.toStringAsFixed(1)}',
                      color: Colors.purple,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Recommendation banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red[50]!,
                      Colors.red[100]!.withOpacity(0.5),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 16,
                      color: Colors.red[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rekomendasi pengadaan: ${notification.jumlahPengadaan} buku',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Date
              Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat.format(notification.tanggalNotifikasi),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(ArsNotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final bool hasArsData = notification.reorderPoint != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.5,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE53935),
                                    Color(0xFFEF5350),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.analytics_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Detail Notifikasi ARS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Buku Info ──
                              _SectionHeader(title: 'Informasi Buku'),
                              const SizedBox(height: 10),
                              _DetailCard(
                                children: [
                                  _DetailRow(
                                    label: 'Judul Buku',
                                    value: notification.judulBuku,
                                  ),
                                  if (notification.kategori != null)
                                    _DetailRow(
                                      label: 'Kategori',
                                      value: notification.kategori!,
                                    ),
                                  _DetailRow(
                                    label: 'Tanggal Notifikasi',
                                    value: dateFormat.format(
                                      notification.tanggalNotifikasi,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── Stok Info ──
                              _SectionHeader(title: 'Informasi Stok'),
                              const SizedBox(height: 10),
                              _DetailCard(
                                children: [
                                  _DetailRow(
                                    label: 'Stok Awal',
                                    value: '${notification.stokAwal} buku',
                                  ),
                                  _DetailRow(
                                    label: 'Total Peminjaman',
                                    value:
                                        '${notification.totalPeminjaman} buku',
                                  ),
                                  _DetailRow(
                                    label: 'Stok Akhir',
                                    value: '${notification.stokAkhir} buku',
                                    valueColor: Colors.red[700],
                                    bold: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // ── ARS Calculation ──
                              if (hasArsData) ...[
                                _SectionHeader(title: 'Perhitungan ARS'),
                                const SizedBox(height: 10),
                                _DetailCard(
                                  children: [
                                    if (notification.peminjamanHarian != null)
                                      _DetailRow(
                                        label: 'Peminjaman/hari',
                                        value: notification.peminjamanHarian!
                                            .join(', '),
                                      ),
                                    _DetailRow(
                                      label: 'Rata-rata (D̅)',
                                      value:
                                          notification.rataRataPermintaan
                                              ?.toStringAsFixed(4) ??
                                          '-',
                                    ),
                                    _DetailRow(
                                      label: 'Std. Deviasi (σ)',
                                      value:
                                          notification.standarDeviasi
                                              ?.toStringAsFixed(4) ??
                                          '-',
                                    ),
                                    _DetailRow(
                                      label: 'Lead Time (L)',
                                      value:
                                          '${notification.leadTime ?? ''} hari',
                                    ),
                                    _DetailRow(
                                      label: 'Nilai Z',
                                      value:
                                          notification.nilaiZ?.toStringAsFixed(
                                            2,
                                          ) ??
                                          '-',
                                    ),
                                    _DetailRow(
                                      label: 'Safety Stock (SS)',
                                      value:
                                          notification.safetyStockCalc
                                              ?.toStringAsFixed(4) ??
                                          '${notification.safetyStock}',
                                    ),
                                    _DetailRow(
                                      label: 'Reorder Point (ROP)',
                                      value:
                                          notification.reorderPoint
                                              ?.toStringAsFixed(4) ??
                                          '-',
                                    ),
                                    if (notification.statusStok != null)
                                      _DetailRow(
                                        label: 'Status Stok',
                                        value: notification.statusStok!,
                                        valueColor:
                                            notification.statusStok!
                                                    .toLowerCase()
                                                    .contains('aman')
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                        bold: true,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ── Rekomendasi ──
                              _SectionHeader(title: 'Rekomendasi'),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red[50]!,
                                      Colors.red[100]!.withOpacity(0.5),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.red[100],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.shopping_cart_outlined,
                                        color: Colors.red[700],
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pengadaan Ulang',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[800],
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Direkomendasikan menambah ${notification.jumlahPengadaan} buku',
                                            style: TextStyle(
                                              color: Colors.red[700],
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Evaluasi sebelum melakukan pemesanan',
                                            style: TextStyle(
                                              color: Colors.red[400],
                                              fontSize: 12,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // ── Detail Peminjaman ──
                              if (notification.detailPeminjaman.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                _SectionHeader(
                                  title: 'Detail Peminjaman Hari Ini',
                                ),
                                const SizedBox(height: 10),
                                _DetailCard(
                                  children:
                                      notification.detailPeminjaman.map((
                                        detail,
                                      ) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.access_time_rounded,
                                                size: 16,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '${detail['jam'] ?? detail['tanggal'] ?? ''}',
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFE3F2FD,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  '${detail['jumlah']} buku',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF1565C0),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Bottom actions
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    try {
                                      await ArsNotificationPrinter.printNotification(
                                        notification,
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Gagal mencetak: ${getFriendlyErrorMessage(e)}',
                                            ),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Cetak'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0D47A1),
                                    side: const BorderSide(
                                      color: Color(0xFF0D47A1),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      notification.id == null
                                          ? null
                                          : () async {
                                            Navigator.pop(context);
                                            try {
                                              await _arsService
                                                  .markNotificationAsRead(
                                                    notification.id!,
                                                  );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: const Text(
                                                      'Notifikasi dikonfirmasi',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green[600],
                                                    behavior:
                                                        SnackBarBehavior
                                                            .floating,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      getFriendlyErrorMessage(
                                                        e,
                                                      ),
                                                    ),
                                                    backgroundColor: Colors.red,
                                                    behavior:
                                                        SnackBarBehavior
                                                            .floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                  icon: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Konfirmasi'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  void _confirmDelete(ArsNotificationModel notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red[600],
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Hapus Notifikasi', style: TextStyle(fontSize: 17)),
              ],
            ),
            content: const Text(
              'Notifikasi yang dihapus tidak dapat dikembalikan. Lanjutkan?',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  if (notification.id != null) {
                    try {
                      await _arsService.deleteNotification(notification.id!);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Notifikasi dihapus'),
                            backgroundColor: Colors.green[600],
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(getFriendlyErrorMessage(e)),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
  }
}

/// Section header with accent bar
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

/// Styled detail card
class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Styled detail row
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
          Text(': ', style: TextStyle(color: Colors.grey[400])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.grey[800],
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Info chip used in notification cards
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color.withOpacity(0.8)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
