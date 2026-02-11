import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../widgets/success_popup.dart';

class PengembalianBukuScreen extends StatefulWidget {
  const PengembalianBukuScreen({super.key});

  @override
  State<PengembalianBukuScreen> createState() => _PengembalianBukuScreenState();
}

class _PengembalianBukuScreenState extends State<PengembalianBukuScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _ticker;
  final Set<String> _notifiedOverdue =
      {}; // Track siswa yang sudah dikirimi notifikasi
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  void initState() {
    super.initState();
    // Update tampilan countdown tiap 30 detik
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatCountdown(DateTime? due, DateTime now) {
    if (due == null) return 'Tanpa batas waktu';
    final diff = due.difference(now);
    if (diff.isNegative) {
      final late = diff.abs();
      final days = late.inDays;
      final hours = late.inHours % 24;
      final mins = late.inMinutes % 60;
      if (days > 0) return 'Terlambat ${days}h ${hours}j';
      if (hours > 0) return 'Terlambat ${hours}j ${mins}m';
      return 'Terlambat ${mins}m';
    }
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final mins = diff.inMinutes % 60;
    if (days > 0) return 'Sisa ${days}h ${hours}j';
    if (hours > 0) return 'Sisa ${hours}j ${mins}m';
    return 'Sisa ${mins}m';
  }

  /// Dialog untuk memilih kondisi buku saat pengembalian
  Future<Map<String, dynamic>?> _showKondisiBukuDialog(
    BuildContext context, {
    required String judulBuku,
    required String namaPeminjam,
    String? kelas,
    required int sisa,
    required bool isOverdue,
    required int totalHariTerlambat,
  }) async {
    String selectedKondisi = 'Baik';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Color kondisiColor(String k) {
              switch (k) {
                case 'Baik':
                  return Colors.green;
                case 'Rusak':
                  return Colors.orange;
                case 'Hilang':
                  return Colors.red;
                default:
                  return Colors.grey;
              }
            }

            IconData kondisiIcon(String k) {
              switch (k) {
                case 'Baik':
                  return Icons.check_circle;
                case 'Rusak':
                  return Icons.warning_amber;
                case 'Hilang':
                  return Icons.error;
                default:
                  return Icons.help;
              }
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    isOverdue ? Icons.warning_amber : Icons.keyboard_return,
                    color: isOverdue ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOverdue
                          ? 'Pengembalian Terlambat'
                          : 'Konfirmasi Pengembalian',
                      style: TextStyle(color: isOverdue ? Colors.orange : null),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Peminjam: $namaPeminjam',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (kelas != null && kelas.isNotEmpty)
                            Text('Kelas: $kelas'),
                          const SizedBox(height: 4),
                          Text('Buku: $judulBuku'),
                          Text('Jumlah: $sisa buku'),
                          if (isOverdue) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Terlambat: $totalHariTerlambat hari',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Condition selector
                    const Text(
                      'Kondisi Buku',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...['Baik', 'Rusak', 'Hilang'].map((k) {
                      return RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: k,
                        groupValue: selectedKondisi,
                        title: Row(
                          children: [
                            Icon(
                              kondisiIcon(k),
                              color: kondisiColor(k),
                              size: 20,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              k,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: kondisiColor(k),
                              ),
                            ),
                          ],
                        ),
                        onChanged: (v) {
                          setDialogState(() => selectedKondisi = v!);
                        },
                      );
                    }),

                    // Warning info for damaged/lost
                    if (selectedKondisi == 'Rusak' ||
                        selectedKondisi == 'Hilang') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedKondisi == 'Rusak'
                                    ? 'Siswa akan mendapat peringatan karena buku dikembalikan dalam kondisi rusak.'
                                    : 'Siswa akan mendapat peringatan serius karena buku hilang.',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (isOverdue) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Siswa akan mendapat peringatan keterlambatan melalui notifikasi.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx, {'kondisi': selectedKondisi});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kondisiColor(selectedKondisi),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ya, kembalikan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    // Simpan context halaman agar tetap bisa dipakai setelah item dihapus dari list
    final pageContext = context;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengembalian Buku')),
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
            return const Center(
              child: Text('Tidak ada buku yang perlu dikembalikan.'),
            );
          }
          // Ambil semua, lalu filter yang masih ada sisa buku dipinjam (jumlah > jumlah_kembali)
          final docs =
              snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final total = (data['jumlah'] ?? 1) as int;
                final kembali = (data['jumlah_kembali'] ?? 0) as int;
                return (total - kembali) > 0;
              }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text('Tidak ada buku yang perlu dikembalikan.'),
            );
          }
          return ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();
              final id = docs[index].id;
              final dueTs = d['tanggal_jatuh_tempo'] as Timestamp?;
              final pinjamTs = d['tanggal_pinjam'] as Timestamp?;
              final due = dueTs?.toDate();
              final mulai = pinjamTs?.toDate();
              final now = DateTime.now();
              final isOverdue = due != null && now.isAfter(due);
              final durasiJalan =
                  (mulai != null) ? now.difference(mulai) : const Duration();
              final totalJam = durasiJalan.inMinutes / 60;
              final totalHari = durasiJalan.inDays;

              final jumlah = (d['jumlah'] ?? 1) as int;
              final sudahKembali = (d['jumlah_kembali'] ?? 0) as int;
              final sisa = (jumlah - sudahKembali).clamp(0, jumlah);
              final uidSiswa = d['uid_siswa'] as String?;
              final terlambatNotified = d['terlambat_notified'] == true;

              // Kirim notifikasi keterlambatan ke siswa jika belum pernah
              if (isOverdue &&
                  sisa > 0 &&
                  uidSiswa != null &&
                  uidSiswa.isNotEmpty &&
                  !terlambatNotified &&
                  !_notifiedOverdue.contains(id)) {
                _notifiedOverdue.add(id);
                final dueDate = due;
                Future.microtask(() async {
                  await service.kirimNotifikasiKeterlambatan(
                    peminjamanId: id,
                    uidSiswa: uidSiswa,
                    judulBuku: d['judul_buku'] ?? '-',
                    namaPeminjam: d['nama_peminjam'] ?? '-',
                    tanggalJatuhTempo: dueDate,
                  );
                });
              }

              final countdownText = _formatCountdown(due, now);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.book, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d['judul_buku'] ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isOverdue
                                      ? Colors.red.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isOverdue ? 'Terlambat' : 'Dipinjam',
                              style: TextStyle(
                                color:
                                    isOverdue ? Colors.red : Colors.orange[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          Text('Peminjam: ${d['nama_peminjam'] ?? '-'}'),
                          if (d['kelas'] != null) Text('Kelas: ${d['kelas']}'),
                          Text('Jumlah dipinjam: $jumlah'),
                          if (sudahKembali > 0)
                            Text('Sudah kembali: $sudahKembali'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (mulai != null) Text('Mulai pinjam: ${_fmt(mulai)}'),
                      if (due != null) Text('Jatuh tempo: ${_fmt(due)}'),
                      Text(
                        'Durasi berjalan: ${totalHari} hari (${totalJam.toStringAsFixed(1)} jam)',
                      ),
                      Text(
                        countdownText,
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.blueGrey,
                          fontWeight:
                              isOverdue ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      // Tampilkan peringatan jika terlambat
                      if (isOverdue && sisa > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Peringatan: Buku ini sudah melewati batas waktu pengembalian. Harap segera dikembalikan.',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.keyboard_return),
                          label: Text(
                            isOverdue
                                ? 'Proses Pengembalian Terlambat (sisa: $sisa)'
                                : 'Konfirmasi pengembalian (sisa: $sisa)',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isOverdue ? Colors.red : null,
                            foregroundColor: isOverdue ? Colors.white : null,
                          ),
                          onPressed:
                              sisa <= 0
                                  ? null
                                  : () async {
                                    if (!Throttle.allow('konfirmasi_${id}')) {
                                      return;
                                    }

                                    // Show book condition dialog
                                    final result = await _showKondisiBukuDialog(
                                      context,
                                      judulBuku: d['judul_buku'] ?? '-',
                                      namaPeminjam: d['nama_peminjam'] ?? '-',
                                      kelas: d['kelas']?.toString(),
                                      sisa: sisa,
                                      isOverdue: isOverdue,
                                      totalHariTerlambat: totalHari,
                                    );

                                    if (result == null) return;

                                    final kondisi = result['kondisi'] as String;
                                    final judulBuku = d['judul_buku'] ?? '-';

                                    try {
                                      await runWithLoading(context, () async {
                                        await service
                                            .kembalikanBukuDenganKondisi(
                                              id,
                                              d['buku_id'] as String,
                                              sisa,
                                              kondisiBuku: kondisi,
                                              isTerlambat: isOverdue,
                                            );
                                      });

                                      if (!mounted) return;

                                      String subtitle;
                                      if (kondisi == 'Rusak') {
                                        subtitle =
                                            'Buku "$judulBuku" dikembalikan dalam kondisi RUSAK.\nSiswa telah diberi peringatan.';
                                      } else if (kondisi == 'Hilang') {
                                        subtitle =
                                            'Buku "$judulBuku" dilaporkan HILANG.\nSiswa telah diberi peringatan serius.';
                                      } else if (isOverdue) {
                                        subtitle =
                                            'Buku "$judulBuku" telah dikembalikan.\nSiswa telah diberi peringatan keterlambatan.';
                                      } else {
                                        subtitle =
                                            'Buku "$judulBuku" telah dikembalikan';
                                      }

                                      await SuccessPopup.show(
                                        pageContext,
                                        title: 'Pengembalian Berhasil!',
                                        subtitle: subtitle,
                                      );
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        pageContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Gagal mengembalikan buku: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  },
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
