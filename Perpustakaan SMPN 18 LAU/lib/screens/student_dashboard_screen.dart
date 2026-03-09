import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/firestore_service.dart';
import '../services/app_notification_service.dart';
import '../models/buku_model.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import 'daftar_buku_screen.dart';
import 'detail_buku_screen.dart';
import 'student_riwayat_screen.dart';
import 'profil_siswa_screen.dart';
import 'notifications_screen.dart';
import 'student_booking_screen.dart';
import 'student_active_loans_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen>
    with TickerProviderStateMixin {
  DateTime? _lastBackPressed;
  final FirestoreService _firestoreService = FirestoreService();
  final AppNotificationService _appNotificationService =
      AppNotificationService();

  // User data
  String _userName = '';
  String _userKelas = '';
  String? _userPhotoUrl;

  // Stats
  int _totalPinjaman = 0;
  int _pinjamanAktif = 0;
  int _pendingBooking = 0;
  int _bukuDikembalikan = 0;

  // Popular books
  List<BukuModel> _popularBooks = [];

  // Carousel
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<String> _libraryPhotos = [
    'assets/images/perpustakaan1.jpeg',
    'assets/images/perpustakaan2.jpeg',
    'assets/images/perpustakaan3.jpeg',
    'assets/images/perpustakaan4.jpeg',
  ];

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();

    _loadUserData();
    _loadStats();
    _loadPopularBooks();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _pageController.hasClients) {
        if (_currentPage < _libraryPhotos.length - 1) {
          _currentPage++;
        } else {
          _currentPage = 0;
        }
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        _startAutoSlide();
      }
    });
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _userName = data['nama'] ?? '';
          _userKelas = data['kelas'] ?? '';
          _userPhotoUrl = data['photo_url'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('peminjaman')
              .where('uid_siswa', isEqualTo: uid)
              .get();

      int total = 0;
      int aktif = 0;
      int pending = 0;
      int dikembalikan = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        total++;
        if (status == 'dipinjam') aktif++;
        if (status == 'pending') pending++;
        if (status == 'dikembalikan') dikembalikan++;
      }

      if (mounted) {
        setState(() {
          _totalPinjaman = total;
          _pinjamanAktif = aktif;
          _pendingBooking = pending;
          _bukuDikembalikan = dikembalikan;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPopularBooks() async {
    try {
      final books = await _firestoreService.getBuku();
      // Sort by total peminjaman descending
      final sorted = List<BukuModel>.from(books);
      sorted.sort((a, b) => b.totalPeminjaman.compareTo(a.totalPeminjaman));

      if (mounted) {
        setState(() {
          _popularBooks = sorted.take(6).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadUserData(), _loadStats(), _loadPopularBooks()]);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

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
        backgroundColor: const Color(0xFFF5F7FA),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: RefreshIndicator(
            onRefresh: _refreshAll,
            color: const Color(0xFF0D47A1),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom App Bar with user greeting
                _buildSliverAppBar(size),

                // Library Photos Carousel (top)
                SliverToBoxAdapter(child: _buildCarouselSection()),

                // Stats Cards
                SliverToBoxAdapter(child: _buildStatsSection()),

                // Quick Menu
                SliverToBoxAdapter(child: _buildQuickMenu()),

                // Popular Books
                SliverToBoxAdapter(child: _buildPopularBooksSection()),

                // Bottom spacing
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(Size size) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF0D47A1),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: greeting + notifications + profile
                  Row(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfilSiswaScreen(),
                            ),
                          );
                          _loadUserData();
                        },
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage:
                              _userPhotoUrl != null
                                  ? CachedNetworkImageProvider(_userPhotoUrl!)
                                  : null,
                          child:
                              _userPhotoUrl == null
                                  ? Text(
                                    _userName.isNotEmpty
                                        ? _userName[0].toUpperCase()
                                        : 'S',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _userName.isNotEmpty ? _userName : 'Siswa',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_userKelas.isNotEmpty)
                              Text(
                                'Kelas $_userKelas',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Notification bell
                      StreamBuilder<List<dynamic>>(
                        stream:
                            _appNotificationService
                                .getUnreadNotificationsStream(),
                        builder: (context, snapshot) {
                          final unreadCount = snapshot.data?.length ?? 0;
                          return IconButton(
                            onPressed:
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                ),
                            icon: Badge(
                              isLabelVisible: unreadCount > 0,
                              label: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(fontSize: 10),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          );
                        },
                      ),
                      // Logout
                      IconButton(
                        onPressed: () async {
                          if (!Throttle.allow('logout_siswa_dash')) return;
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
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Bottom search bar
                  GestureDetector(
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DaftarBukuScreen(),
                          ),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Cari buku, pengarang...',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik Saya',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.menu_book_rounded,
                  label: 'Sedang Dipinjam',
                  value: '$_pinjamanAktif',
                  color: const Color(0xFF2196F3),
                  gradient: const [Color(0xFF2196F3), Color(0xFF1565C0)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions,
                  label: 'Menunggu Konfirmasi',
                  value: '$_pendingBooking',
                  color: const Color(0xFFFF9800),
                  gradient: const [Color(0xFFFF9800), Color(0xFFF57C00)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline,
                  label: 'Dikembalikan',
                  value: '$_bukuDikembalikan',
                  color: const Color(0xFF4CAF50),
                  gradient: const [Color(0xFF4CAF50), Color(0xFF388E3C)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.library_books,
                  label: 'Total Peminjaman',
                  value: '$_totalPinjaman',
                  color: const Color(0xFF9C27B0),
                  gradient: const [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMenu() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Menu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MenuButton(
                  icon: Icons.bookmark_add_rounded,
                  label: 'Pinjam\nBuku',
                  color: const Color(0xFFFF6B35),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentBookingScreen(),
                      ),
                    );
                    _loadStats();
                  },
                ),
                _MenuButton(
                  icon: Icons.library_books_rounded,
                  label: 'Pinjaman\nAktif',
                  color: const Color(0xFF2196F3),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentActiveLoansScreen(),
                      ),
                    );
                    _loadStats();
                  },
                ),
                _MenuButton(
                  icon: Icons.history_rounded,
                  label: 'Riwayat\nSaya',
                  color: const Color(0xFF9C27B0),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentRiwayatScreen(),
                        ),
                      ),
                ),
                _MenuButton(
                  icon: Icons.person_rounded,
                  label: 'Profil\nSaya',
                  color: const Color(0xFF4CAF50),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfilSiswaScreen(),
                      ),
                    );
                    _loadUserData();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularBooksSection() {
    if (_popularBooks.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Buku Populer',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              TextButton(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DaftarBukuScreen(),
                      ),
                    ),
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _popularBooks.length,
              itemBuilder: (context, index) {
                final buku = _popularBooks[index];
                return GestureDetector(
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailBukuScreen(buku: buku),
                        ),
                      ),
                  child: Container(
                    width: 130,
                    margin: EdgeInsets.only(
                      right: index < _popularBooks.length - 1 ? 12 : 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: SizedBox(
                            height: 120,
                            width: double.infinity,
                            child:
                                buku.coverUrl != null &&
                                        buku.coverUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: buku.coverUrl!,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (_, __) => Container(
                                            color: const Color(
                                              0xFF0D47A1,
                                            ).withOpacity(0.1),
                                            child: const Icon(
                                              Icons.menu_book,
                                              color: Color(0xFF0D47A1),
                                              size: 32,
                                            ),
                                          ),
                                      errorWidget:
                                          (_, __, ___) => Container(
                                            color: const Color(
                                              0xFF0D47A1,
                                            ).withOpacity(0.1),
                                            child: const Icon(
                                              Icons.menu_book,
                                              color: Color(0xFF0D47A1),
                                              size: 32,
                                            ),
                                          ),
                                    )
                                    : Container(
                                      color: const Color(
                                        0xFF0D47A1,
                                      ).withOpacity(0.1),
                                      child: const Center(
                                        child: Icon(
                                          Icons.menu_book,
                                          color: Color(0xFF0D47A1),
                                          size: 36,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                        // Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  buku.judul,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.bookmark,
                                      size: 12,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${buku.totalPeminjaman}x dipinjam',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCarouselSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perpustakaan Kami',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _libraryPhotos.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              _libraryPhotos[index],
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF0D47A1),
                                          const Color(0xFF1976D2),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.library_books,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.4),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 16,
                              left: 16,
                              child: Text(
                                'Perpustakaan SMPN 18 LAU',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _libraryPhotos.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: _currentPage == i ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color:
                              _currentPage == i
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
        ],
      ),
    );
  }
}

// ============================================================================
// REUSABLE WIDGETS
// ============================================================================

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final List<Color> gradient;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
