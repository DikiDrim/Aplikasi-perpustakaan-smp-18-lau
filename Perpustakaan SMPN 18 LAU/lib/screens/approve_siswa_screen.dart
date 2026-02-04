import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firestore_service.dart';

class ApproveSiswaScreen extends StatefulWidget {
  const ApproveSiswaScreen({super.key});

  @override
  State<ApproveSiswaScreen> createState() => _ApproveSiswaScreenState();
}

class _ApproveSiswaScreenState extends State<ApproveSiswaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _pendingRegistrations = [];
  bool _loading = true;
  String? _processingId;

  @override
  void initState() {
    super.initState();
    _loadPendingRegistrations();
  }

  Future<void> _loadPendingRegistrations() async {
    setState(() => _loading = true);
    try {
      final registrations = await _firestoreService.getPendingRegistrations();
      setState(() {
        _pendingRegistrations = registrations;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _approveRegistration(String registrationId) async {
    setState(() => _processingId = registrationId);
    try {
      final accountInfo = await _firestoreService.approveSiswaRegistration(
        registrationId,
      );

      if (mounted) {
        // Tampilkan dialog dengan username dan password
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Pendaftaran Disetujui'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akun siswa berhasil dibuat. Berikut kredensialnya:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        label: 'Username',
                        value: accountInfo['username']!,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 8),
                      _InfoRow(
                        label: 'Password',
                        value: accountInfo['password']!,
                        icon: Icons.lock,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Catat kredensial ini dan berikan kepada siswa',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _loadPendingRegistrations();
                    },
                    child: const Text('OK'),
                  ),
                  TextButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(
                          text:
                              'Username: ${accountInfo['username']}\nPassword: ${accountInfo['password']}',
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Kredensial disalin ke clipboard'),
                        ),
                      );
                    },
                    child: const Text('Salin'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menyetujui: $e')));
      }
    } finally {
      setState(() => _processingId = null);
    }
  }

  Future<void> _rejectRegistration(String registrationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Tolak Pendaftaran'),
            content: const Text(
              'Apakah Anda yakin ingin menolak pendaftaran ini?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tolak', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() => _processingId = registrationId);
    try {
      await _firestoreService.rejectSiswaRegistration(registrationId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Pendaftaran ditolak')));
        _loadPendingRegistrations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menolak: $e')));
      }
    } finally {
      setState(() => _processingId = null);
    }
  }

  /// Format tanggal dengan benar dari Timestamp Firestore
  String _formatTanggal(dynamic createdAt) {
    if (createdAt == null) return '-';

    try {
      DateTime? dt;

      // Handle Timestamp object dari Firestore
      if (createdAt is Timestamp) {
        dt = createdAt.toDate();
      } else if (createdAt is DateTime) {
        dt = createdAt;
      } else if (createdAt is String) {
        // Jika tersimpan sebagai string, coba parse
        // Pattern: "Timestamp(seconds=1769838132, nanoseconds=...)"
        final regex = RegExp(r'seconds=(\d+)');
        final match = regex.firstMatch(createdAt);
        if (match != null) {
          final seconds = int.tryParse(match.group(1) ?? '');
          if (seconds != null) {
            dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
          }
        } else {
          // Coba parse sebagai ISO string
          dt = DateTime.tryParse(createdAt);
        }
      } else if (createdAt is Map) {
        // Jika berupa map dengan seconds
        final seconds = createdAt['seconds'] ?? createdAt['_seconds'];
        if (seconds != null) {
          dt = DateTime.fromMillisecondsSinceEpoch(
            (seconds as num).toInt() * 1000,
          );
        }
      }

      if (dt != null) {
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year;
        final hour = dt.hour.toString().padLeft(2, '0');
        final minute = dt.minute.toString().padLeft(2, '0');
        return '$day/$month/$year $hour:$minute';
      }
    } catch (e) {
      debugPrint('Error format tanggal: $e');
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Persetujuan Pendaftaran Siswa'),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingRegistrations,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _pendingRegistrations.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada pendaftaran yang menunggu',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadPendingRegistrations,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingRegistrations.length,
                  // Optimize: cacheExtent untuk lazy loading
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    final registration = _pendingRegistrations[index];
                    final isProcessing = _processingId == registration['id'];
                    final tanggalDaftar = _formatTanggal(
                      registration['created_at'],
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header with avatar and name
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.orange.withOpacity(
                                    0.2,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.orange,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        registration['nama'] ?? '-',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'NIS: ${registration['nis'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Tanggal pendaftaran
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Didaftar: $tanggalDaftar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        isProcessing
                                            ? null
                                            : () => _rejectRegistration(
                                              registration['id'],
                                            ),
                                    icon: const Icon(Icons.close, size: 18),
                                    label: const Text('Tolak'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(
                                        color: Colors.red,
                                        width: 1.5,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        isProcessing
                                            ? null
                                            : () => _approveRegistration(
                                              registration['id'],
                                            ),
                                    icon: const Icon(Icons.check, size: 18),
                                    label: const Text('Setujui'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (isProcessing) ...[
                              const SizedBox(height: 12),
                              const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }
}
