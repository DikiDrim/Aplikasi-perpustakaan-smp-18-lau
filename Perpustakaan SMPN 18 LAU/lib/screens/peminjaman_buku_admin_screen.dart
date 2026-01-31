import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/buku_model.dart';
import '../models/peminjaman_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/ars_service_impl.dart';
import '../services/app_notification_service.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../configs/feature_flags.dart';

class PeminjamanBukuAdminScreen extends StatefulWidget {
  const PeminjamanBukuAdminScreen({super.key});

  @override
  State<PeminjamanBukuAdminScreen> createState() =>
      _PeminjamanBukuAdminScreenState();
}

class _PeminjamanBukuAdminScreenState extends State<PeminjamanBukuAdminScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final ArsService _arsService = ArsService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();
  final TextEditingController _searchSiswaController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nisController = TextEditingController();
  final TextEditingController _kelasController = TextEditingController();
  final TextEditingController _jumlahController = TextEditingController();
  final TextEditingController _durasiController = TextEditingController();
  String? _unit;
  String _kategoriFilter = 'Semua';
  List<String> _kategoriList = const ['Semua'];
  List<BukuModel> _bukuList = [];
  bool _loading = true;
  final TextEditingController _searchBukuController = TextEditingController();
  String _searchBukuQuery = '';
  String? _selectedSiswaUid;
  List<Map<String, dynamic>> _siswaSearchResults = [];
  bool _searchingSiswa = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final int tabCount = bookingEnabled ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this);

    // Listener untuk menutup keyboard saat pindah tab
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Tutup keyboard saat mulai pindah tab
        FocusScope.of(context).unfocus();
      }
    });
    _load();
    FirestoreService().getCategoriesStream().listen((cats) {
      if (!mounted) return;
      setState(() {
        _kategoriList = ['Semua', ...cats];
        if (!_kategoriList.contains(_kategoriFilter)) {
          _kategoriFilter = 'Semua';
        }
      });
    });
  }

  Future<void> _load() async {
    try {
      final list = await _firestoreService.getBuku();
      setState(() {
        _bukuList = list.where((b) => b.stok > 0).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat buku: $e')));
      }
    }
  }

  DateTime _buildDueDate() {
    // Diasumsikan sudah tervalidasi sebelum pemanggilan
    final val = int.parse(_durasiController.text.trim());
    if (_unit == 'jam') {
      final jamPelajaran = val.clamp(1, 3);
      final totalMenit = jamPelajaran * 45;
      return DateTime.now().add(Duration(minutes: totalMenit));
    }
    final days = val.clamp(1, 60);
    return DateTime.now().add(Duration(days: days));
  }

  Future<void> _pinjam(BukuModel buku) async {
    // Ambil data dari controller
    final nama = _namaController.text.trim();
    final qtyText = _jumlahController.text.trim();
    final unit = _unit;
    final durasiText = _durasiController.text.trim();

    // VALIDASI INPUT - Jika gagal, TETAP di halaman ini
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama peminjam wajib diisi'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    if (qtyText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah buku wajib diisi'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    final qty = int.tryParse(qtyText) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah harus lebih dari 0'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    if (qty > buku.stok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok tidak cukup! Tersedia: ${buku.stok}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    if (unit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih satuan waktu (Hari/Jam)'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    if (durasiText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durasi peminjaman wajib diisi'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    final durasi = int.tryParse(durasiText) ?? 0;
    if (durasi <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durasi harus lebih dari 0'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    if (unit == 'jam' && durasi > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Durasi maksimal 3 jam pelajaran'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return; // STOP - tetap di halaman peminjaman
    }

    // DIALOG KONFIRMASI - User harus konfirmasi dulu
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Konfirmasi Peminjaman'),
            content: Text('Pinjam ${qty}x "${buku.judul}" untuk $nama?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Ya, Pinjam'),
              ),
            ],
          ),
    );

    // Jika user klik Batal atau tutup dialog, STOP di sini
    if (confirmed != true) return;

    // SEMUA VALIDASI LOLOS & USER SUDAH KONFIRMASI - Mulai proses
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final kelas = _kelasController.text.trim();
      final dueDate = _buildDueDate();

      final peminjaman = PeminjamanModel(
        namaPeminjam: nama,
        kelas: kelas.isNotEmpty ? kelas : null,
        uidSiswa: _selectedSiswaUid,
        judulBuku: buku.judul,
        tanggalPinjam: DateTime.now(),
        tanggalJatuhTempo: dueDate,
        status: 'dipinjam',
        bukuId: buku.id!,
        jumlah: qty,
      );

      final didRestock = await _firestoreService.addPeminjaman(peminjaman);

      // ARS check REALTIME (trigger dengan stok sebelum dan jumlah dipinjam)
      _arsService
          .checkArsOnTransaction(
            bukuId: buku.id!,
            stokSebelumTransaksi: buku.stok,
            jumlahDipinjam: qty,
          )
          .catchError((_) => null);

      // Notifikasi untuk siswa (tidak menghambat jika gagal)
      if (_selectedSiswaUid != null) {
        _appNotificationService
            .createNotification(
              userId: _selectedSiswaUid!,
              title: 'Peminjaman Berhasil',
              body:
                  'Buku "${buku.judul}" berhasil dipinjam. Jatuh tempo: ${dueDate.day}/${dueDate.month}/${dueDate.year}',
              type: 'peminjaman',
              data: {
                'buku_id': buku.id,
                'judul_buku': buku.judul,
                'tanggal_jatuh_tempo': dueDate.toIso8601String(),
              },
            )
            .catchError((_) {});

        NotificationService.scheduleDueNotification(
          id: DateTime.now().millisecondsSinceEpoch % 1000000,
          title: 'Jatuh Tempo Peminjaman',
          body: '"${buku.judul}" jatuh tempo hari ini',
          dueAt: dueDate,
          userId: _selectedSiswaUid!,
          remindAfterDue: true,
          data: {'buku_id': buku.id, 'judul_buku': buku.judul},
        ).catchError((_) {});
      }

      // Tutup loading
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      // Reset form
      _clearSiswaSelection();
      _jumlahController.clear();
      _durasiController.clear();
      setState(() => _unit = null);

      // Tampilkan pop-up sukses sementara di tengah layar
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Text('Berhasil!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buku "${buku.judul}" berhasil dipinjam!'),
                  if (didRestock) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stok menipis. Restok otomatis dilakukan.',
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
      );

      // Auto-close setelah 2 detik
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      // Navigasi ke home HANYA jika sukses DAN user sudah baca notif
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      // Tutup loading jika error
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!mounted) return;

      // Tampilkan error dan TETAP di halaman peminjaman
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      // TIDAK ADA NAVIGASI - tetap di halaman peminjaman
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchSiswaController.dispose();
    _searchBukuController.dispose();
    _namaController.dispose();
    _nisController.dispose();
    _kelasController.dispose();
    _jumlahController.dispose();
    _durasiController.dispose();
    super.dispose();
  }

  Future<void> _searchSiswa(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _siswaSearchResults = [];
        _searchingSiswa = false;
      });
      return;
    }

    setState(() => _searchingSiswa = true);

    try {
      final queryLower = query.trim().toLowerCase();
      final siswaSnapshot =
          await FirebaseFirestore.instance.collection('siswa').get();

      // Map docs and include `uid` for consistent selection key
      final results =
          siswaSnapshot.docs
              .map((doc) => {'uid': doc.id, ...doc.data()})
              .where((siswa) {
                final nama = (siswa['nama'] ?? '').toString().toLowerCase();
                final nis = (siswa['nis'] ?? '').toString().toLowerCase();
                final username =
                    (siswa['username'] ?? '').toString().toLowerCase();
                return nama.contains(queryLower) ||
                    nis.contains(queryLower) ||
                    username.contains(queryLower);
              })
              .take(10)
              .toList();

      setState(() {
        _siswaSearchResults = results;
        _searchingSiswa = false;
      });
    } catch (e) {
      setState(() => _searchingSiswa = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mencari siswa: $e')));
      }
    }
  }

  void _selectSiswa(Map<String, dynamic> siswa) {
    setState(() {
      // Prefer explicit 'uid' from mapping, fall back to 'id' if present
      _selectedSiswaUid = siswa['uid'] ?? siswa['id'];
      _namaController.text = siswa['nama'] ?? '';
      _nisController.text = siswa['nis'] ?? '';
      // Biarkan kelas kosong - admin akan input sendiri
      _kelasController.clear();
      _searchSiswaController.text = '${siswa['nama']} (NIS: ${siswa['nis']})';
      _siswaSearchResults = [];
    });
    // Scroll ke bawah setelah memilih siswa
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        // Focus ke field berikutnya
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _clearSiswaSelection() {
    setState(() {
      _selectedSiswaUid = null;
      _namaController.clear();
      _nisController.clear();
      _kelasController.clear();
      _searchSiswaController.clear();
      _siswaSearchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Peminjaman Buku (Admin)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.person), text: 'Data Siswa'),
            const Tab(icon: Icon(Icons.book), text: 'Pilih Buku'),
            if (bookingEnabled)
              const Tab(icon: Icon(Icons.list_alt), text: 'Permintaan'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Data Siswa
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Pencarian Siswa
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: Color(0xFF0D47A1),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Cari Siswa Terdaftar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _searchSiswaController,
                          decoration: InputDecoration(
                            labelText: 'Cari Siswa',
                            hintText: 'Ketik NIS atau nama siswa...',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF87CEEB),
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFF87CEEB),
                            ),
                            helperText: 'Contoh: 222137 atau DikiDrim',
                            helperStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          onChanged: _searchSiswa,
                        ),
                        const SizedBox(height: 12),
                        // Search results dropdown
                        if (_searchingSiswa)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF0D47A1),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Mencari siswa...',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!_searchingSiswa && _siswaSearchResults.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    '${_siswaSearchResults.length} siswa ditemukan:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    itemCount: _siswaSearchResults.length,
                                    separatorBuilder:
                                        (_, __) => Divider(
                                          height: 1,
                                          color: Colors.grey[300],
                                        ),
                                    itemBuilder: (context, idx) {
                                      final s = _siswaSearchResults[idx];
                                      final sName = s['nama'] ?? 'Unknown';
                                      final sNis = s['nis'] ?? '';
                                      final sKelas = s['kelas'] ?? '';
                                      return ListTile(
                                        title: Text(
                                          sName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Text(
                                          sNis.isNotEmpty
                                              ? 'NIS: $sNis ${sKelas.isNotEmpty ? '• Kelas: $sKelas' : ''}'
                                              : (sKelas.isNotEmpty
                                                  ? 'Kelas: $sKelas'
                                                  : ''),
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        leading: CircleAvatar(
                                          backgroundColor: Color(0xFF0D47A1),
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        onTap:
                                            () => _selectSiswa(
                                              Map<String, dynamic>.from(s),
                                            ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Informasi siswa terpilih (jika ada)
                if (_selectedSiswaUid != null)
                  Card(
                    elevation: 2,
                    color: Colors.green.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.green.shade200, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Siswa Dipilih',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _namaController.text,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tombol hapus pilihan siswa
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.red),
                                onPressed: _clearSiswaSelection,
                                tooltip: 'Hapus pilihan siswa',
                              ),
                            ],
                          ),
                          if (_nisController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'NIS: ${_nisController.text}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Input kelas untuk siswa terpilih
                          const SizedBox(height: 12),
                          Text(
                            'Kelas (Opsional)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _kelasController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan kelas, contoh: 7A',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0D47A1),
                                  width: 2,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.class_,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Form Data Siswa (bisa diisi manual jika bukan anggota terdaftar)
                if (_selectedSiswaUid == null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Siswa tidak ditemukan? Isi data manual di bawah ini',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[800],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Field Nama
                          Text(
                            'Nama Peminjam *',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          TextField(
                            controller: _namaController,
                            decoration: InputDecoration(
                              hintText: 'Masukkan nama lengkap peminjam',
                              filled: true,
                              fillColor:
                                  _selectedSiswaUid != null
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0D47A1),
                                  width: 2,
                                ),
                              ),
                              prefixIcon: const Icon(
                                Icons.person,
                                color: Color(0xFF0D47A1),
                              ),
                              helperText:
                                  _selectedSiswaUid != null
                                      ? '✓ Data dari siswa terdaftar'
                                      : 'Wajib diisi',
                              helperStyle: TextStyle(
                                color:
                                    _selectedSiswaUid != null
                                        ? Colors.green
                                        : Colors.grey[600],
                                fontSize: 11,
                                fontWeight:
                                    _selectedSiswaUid != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                              ),
                            ),
                            enabled: _selectedSiswaUid == null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NIS (Opsional)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    TextField(
                                      controller: _nisController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        hintText: 'Contoh: 222137',
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0D47A1),
                                            width: 2,
                                          ),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.badge,
                                          color: Color(0xFF0D47A1),
                                        ),
                                      ),
                                      enabled: _selectedSiswaUid == null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kelas (Opsional)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    TextField(
                                      controller: _kelasController,
                                      decoration: InputDecoration(
                                        hintText: 'Contoh: 7A',
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF0D47A1),
                                            width: 2,
                                          ),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.class_,
                                          color: Color(0xFF0D47A1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                // Card Detail Peminjaman
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.event_note,
                              color: Color(0xFF0D47A1),
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Detail Peminjaman',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Jumlah Buku
                        Text(
                          'Jumlah Buku *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _jumlahController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Masukkan jumlah buku',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0D47A1),
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.numbers,
                              color: Color(0xFF0D47A1),
                            ),
                            helperText: 'Wajib diisi',
                            helperStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Satuan Waktu
                        Text(
                          'Satuan Waktu *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _unit,
                          items: const [
                            DropdownMenuItem(
                              value: 'hari',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Hari'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'jam',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 18,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Jam Pelajaran'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              _unit = v;
                            });
                          },
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0D47A1),
                                width: 2,
                              ),
                            ),
                            helperText:
                                _unit == null
                                    ? 'Pilih satuan waktu'
                                    : (_unit == 'hari'
                                        ? 'Untuk peminjaman harian'
                                        : '1 jam pelajaran = 45 menit (max 3 jam)'),
                            helperStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Durasi
                        Text(
                          'Lama Waktu Peminjaman *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        TextField(
                          controller: _durasiController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            hintText:
                                _unit == null
                                    ? 'Isi angka durasi (misal: 7)'
                                    : (_unit == 'hari'
                                        ? 'Contoh: 7 (untuk 7 hari)'
                                        : 'Contoh: 2 (untuk 2 jam pelajaran)'),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF0D47A1),
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              _unit == 'hari'
                                  ? Icons.calendar_today
                                  : Icons.access_time,
                              color: Color(0xFF0D47A1),
                            ),
                            suffixText: _unit,
                            suffixStyle: TextStyle(
                              color: Color(0xFF0D47A1),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            helperText:
                                _unit == null
                                    ? 'Masukkan durasi setelah memilih satuan'
                                    : (_unit == 'hari'
                                        ? 'Masukkan durasi dalam hari'
                                        : 'Max: 3 jam (1 jam = 45 menit)'),
                            helperStyle: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab 2: Pilih Buku
          SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              // tambahkan safe area bottom + viewInsets untuk mencegah overflow
              bottom:
                  MediaQuery.of(context).viewInsets.bottom +
                  MediaQuery.of(context).padding.bottom +
                  24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Buku (admin)
                TextField(
                  controller: _searchBukuController,
                  decoration: InputDecoration(
                    hintText: 'Cari buku menurut judul atau pengarang...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF87CEEB),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _searchBukuQuery = v.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),
                // Filter Kategori
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value:
                            _kategoriList.contains(_kategoriFilter)
                                ? _kategoriFilter
                                : (_kategoriList.isNotEmpty
                                    ? _kategoriList.first
                                    : null),
                        items:
                            _kategoriList
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c == 'Semua' ? 'Semua Kategori' : c,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          setState(() {
                            _kategoriFilter = v ?? 'Semua';
                          });
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF87CEEB),
                              width: 2,
                            ),
                          ),
                          prefixIcon: const Icon(
                            Icons.filter_list,
                            color: Color(0xFF87CEEB),
                          ),
                          labelText: 'Filter Kategori',
                          labelStyle: const TextStyle(color: Colors.grey),
                        ),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Grid Buku
                _loading
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                    : _bukuList.isEmpty
                    ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('Tidak ada buku tersedia untuk dipinjam'),
                      ),
                    )
                    : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Optimize: cacheExtent untuk lazy loading
                      cacheExtent: 500,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        // Aspect ratio yang lebih proporsional seperti sampul buku
                        // (tinggi lebih besar dari lebar untuk terlihat seperti buku sejati)
                        childAspectRatio: 0.55,
                      ),
                      itemCount: _bukuList.length,
                      itemBuilder: (context, index) {
                        final b = _bukuList[index];
                        // Apply category filter
                        if (_kategoriFilter != 'Semua' &&
                            (b.kategori != _kategoriFilter)) {
                          return const SizedBox.shrink();
                        }
                        // Apply search filter (judul / pengarang)
                        if (_searchBukuQuery.isNotEmpty) {
                          final matchJudul = b.judul.toLowerCase().contains(
                            _searchBukuQuery,
                          );
                          final matchPengarang = b.pengarang
                              .toLowerCase()
                              .contains(_searchBukuQuery);
                          if (!matchJudul && !matchPengarang)
                            return const SizedBox.shrink();
                        }
                        return _BookCard(
                          key: ValueKey(b.id), // Key untuk optimize rebuilds
                          buku: b,
                          onPinjam: () async {
                            if (!Throttle.allow('pinjam_admin_${b.id}')) return;
                            await _pinjam(b);
                            // Navigasi sudah ditangani di dalam _pinjam()
                            // Hanya navigasi jika berhasil
                          },
                        );
                      },
                    ),
                const SizedBox(height: 16), // Extra padding at bottom
              ],
            ),
          ),
          // Tab 3: Permintaan (booking pending)
          if (bookingEnabled)
            StreamBuilder<List<PeminjamanModel>>(
              stream: _firestoreService.getPeminjamanStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list =
                    (snap.data ?? [])
                        .where((p) => p.status == 'pending')
                        .toList();
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Tidak ada permintaan peminjaman'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = list[index];
                    return Card(
                      child: ListTile(
                        title: Text(p.judulBuku),
                        subtitle: Text(
                          '${p.namaPeminjam} • Jumlah: ${p.jumlah}',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await runWithLoading(context, () async {
                                  try {
                                    await _firestoreService.approvePeminjaman(
                                      p.id!,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Peminjaman disetujui'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal setujui: $e'),
                                      ),
                                    );
                                  }
                                });
                              },
                              child: const Text('Setujui'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await runWithLoading(context, () async {
                                  try {
                                    await _firestoreService.deletePeminjaman(
                                      p.id!,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Permintaan dibatalkan'),
                                      ),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal batalkan: $e'),
                                      ),
                                    );
                                  }
                                });
                              },
                              child: const Text('Tolak'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final BukuModel buku;
  final VoidCallback onPinjam;
  const _BookCard({super.key, required this.buku, required this.onPinjam});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover Image - Expanded (flex: 2)
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child:
                  buku.coverUrl != null && buku.coverUrl!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: buku.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.broken_image, size: 32),
                              ),
                            ),
                        memCacheWidth: 160,
                        memCacheHeight: 240,
                      )
                      : Container(
                        color: Colors.grey[200],
                        child: const Center(child: Icon(Icons.book, size: 32)),
                      ),
            ),
          ),
          // Title + stok - Expanded (flex: 1)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buku.judul,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: ${buku.stok}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Button - Expanded (flex: 1)
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Center(
                child: ElevatedButton(
                  onPressed: onPinjam,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 2,
                    minimumSize: const Size(double.infinity, 36),
                    maximumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Pinjam',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
