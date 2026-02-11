import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../services/lending_statistics_service.dart';
import '../models/peminjaman_model.dart';
import '../configs/claudinary_api_config.dart';
import '../providers/auth_provider.dart';
import '../configs/feature_flags.dart';
import 'baca_buku_screen.dart';
import 'edit_buku_screen.dart';
import 'ubah_kondisi_buku_screen.dart';

class DetailBukuScreen extends StatefulWidget {
  final BukuModel buku;

  const DetailBukuScreen({super.key, required this.buku});

  @override
  State<DetailBukuScreen> createState() => _DetailBukuScreenState();
}

class _DetailBukuScreenState extends State<DetailBukuScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final LendingStatisticsService _lendingStatsService =
      LendingStatisticsService();
  bool _isLoading = false;
  BukuModel? _currentBuku;
  int _totalLoansToday = 0;

  @override
  void initState() {
    super.initState();
    _currentBuku = widget.buku;
    _loadLendingStatistics();
  }

  Future<void> _loadLendingStatistics() async {
    if (widget.buku.id == null) return;
    try {
      final today = await _lendingStatsService.getTotalLoansTodayForBook(
        widget.buku.id!,
      );
      if (mounted) {
        setState(() {
          _totalLoansToday = today;
        });
      }
    } catch (e) {
      print('Error loading lending statistics: $e');
    }
  }

  Future<void> _refreshBuku() async {
    if (widget.buku.id == null) return;
    final latest = await _firestoreService.getBukuById(widget.buku.id!);
    if (mounted && latest != null) {
      setState(() {
        _currentBuku = latest;
      });
      await _loadLendingStatistics();
    }
  }

  Future<void> _showSetStokDialog() async {
    if (widget.buku.id == null) return;
    final buku = _currentBuku ?? widget.buku;
    final controller = TextEditingController(text: buku.stok.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Atur Stok Buku'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok baru'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Simpan'),
              ),
            ],
          ),
    );

    if (ok == true) {
      final val = int.tryParse(controller.text.trim());
      if (val == null || val < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Masukkan angka stok yang valid')),
        );
        return;
      }
      setState(() => _isLoading = true);
      try {
        // Set stok absolut
        await _firestoreService.setStokBukuAbsolute(
          widget.buku.id!,
          val,
          updateStokAwal: false,
        );
        await _refreshBuku();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stok berhasil diperbarui')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal atur stok: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = (auth.role == 'admin');
    final buku = _currentBuku ?? widget.buku;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Detail Buku',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Hanya admin yang bisa edit dan delete
          if (isAdmin) ...[
            IconButton(
              onPressed:
                  _isLoading
                      ? null
                      : () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => EditBukuScreen(buku: widget.buku),
                          ),
                        );
                        if (result == true && mounted) {
                          // Refresh data jika diperlukan
                          Navigator.pop(context, true);
                        }
                      },
              icon: const Icon(Icons.edit, color: Colors.white),
              tooltip: 'Edit Buku',
            ),
            IconButton(
              onPressed: _isLoading ? null : _showDeleteActions,
              icon: const Icon(Icons.delete, color: Colors.white),
              tooltip: 'Hapus Buku',
            ),
          ],
        ],
      ),

      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                color: Colors.grey[50],
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Book Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              // Cover Image
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    color: Colors.grey[100],
                                    width: double.infinity,
                                    constraints: const BoxConstraints(
                                      maxWidth: 300,
                                      maxHeight: 400,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: 2 / 3,
                                      child:
                                          buku.coverUrl != null &&
                                                  buku.coverUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                imageUrl: buku.coverUrl!,
                                                fit: BoxFit.contain,
                                                placeholder:
                                                    (context, url) => Container(
                                                      color: Colors.grey[200],
                                                      child: const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Container(
                                                      color: Colors.grey[200],
                                                      child: const Center(
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          size: 48,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ),
                                                memCacheWidth:
                                                    400, // Optimize: smaller cache
                                                memCacheHeight:
                                                    600, // Optimize: smaller cache
                                                filterQuality:
                                                    FilterQuality
                                                        .low, // For low-end devices
                                              )
                                              : Container(
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.book,
                                                    size: 56,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Title
                              Text(
                                widget.buku.judul,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              // Publisher
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_circle_outlined,
                                    size: 18,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      widget.buku.pengarang,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.grey[700]),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Category and Year Chips
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  Chip(
                                    avatar: Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: Colors.grey[700],
                                    ),
                                    label: Text(
                                      widget.buku.kategori,
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  Chip(
                                    avatar: Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: Colors.grey[700],
                                    ),
                                    label: Text(
                                      widget.buku.tahun.toString(),
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 13,
                                      ),
                                    ),
                                    backgroundColor: Colors.grey[100],
                                    side: BorderSide(color: Colors.grey[300]!),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info Cards - Redesigned with daily/monthly lending stats
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi Buku',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Row 1: Stock Available
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _infoTile(
                                    Icons.inventory_2_outlined,
                                    'Stok Tersedia',
                                    buku.stok.toString(),
                                    const Color(0xFF455A64),
                                  ),
                                  _infoTile(
                                    Icons.trending_up_outlined,
                                    'Dipinjam Hari Ini',
                                    _totalLoansToday.toString(),
                                    const Color(0xFF455A64),
                                  ),
                                  if (buku.effectiveJumlahRusak > 0)
                                    _infoTile(
                                      Icons.build_circle_outlined,
                                      'Jumlah Rusak',
                                      '${buku.effectiveJumlahRusak} eksemplar',
                                      const Color(0xFFE65100),
                                    ),
                                  if (buku.effectiveJumlahHilang > 0)
                                    _infoTile(
                                      Icons.search_off_rounded,
                                      'Jumlah Hilang',
                                      '${buku.effectiveJumlahHilang} eksemplar',
                                      const Color(0xFFC62828),
                                    ),
                                  if (buku.statusKondisi != 'Tersedia' &&
                                      buku.catatanKondisi != null &&
                                      buku.catatanKondisi!.trim().isNotEmpty)
                                    _infoTile(
                                      Icons.notes_rounded,
                                      'Catatan Kondisi',
                                      buku.catatanKondisi!.trim(),
                                      Colors.grey[600]!,
                                    ),
                                  if (widget.buku.isbn != null &&
                                      widget.buku.isbn!.isNotEmpty)
                                    _infoTile(
                                      Icons.book_outlined,
                                      'ISBN',
                                      widget.buku.isbn!,
                                      Colors.green,
                                    ),
                                ],
                              ),
                              if (isAdmin) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.inventory_2),
                                      label: const Text('Atur Stok'),
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : _showSetStokDialog,
                                    ),
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.build_circle_outlined,
                                      ),
                                      label: const Text('Atur Buku Rusak'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE65100,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed:
                                          _isLoading
                                              ? null
                                              : () async {
                                                final changed =
                                                    await Navigator.push<bool>(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder:
                                                            (_) =>
                                                                UbahKondisiBukuScreen(
                                                                  buku: buku,
                                                                ),
                                                      ),
                                                    );
                                                if (changed == true)
                                                  _refreshBuku();
                                              },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Description Card
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Deskripsi',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.buku.deskripsi?.trim() ??
                                    'Tidak ada deskripsi',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[700],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Baca Buku Button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed:
                              buku.bookFileUrl != null &&
                                      buku.bookFileUrl!.isNotEmpty
                                  ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) =>
                                                BacaBukuScreen(buku: buku),
                                      ),
                                    );
                                  }
                                  : null,
                          icon: Icon(
                            widget.buku.bookFileUrl != null &&
                                    widget.buku.bookFileUrl!.isNotEmpty
                                ? Icons.menu_book
                                : Icons.book_outlined,
                          ),
                          label: Text(
                            widget.buku.bookFileUrl != null &&
                                    widget.buku.bookFileUrl!.isNotEmpty
                                ? 'Baca Buku'
                                : 'File Buku Belum Tersedia',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0D47A1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Booking Peminjaman (untuk siswa) - controlled by feature flag
                      if (!isAdmin && bookingEnabled)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                buku.stok > 0
                                    ? () => _showBookingDialog(auth)
                                    : null,
                            icon: const Icon(Icons.event_available),
                            label: const Text('Booking Peminjaman'),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showBookingDialog(AuthProvider auth) async {
    final namaController = TextEditingController(
      text: auth.currentUser?.displayName ?? '',
    );
    final jumlahController = TextEditingController(text: '1');
    final durasiController = TextEditingController(text: '7');
    String unit = 'hari';

    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Booking Peminjaman'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: namaController,
                        decoration: const InputDecoration(
                          labelText: 'Nama Peminjam',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: jumlahController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Jumlah'),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: durasiController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Durasi',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: unit,
                            items: const [
                              DropdownMenuItem(
                                value: 'hari',
                                child: Text('hari'),
                              ),
                              DropdownMenuItem(
                                value: 'jam',
                                child: Text('jam'),
                              ),
                            ],
                            onChanged:
                                (v) => setState(() => unit = v ?? 'hari'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Batal'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Booking'),
                  ),
                ],
              );
            },
          ),
    );

    if (ok != true) return;

    final nama = namaController.text.trim();
    final jumlah = int.tryParse(jumlahController.text.trim()) ?? 1;
    final durasiVal = int.tryParse(durasiController.text.trim()) ?? 7;
    DateTime due;
    if (unit == 'jam') {
      final menit = (durasiVal.clamp(1, 3)) * 45;
      due = DateTime.now().add(Duration(minutes: menit));
    } else {
      due = DateTime.now().add(Duration(days: durasiVal.clamp(1, 60)));
    }

    if (nama.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nama peminjam diperlukan')));
      return;
    }
    if (jumlah <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jumlah minimal 1')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Load kelas dari data user
      String? studentKelas;
      final uid = auth.currentUser?.uid;
      if (uid != null) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (userDoc.exists) {
          final kelas = userDoc.data()?['kelas'] ?? '';
          if (kelas.toString().isNotEmpty) {
            studentKelas = kelas.toString();
          }
        }
      }

      final peminjaman = PeminjamanModel(
        namaPeminjam: nama,
        kelas: studentKelas,
        uidSiswa: auth.currentUser?.uid,
        judulBuku: (widget.buku.judul),
        tanggalPinjam: DateTime.now(),
        tanggalJatuhTempo: due,
        status: 'pending',
        bukuId: widget.buku.id!,
        jumlah: jumlah,
      );
      await _firestoreService.addBooking(peminjaman);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil, tunggu konfirmasi admin'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal booking: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteActions() async {
    // Dialog with three options: delete cover, delete document, delete both
    final choice = await showDialog<String?>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Buku'),
            content: const Text('Pilih tindakan yang ingin dilakukan:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: const Text('Batal'),
              ),
              if (ClaudinaryApiConfig.allowClientDelete)
                TextButton(
                  onPressed: () => Navigator.pop(context, 'cover'),
                  child: const Text('Hapus Gambar (Cloudinary)'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'both'),
                child: const Text('Hapus Buku'),
              ),
            ],
          ),
    );

    if (choice == null || choice == 'cancel') return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (choice == 'cover' || choice == 'both') {
        final ok = await _firestoreService.deleteCover(widget.buku.id!);
        if (ok) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gambar berhasil dihapus')),
            );
        } else {
          // Jika tidak ada gambar, tidak perlu tampilkan pesan error
          // Hanya log untuk debugging
          print('Info: Buku tidak memiliki gambar sampul untuk dihapus');
        }
      }

      if (choice == 'doc' || choice == 'both') {
        await _firestoreService.deleteBukuDocument(widget.buku.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Buku berhasil dihapus')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
