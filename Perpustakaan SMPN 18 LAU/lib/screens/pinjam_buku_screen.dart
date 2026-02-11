import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buku_model.dart';
import '../models/peminjaman_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/app_notification_service.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../widgets/success_popup.dart';

class PinjamBukuScreen extends StatefulWidget {
  final BukuModel buku;

  const PinjamBukuScreen({super.key, required this.buku});

  @override
  State<PinjamBukuScreen> createState() => _PinjamBukuScreenState();
}

class _PinjamBukuScreenState extends State<PinjamBukuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _durasiController = TextEditingController(text: '7');
  String _unit = 'hari'; // 'jam' atau 'hari'
  final FirestoreService _firestoreService = FirestoreService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();
  String? _studentKelas;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        setState(() {
          _namaController.text = data?['nama'] ?? '';
          _studentKelas = data?['kelas'];
          if (_studentKelas != null && _studentKelas!.isEmpty) {
            _studentKelas = null;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _namaController.dispose();
    _durasiController.dispose();
    super.dispose();
  }

  DateTime _calculateDueDate() {
    final val = int.tryParse(_durasiController.text.trim()) ?? 7;
    if (_unit == 'jam') {
      final jamPelajaran = val.clamp(1, 3);
      final totalMenit = jamPelajaran * 45;
      return DateTime.now().add(Duration(minutes: totalMenit));
    }
    final days = val.clamp(1, 60);
    return DateTime.now().add(Duration(days: days));
  }

  Future<void> _pinjamBuku() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.buku.stok <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stok buku habis!')));
      return;
    }

    await runWithLoading(context, () async {
      final dueDate = _calculateDueDate();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      final peminjaman = PeminjamanModel(
        namaPeminjam: _namaController.text,
        kelas: _studentKelas,
        uidSiswa: currentUserId,
        judulBuku: widget.buku.judul,
        tanggalPinjam: DateTime.now(),
        tanggalJatuhTempo: dueDate,
        status: 'dipinjam',
        bukuId: widget.buku.id!,
      );

      // Simpan peminjaman (ARS check dilakukan otomatis di dalam addPeminjaman)
      await _firestoreService.addPeminjaman(peminjaman);

      // Simpan notifikasi ke inbox user
      if (currentUserId != null) {
        final kelasNotif =
            (_studentKelas != null && _studentKelas!.isNotEmpty)
                ? ' (Kelas: $_studentKelas)'
                : '';
        // Notifikasi peminjaman berhasil
        await _appNotificationService.createNotification(
          userId: currentUserId,
          title: 'Peminjaman Berhasil',
          body:
              'Anda telah meminjam buku "${widget.buku.judul}"$kelasNotif. Jatuh tempo: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          type: 'peminjaman',
          data: {
            'buku_id': widget.buku.id,
            'judul_buku': widget.buku.judul,
            'kelas': _studentKelas,
            'tanggal_jatuh_tempo': dueDate.toIso8601String(),
          },
        );

        // Jadwalkan notifikasi jatuh tempo
        await NotificationService.scheduleDueNotification(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          title: 'Jatuh tempo peminjaman',
          body: '"${widget.buku.judul}" jatuh tempo hari ini',
          dueAt: peminjaman.tanggalJatuhTempo ?? DateTime.now(),
          userId: currentUserId,
          remindAfterDue: true,
          data: {'buku_id': widget.buku.id, 'judul_buku': widget.buku.judul},
        );
      }

      if (mounted) {
        // Tampilkan pop-up sukses
        await SuccessPopup.show(
          context,
          title: 'Peminjaman Berhasil!',
          subtitle: 'Buku "${widget.buku.judul}" telah dipinjam',
        );
        Navigator.pop(context, true);
      }
    }, message: '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Pinjam Buku',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF87CEEB), Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Buku
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Buku',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2C3E50),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Judul', widget.buku.judul),
                        _buildInfoRow('Penerbit', widget.buku.pengarang),
                        _buildInfoRow('Kategori', widget.buku.kategori),
                        _buildInfoRow('Tahun', widget.buku.tahun.toString()),
                        _buildInfoRow(
                          'Stok Tersedia',
                          widget.buku.stok.toString(),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.buku.stok > 0
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color:
                                  widget.buku.stok > 0
                                      ? Colors.green
                                      : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.buku.stok > 0
                                ? 'Tersedia'
                                : 'Tidak Tersedia',
                            style: TextStyle(
                              color:
                                  widget.buku.stok > 0
                                      ? Colors.green
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Form Peminjaman
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Form Peminjaman',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _durasiController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Durasi',
                                    hintText: 'mis. 7',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    final x = int.tryParse(v ?? '');
                                    if (x == null || x <= 0) {
                                      return 'Isi angka > 0';
                                    }
                                    if (_unit == 'jam' && x > 3) {
                                      return 'Durasi maksimal 3 jam pelajaran';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildDurationDropdown(),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildPeminjamField(),
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7F8C8D),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF2C3E50)),
            ),
          ),
        ],
      ),
    );
  }

  // Optimize: Extract dropdown widget untuk mengurangi rebuild
  Widget _buildDurationDropdown() {
    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<String>(
        value: _unit,
        items: const [
          DropdownMenuItem(value: 'hari', child: Text('Hari')),
          DropdownMenuItem(value: 'jam', child: Text('Jam')),
        ],
        onChanged: (v) => setState(() => _unit = v ?? 'hari'),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          labelText: 'Unit',
        ),
      ),
    );
  }

  // Optimize: Extract peminjam name field
  Widget _buildPeminjamField() {
    return TextFormField(
      controller: _namaController,
      decoration: InputDecoration(
        labelText: 'Nama Peminjam',
        hintText: 'Masukkan nama lengkap',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        prefixIcon: const Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Nama peminjam harus diisi';
        }
        return null;
      },
    );
  }

  // Optimize: Extract submit button
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed:
            widget.buku.stok > 0
                ? () async {
                  if (!Throttle.allow('pinjam_buku')) return;
                  await _pinjamBuku();
                }
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3498DB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: const Text(
          'Pinjam Buku',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
