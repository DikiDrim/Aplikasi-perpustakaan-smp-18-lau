import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../models/buku_model.dart';
import '../models/peminjaman_model.dart';
import '../services/firestore_service.dart';
import '../services/app_notification_service.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../widgets/success_popup.dart';
import 'detail_buku_screen.dart';

class StudentBookingScreen extends StatefulWidget {
  const StudentBookingScreen({super.key});

  @override
  State<StudentBookingScreen> createState() => _StudentBookingScreenState();
}

class _StudentBookingScreenState extends State<StudentBookingScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<BukuModel> _allBooks = [];
  List<BukuModel> _filteredBooks = [];
  List<String> _categories = ['Semua'];
  String _selectedCategory = 'Semua';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    try {
      final books = await _firestoreService.getBuku();
      final cats = await _firestoreService.getCategories();
      if (mounted) {
        setState(() {
          _allBooks =
              books
                  .where((b) => b.stok > 0 && b.statusKondisi != 'Hilang')
                  .toList();
          _filteredBooks = _allBooks;
          _categories = ['Semua', ...cats];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat buku: $e')));
      }
    }
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredBooks =
          _allBooks.where((b) {
            final matchSearch =
                query.isEmpty ||
                b.judul.toLowerCase().contains(query) ||
                b.pengarang.toLowerCase().contains(query) ||
                (b.isbn ?? '').toLowerCase().contains(query);
            final matchCategory =
                _selectedCategory == 'Semua' ||
                b.kategori.toLowerCase() == _selectedCategory.toLowerCase();
            return matchSearch && matchCategory;
          }).toList();
    });
  }

  void _showBookingDialog(BukuModel buku) {
    int durasi = 7;
    String unit = 'hari';
    int jumlahPinjam = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                    // Title
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child:
                              buku.coverUrl != null && buku.coverUrl!.isNotEmpty
                                  ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: buku.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) => const Icon(
                                            Icons.menu_book,
                                            color: Color(0xFF0D47A1),
                                          ),
                                    ),
                                  )
                                  : const Icon(
                                    Icons.menu_book,
                                    color: Color(0xFF0D47A1),
                                  ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                buku.judul,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                buku.pengarang,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Info stok
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Stok tersedia: ${buku.stok} buku. Peminjaman akan menunggu konfirmasi admin saat Anda datang ke perpustakaan.',
                              style: TextStyle(
                                color: Colors.blue[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Jumlah Buku
                    const Text(
                      'Jumlah Buku',
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
                              if (jumlahPinjam > 1) {
                                setModalState(() => jumlahPinjam--);
                              }
                            },
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFF0D47A1),
                          ),
                          Expanded(
                            child: Text(
                              '$jumlahPinjam',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              if (jumlahPinjam < buku.stok) {
                                setModalState(() => jumlahPinjam++);
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF0D47A1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Maksimal ${buku.stok} buku tersedia',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    // Durasi
                    const Text(
                      'Durasi Peminjaman',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Durasi input
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    if (durasi > 1) {
                                      setModalState(() => durasi--);
                                    }
                                  },
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: const Color(0xFF0D47A1),
                                ),
                                Expanded(
                                  child: Text(
                                    '$durasi',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    final maxDurasi = unit == 'jam' ? 3 : 30;
                                    if (durasi < maxDurasi) {
                                      setModalState(() => durasi++);
                                    }
                                  },
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: const Color(0xFF0D47A1),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Unit selector
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: unit,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'jam',
                                    child: Text('Jam'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hari',
                                    child: Text('Hari'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val == null) return;
                                  setModalState(() {
                                    unit = val;
                                    if (unit == 'jam' && durasi > 3) durasi = 3;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Preview tanggal
                    Text(
                      _buildDuePreview(durasi, unit),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          if (!Throttle.allow('booking_submit')) return;
                          Navigator.pop(context);
                          _submitBooking(buku, durasi, unit, jumlahPinjam);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Pinjam Sekarang',
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

  String _buildDuePreview(int durasi, String unit) {
    final now = DateTime.now();
    late DateTime due;
    if (unit == 'jam') {
      due = now.add(Duration(hours: durasi));
    } else {
      due = now.add(Duration(days: durasi));
    }
    return 'Estimasi jatuh tempo: ${DateFormat('EEEE, dd MMMM yyyy HH:mm', 'id_ID').format(due)}';
  }

  Future<void> _submitBooking(
    BukuModel buku,
    int durasi,
    String unit,
    int jumlah,
  ) async {
    try {
      await runWithLoading(context, () async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null) throw Exception('Anda belum login');

        // Get student data
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final nama = userData?['nama'] ?? '';
        final kelas = userData?['kelas'] ?? '';

        // Calculate due date
        final now = DateTime.now();
        late DateTime dueDate;
        if (unit == 'jam') {
          dueDate = now.add(Duration(hours: durasi));
        } else {
          dueDate = now.add(Duration(days: durasi));
        }

        final peminjaman = PeminjamanModel(
          namaPeminjam: nama,
          kelas: kelas,
          uidSiswa: uid,
          judulBuku: buku.judul,
          tanggalPinjam: now,
          tanggalJatuhTempo: dueDate,
          status: 'pending',
          bukuId: buku.id ?? '',
          jumlah: jumlah,
        );

        await _firestoreService.addBooking(peminjaman);

        // Send notification to admins
        try {
          final appNotif = AppNotificationService();
          // Get all admin UIDs
          final adminsSnap =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'admin')
                  .get();
          for (final adminDoc in adminsSnap.docs) {
            await appNotif.createNotification(
              userId: adminDoc.id,
              title: 'Peminjaman Baru',
              body:
                  '$nama (Kelas $kelas) mengajukan peminjaman buku "${buku.judul}"',
              type: 'booking_baru',
              data: {'buku_id': buku.id, 'uid_siswa': uid},
            );
          }
        } catch (_) {}
      }, message: 'Memproses peminjaman...');

      if (mounted) {
        await SuccessPopup.show(
          context,
          title: 'Peminjaman Berhasil Diajukan!',
          subtitle: 'Datang ke perpustakaan untuk konfirmasi oleh admin.',
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (_) {
      // Error handled by runWithLoading
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Pinjam Buku',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D47A1).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari judul, pengarang, atau ISBN...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (_) => _filterBooks(),
                ),
                const SizedBox(height: 10),
                // Category chips
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = cat);
                          _filterBooks();
                        },
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < _categories.length - 1 ? 8 : 0,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color:
                                  isSelected
                                      ? const Color(0xFF0D47A1)
                                      : Colors.white.withOpacity(0.8),
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Book list
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredBooks.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tidak ada buku ditemukan',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredBooks.length,
                      itemBuilder: (context, index) {
                        final buku = _filteredBooks[index];
                        return _BookingBookCard(
                          buku: buku,
                          onBooking: () => _showBookingDialog(buku),
                          onDetail:
                              () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailBukuScreen(buku: buku),
                                ),
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _BookingBookCard extends StatelessWidget {
  final BukuModel buku;
  final VoidCallback onBooking;
  final VoidCallback onDetail;

  const _BookingBookCard({
    required this.buku,
    required this.onBooking,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetail,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 70,
                height: 90,
                child:
                    buku.coverUrl != null && buku.coverUrl!.isNotEmpty
                        ? CachedNetworkImage(
                          imageUrl: buku.coverUrl!,
                          fit: BoxFit.cover,
                          placeholder:
                              (_, __) => Container(
                                color: const Color(0xFF0D47A1).withOpacity(0.1),
                                child: const Icon(
                                  Icons.menu_book,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                          errorWidget:
                              (_, __, ___) => Container(
                                color: const Color(0xFF0D47A1).withOpacity(0.1),
                                child: const Icon(
                                  Icons.menu_book,
                                  color: Color(0xFF0D47A1),
                                ),
                              ),
                        )
                        : Container(
                          color: const Color(0xFF0D47A1).withOpacity(0.1),
                          child: const Center(
                            child: Icon(
                              Icons.menu_book,
                              color: Color(0xFF0D47A1),
                              size: 30,
                            ),
                          ),
                        ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    buku.judul,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    buku.pengarang,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _InfoChip(
                        icon: Icons.category_outlined,
                        text: buku.kategori,
                        color: Colors.blue,
                      ),
                      _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        text: 'Stok: ${buku.stok}',
                        color: buku.stok > 3 ? Colors.green : Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Booking button
            ElevatedButton(
              onPressed: onBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_add, size: 18),
                  SizedBox(height: 2),
                  Text(
                    'Pinjam',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
