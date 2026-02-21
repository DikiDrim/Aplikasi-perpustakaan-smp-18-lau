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
  /// Memungkinkan input jumlah untuk setiap kondisi (Baik, Rusak, Hilang)
  Future<Map<String, dynamic>?> _showKondisiBukuDialog(
    BuildContext context, {
    required String judulBuku,
    required String namaPeminjam,
    String? kelas,
    required int sisa,
    required bool isOverdue,
    required int totalHariTerlambat,
  }) async {
    int jumlahBaik = sisa;
    int jumlahRusak = 0;
    int jumlahHilang = 0;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Validasi total harus sama dengan sisa
            final total = jumlahBaik + jumlahRusak + jumlahHilang;
            final isValid = total == sisa;

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

            Widget buildQuantityRow(
              String label,
              int value,
              int maxValue,
              Function(int) onChanged,
            ) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      value > 0
                          ? kondisiColor(label).withOpacity(0.1)
                          : Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        value > 0
                            ? kondisiColor(label).withOpacity(0.3)
                            : Colors.grey.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      kondisiIcon(label),
                      color: kondisiColor(label),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: kondisiColor(label),
                          fontSize: 15,
                        ),
                      ),
                    ),
                    // Stepper controls
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap:
                                value > 0 ? () => onChanged(value - 1) : null,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.remove,
                                size: 18,
                                color:
                                    value > 0
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                              ),
                            ),
                          ),
                          Container(
                            width: 36,
                            alignment: Alignment.center,
                            child: Text(
                              '$value',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: kondisiColor(label),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap:
                                total < sisa
                                    ? () => onChanged(value + 1)
                                    : null,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color:
                                    total < sisa
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
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
                          Text(
                            'Jumlah dikembalikan: $sisa buku',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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

                    // Condition selector with quantities
                    const Text(
                      'Kondisi Buku',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tentukan jumlah buku berdasarkan kondisinya:',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),

                    buildQuantityRow('Baik', jumlahBaik, sisa, (val) {
                      setDialogState(() {
                        jumlahBaik = val;
                      });
                    }),
                    const SizedBox(height: 8),
                    buildQuantityRow('Rusak', jumlahRusak, sisa, (val) {
                      setDialogState(() {
                        jumlahRusak = val;
                      });
                    }),
                    const SizedBox(height: 8),
                    buildQuantityRow('Hilang', jumlahHilang, sisa, (val) {
                      setDialogState(() {
                        jumlahHilang = val;
                      });
                    }),

                    const SizedBox(height: 12),

                    // Total indicator
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            isValid
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isValid
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.red.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isValid ? Icons.check_circle : Icons.info_outline,
                            color: isValid ? Colors.green : Colors.red,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isValid
                                  ? 'Total: $total dari $sisa buku'
                                  : 'Total: $total (harus $sisa buku)',
                              style: TextStyle(
                                color: isValid ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Warning info for damaged/lost
                    if (jumlahRusak > 0 || jumlahHilang > 0) ...[
                      const SizedBox(height: 10),
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
                                jumlahRusak > 0 && jumlahHilang > 0
                                    ? 'Siswa akan mendapat peringatan karena ${jumlahRusak} buku rusak dan ${jumlahHilang} buku hilang.'
                                    : jumlahRusak > 0
                                    ? 'Siswa akan mendapat peringatan karena ${jumlahRusak} buku dikembalikan rusak.'
                                    : 'Siswa akan mendapat peringatan serius karena ${jumlahHilang} buku hilang.',
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
                  onPressed:
                      isValid
                          ? () {
                            Navigator.pop(ctx, {
                              'jumlahBaik': jumlahBaik,
                              'jumlahRusak': jumlahRusak,
                              'jumlahHilang': jumlahHilang,
                            });
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        jumlahRusak > 0 || jumlahHilang > 0
                            ? Colors.orange
                            : Colors.green,
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
                          Text('Jumlah dipinjam: $jumlah buku'),
                          if (sudahKembali > 0)
                            Text('Sudah kembali: $sudahKembali buku'),
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

                                    final jumlahBaik =
                                        (result['jumlahBaik'] as int?) ?? sisa;
                                    final jumlahRusak =
                                        (result['jumlahRusak'] as int?) ?? 0;
                                    final jumlahHilang =
                                        (result['jumlahHilang'] as int?) ?? 0;
                                    final judulBuku = d['judul_buku'] ?? '-';

                                    try {
                                      await runWithLoading(context, () async {
                                        await service
                                            .kembalikanBukuDenganKondisiGabungan(
                                              id,
                                              d['buku_id'] as String,
                                              jumlahBaik: jumlahBaik,
                                              jumlahRusak: jumlahRusak,
                                              jumlahHilang: jumlahHilang,
                                              isTerlambat: isOverdue,
                                            );
                                      });

                                      if (!mounted) return;

                                      String subtitle;
                                      final parts = <String>[];
                                      if (jumlahBaik > 0) {
                                        parts.add(
                                          '$jumlahBaik buku kondisi baik',
                                        );
                                      }
                                      if (jumlahRusak > 0) {
                                        parts.add('$jumlahRusak buku rusak');
                                      }
                                      if (jumlahHilang > 0) {
                                        parts.add('$jumlahHilang buku hilang');
                                      }

                                      if (jumlahRusak > 0 || jumlahHilang > 0) {
                                        subtitle =
                                            'Buku "$judulBuku" dikembalikan:\n${parts.join(', ')}.\nSiswa telah diberi peringatan.';
                                      } else if (isOverdue) {
                                        subtitle =
                                            'Buku "$judulBuku" telah dikembalikan.\nSiswa telah diberi peringatan keterlambatan.';
                                      } else {
                                        subtitle =
                                            'Buku "$judulBuku" telah dikembalikan dalam kondisi baik.';
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
