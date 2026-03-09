import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'laporan_buku_rusak_hilang_screen.dart';
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
  DateTime? _lastBackPressed;
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
      // Peringatan stok rendah untuk admin (adaptive: gunakan safety stock masing-masing buku)
      final auth = context.read<AuthProvider>();
      if (auth.role == 'admin' && mounted) {
        final lowStockBooks =
            bukuList.where((b) {
              if (!b.isArsEnabled) return false;
              // Gunakan safety stock manual jika ada, atau hitung adaptif (30% stok awal, min 1, max 5)
              final int ss;
              if (b.safetyStock != null) {
                ss = b.safetyStock!;
              } else {
                final stokRef = b.stokAwal ?? b.stok;
                ss = (stokRef * 0.3).ceil().clamp(1, 5);
              }
              return b.stok <= ss;
            }).toList();
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tekan kembali sekali lagi untuk keluar'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Perpustakaan SMPN 18 LAU',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0D47A1),
                  Color(0xFF1565C0),
                  Color(0xFF1976D2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [if (isAdmin) const ArsNotificationWidget()],
        ),
        drawer:
            isAdmin
                ? Drawer(
                  child: SafeArea(
                    child: Column(
                      children: [
                        // Gradient Header with user info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF0D47A1),
                                Color(0xFF1565C0),
                                Color(0xFF1976D2),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 32,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.2,
                                  ),
                                  child: Image.asset(
                                    'assets/images/Tutwurihandayani-.png',
                                    height: 44,
                                    width: 44,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.admin_panel_settings,
                                        size: 32,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Administrator',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                auth.currentUser?.email ?? 'admin@perpustakaan',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Menu items
                        Expanded(
                          child: ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              // Section: Notifikasi
                              _DrawerSectionHeader(title: 'NOTIFIKASI'),
                              StreamBuilder<List<dynamic>>(
                                stream:
                                    _arsService.getUnreadNotificationsStream(),
                                builder: (context, snapshot) {
                                  final unreadCount =
                                      snapshot.data?.length ?? 0;
                                  return _DrawerMenuItem(
                                    icon: Icons.notifications_active_rounded,
                                    iconColor: Colors.orange,
                                    title: 'Notifikasi ARS',
                                    badge:
                                        unreadCount > 0
                                            ? (unreadCount > 9
                                                ? '9+'
                                                : '$unreadCount')
                                            : null,
                                    subtitle:
                                        unreadCount > 0
                                            ? '$unreadCount notifikasi baru'
                                            : null,
                                    onTap: () {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) =>
                                                  const ArsNotificationsScreen(),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              // Section: Perpustakaan
                              _DrawerSectionHeader(title: 'PERPUSTAKAAN'),
                              _DrawerMenuItem(
                                icon: Icons.history_rounded,
                                iconColor: const Color(0xFF5C6BC0),
                                title: 'Riwayat Peminjaman',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              const PeminjamanRiwayatScreen(),
                                    ),
                                  );
                                },
                              ),
                              // Section: Anggota
                              _DrawerSectionHeader(title: 'ANGGOTA'),
                              _DrawerMenuItem(
                                icon: Icons.people_alt_rounded,
                                iconColor: const Color(0xFF26A69A),
                                title: 'Daftar Anggota Perpus',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const DaftarAnggotaScreen(),
                                    ),
                                  );
                                },
                              ),
                              _DrawerMenuItem(
                                icon: Icons.person_add_alt_1_rounded,
                                iconColor: Colors.orange,
                                title: 'Persetujuan Pendaftaran',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => const ApproveSiswaScreen(),
                                    ),
                                  );
                                },
                              ),
                              // Section: Laporan
                              _DrawerSectionHeader(title: 'LAPORAN'),
                              _DrawerMenuItem(
                                icon: Icons.report_problem_rounded,
                                iconColor: const Color(0xFFE53935),
                                title: 'Buku Rusak / Hilang',
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              const LaporanBukuRusakHilangScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              _DrawerMenuItem(
                                icon: Icons.logout_rounded,
                                iconColor: Colors.red,
                                title: 'Keluar',
                                titleColor: Colors.red,
                                onTap: () async {
                                  if (!Throttle.allow('logout_admin')) return;
                                  Navigator.pop(context);
                                  await runWithLoading(context, () async {
                                    await context
                                        .read<AuthProvider>()
                                        .signOut();
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
                                          unreadCount > 9
                                              ? '9+'
                                              : '$unreadCount',
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
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Header dengan carousel foto perpustakaan
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 240,
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
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      // Foto perpustakaan
                                      _buildImage(_libraryPhotos[index]),
                                      // Overlay gradient
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.1),
                                              Colors.black.withOpacity(0.6),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              // Teks
                              Positioned(
                                bottom: 36,
                                left: 24,
                                right: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Selamat Datang!',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Perpustakaan SMPN 18 LAU',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.3,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black54,
                                            blurRadius: 6,
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
                                bottom: 12,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    _libraryPhotos.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      width: _currentPage == index ? 24 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color:
                                            _currentPage == index
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Quick Actions Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF0D47A1),
                                        Color(0xFF42A5F5),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Menu Utama',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A237E),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            GridView.count(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.15,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              children: [
                                _QuickAction(
                                  icon: Icons.menu_book_rounded,
                                  label: 'Daftar Buku',
                                  gradientColors: const [
                                    Color(0xFF1976D2),
                                    Color(0xFF42A5F5),
                                  ],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const DaftarBukuScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _QuickAction(
                                  icon: Icons.add_circle_rounded,
                                  label: 'Tambah Buku',
                                  gradientColors: const [
                                    Color(0xFF2E7D32),
                                    Color(0xFF66BB6A),
                                  ],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => const TambahBukuScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _QuickAction(
                                  icon: Icons.book_online_rounded,
                                  label: 'Peminjaman',
                                  gradientColors: const [
                                    Color(0xFFE65100),
                                    Color(0xFFFFA726),
                                  ],
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
                                  icon: Icons.assignment_return_rounded,
                                  label: 'Pengembalian',
                                  gradientColors: const [
                                    Color(0xFF283593),
                                    Color(0xFF5C6BC0),
                                  ],
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                const PengembalianBukuScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ARS Section Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 22,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFE65100),
                                    Color(0xFFFFA726),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Notifikasi Stok',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ARS Notification Widget
                      const ArsNotificationListWidget(maxItems: 5),
                      const SizedBox(height: 24),
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
                          Flexible(
                            child: DropdownButton<String>(
                              isExpanded: true,
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
                                          child: Text(
                                            c,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                                                (context) => DetailBukuScreen(
                                                  buku: buku,
                                                ),
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
                ? Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
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
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                )
                : null,
      ),
    ); // PopScope
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.first.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Drawer section header
class _DrawerSectionHeader extends StatelessWidget {
  final String title;
  const _DrawerSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Styled drawer menu item
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.subtitle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: titleColor ?? Colors.grey[800],
        ),
      ),
      subtitle:
          subtitle != null
              ? Text(
                subtitle!,
                style: TextStyle(color: iconColor, fontSize: 12),
              )
              : null,
      trailing:
          badge != null
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      onTap: onTap,
    );
  }
}
