import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import '../models/peminjaman_model.dart';
import '../services/app_notification_service.dart';
import '../services/firestore_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final AppNotificationService _notificationService = AppNotificationService();
  final FirestoreService _firestoreService = FirestoreService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tandai Semua Sudah Dibaca?'),
            content: const Text(
              'Apakah Anda yakin ingin menandai semua notifikasi sebagai sudah dibaca?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('Ya'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _notificationService.markAllAsRead();
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
    }
  }

  Future<void> _deleteAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Semua Notifikasi?'),
            content: const Text(
              'Apakah Anda yakin ingin menghapus semua notifikasi? Tindakan ini tidak dapat dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await _notificationService.deleteAllNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi berhasil dihapus'),
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
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        title: const Text('Notifikasi'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Pengingat'), Tab(text: 'Semua')],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'mark_all_read') {
                _markAllAsRead();
              } else if (value == 'delete_all') {
                _deleteAllNotifications();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 20),
                        SizedBox(width: 8),
                        Text('Tandai Semua Sudah Dibaca'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Hapus Semua',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReminderList(),
          _buildNotificationList(unreadOnly: false),
        ],
      ),
    );
  }

  Widget _buildNotificationList({required bool unreadOnly}) {
    return StreamBuilder<List<NotificationModel>>(
      stream:
          unreadOnly
              ? _notificationService.getUnreadNotificationsStream()
              : _notificationService.getNotificationsStream(),
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
                  unreadOnly
                      ? 'Tidak ada notifikasi baru'
                      : 'Tidak ada notifikasi',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return _buildNotificationCard(notification);
          },
        );
      },
    );
  }

  Widget _buildReminderList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Anda belum login'));
    }
    return StreamBuilder<List<PeminjamanModel>>(
      stream: _firestoreService.getActiveLoansStreamForUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final loans = snapshot.data ?? [];
        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.event_available, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada pengingat jatuh tempo',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: loans.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final p = loans[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book, color: Color(0xFF1976D2)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.judulBuku,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (p.tanggalJatuhTempo != null)
                      _CountdownTimer(dueDate: p.tanggalJatuhTempo!),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dipinjam: ${DateFormat('dd/MM/yyyy').format(p.tanggalPinjam)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (p.tanggalJatuhTempo != null)
                          Text(
                            'Jatuh tempo: ${DateFormat('dd/MM/yyyy').format(p.tanggalJatuhTempo!)}',
                            style: const TextStyle(fontSize: 12),
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

  Widget _buildNotificationCard(NotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final isUnread = notification.status == 'unread';

    Color getColor() {
      switch (notification.type) {
        case 'peminjaman':
          return const Color(0xFF1976D2);
        case 'pengembalian':
          return const Color(0xFF388E3C);
        case 'ars':
          return const Color(0xFFF57C00);
        case 'keterlambatan':
          return const Color(0xFFD32F2F);
        case 'approval':
          return const Color(0xFF7B1FA2);
        default:
          return const Color(0xFF455A64);
      }
    }

    IconData getIcon() {
      switch (notification.type) {
        case 'peminjaman':
          return Icons.book;
        case 'pengembalian':
          return Icons.check_circle;
        case 'ars':
          return Icons.warning_amber;
        case 'keterlambatan':
          return Icons.access_time;
        case 'approval':
          return Icons.person_add;
        default:
          return Icons.info;
      }
    }

    return Dismissible(
      key: Key(notification.id ?? DateTime.now().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        if (notification.id != null) {
          await _notificationService.deleteNotification(notification.id!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifikasi dihapus'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Card(
        elevation: isUnread ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isUnread ? getColor() : Colors.grey[300]!,
            width: isUnread ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () async {
            if (isUnread && notification.id != null) {
              await _notificationService.markAsRead(notification.id!);
            }
            // Tampilkan detail notifikasi
            _showDetailDialog(notification);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: getColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(getIcon(), color: getColor(), size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    isUnread
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: getColor(),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.body,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateFormat.format(notification.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(NotificationModel notification) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    Color getColor() {
      switch (notification.type) {
        case 'peminjaman':
          return const Color(0xFF1976D2);
        case 'pengembalian':
          return const Color(0xFF388E3C);
        case 'ars':
          return const Color(0xFFF57C00);
        case 'keterlambatan':
          return const Color(0xFFD32F2F);
        case 'approval':
          return const Color(0xFF7B1FA2);
        default:
          return const Color(0xFF455A64);
      }
    }

    IconData getIcon() {
      switch (notification.type) {
        case 'peminjaman':
          return Icons.book;
        case 'pengembalian':
          return Icons.check_circle;
        case 'ars':
          return Icons.warning_amber;
        case 'keterlambatan':
          return Icons.access_time;
        case 'approval':
          return Icons.person_add;
        default:
          return Icons.info;
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(getIcon(), color: getColor()),
                const SizedBox(width: 8),
                const Expanded(child: Text('Detail Notifikasi')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(notification.timestamp),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Divider(height: 24),
                  Text(notification.body, style: const TextStyle(fontSize: 14)),
                  // Countdown timer untuk notifikasi peminjaman
                  if (notification.type == 'peminjaman' &&
                      notification.data != null &&
                      notification.data!.containsKey(
                        'tanggal_jatuh_tempo',
                      )) ...[
                    const SizedBox(height: 12),
                    _buildCountdownTimer(
                      notification.data!['tanggal_jatuh_tempo'],
                    ),
                  ],
                  if (notification.data != null &&
                      notification.data!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text(
                      'Informasi Tambahan:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...notification.data!.entries.map((entry) {
                      // Skip tanggal_jatuh_tempo karena sudah ditampilkan di countdown
                      if (entry.key == 'tanggal_jatuh_tempo') {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '• ${entry.key}: ${entry.value}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
              if (notification.id != null)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _notificationService.deleteNotification(
                      notification.id!,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifikasi dihapus'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Hapus'),
                ),
            ],
          ),
    );
  }

  Widget _buildCountdownTimer(dynamic dueDate) {
    // Parse ISO string jika perlu
    DateTime parsedDate;
    try {
      if (dueDate is String) {
        parsedDate = DateTime.parse(dueDate);
      } else {
        parsedDate = dueDate as DateTime;
      }
    } catch (e) {
      return const Text('Invalid due date');
    }

    return _CountdownTimer(dueDate: parsedDate);
  }
}

class _CountdownTimer extends StatefulWidget {
  final DateTime dueDate;

  const _CountdownTimer({required this.dueDate});

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late String _countdownText;
  late Color _countdownColor;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    // Update setiap 60 detik
    Future.delayed(const Duration(seconds: 1), _scheduleUpdate);
  }

  void _scheduleUpdate() {
    if (mounted) {
      setState(() => _updateCountdown());
      Future.delayed(const Duration(seconds: 60), _scheduleUpdate);
    }
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final diff = widget.dueDate.difference(now);

    if (diff.isNegative) {
      final late = diff.abs();
      final days = late.inDays;
      final hours = late.inHours % 24;
      final mins = late.inMinutes % 60;

      if (days > 0) {
        _countdownText = 'TERLAMBAT ${days}h ${hours}j';
      } else if (hours > 0) {
        _countdownText = 'TERLAMBAT ${hours}j ${mins}m';
      } else {
        _countdownText = 'TERLAMBAT ${mins}m';
      }
      _countdownColor = const Color(0xFFD32F2F); // Red
    } else {
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      final mins = diff.inMinutes % 60;

      if (days > 7) {
        _countdownText = 'Sisa ${days} hari';
        _countdownColor = const Color(0xFF388E3C); // Green
      } else if (days >= 1) {
        _countdownText = 'Sisa ${days} hari ${hours}j';
        _countdownColor = const Color(0xFFF57C00); // Orange warning
      } else if (hours >= 1) {
        _countdownText = 'Sisa ${hours}j ${mins}m';
        _countdownColor = const Color(0xFFD32F2F); // Red
      } else {
        _countdownText = 'Sisa ${mins}m';
        _countdownColor = const Color(0xFFD32F2F); // Red
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _countdownColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _countdownColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, color: _countdownColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _countdownText,
              style: TextStyle(
                color: _countdownColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
