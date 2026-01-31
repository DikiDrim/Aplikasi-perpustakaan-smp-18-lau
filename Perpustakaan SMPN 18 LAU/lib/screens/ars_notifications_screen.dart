import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ars_notification_model.dart';
import '../services/ars_service_impl.dart';
import '../utils/ars_notification_printer.dart';

class ArsNotificationsScreen extends StatefulWidget {
  const ArsNotificationsScreen({super.key});

  @override
  State<ArsNotificationsScreen> createState() => _ArsNotificationsScreenState();
}

class _ArsNotificationsScreenState extends State<ArsNotificationsScreen> {
  final ArsService _arsService = ArsService();
  bool _isLoading = false;

  Future<void> _markAllAsRead() async {
    try {
      setState(() => _isLoading = true);
      await _arsService.markAllNotificationsAsRead();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi ditandai sebagai sudah dibaca'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _arsService.deleteNotification(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifikasi dihapus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tandai Semua Sudah Dibaca',
            onPressed: _isLoading ? null : _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<List<ArsNotificationModel>>(
        stream: _arsService.getUnreadNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak ada notifikasi',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(ArsNotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              notification.status == 'unread'
                  ? const Color(0xFF0D47A1)
                  : Colors.grey[300]!,
          width: notification.status == 'unread' ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          if (mounted) _showDetailDialog(notification);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and timestamp
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[700],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekomendasi Pengadaan Ulang',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(notification.tanggalNotifikasi),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.status == 'unread')
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D47A1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: Colors.red,
                    onPressed:
                        notification.id != null
                            ? () => _showDeleteConfirmation(notification.id!)
                            : null,
                  ),
                ],
              ),
              const Divider(height: 24),
              // Book title
              Text(
                notification.judulBuku,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              // Simple information - easy to understand
              _buildSimpleInfoRow(
                'Stok Awal',
                '${notification.stokAwal} buku',
                Icons.inventory_2_outlined,
              ),
              const SizedBox(height: 8),
              _buildSimpleInfoRow(
                'Total Peminjaman Hari Ini',
                '${notification.totalPeminjaman} buku',
                Icons.trending_down,
              ),
              const SizedBox(height: 8),
              _buildSimpleInfoRow(
                'Stok Akhir',
                '${notification.stokAkhir} buku',
                Icons.inventory_outlined,
                valueColor:
                    notification.stokAkhir <= 5 ? Colors.red : Colors.orange,
              ),
              const Divider(height: 24),
              // Recommendation - clear and direct
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[300]!, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange[700],
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Perlu Pengadaan Ulang',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${notification.jumlahPengadaan} buku',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
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
      ),
    );
  }

  Widget _buildSimpleInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  void _showDetailDialog(ArsNotificationModel notification) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Detail Notifikasi'),
            contentPadding: const EdgeInsets.all(20),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Book title
                  Text(
                    notification.judulBuku,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  // Simple stock info
                  _buildSimpleInfoRow(
                    'Jumlah buku sebelumnya',
                    '${notification.stokAwal} buku',
                    Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildSimpleInfoRow(
                    'Jumlah yang dipinjam',
                    '${notification.totalPeminjaman} buku',
                    Icons.trending_down,
                  ),
                  const SizedBox(height: 12),
                  _buildSimpleInfoRow(
                    'Stok Akhir',
                    '${notification.stokAkhir} buku',
                    Icons.inventory_outlined,
                    valueColor:
                        notification.stokAkhir <= 5
                            ? Colors.red
                            : Colors.orange,
                  ),
                  const Divider(height: 24),
                  // Recommendation
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Perlu Pengadaan Ulang',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${notification.jumlahPengadaan} buku',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Timestamp
                  Text(
                    'Waktu: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(notification.tanggalNotifikasi)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal mencetak: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text('Print'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              TextButton(
                onPressed:
                    notification.id == null
                        ? null
                        : () async {
                          Navigator.pop(context);
                          try {
                            await _arsService.markNotificationAsRead(
                              notification.id!,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifikasi dikonfirmasi'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                child: const Text('Konfirmasi'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(String notificationId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Notifikasi'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus notifikasi ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteNotification(notificationId);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );
  }
}
