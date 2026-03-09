import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/peminjaman_model.dart';
import '../services/app_notification_service.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../widgets/success_popup.dart';

class StudentActiveLoansScreen extends StatefulWidget {
  const StudentActiveLoansScreen({super.key});

  @override
  State<StudentActiveLoansScreen> createState() =>
      _StudentActiveLoansScreenState();
}

class _StudentActiveLoansScreenState extends State<StudentActiveLoansScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final uid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pinjaman Saya')),
        body: const Center(child: Text('Anda belum login')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pinjaman Saya',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Aktif'),
            Tab(icon: Icon(Icons.pending_actions, size: 18), text: 'Menunggu'),
            Tab(icon: Icon(Icons.cancel_outlined, size: 18), text: 'Ditolak'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoansList('dipinjam'),
          _buildLoansList('pending'),
          _buildLoansList('ditolak'),
        ],
      ),
    );
  }

  Widget _buildLoansList(String statusFilter) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('peminjaman')
              .where('uid_siswa', isEqualTo: uid)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        final loans =
            docs
                .map(
                  (d) => PeminjamanModel.fromMap(
                    d.data() as Map<String, dynamic>,
                    d.id,
                  ),
                )
                .where((p) => p.status.toLowerCase() == statusFilter)
                .toList();

        // Sort by due date ascending for active, by creation for pending
        if (statusFilter == 'dipinjam') {
          loans.sort((a, b) {
            final ad = a.tanggalJatuhTempo ?? DateTime(2100);
            final bd = b.tanggalJatuhTempo ?? DateTime(2100);
            return ad.compareTo(bd);
          });
        } else {
          loans.sort((a, b) => b.tanggalPinjam.compareTo(a.tanggalPinjam));
        }

        if (loans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusFilter == 'dipinjam'
                      ? Icons.library_books_outlined
                      : statusFilter == 'pending'
                      ? Icons.pending_outlined
                      : Icons.block,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  statusFilter == 'dipinjam'
                      ? 'Tidak ada pinjaman aktif'
                      : statusFilter == 'pending'
                      ? 'Tidak ada booking menunggu konfirmasi'
                      : 'Tidak ada booking ditolak',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return _LoanCard(
              loan: loan,
              statusFilter: statusFilter,
              onExtend:
                  statusFilter == 'dipinjam'
                      ? () => _showExtendDialog(loan)
                      : null,
              onCancel:
                  statusFilter == 'pending' ? () => _cancelBooking(loan) : null,
            );
          },
        );
      },
    );
  }

  void _showExtendDialog(PeminjamanModel loan) async {
    // Only allow extension for daily loans (not hourly)
    final dueDate = loan.tanggalJatuhTempo;
    if (dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat memperpanjang: tanggal jatuh tempo tidak tersedia',
          ),
        ),
      );
      return;
    }

    // Check perpanjangan_count from Firestore
    if (loan.id == null) return;
    final doc =
        await FirebaseFirestore.instance
            .collection('peminjaman')
            .doc(loan.id)
            .get();
    final data = doc.data();
    final currentCount = (data?['perpanjangan_count'] ?? 0) as int;
    if (currentCount >= 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Batas perpanjangan sudah tercapai (maksimal 2 kali).',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    int extendDays = 3;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final newDueDate = dueDate.add(Duration(days: extendDays));
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Perpanjang Peminjaman',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sisa kesempatan perpanjangan: ${2 - currentCount}',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            (2 - currentCount) == 1
                                ? Colors.orange[700]
                                : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Book info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.judulBuku,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.date_range,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Jatuh tempo: ${DateFormat('dd MMM yyyy', 'id_ID').format(dueDate)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Extend duration
                    const Text(
                      'Tambah Durasi (Hari)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (extendDays > 1) {
                                setModalState(() => extendDays--);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFF0D47A1),
                          ),
                          Expanded(
                            child: Text(
                              '$extendDays hari',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (extendDays < 14) {
                                setModalState(() => extendDays++);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF0D47A1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // New due date preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Jatuh tempo baru: ${DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(newDueDate)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!Throttle.allow('extend_loan')) return;
                          Navigator.pop(context);
                          _extendLoan(loan, extendDays);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.update, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Perpanjang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _extendLoan(PeminjamanModel loan, int extendDays) async {
    try {
      await runWithLoading(context, () async {
        if (loan.id == null) throw Exception('ID peminjaman tidak valid');

        final dueDate = loan.tanggalJatuhTempo;
        if (dueDate == null)
          throw Exception('Tanggal jatuh tempo tidak tersedia');

        final newDueDate = dueDate.add(Duration(days: extendDays));

        await FirebaseFirestore.instance
            .collection('peminjaman')
            .doc(loan.id)
            .update({
              'tanggal_jatuh_tempo': Timestamp.fromDate(newDueDate),
              'diperpanjang': true,
              'perpanjangan_hari': extendDays,
              'perpanjangan_tanggal': FieldValue.serverTimestamp(),
              'perpanjangan_count': FieldValue.increment(1),
            });

        // Notify admins
        try {
          final appNotif = AppNotificationService();
          final adminsSnap =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'admin')
                  .get();
          for (final adminDoc in adminsSnap.docs) {
            await appNotif.createNotification(
              userId: adminDoc.id,
              title: 'Perpanjangan Peminjaman',
              body:
                  '${loan.namaPeminjam} memperpanjang peminjaman "${loan.judulBuku}" selama $extendDays hari.',
              type: 'perpanjangan',
              data: {'peminjaman_id': loan.id},
            );
          }
        } catch (_) {}
      }, message: 'Memproses perpanjangan...');

      if (mounted) {
        SuccessPopup.show(
          context,
          title: 'Perpanjangan Berhasil!',
          subtitle: 'Peminjaman diperpanjang $extendDays hari.',
        );
      }
    } catch (_) {
      // Error handled by runWithLoading
    }
  }

  Future<void> _cancelBooking(PeminjamanModel loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Batalkan Peminjaman?'),
            content: Text(
              'Apakah Anda yakin ingin membatalkan peminjaman buku "${loan.judulBuku}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Tidak'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Ya, Batalkan'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await runWithLoading(context, () async {
        if (loan.id == null) throw Exception('ID peminjaman tidak valid');
        await FirebaseFirestore.instance
            .collection('peminjaman')
            .doc(loan.id)
            .delete();
      }, message: 'Membatalkan booking...');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil dibatalkan'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {}
  }
}

// ============================================================================
// LOAN CARD WIDGET
// ============================================================================

class _LoanCard extends StatelessWidget {
  final PeminjamanModel loan;
  final String statusFilter;
  final VoidCallback? onExtend;
  final VoidCallback? onCancel;

  const _LoanCard({
    required this.loan,
    required this.statusFilter,
    this.onExtend,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueDate = loan.tanggalJatuhTempo;
    final isOverdue =
        statusFilter == 'dipinjam' && dueDate != null && dueDate.isBefore(now);
    final daysLeft =
        statusFilter == 'dipinjam' && dueDate != null
            ? dueDate.difference(now).inDays
            : null;

    // Determine card accent color
    Color accentColor;
    if (statusFilter == 'pending') {
      accentColor = const Color(0xFFFF9800);
    } else if (statusFilter == 'ditolak') {
      accentColor = Colors.red;
    } else if (isOverdue) {
      accentColor = Colors.red;
    } else if (daysLeft != null && daysLeft <= 2) {
      accentColor = Colors.orange;
    } else {
      accentColor = const Color(0xFF4CAF50);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Status
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    statusFilter == 'pending'
                        ? Icons.pending_actions
                        : statusFilter == 'ditolak'
                        ? Icons.cancel
                        : Icons.menu_book_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.judulBuku,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Jumlah: ${loan.jumlah} buku',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusFilter == 'pending'
                        ? 'Menunggu'
                        : statusFilter == 'ditolak'
                        ? 'Ditolak'
                        : isOverdue
                        ? 'Terlambat'
                        : 'Dipinjam',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _DateRow(
                    icon: Icons.calendar_today,
                    label: 'Tanggal Pinjam',
                    value: DateFormat(
                      'dd MMM yyyy',
                      'id_ID',
                    ).format(loan.tanggalPinjam),
                  ),
                  if (dueDate != null) ...[
                    const SizedBox(height: 6),
                    _DateRow(
                      icon: Icons.event,
                      label: 'Jatuh Tempo',
                      value: DateFormat('dd MMM yyyy', 'id_ID').format(dueDate),
                      valueColor: isOverdue ? Colors.red : null,
                    ),
                  ],
                  if (statusFilter == 'dipinjam' && daysLeft != null) ...[
                    const SizedBox(height: 6),
                    _DateRow(
                      icon: Icons.timer,
                      label: 'Sisa Waktu',
                      value:
                          isOverdue
                              ? 'Terlambat ${(-daysLeft)} hari'
                              : '$daysLeft hari lagi',
                      valueColor:
                          isOverdue
                              ? Colors.red
                              : daysLeft <= 2
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons
            if (onExtend != null || onCancel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onExtend != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onExtend,
                        icon: const Icon(Icons.update, size: 16),
                        label: const Text('Perpanjang'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4CAF50),
                          side: const BorderSide(color: Color(0xFF4CAF50)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  if (onCancel != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCancel,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Batalkan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.grey[800],
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
