import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ars_notification_model.dart';
import '../models/ars_result_model.dart';
import '../models/buku_model.dart';
import '../models/replenishment_order_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Automatic Replenishment System (ARS) Service
///
/// Ketentuan ARS:
/// 1. Perhitungan berdasarkan KATEGORI buku.
/// 2. Data input: array jumlah peminjaman harian selama 7 hari.
/// 3. Total stok tersedia dari database.
/// 4. Lead time (L) = 3 hari.
/// 5. Service level 95% → Z = 1.65.
/// 6. Sistem TIDAK melakukan pemesanan otomatis.
/// 7. Sistem hanya menampilkan notifikasi rekomendasi pengadaan ulang.
///
/// Rumus:
/// - Rata-rata permintaan harian: D̅ = total_peminjaman / jumlah_hari
/// - Standar deviasi: σ = sqrt( Σ(Xi - D̅)² / n )
/// - Safety Stock: SS = Z × σ × √L
/// - Reorder Point: ROP = (D̅ × L) + SS
/// - Stok saat ini: langsung dari DB (buku perpustakaan dikembalikan)
/// - Jika stok_saat_ini ≤ ROP → notifikasi pengadaan ulang
/// - Jika stok_saat_ini > ROP → stok aman
class ArsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final String _replenishmentCollection = 'replenishment_orders';
  final String _booksCollection = 'books';
  final String _notificationsCollection = 'ars_notifications';
  final String _peminjamanCollection = 'peminjaman';

  /// Konstanta ARS
  static const int defaultLeadTime = 3; // hari
  static const double defaultNilaiZ = 1.65; // service level 95%
  static const int defaultJumlahHari = 7; // observasi 7 hari

  ArsService();

  // ════════════════════════════════════════════════════════════════════════════
  // CORE: Perhitungan ARS per Kategori
  // ════════════════════════════════════════════════════════════════════════════

  /// Ambil data peminjaman harian selama [jumlahHari] terakhir
  /// untuk SEMUA buku dalam satu [kategori].
  ///
  /// Returns List<int> dengan panjang [jumlahHari], masing-masing berisi
  /// total peminjaman pada hari tersebut.
  Future<List<int>> _getPeminjamanHarianByKategori(
    String kategori, {
    int jumlahHari = defaultJumlahHari,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Ambil semua buku dalam kategori ini
    final bukuSnap =
        await _firestore
            .collection(_booksCollection)
            .where('kategori', isEqualTo: kategori)
            .get();

    final bukuIds = bukuSnap.docs.map((d) => d.id).toList();
    if (bukuIds.isEmpty) {
      return List.filled(jumlahHari, 0);
    }

    // Inisialisasi array 7 hari dengan 0
    final List<int> dailyCounts = List.filled(jumlahHari, 0);

    // Tanggal mulai = 7 hari lalu (termasuk hari ini)
    final startDate = today.subtract(Duration(days: jumlahHari - 1));

    // Query per buku_id (tanpa composite index) – lalu filter tanggal di memory
    final bukuIdSet = bukuIds.toSet();

    // Query berdasarkan tanggal saja (single inequality, tidak butuh composite index)
    final snap =
        await _firestore
            .collection(_peminjamanCollection)
            .where(
              'tanggal_pinjam',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
            )
            .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final docBukuId = data['buku_id'] as String? ?? '';

      // Filter hanya buku dalam kategori ini
      if (!bukuIdSet.contains(docBukuId)) continue;

      // Hanya hitung peminjaman yang benar-benar terjadi (bukan pending/ditolak)
      final status = (data['status'] ?? '') as String;
      if (status == 'pending' || status == 'ditolak') continue;

      final tanggalRaw = data['tanggal_pinjam'];
      DateTime tanggalPinjam;
      if (tanggalRaw is Timestamp) {
        tanggalPinjam = tanggalRaw.toDate();
      } else if (tanggalRaw is DateTime) {
        tanggalPinjam = tanggalRaw;
      } else {
        continue;
      }

      final tanggalDate = DateTime(
        tanggalPinjam.year,
        tanggalPinjam.month,
        tanggalPinjam.day,
      );

      // Hitung index hari (0 = hari tertua, 6 = hari ini)
      final dayIndex = tanggalDate.difference(startDate).inDays;
      if (dayIndex >= 0 && dayIndex < jumlahHari) {
        final jumlah = (data['jumlah'] ?? 1) as num;
        dailyCounts[dayIndex] += jumlah.toInt();
      }
    }

    return dailyCounts;
  }

  /// Hitung total stok untuk semua buku dalam satu [kategori].
  Future<int> _getTotalStokByKategori(String kategori) async {
    final snap =
        await _firestore
            .collection(_booksCollection)
            .where('kategori', isEqualTo: kategori)
            .get();

    int totalStok = 0;
    for (final doc in snap.docs) {
      totalStok += ((doc.data()['stok'] ?? 0) as num).toInt();
    }
    return totalStok;
  }

  /// Jalankan perhitungan ARS untuk SATU kategori.
  ///
  /// Returns [ArsResultModel] berisi semua hasil perhitungan.
  Future<ArsResultModel> calculateArsForKategori(String kategori) async {
    // 1. Ambil data peminjaman harian 7 hari terakhir
    final peminjamanHarian = await _getPeminjamanHarianByKategori(kategori);

    // 2. Ambil total stok dari DB
    final totalStok = await _getTotalStokByKategori(kategori);

    // 3. Hitung jumlah buku
    final bukuSnap =
        await _firestore
            .collection(_booksCollection)
            .where('kategori', isEqualTo: kategori)
            .get();
    final jumlahBuku = bukuSnap.docs.length;

    // 4. Lakukan perhitungan menggunakan model
    final result = ArsResultModel.calculate(
      kategori: kategori,
      peminjamanHarian: peminjamanHarian,
      stokAwal: totalStok,
      leadTime: defaultLeadTime,
      nilaiZ: defaultNilaiZ,
      jumlahBuku: jumlahBuku,
    );

    print(result); // Log hasil

    return result;
  }

  /// Jalankan perhitungan ARS untuk SEMUA kategori.
  ///
  /// Returns list [ArsResultModel] per kategori, sorted:
  /// - Kategori 'Perlu Pengadaan Ulang' di atas
  /// - Kemudian diurutkan berdasarkan stok akhir (ascending)
  Future<List<ArsResultModel>> runArsAllKategori() async {
    // Ambil semua kategori unik dari koleksi buku
    final bukuSnap = await _firestore.collection(_booksCollection).get();

    final Set<String> kategoriSet = {};
    for (final doc in bukuSnap.docs) {
      final kat = doc.data()['kategori'] as String? ?? '';
      if (kat.isNotEmpty) kategoriSet.add(kat);
    }

    final results = <ArsResultModel>[];
    for (final kategori in kategoriSet) {
      final result = await calculateArsForKategori(kategori);
      results.add(result);
    }

    // Sort: perlu pengadaan dulu, lalu berdasarkan stok akhir ascending
    results.sort((a, b) {
      if (a.perluPengadaan && !b.perluPengadaan) return -1;
      if (!a.perluPengadaan && b.perluPengadaan) return 1;
      return a.stokAkhir.compareTo(b.stokAkhir);
    });

    return results;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TRANSAKSI: Cek ARS saat ada peminjaman
  // ════════════════════════════════════════════════════════════════════════════

  /// Dipanggil setiap kali ada transaksi peminjaman.
  ///
  /// Melakukan perhitungan ARS per-kategori buku yang bersangkutan, lalu
  /// menyimpan notifikasi jika stok_akhir ≤ ROP.
  ///
  /// Parameter:
  /// - bukuId: ID buku
  /// - stokSetelahTransaksi: Stok SETELAH peminjaman (sudah dikurangi)
  /// - jumlahDipinjam: Jumlah buku yang dipinjam
  Future<ArsNotificationModel?> checkArsOnTransaction({
    required String bukuId,
    required int stokSetelahTransaksi,
    required int jumlahDipinjam,
  }) async {
    print('\n[ARS REALTIME CHECK]');
    print('  Buku ID: $bukuId');
    print('  Stok Setelah Transaksi: $stokSetelahTransaksi');
    print('  Jumlah Dipinjam: $jumlahDipinjam');

    try {
      if (jumlahDipinjam <= 0) {
        print('  ❌ ERROR: Jumlah peminjaman harus > 0');
        return null;
      }

      // Ambil data buku untuk mengetahui kategori
      final docBuku =
          await _firestore.collection(_booksCollection).doc(bukuId).get();
      if (!docBuku.exists) {
        print('  ⚠️ Buku tidak ditemukan');
        return null;
      }

      final buku = BukuModel.fromMap(
        docBuku.data() as Map<String, dynamic>,
        docBuku.id,
      );

      print('  Buku: ${buku.judul}');
      print('  Kategori: ${buku.kategori}');

      // ── Perhitungan ARS per KATEGORI ──
      final arsResult = await calculateArsForKategori(buku.kategori);

      // Gunakan stok SETELAH transaksi (bukan stok DB yang mungkin sudah
      // naik kembali karena pengembalian). Di perpustakaan buku dikembalikan
      // sehingga stok DB selalu tinggi. Yang relevan adalah stok SAAT INI
      // setelah peminjaman terjadi.
      final effectiveStok = stokSetelahTransaksi;

      print('  === Hasil ARS (Kategori: ${buku.kategori}) ===');
      print('  Peminjaman Harian: ${arsResult.peminjamanHarian}');
      print(
        '  D̅ (rata-rata): ${arsResult.rataRataPermintaan.toStringAsFixed(4)}',
      );
      print('  σ (std dev): ${arsResult.standarDeviasi.toStringAsFixed(4)}');
      print('  SS (safety stock): ${arsResult.safetyStock.toStringAsFixed(4)}');
      print(
        '  ROP (reorder point): ${arsResult.reorderPoint.toStringAsFixed(4)}',
      );
      print('  Stok Kategori (DB): ${arsResult.stokAkhir}');
      print('  Stok Buku Setelah Transaksi: $effectiveStok');
      print('  Status: ${arsResult.statusStok}');

      final now = DateTime.now();

      // Cek apakah stok ≤ ROP → notifikasi pengadaan ulang
      // Gunakan stok setelah transaksi (effectiveStok) karena di perpustakaan
      // buku yang dikembalikan membuat stok DB selalu tinggi, tapi yang
      // penting adalah stok SAAT peminjaman terjadi.
      final perluPengadaan = effectiveStok <= arsResult.reorderPoint;

      if (perluPengadaan) {
        print(
          '  ⚠️ STOK PERLU PENGADAAN! (Stok $effectiveStok ≤ ROP ${arsResult.reorderPoint.toStringAsFixed(2)})',
        );

        // Hitung jumlah rekomendasi pengadaan:
        // selisih antara ROP dan stok saat ini, minimal 1
        final jumlahPengadaan = (arsResult.reorderPoint.ceil() - effectiveStok)
            .clamp(1, 9999);

        final notification = ArsNotificationModel(
          bukuId: bukuId,
          judulBuku: arsResult.kategori, // gunakan nama kategori
          stokAwal: arsResult.stokAwal,
          stokAkhir: effectiveStok,
          totalPeminjaman: arsResult.totalPeminjaman,
          safetyStock: arsResult.safetyStock.ceil(),
          jumlahPengadaan: jumlahPengadaan,
          status: 'unread',
          tanggalNotifikasi: now,
          detailPeminjaman: List.generate(arsResult.peminjamanHarian.length, (
            i,
          ) {
            final date = DateTime.now().subtract(
              Duration(days: arsResult.jumlahHari - 1 - i),
            );
            return {
              'tanggal':
                  '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              'jumlah': arsResult.peminjamanHarian[i],
            };
          }),
          // Field ARS statistik
          kategori: arsResult.kategori,
          peminjamanHarian: arsResult.peminjamanHarian,
          rataRataPermintaan: arsResult.rataRataPermintaan,
          standarDeviasi: arsResult.standarDeviasi,
          safetyStockCalc: arsResult.safetyStock,
          reorderPoint: arsResult.reorderPoint,
          statusStok: arsResult.statusStok,
          leadTime: arsResult.leadTime,
          nilaiZ: arsResult.nilaiZ,
        );

        // Simpan notifikasi
        await _firestore
            .collection(_notificationsCollection)
            .add(notification.toMap());
        print('  ✓ Notifikasi disimpan');

        // Push ke admin
        await NotificationService.showNotificationToAllAdmins(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Rekomendasi Pengadaan Ulang',
          body:
              'Kategori "${arsResult.kategori}": Stok $effectiveStok ≤ ROP ${arsResult.reorderPoint.toStringAsFixed(2)}. '
              'Disarankan tambah $jumlahPengadaan buku.',
          type: 'ars',
          data: {
            'kategori': arsResult.kategori,
            'stok_awal': arsResult.stokAwal,
            'stok_akhir': effectiveStok,
            'reorder_point': arsResult.reorderPoint,
            'safety_stock': arsResult.safetyStock,
            'jumlah_pengadaan': jumlahPengadaan,
          },
        );

        return notification;
      } else {
        print(
          '  ✓ Stok aman (Stok $effectiveStok > ROP ${arsResult.reorderPoint.toStringAsFixed(2)})',
        );
        return null;
      }
    } catch (e) {
      print('  ❌ ERROR: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get unread notifications
  Stream<List<ArsNotificationModel>> getUnreadNotificationsStream() {
    return _firestore
        .collection(_notificationsCollection)
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .map((snap) {
          final list =
              snap.docs
                  .map((d) => ArsNotificationModel.fromMap(d.data(), d.id))
                  .toList();
          list.sort(
            (a, b) => b.tanggalNotifikasi.compareTo(a.tanggalNotifikasi),
          );
          return list;
        });
  }

  /// Get all notifications with filters
  Future<List<ArsNotificationModel>> getNotifications({
    int limit = 50,
    bool? unreadOnly,
  }) async {
    try {
      Query query = _firestore.collection(_notificationsCollection);

      if (unreadOnly == true) {
        query = query.where('status', isEqualTo: 'unread');
      }

      query = query
          .orderBy('tanggal_notifikasi', descending: true)
          .limit(limit);

      final snap = await query.get();
      final list =
          snap.docs
              .map(
                (d) => ArsNotificationModel.fromMap(
                  d.data() as Map<String, dynamic>,
                  d.id,
                ),
              )
              .toList();
      return list;
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .update({'status': 'read'});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final snap =
          await _firestore
              .collection(_notificationsCollection)
              .where('status', isEqualTo: 'unread')
              .get();

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore
          .collection(_notificationsCollection)
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // REPLENISHMENT ORDERS (legacy — tetap dipertahankan untuk kompatibilitas)
  // ════════════════════════════════════════════════════════════════════════════

  /// Create replenishment order
  Future<void> createReplenishmentOrder(ReplenishmentOrderModel order) async {
    try {
      await _firestore.collection(_replenishmentCollection).add(order.toMap());
    } catch (e) {
      throw Exception('Gagal membuat pesanan pengadaan: $e');
    }
  }

  /// Get all replenishment orders
  Stream<List<ReplenishmentOrderModel>> getReplenishmentOrdersStream() {
    return _firestore
        .collection(_replenishmentCollection)
        .orderBy('tanggal_pesan', descending: true)
        .snapshots()
        .map((s) {
          final list =
              s.docs
                  .map((d) => ReplenishmentOrderModel.fromMap(d.data(), d.id))
                  .toList();
          list.sort((a, b) => b.tanggalPesan.compareTo(a.tanggalPesan));
          return list;
        });
  }

  /// Update order status
  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? catatan,
  }) async {
    final updateData = <String, dynamic>{'status': status};
    if (catatan != null) updateData['catatan'] = catatan;
    if (status == 'diterima') updateData['tanggal_diterima'] = Timestamp.now();
    await _firestore
        .collection(_replenishmentCollection)
        .doc(orderId)
        .update(updateData);
  }

  /// Receive order (update stok)
  Future<void> receiveOrder(String orderId) async {
    final orderDoc =
        await _firestore
            .collection(_replenishmentCollection)
            .doc(orderId)
            .get();
    if (!orderDoc.exists) return;

    final order = ReplenishmentOrderModel.fromMap(
      orderDoc.data() as Map<String, dynamic>,
      orderDoc.id,
    );

    await _firestoreService.updateStokBuku(order.bukuId, order.quantity);
    await updateOrderStatus(orderId, 'diterima');
  }

  /// Cancel order
  Future<void> cancelOrder(String orderId, String reason) async {
    await updateOrderStatus(orderId, 'dibatalkan', catatan: reason);
  }

  /// Force check all categories (for dashboard / manual trigger)
  Future<List<ReplenishmentOrderModel>>
  checkAndCreateReplenishmentOrders() async {
    final notifications = await getNotifications(unreadOnly: true);
    final created = <ReplenishmentOrderModel>[];
    for (final n in notifications) {
      final qty = n.jumlahPengadaan;
      final order = ReplenishmentOrderModel(
        bukuId: n.bukuId,
        judulBuku: n.judulBuku,
        quantity: qty,
        tanggalPesan: DateTime.now(),
        isAutomatic: true,
        stokSaatPesan: n.stokAkhir,
      );
      await createReplenishmentOrder(order);
      created.add(order);
    }
    return created;
  }

  /// Get all replenishment orders
  Future<List<ReplenishmentOrderModel>> getReplenishmentOrders() async {
    try {
      final snapshot =
          await _firestore
              .collection(_replenishmentCollection)
              .orderBy('tanggal_pesan', descending: true)
              .get();

      return snapshot.docs
          .map((d) => ReplenishmentOrderModel.fromMap(d.data(), d.id))
          .toList();
    } catch (e) {
      print('Error getting replenishment orders: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DASHBOARD HELPERS
  // ════════════════════════════════════════════════════════════════════════════

  /// Get books with low stock (backward compatible)
  Future<List<Map<String, dynamic>>> getLowStockBooks() async {
    try {
      final bukuList = await _firestoreService.getBuku();
      final lowStockBooks = <Map<String, dynamic>>[];

      for (final buku in bukuList) {
        final int safetyStock;
        if (buku.safetyStock != null) {
          safetyStock = buku.safetyStock!;
        } else {
          final stokRef = buku.stokAwal ?? buku.stok;
          safetyStock = (stokRef * 0.3).ceil().clamp(1, 5);
        }
        if (buku.stok <= safetyStock) {
          lowStockBooks.add({
            'buku_id': buku.id,
            'judul': buku.judul,
            'stok': buku.stok,
            'safety_stock': safetyStock,
          });
        }
      }

      return lowStockBooks;
    } catch (e) {
      print('Error getting low stock books: $e');
      return [];
    }
  }

  /// Get ARS statistics
  Future<Map<String, dynamic>> getArsStatistics() async {
    try {
      final notifications = await getNotifications(limit: 100);
      final orders = await getReplenishmentOrders();
      final lowStockBooks = await getLowStockBooks();

      return {
        'total_notifications': notifications.length,
        'unread_notifications':
            notifications.where((n) => n.status == 'unread').length,
        'total_orders': orders.length,
        'pending_orders': orders.where((o) => o.status == 'pending').length,
        'low_stock_books': lowStockBooks.length,
      };
    } catch (e) {
      print('Error getting ARS statistics: $e');
      return {
        'total_notifications': 0,
        'unread_notifications': 0,
        'total_orders': 0,
        'pending_orders': 0,
        'low_stock_books': 0,
      };
    }
  }
}
