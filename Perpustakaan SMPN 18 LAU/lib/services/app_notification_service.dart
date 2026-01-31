import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';

/// Service untuk mengelola notifikasi aplikasi
/// Mengganti pop-up notification dengan sistem inbox
class AppNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'notifications';

  /// Membuat notifikasi baru untuk user
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = NotificationModel(
        userId: userId,
        title: title,
        body: body,
        type: type,
        timestamp: DateTime.now(),
        data: data,
      );

      await _firestore.collection(_collection).add(notification.toMap());
    } catch (e) {
      throw Exception('Gagal membuat notifikasi: $e');
    }
  }

  /// Membuat notifikasi untuk semua admin
  Future<void> createNotificationForAllAdmins({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Ambil semua admin
      final adminsSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'admin')
              .get();

      // Buat notifikasi untuk setiap admin
      final batch = _firestore.batch();
      for (final doc in adminsSnapshot.docs) {
        final notification = NotificationModel(
          userId: doc.id,
          title: title,
          body: body,
          type: type,
          timestamp: DateTime.now(),
          data: data,
        );

        final notificationRef = _firestore.collection(_collection).doc();
        batch.set(notificationRef, notification.toMap());
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Gagal membuat notifikasi untuk admin: $e');
    }
  }

  /// Stream notifikasi untuk user tertentu (default current user)
  Stream<List<NotificationModel>> getNotificationsStream({String? userId}) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: uid)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs
                  .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
                  .toList();
          // Sort client-side to avoid composite index requirement
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Stream notifikasi yang belum dibaca
  Stream<List<NotificationModel>> getUnreadNotificationsStream({
    String? userId,
  }) {
    final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(_collection)
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list =
              snapshot.docs
                  .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
                  .where((n) => n.status == 'unread')
                  .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  /// Menandai notifikasi sebagai sudah dibaca
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).update({
        'status': 'read',
      });
    } catch (e) {
      throw Exception('Gagal menandai notifikasi: $e');
    }
  }

  /// Menandai semua notifikasi user sebagai sudah dibaca
  Future<void> markAllAsRead({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot =
          await _firestore
              .collection(_collection)
              .where('user_id', isEqualTo: uid)
              .where('status', isEqualTo: 'unread')
              .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Gagal menandai semua notifikasi: $e');
    }
  }

  /// Menghapus notifikasi
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collection).doc(notificationId).delete();
    } catch (e) {
      throw Exception('Gagal menghapus notifikasi: $e');
    }
  }

  /// Menghapus semua notifikasi user
  Future<void> deleteAllNotifications({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot =
          await _firestore
              .collection(_collection)
              .where('user_id', isEqualTo: uid)
              .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Gagal menghapus semua notifikasi: $e');
    }
  }

  /// Mendapatkan jumlah notifikasi yang belum dibaca
  Future<int> getUnreadCount({String? userId}) async {
    try {
      final uid = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;

      final snapshot =
          await _firestore
              .collection(_collection)
              .where('user_id', isEqualTo: uid)
              .where('status', isEqualTo: 'unread')
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
