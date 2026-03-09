import 'package:cloud_firestore/cloud_firestore.dart';

class ArsNotificationModel {
  final String? id;
  final String bukuId; // kosong jika notifikasi per-kategori
  final String judulBuku; // nama kategori jika notifikasi per-kategori
  final int stokAwal;
  final int stokAkhir;
  final int totalPeminjaman;
  final int safetyStock; // legacy — dipertahankan agar data lama tetap terbaca
  final int jumlahPengadaan;
  final String status; // 'unread', 'read'
  final DateTime tanggalNotifikasi;
  final List<Map<String, dynamic>>
  detailPeminjaman; // [{tanggal: '...', jumlah: 5}, ...]

  // ── Field baru untuk perhitungan ARS statistik ──
  final String? kategori; // nama kategori (null = data lama)
  final List<int>? peminjamanHarian; // array peminjaman 7 hari
  final double? rataRataPermintaan; // D̅
  final double? standarDeviasi; // σ
  final double? safetyStockCalc; // SS (double, hasil rumus)
  final double? reorderPoint; // ROP
  final String? statusStok; // 'Perlu Pengadaan Ulang' / 'Stok Aman'
  final int? leadTime; // L (hari)
  final double? nilaiZ; // Z

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
    this.kategori,
    this.peminjamanHarian,
    this.rataRataPermintaan,
    this.standarDeviasi,
    this.safetyStockCalc,
    this.reorderPoint,
    this.statusStok,
    this.leadTime,
    this.nilaiZ,
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
      // Field ARS statistik
      'kategori': kategori,
      'peminjaman_harian': peminjamanHarian,
      'rata_rata_permintaan': rataRataPermintaan,
      'standar_deviasi': standarDeviasi,
      'safety_stock_calc': safetyStockCalc,
      'reorder_point': reorderPoint,
      'status_stok': statusStok,
      'lead_time': leadTime,
      'nilai_z': nilaiZ,
    };
  }

  factory ArsNotificationModel.fromMap(Map<String, dynamic> map, String id) {
    // Baca tanggal_notifikasi dengan aman (Timestamp, DateTime, atau null)
    DateTime tanggal;
    final raw = map['tanggal_notifikasi'];
    if (raw is Timestamp) {
      tanggal = raw.toDate();
    } else if (raw is DateTime) {
      tanggal = raw;
    } else {
      tanggal = DateTime.now();
    }

    return ArsNotificationModel(
      id: id,
      bukuId: map['buku_id'] ?? '',
      judulBuku: map['judul_buku'] ?? '',
      stokAwal: map['stok_awal'] ?? 0,
      stokAkhir: map['stok_akhir'] ?? 0,
      totalPeminjaman: map['total_peminjaman'] ?? 0,
      safetyStock:
          (map['safety_stock'] ?? 5) is int
              ? map['safety_stock'] ?? 5
              : (map['safety_stock'] as num).toInt(),
      jumlahPengadaan: map['jumlah_pengadaan'] ?? 0,
      status: map['status'] ?? 'unread',
      tanggalNotifikasi: tanggal,
      detailPeminjaman: List<Map<String, dynamic>>.from(
        map['detail_peminjaman'] ?? [],
      ),
      // Field ARS statistik (nullable, backward-compatible)
      kategori: map['kategori'] as String?,
      peminjamanHarian:
          map['peminjaman_harian'] != null
              ? List<int>.from(
                (map['peminjaman_harian'] as List).map(
                  (e) => (e as num).toInt(),
                ),
              )
              : null,
      rataRataPermintaan:
          map['rata_rata_permintaan'] != null
              ? (map['rata_rata_permintaan'] as num).toDouble()
              : null,
      standarDeviasi:
          map['standar_deviasi'] != null
              ? (map['standar_deviasi'] as num).toDouble()
              : null,
      safetyStockCalc:
          map['safety_stock_calc'] != null
              ? (map['safety_stock_calc'] as num).toDouble()
              : null,
      reorderPoint:
          map['reorder_point'] != null
              ? (map['reorder_point'] as num).toDouble()
              : null,
      statusStok: map['status_stok'] as String?,
      leadTime:
          map['lead_time'] != null ? (map['lead_time'] as num).toInt() : null,
      nilaiZ:
          map['nilai_z'] != null ? (map['nilai_z'] as num).toDouble() : null,
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
      kategori: kategori,
      peminjamanHarian: peminjamanHarian,
      rataRataPermintaan: rataRataPermintaan,
      standarDeviasi: standarDeviasi,
      safetyStockCalc: safetyStockCalc,
      reorderPoint: reorderPoint,
      statusStok: statusStok,
      leadTime: leadTime,
      nilaiZ: nilaiZ,
    );
  }
}
