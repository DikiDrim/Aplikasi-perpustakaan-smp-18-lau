import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ars_notification_model.dart';
import '../models/buku_model.dart';
import '../models/replenishment_order_model.dart';
import 'firestore_service.dart';
import 'notification_service.dart';

/// Automatic Replenishment System (ARS) Service - CLEAN VERSION
///
/// Ketentuan ARS:
/// a. Sistem ARS dijalankan setiap kali ada perubahan stok (peminjaman/pengembalian)
/// b. Stok awal = stok sebelum transaksi peminjaman
/// c. Total peminjaman harian = transaksi peminjaman pada tanggal yang sama
/// d. Stok akhir = stok_awal - total_peminjaman_harian
/// e. Cegah peminjaman jika stok_akhir <= 0
/// f. ARS aktif jika: stok_akhir <= safety_stock
/// g. Notifikasi muncul setiap kali stok menyentuh safety_stock
/// h. Notifikasi merepresentasikan kondisi stok saat ini
/// i. Hindari perhitungan ganda
/// j. Validasi: stok_awal >= total_peminjaman_harian

class ArsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  final String _replenishmentCollection = 'replenishment_orders';
  final String _booksCollection = 'books';
  final String _notificationsCollection = 'ars_notifications';

  ArsService();

  /// === MAIN METHOD ===
  /// Dipanggil REALTIME setiap kali ada transaksi peminjaman
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
      // VALIDASI: Jumlah transaksi harus valid
      if (jumlahDipinjam <= 0) {
        print('  ❌ ERROR: Jumlah peminjaman harus > 0');
        return null;
      }

      // Ambil data buku untuk cek isArsEnabled, safetyStock, stokAwal dll
      // PENTING: Kita TIDAK menggunakan buku.stok karena bisa stale dari cache!
      // Kita menggunakan stokSetelahTransaksi yang dihitung langsung dari transaksi.
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

      // Gunakan stok yang LANGSUNG dari parameter (bukan dari DB/cache)
      final int stokAkhirAktual = stokSetelahTransaksi;
      final int stokSebelumAktual = stokAkhirAktual + jumlahDipinjam;

      print('  Stok Setelah Transaksi (param langsung): $stokAkhirAktual');
      print('  Stok Sebelum (rekonstruksi): $stokSebelumAktual');
      print('  isArsEnabled (from DB): ${buku.isArsEnabled}');

      // ARS selalu aktif - field is_ars_enabled bisa salah karena bug edit sebelumnya
      // Jika di masa depan ingin nonaktifkan ARS per buku, bisa diaktifkan kembali
      // if (!buku.isArsEnabled) {
      //   print('  ⚠️ ARS tidak enabled untuk buku ini');
      //   return null;
      // }

      // Safety stock adaptif: jika buku punya safetyStock manual, gunakan itu.
      // Jika tidak, hitung otomatis berdasarkan stok awal.
      final int safetyStock;
      if (buku.safetyStock != null) {
        safetyStock = buku.safetyStock!;
      } else {
        // Default: 30% dari stok awal, minimal 1, maksimal 5
        final stokRef = buku.stokAwal ?? stokSebelumAktual;
        safetyStock = (stokRef * 0.3).ceil().clamp(1, 5);
      }
      final now = DateTime.now();

      // PERHITUNGAN FINAL (menggunakan data aktual dari Firestore)
      final stokAwal = stokSebelumAktual; // STOK AWAL (sebelum transaksi ini)
      final totalPeminjamanHariIni = jumlahDipinjam; // JUMLAH DIPINJAM KALI INI
      final stokAkhirHitung = stokAkhirAktual; // STOK AKHIR (aktual dari DB)

      print('  Buku: ${buku.judul}');
      print('  Stok Awal: $stokAwal');
      print('  Total Peminjaman Hari Ini: $totalPeminjamanHariIni');
      print('  Stok Akhir: $stokAkhirHitung');
      print('  Safety Stock: $safetyStock');

      // CEK KONDISI ARS: stok_akhir <= safety_stock?
      if (stokAkhirHitung <= safetyStock) {
        print(
          '  ✓✓✓ STOK KRITIS! (Stok Akhir $stokAkhirHitung <= Safety Stock $safetyStock)',
        );

        // Hitung jumlah pengadaan: berapa buku perlu diadakan agar stok kembali ke safety stock, minimal 1
        final jumlahPengadaan = (safetyStock - stokAkhirHitung).clamp(
          1,
          safetyStock,
        );

        final notification = ArsNotificationModel(
          bukuId: buku.id!,
          judulBuku: buku.judul,
          stokAwal: stokAwal,
          stokAkhir: stokAkhirHitung,
          totalPeminjaman: totalPeminjamanHariIni,
          safetyStock: safetyStock,
          jumlahPengadaan: jumlahPengadaan,
          status: 'unread',
          tanggalNotifikasi: now,
          detailPeminjaman: [
            {
              'tanggal': now.toIso8601String(),
              'jumlah': totalPeminjamanHariIni,
            },
          ],
        );

        // Simpan notifikasi
        await _firestore
            .collection(_notificationsCollection)
            .add(notification.toMap());
        print('  ✓ Notifikasi disimpan');

        // Push ke admin
        await NotificationService.showNotificationToAllAdmins(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'Rekomendasi Pengadaan Ulang Buku',
          body:
              '${buku.judul}: Stok awal $stokAwal, peminjaman hari ini $totalPeminjamanHariIni, sisa stok $stokAkhirHitung <= safety stock $safetyStock. Disarankan pesan $jumlahPengadaan buku.',
          type: 'ars',
          data: {
            'buku_id': buku.id,
            'judul_buku': buku.judul,
            'stok_awal': stokAwal,
            'stok_akhir': stokAkhirHitung,
            'safety_stock': safetyStock,
            'jumlah_pengadaan': jumlahPengadaan,
            'total_peminjaman_hari_ini': totalPeminjamanHariIni,
          },
        );

        return notification;
      } else {
        print(
          '  ✓ Stok masih aman (Stok Akhir $stokAkhirHitung > Safety Stock $safetyStock)',
        );
        return null;
      }
    } catch (e) {
      print('  ❌ ERROR: $e');
      rethrow;
    }
  }

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

  /// Force check all books (for compatibility/testing)
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

  /// Get all replenishment orders (for dashboard compatibility)
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

  /// Get books with low stock (stok <= safety_stock)
  Future<List<Map<String, dynamic>>> getLowStockBooks() async {
    try {
      final bukuList = await _firestoreService.getBuku();
      final lowStockBooks = <Map<String, dynamic>>[];

      for (final buku in bukuList) {
        if (!buku.isArsEnabled) continue;

        // Safety stock adaptif: manual jika diset, atau 30% dari stok awal
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
