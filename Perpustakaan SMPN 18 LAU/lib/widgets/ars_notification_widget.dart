import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ars_notification_model.dart';
import '../services/ars_service_impl.dart';
import '../screens/ars_notifications_screen.dart';
import '../utils/ars_notification_printer.dart';
import '../utils/async_action.dart';

/// Widget notifikasi ARS yang menampilkan badge notifikasi di sudut kanan atas
/// Menampilkan jumlah buku yang direkomendasikan untuk pengadaan ulang
class ArsNotificationWidget extends StatelessWidget {
  const ArsNotificationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final arsService = ArsService();

    return StreamBuilder<List<ArsNotificationModel>>(
      stream: arsService.getUnreadNotificationsStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(
                Icons.notifications_outlined,
                color: Colors.white,
              ),
              tooltip: 'Notifikasi Stok Buku',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ArsNotificationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: IgnorePointer(
                  ignoring: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Widget untuk menampilkan daftar notifikasi ARS di dashboard
/// Menampilkan informasi stok rendah dan jumlah pengadaan yang diperlukan
class ArsNotificationListWidget extends StatelessWidget {
  final int maxItems;
  final bool showAll;

  const ArsNotificationListWidget({
    super.key,
    this.maxItems = 5,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    final arsService = ArsService();

    return StreamBuilder<List<ArsNotificationModel>>(
      stream: arsService.getUnreadNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                getFriendlyErrorMessage(snapshot.error ?? 'Error'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final allNotifications = snapshot.data ?? [];
        final notifications =
            showAll
                ? allNotifications
                : allNotifications.take(maxItems).toList();

        if (notifications.isEmpty) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Semua Stok Aman',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tidak ada buku yang direkomendasikan restok saat ini',
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;

                    final headerContent = Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Rekomendasi Pengadaan Ulang',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${allNotifications.length} buku direkomendasikan restok',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    final actionButton =
                        (!showAll && allNotifications.length > maxItems)
                            ? Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const ArsNotificationsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Lihat Semua'),
                              ),
                            )
                            : const SizedBox.shrink();

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [headerContent, actionButton],
                      );
                    }

                    return Row(
                      children: [Expanded(child: headerContent), actionButton],
                    );
                  },
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _buildNotificationItem(context, notification);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    ArsNotificationModel notification,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return InkWell(
      onTap: () {
        _showDetailDialog(context, notification);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.library_books,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.judulBuku,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(
                        'Stok Akhir: ${notification.stokAkhir} buku',
                        Colors.orange,
                      ),
                      _buildInfoChip(
                        'Safety Stock: ${notification.safetyStock} buku',
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Text(
                      'Rekomendasi Pengadaan: ${notification.jumlahPengadaan} buku',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dateFormat.format(notification.tanggalNotifikasi),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: _getDarkerColor(color),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getDarkerColor(Color color) {
    // Menghasilkan warna lebih gelap untuk teks
    if (color == Colors.orange) return Colors.orange.shade800;
    if (color == Colors.blue) return Colors.blue.shade800;
    if (color == Colors.red) return Colors.red.shade800;
    if (color == Colors.green) return Colors.green.shade800;

    // Default: buat warna lebih gelap secara manual
    return Color.fromARGB(
      255,
      (color.red * 0.6).toInt(),
      (color.green * 0.6).toInt(),
      (color.blue * 0.6).toInt(),
    );
  }

  void _showDetailDialog(
    BuildContext context,
    ArsNotificationModel notification,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final arsService = ArsService();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.red),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Detail Notifikasi',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Judul Buku', notification.judulBuku),
                  const Divider(),
                  _buildDetailRow('Stok Awal', '${notification.stokAwal} buku'),
                  _buildDetailRow(
                    'Total Peminjaman',
                    '${notification.totalPeminjaman} buku',
                  ),
                  _buildDetailRow(
                    'Stok Akhir',
                    '${notification.stokAkhir} buku',
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Safety Stock',
                    '${notification.safetyStock} buku',
                  ),
                  _buildDetailRow(
                    'Status Stok',
                    'Rekomendasi pengadaan ulang (evaluasi sebelum order)',
                    valueColor: Colors.red,
                    valueWeight: FontWeight.bold,
                  ),
                  _buildDetailRow(
                    'Jumlah Pengadaan',
                    '${notification.jumlahPengadaan} buku',
                    valueColor: Colors.red,
                    valueWeight: FontWeight.bold,
                  ),
                  const Divider(),
                  _buildDetailRow(
                    'Tanggal Notifikasi',
                    dateFormat.format(notification.tanggalNotifikasi),
                  ),
                  if (notification.detailPeminjaman.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Detail Peminjaman Hari Ini:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...notification.detailPeminjaman.map((detail) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${detail['jam'] ?? detail['tanggal'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.book, size: 16),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${detail['jumlah']} buku',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  try {
                    await ArsNotificationPrinter.printNotification(
                      notification,
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Gagal mencetak: ${getFriendlyErrorMessage(e)}',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed:
                    notification.id == null
                        ? null
                        : () async {
                          Navigator.of(context).pop();
                          try {
                            await arsService.markNotificationAsRead(
                              notification.id!,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notifikasi dikonfirmasi'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(getFriendlyErrorMessage(e)),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: valueWeight ?? FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
