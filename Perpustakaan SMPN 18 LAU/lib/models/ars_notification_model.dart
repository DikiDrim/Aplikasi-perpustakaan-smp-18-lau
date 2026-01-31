import 'package:cloud_firestore/cloud_firestore.dart';

class ArsNotificationModel {
  final String? id;
  final String bukuId;
  final String judulBuku;
  final int stokAwal;
  final int stokAkhir;
  final int totalPeminjaman;
  final int safetyStock;
  final int jumlahPengadaan;
  final String status; // 'unread', 'read'
  final DateTime tanggalNotifikasi;
  final List<Map<String, dynamic>>
  detailPeminjaman; // [{jam: '08:00', jumlah: 12}, ...]

  ArsNotificationModel({
    this.id,
    required this.bukuId,
    required this.judulBuku,
    required this.stokAwal,
    required this.stokAkhir,
    required this.totalPeminjaman,
    required this.safetyStock,
    required this.jumlahPengadaan,
    this.status = 'unread',
    required this.tanggalNotifikasi,
    this.detailPeminjaman = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'buku_id': bukuId,
      'judul_buku': judulBuku,
      'stok_awal': stokAwal,
      'stok_akhir': stokAkhir,
      'total_peminjaman': totalPeminjaman,
      'safety_stock': safetyStock,
      'jumlah_pengadaan': jumlahPengadaan,
      'status': status,
      'tanggal_notifikasi': Timestamp.fromDate(tanggalNotifikasi),
      'detail_peminjaman': detailPeminjaman,
    };
  }

  factory ArsNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return ArsNotificationModel(
      id: id,
      bukuId: map['buku_id'] ?? '',
      judulBuku: map['judul_buku'] ?? '',
      stokAwal: map['stok_awal'] ?? 0,
      stokAkhir: map['stok_akhir'] ?? 0,
      totalPeminjaman: map['total_peminjaman'] ?? 0,
      safetyStock: map['safety_stock'] ?? 5,
      jumlahPengadaan: map['jumlah_pengadaan'] ?? 0,
      status: map['status'] ?? 'unread',
      tanggalNotifikasi: (map['tanggal_notifikasi'] as Timestamp).toDate(),
      detailPeminjaman: List<Map<String, dynamic>>.from(
        map['detail_peminjaman'] ?? [],
      ),
    );
  }

  ArsNotificationModel copyWith({String? status}) {
    return ArsNotificationModel(
      id: id,
      bukuId: bukuId,
      judulBuku: judulBuku,
      stokAwal: stokAwal,
      stokAkhir: stokAkhir,
      totalPeminjaman: totalPeminjaman,
      safetyStock: safetyStock,
      jumlahPengadaan: jumlahPengadaan,
      status: status ?? this.status,
      tanggalNotifikasi: tanggalNotifikasi,
      detailPeminjaman: detailPeminjaman,
    );
  }
}
