import 'package:cloud_firestore/cloud_firestore.dart';

/// Model notifikasi umum untuk sistem perpustakaan
/// Menggabungkan semua jenis notifikasi dalam satu tempat
class NotificationModel {
  final String? id;
  final String userId; // User yang menerima notifikasi
  final String title; // Judul notifikasi
  final String body; // Isi notifikasi
  final String
  type; // 'peminjaman', 'pengembalian', 'ars', 'keterlambatan', 'approval', 'info'
  final String status; // 'unread', 'read'
  final DateTime timestamp;
  final Map<String, dynamic>? data; // Data tambahan (optional)

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.status = 'unread',
    required this.timestamp,
    this.data,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'info',
      status: map['status'] ?? 'unread',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  // Helper untuk mendapatkan icon berdasarkan tipe
  String getIconData() {
    switch (type) {
      case 'peminjaman':
        return '📚';
      case 'pengembalian':
        return '✅';
      case 'ars':
        return '⚠️';
      case 'keterlambatan':
        return '⏰';
      case 'approval':
        return '👤';
      case 'info':
      default:
        return '📢';
    }
  }

  // Helper untuk mendapatkan warna berdasarkan tipe
  String getColorHex() {
    switch (type) {
      case 'peminjaman':
        return '0xFF1976D2'; // Blue
      case 'pengembalian':
        return '0xFF388E3C'; // Green
      case 'ars':
        return '0xFFF57C00'; // Orange
      case 'keterlambatan':
        return '0xFFD32F2F'; // Red
      case 'approval':
        return '0xFF7B1FA2'; // Purple
      case 'info':
      default:
        return '0xFF455A64'; // Blue Grey
    }
  }
}
