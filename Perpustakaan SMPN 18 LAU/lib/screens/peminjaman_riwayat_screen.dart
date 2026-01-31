import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class PeminjamanRiwayatScreen extends StatefulWidget {
  const PeminjamanRiwayatScreen({super.key});

  @override
  State<PeminjamanRiwayatScreen> createState() =>
      _PeminjamanRiwayatScreenState();
}

class _PeminjamanRiwayatScreenState extends State<PeminjamanRiwayatScreen> {
  bool _selectMode = false;
  final Set<String> _selectedIds = {};
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  final ScrollController _scrollController = ScrollController();
  bool _selectAllRequested = false;

  String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Peminjaman'),
        actions: [
          if (_selectMode)
            IconButton(
              tooltip: 'Pilih semua',
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  _selectAllRequested = true;
                  _selectMode = true;
                });
              },
            ),
          if (_selectMode)
            IconButton(
              tooltip: 'Hapus terpilih',
              icon: const Icon(Icons.delete),
              onPressed: () async {
                if (_selectedIds.isEmpty) return;
                final konfirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('Hapus Riwayat'),
                        content: Text(
                          'Yakin menghapus ${_selectedIds.length} riwayat?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                );
                if (konfirm == true) {
                  for (final id in _selectedIds) {
                    await service.deletePeminjaman(id);
                  }
                  if (mounted) {
                    setState(() {
                      _selectMode = false;
                      _selectedIds.clear();
                    });
                    if (_scrollController.hasClients) {
                      _scrollController.jumpTo(0);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Riwayat terhapus')),
                    );
                  }
                }
              },
            )
          else
            IconButton(
              tooltip: 'Mode hapus',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  _selectMode = true;
                  _selectedIds.clear();
                });
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
          final docs = snapshot.data!.docs;
          // Notifikasi sederhana bila ada yang terlambat (sekali per menit)
          final now = DateTime.now();
          if (now.difference(_lastNotify).inMinutes >= 1) {
            final overdueCount =
                docs.where((doc) {
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
          // Jika tombol pilih semua ditekan sebelumnya, pilih semua dokumen sekali
          if (_selectMode && _selectAllRequested && _selectedIds.isEmpty) {
            _selectedIds.addAll(docs.map((d) => d.id));
            _selectAllRequested = false;
          }

          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final status = (d['status'] ?? '').toString();
              final id = docs[index].id;
              final selected = _selectedIds.contains(id);
              final due =
                  d['tanggal_jatuh_tempo'] != null
                      ? (d['tanggal_jatuh_tempo'] as Timestamp).toDate()
                      : null;
              final now = DateTime.now();
              final isOverdue =
                  status != 'dikembalikan' &&
                  due != null &&
                  now.isAfter(DateTime(due.year, due.month, due.day, 23, 59));
              final daysLeft =
                  due != null
                      ? due
                          .difference(DateTime(now.year, now.month, now.day))
                          .inDays
                      : null;
              return Card(
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
                        padding: const EdgeInsets.only(right: 12, top: 2),
                        child:
                            _selectMode
                                ? Checkbox(
                                  value: selected,
                                  onChanged: (v) {
                                    setState(() {
                                      if (v == true) {
                                        _selectedIds.add(id);
                                      } else {
                                        _selectedIds.remove(id);
                                      }
                                    });
                                  },
                                )
                                : Icon(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                            // Info row: Peminjam, Kelas, Jumlah
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                Text('Peminjam: ${d['nama_peminjam'] ?? '-'}'),
                                if (d['kelas'] != null)
                                  Text('Kelas: ${d['kelas']}'),
                                if (d['jumlah'] != null)
                                  Text('Jumlah: ${d['jumlah']}'),
                              ],
                            ),
                            if (due != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                          : 'Jatuh tempo: ${_fmt(due)}${daysLeft != null ? ' • ${daysLeft} hari' : ''}',
                                      style: TextStyle(
                                        color:
                                            isOverdue
                                                ? Colors.red
                                                : Colors.black87,
                                        fontWeight:
                                            isOverdue ? FontWeight.bold : null,
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
              );
            },
          );
        },
      ),
    );
  }
}
