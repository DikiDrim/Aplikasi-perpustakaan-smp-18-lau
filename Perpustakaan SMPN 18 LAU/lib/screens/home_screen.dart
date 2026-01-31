import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'tambah_buku_screen.dart';
import 'detail_buku_screen.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../widgets/buku_card.dart';
import 'daftar_buku_screen.dart';
import 'peminjaman_riwayat_screen.dart';
import 'peminjaman_buku_admin_screen.dart';
import 'pengembalian_buku_screen.dart';
import 'student_riwayat_screen.dart';
import 'daftar_anggota_screen.dart';
import 'profil_siswa_screen.dart';
import 'approve_siswa_screen.dart';
import 'notifications_screen.dart';
import '../services/app_notification_service.dart';
import '../services/ars_service_impl.dart';
import '../screens/ars_notifications_screen.dart';
import '../widgets/ars_notification_widget.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  static const routeName = '/home';
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();
  final ArsService _arsService = ArsService();
  List<BukuModel> _bukuList = [];
  List<BukuModel> _filteredBukuList = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  List<String> _categories = ['Semua'];
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // List foto perpustakaan - bisa diganti dengan URL atau path asset
  // CARA MENGUBAH GAMBAR:
  // 1. Untuk menggunakan URL gambar dari internet:
  //    - Ganti URL di bawah dengan URL gambar yang diinginkan
  //    - Contoh: 'https://example.com/gambar-perpustakaan.jpg'
  //
  // 2. Untuk menggunakan gambar dari asset lokal:
  //    - Simpan gambar di folder assets/images/
  //    - Tambahkan path di pubspec.yaml (bagian assets)
  //    - Gunakan format: 'assets/images/nama-gambar.jpg'
  //    - Contoh: 'assets/images/perpustakaan1.jpg'
  //
  // 3. Bisa menambah atau mengurangi jumlah gambar sesuai kebutuhan
  final List<String> _libraryPhotos = [
    // Gambar perpustakaan dari asset lokal
    // Simpan gambar dengan nama berikut di folder assets/images/
    'assets/images/perpustakaan1.jpeg',
    'assets/images/perpustakaan2.jpeg',
    'assets/images/perpustakaan3.jpeg',
    'assets/images/perpustakaan4.jpeg',

    // Jika ingin menggunakan URL dari internet, uncomment dan ganti dengan URL:
    // 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=800',
    // 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=800',
  ];

  @override
  void initState() {
    super.initState();
    _loadBuku();
    _loadCategories();
    // Auto slide carousel
    _startAutoSlide();
    // Trigger ARS check for admin when dashboard opens
    _checkArsNotifications();
    // Initialize FCM (register token) and set up realtime local popup for admins
    _initFcmAndRealtimeNotifications();
  }

  Future<void> _initFcmAndRealtimeNotifications() async {
    try {
      await FcmService.init();
    } catch (e) {
      // Non-fatal
      debugPrint('FCM init failed: $e');
    }

    // Listen for ARS notifications and show local popup for admin users
    final auth = context.read<AuthProvider>();
    if (auth.role != 'admin') return;

    FirebaseFirestore.instance
        .collection('ars_notifications')
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .listen((snapshot) async {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              try {
                final data = change.doc.data();
                final title =
                    data?['judul_buku'] ?? 'ARS - Rekomendasi Pengadaan Ulang';
                final body =
                    'Stok akhir ${data?['stok_akhir'] ?? ''} <= safety ${data?['safety_stock'] ?? ''}. Rekomendasi restok (evaluasi sebelum order).';
                // Show local popup
                await NotificationService.showNotification(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: title,
                  body: body,
                  userId: auth.currentUser?.uid ?? '',
                  type: 'ars',
                );
              } catch (_) {}
            }
          }
        });
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _pageController.hasClients) {
        if (_currentPage < _libraryPhotos.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _startAutoSlide();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Helper method untuk memuat gambar (dari network atau asset) - Optimized
  Widget _buildImage(String imagePath) {
    // Cek apakah path adalah URL (dimulai dengan http/https) atau asset
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      // Load dari network dengan caching
      return CachedNetworkImage(
        imageUrl: imagePath,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildLoadingImage(),
        errorWidget: (context, url, error) => _buildErrorImage(),
        memCacheWidth: 600, // Reduce memory usage
        memCacheHeight: 400, // Reduce memory usage
        filterQuality: FilterQuality.low, // Optimize for low-end devices
      );
    } else {
      // Load dari asset lokal dengan optimization
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorImage();
        },
        cacheWidth: 600,
        cacheHeight: 400,
        filterQuality: FilterQuality.low,
      );
    }
  }

  // Widget untuk menampilkan error jika gambar tidak bisa dimuat
  Widget _buildErrorImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D47A1),
            const Color(0xFF0D47A1).withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.library_books, size: 80, color: Colors.white),
      ),
    );
  }

  // Widget untuk menampilkan loading indicator
  Widget _buildLoadingImage() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D47A1),
            const Color(0xFF0D47A1).withOpacity(0.8),
          ],
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Future<void> _loadBuku() async {
    try {
      final bukuList = await _firestoreService.getBuku();
      setState(() {
        _bukuList = bukuList;
        _filterBuku();
      });
      // Peringatan stok rendah untuk admin (optimize: hanya show first alert)
      final auth = context.read<AuthProvider>();
      if (auth.role == 'admin' && mounted) {
        final lowStockBooks = bukuList.where((b) => b.stok <= 5).toList();
        if (lowStockBooks.isNotEmpty) {
          final b = lowStockBooks.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${b.judul}" • Stok menipis (${b.stok} buku). Pertimbangkan restock.',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _firestoreService.getCategories();
      setState(() {
        _categories = ['Semua', ...cats];
      });
    } catch (_) {}
  }

  void _filterBuku() {
    final q = _searchQuery.toLowerCase().trim();
    setState(() {
      _filteredBukuList =
          _bukuList.where((b) {
            final matchQuery =
                q.isEmpty
                    ? true
                    : (b.judul.toLowerCase().contains(q) ||
                        b.pengarang.toLowerCase().contains(q));
            final matchCategory =
                _selectedCategory == 'Semua'
                    ? true
                    : b.kategori.toLowerCase() ==
                        _selectedCategory.toLowerCase();
            return matchQuery && matchCategory;
          }).toList();
    });
  }

  /// Memeriksa notifikasi ARS saat dashboard dibuka (khusus admin)
  Future<void> _checkArsNotifications() async {
    // Delay untuk memastikan context sudah siap
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // ARS sekarang REALTIME - dipicu setiap kali ada peminjaman
    // (tidak perlu di-trigger secara berkala di home screen)
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = (auth.role == 'admin');
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perpustakaan SMPN 18 LAU',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [if (isAdmin) const ArsNotificationWidget()],
      ),
      drawer:
          isAdmin
              ? Drawer(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(color: Color(0xFF0D47A1)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: Image.asset(
                                  'assets/images/Tutwurihandayani-.png',
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.library_books,
                                      size: 80,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                'Menu Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Admin drawer: show ARS notifications (same as bell)
                      StreamBuilder<List<dynamic>>(
                        stream: _arsService.getUnreadNotificationsStream(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.length ?? 0;
                          return ListTile(
                            leading: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications,
                                  color: Colors.orange,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: const Text('Notifikasi ARS'),
                            subtitle:
                                unreadCount > 0
                                    ? Text(
                                      '$unreadCount notifikasi ARS baru',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 12,
                                      ),
                                    )
                                    : null,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const ArsNotificationsScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Riwayat Peminjaman'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PeminjamanRiwayatScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.people),
                        title: const Text('Daftar Anggota Perpus'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DaftarAnggotaScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.person_add,
                          color: Colors.orange,
                        ),
                        title: const Text('Persetujuan Pendaftaran'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ApproveSiswaScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text(
                          'Keluar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        onTap: () async {
                          if (!Throttle.allow('logout_admin')) return;
                          Navigator.pop(context);
                          await runWithLoading(context, () async {
                            await context.read<AuthProvider>().signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            }
                          }, message: 'Keluar dari akun...');
                        },
                      ),
                    ],
                  ),
                ),
              )
              : Drawer(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(color: Color(0xFF0D47A1)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Center(
                                child: Image.asset(
                                  'assets/images/Tutwurihandayani-.png',
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.library_books,
                                      size: 80,
                                      color: Colors.white,
                                    );
                                  },
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                'Menu',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      StreamBuilder<List<dynamic>>(
                        stream:
                            _appNotificationService
                                .getUnreadNotificationsStream(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.length ?? 0;
                          return ListTile(
                            leading: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications,
                                  color: Colors.blue,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 14,
                                        minHeight: 14,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: const Text('Notifikasi'),
                            subtitle:
                                unreadCount > 0
                                    ? Text(
                                      '$unreadCount notifikasi baru',
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                      ),
                                    )
                                    : null,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationsScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Profil Saya'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilSiswaScreen(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.history),
                        title: const Text('Riwayat Saya'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentRiwayatScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Keluar'),
                        onTap: () async {
                          if (!Throttle.allow('logout_siswa')) return;
                          Navigator.pop(context);
                          await runWithLoading(context, () async {
                            await context.read<AuthProvider>().signOut();
                            if (context.mounted) {
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/',
                                (route) => false,
                              );
                            }
                          }, message: 'Keluar dari akun...');
                        },
                      ),
                    ],
                  ),
                ),
              ),
      body:
          isAdmin
              ? SingleChildScrollView(
                child: Column(
                  children: [
                    // Header dengan carousel foto perpustakaan
                    SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: Stack(
                        children: [
                          // Carousel foto
                          PageView.builder(
                            controller: _pageController,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemCount: _libraryPhotos.length,
                            itemBuilder: (context, index) {
                              return Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF0D47A1).withOpacity(0.8),
                                      const Color(0xFF0D47A1).withOpacity(0.9),
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Foto perpustakaan
                                    _buildImage(_libraryPhotos[index]),
                                    // Overlay gelap untuk kontras teks
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.5),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Teks di bawah
                          Positioned(
                            bottom: 30,
                            left: 0,
                            right: 0,
                            child: Column(
                              children: [
                                const Text(
                                  'Perpustakaan SMPN 18 LAU',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dashboard Admin',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 15,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Indicator dots
                          Positioned(
                            bottom: 10,
                            left: 0,
                            right: 0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                _libraryPhotos.length,
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        _currentPage == index
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Quick Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Menu Utama',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            children: [
                              _QuickAction(
                                icon: Icons.menu_book_rounded,
                                label: 'Daftar Buku',
                                color: const Color(0xFF2196F3),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const DaftarBukuScreen(),
                                    ),
                                  );
                                },
                              ),
                              _QuickAction(
                                icon: Icons.add_circle_rounded,
                                label: 'Tambah Buku',
                                color: const Color(0xFF4CAF50),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TambahBukuScreen(),
                                    ),
                                  );
                                },
                              ),
                              _QuickAction(
                                icon: Icons.book_online_rounded,
                                label: 'Peminjaman',
                                color: const Color(0xFFFF9800),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              const PeminjamanBukuAdminScreen(),
                                    ),
                                  );
                                },
                              ),
                              _QuickAction(
                                icon: Icons.assignment_return,
                                label: 'Pengembalian',
                                color: const Color(0xFF3F51B5),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const PengembalianBukuScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ARS Notification Widget - Menampilkan notifikasi stok rendah
                    const ArsNotificationListWidget(maxItems: 5),
                  ],
                ),
              )
              : _bukuList.isEmpty
              ? const Center(
                child: Text(
                  'Belum ada buku tersedia',
                  style: TextStyle(fontSize: 18),
                ),
              )
              : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search & Category filter (untuk siswa)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Cari buku atau pengarang...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) {
                              _searchQuery = val;
                              _filterBuku();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value:
                              _categories.contains(_selectedCategory)
                                  ? _selectedCategory
                                  : (_categories.isNotEmpty
                                      ? _categories.first
                                      : null),
                          items:
                              _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _selectedCategory = val;
                            });
                            _filterBuku();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child:
                          _filteredBukuList.isEmpty
                              ? const Center(
                                child: Text('Tidak ada buku sesuai filter'),
                              )
                              : ListView.builder(
                                itemCount: _filteredBukuList.length,
                                cacheExtent: 500,
                                itemBuilder: (context, index) {
                                  final buku = _filteredBukuList[index];
                                  return BukuCard(
                                    key: ValueKey(buku.id),
                                    buku: buku,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  DetailBukuScreen(buku: buku),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
      floatingActionButton:
          isAdmin
              ? FloatingActionButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TambahBukuScreen(),
                    ),
                  );
                  if (result == true) {
                    _loadBuku();
                  }
                },
                tooltip: 'Tambah Buku',
                backgroundColor: const Color(0xFF3498DB),
                child: const Icon(Icons.add, color: Colors.white),
              )
              : null,
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: (MediaQuery.of(context).size.width - 56) / 2,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
