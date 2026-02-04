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
              final dendaExisting = d['denda'] as String?;
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
                      // Tampilkan denda jika sudah ada
                      if (dendaExisting != null &&
                          dendaExisting.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hukuman: $dendaExisting',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500,
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

                                    // Jika buku terlambat, tampilkan dialog dengan opsi hukuman
                                    if (isOverdue) {
                                      final result =
                                          await _showOverdueReturnDialog(
                                            context: context,
                                            namaPeminjam:
                                                d['nama_peminjam'] ?? '-',
                                            judulBuku: d['judul_buku'] ?? '-',
                                            sisa: sisa,
                                            hariTerlambat: totalHari,
                                            existingDenda: dendaExisting,
                                          );

                                      if (result != null) {
                                        final judulBuku =
                                            d['judul_buku'] ?? '-';
                                        try {
                                          await runWithLoading(
                                            context,
                                            () async {
                                              await service.kembalikanBuku(
                                                id,
                                                d['buku_id'] as String,
                                                sisa,
                                                denda:
                                                    result['denda'] as String?,
                                                isTerlambat: true,
                                              );
                                            },
                                          );

                                          if (!mounted) return;

                                          final dendaMsg =
                                              result['denda'] != null &&
                                                      (result['denda']
                                                              as String)
                                                          .isNotEmpty
                                                  ? '\nHukuman: ${result['denda']}'
                                                  : '';

                                          await SuccessPopup.show(
                                            pageContext,
                                            title: 'Pengembalian Berhasil!',
                                            subtitle:
                                                'Buku "$judulBuku" telah dikembalikan$dendaMsg',
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
                                      }
                                    } else {
                                      // Buku tidak terlambat, dialog biasa
                                      final konfirm = await showDialog<bool>(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text(
                                                'Konfirmasi Pengembalian',
                                              ),
                                              content: Text(
                                                '${d['nama_peminjam'] ?? '-'} sudah mengembalikan $sisa buku?\nJudul: ${d['judul_buku'] ?? '-'}',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Batal'),
                                                ),
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Ya, kembalikan',
                                                  ),
                                                ),
                                              ],
                                            ),
                                      );

                                      if (konfirm == true) {
                                        final judulBuku =
                                            d['judul_buku'] ?? '-';

                                        try {
                                          await runWithLoading(
                                            context,
                                            () async {
                                              await service.kembalikanBuku(
                                                id,
                                                d['buku_id'] as String,
                                                sisa,
                                              );
                                            },
                                          );

                                          if (!mounted) return;

                                          await SuccessPopup.show(
                                            pageContext,
                                            title: 'Pengembalian Berhasil!',
                                            subtitle:
                                                'Buku "$judulBuku" telah dikembalikan',
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
                                      }
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

  /// Dialog untuk pengembalian buku terlambat dengan opsi hukuman
  Future<Map<String, dynamic>?> _showOverdueReturnDialog({
    required BuildContext context,
    required String namaPeminjam,
    required String judulBuku,
    required int sisa,
    required int hariTerlambat,
    String? existingDenda,
  }) async {
    final dendaController = TextEditingController(text: existingDenda ?? '');
    bool sudahDikembalikan = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Pengembalian Terlambat',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Peminjam: $namaPeminjam',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text('Buku: $judulBuku'),
                          Text('Jumlah: $sisa buku'),
                          const SizedBox(height: 8),
                          Text(
                            'Terlambat: $hariTerlambat hari',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Checkbox konfirmasi buku sudah dikembalikan
                    CheckboxListTile(
                      value: sudahDikembalikan,
                      onChanged: (val) {
                        setDialogState(() {
                          sudahDikembalikan = val ?? false;
                        });
                      },
                      title: const Text('Buku sudah dikembalikan oleh siswa'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Hukuman/Sanksi (opsional):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dendaController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Contoh: Tugas membersihkan perpustakaan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hukuman akan dikirimkan ke notifikasi siswa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, null),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed:
                      sudahDikembalikan
                          ? () {
                            Navigator.pop(dialogContext, {
                              'dikembalikan': true,
                              'denda': dendaController.text.trim(),
                            });
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Proses Pengembalian'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
