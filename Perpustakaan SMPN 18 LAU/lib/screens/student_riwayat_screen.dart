import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentRiwayatScreen extends StatefulWidget {
  const StudentRiwayatScreen({super.key});

  @override
  State<StudentRiwayatScreen> createState() => _StudentRiwayatScreenState();
}

class _StudentRiwayatScreenState extends State<StudentRiwayatScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat Saya')),
        body: const Center(child: Text('Anda belum login')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Riwayat Saya',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('peminjaman')
                .where('uid_siswa', isEqualTo: _currentUser.uid)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];
          // Sort by tanggal_pinjam descending (newest first)
          final docs =
              allDocs.toList()..sort((a, b) {
                final aDate =
                    (a.data()['tanggal_pinjam'] as Timestamp?)?.toDate();
                final bDate =
                    (b.data()['tanggal_pinjam'] as Timestamp?)?.toDate();
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate); // descending
              });

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat peminjaman',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, idx) {
              final d = docs[idx].data();
              final status = (d['status'] ?? '').toString();
              final tanggalPinjam = d['tanggal_pinjam'] as Timestamp?;
              final tanggalKembali = d['tanggal_kembali'] as Timestamp?;
              final tanggalJatuhTempo = d['tanggal_jatuh_tempo'] as Timestamp?;

              final isOverdue =
                  tanggalJatuhTempo != null &&
                  status == 'dipinjam' &&
                  tanggalJatuhTempo.toDate().isBefore(DateTime.now());

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          status == 'dikembalikan'
                              ? Colors.green.withOpacity(0.1)
                              : isOverdue
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      status == 'dikembalikan'
                          ? Icons.check_circle
                          : Icons.book,
                      color:
                          status == 'dikembalikan'
                              ? Colors.green
                              : isOverdue
                              ? Colors.red
                              : Colors.orange,
                    ),
                  ),
                  title: Text(
                    d['judul_buku'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Jumlah: ${d['jumlah'] ?? 1}'),
                      Text('Pinjam: ${_formatDate(tanggalPinjam?.toDate())}'),
                      if (tanggalKembali != null)
                        Text('Kembali: ${_formatDate(tanggalKembali.toDate())}')
                      else if (tanggalJatuhTempo != null)
                        Text(
                          'Jatuh tempo: ${_formatDate(tanggalJatuhTempo.toDate())}',
                          style: TextStyle(
                            color: isOverdue ? Colors.red : Colors.grey[600],
                            fontWeight:
                                isOverdue ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      // Tampilkan denda jika ada
                      if (d['denda'] != null &&
                          (d['denda'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Hukuman: ${d['denda']}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          status == 'dikembalikan'
                              ? Colors.green.withOpacity(0.1)
                              : isOverdue
                              ? Colors.red.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status == 'dikembalikan'
                          ? 'SELESAI'
                          : isOverdue
                          ? 'TERLAMBAT'
                          : 'DIPINJAM',
                      style: TextStyle(
                        color:
                            status == 'dikembalikan'
                                ? Colors.green
                                : isOverdue
                                ? Colors.red
                                : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
