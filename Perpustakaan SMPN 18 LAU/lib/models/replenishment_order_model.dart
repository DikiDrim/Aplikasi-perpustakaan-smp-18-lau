import 'package:cloud_firestore/cloud_firestore.dart';

class ReplenishmentOrderModel {
  final String? id;
  final String bukuId;
  final String judulBuku;
  final int quantity; // jumlah yang dipesan
  final DateTime tanggalPesan;
  final DateTime? tanggalDiterima;
  final String status; // 'pending', 'diproses', 'diterima', 'dibatalkan'
  final String? catatan;
  final double? totalHarga;
  final bool isAutomatic; // apakah order dibuat otomatis oleh ARS
  final int? stokSaatPesan; // stok saat order dibuat

  ReplenishmentOrderModel({
    this.id,
    required this.bukuId,
    required this.judulBuku,
    required this.quantity,
    required this.tanggalPesan,
    this.tanggalDiterima,
    this.status = 'pending',
    this.catatan,
    this.totalHarga,
    this.isAutomatic = false,
    this.stokSaatPesan,
  });

  factory ReplenishmentOrderModel.fromMap(Map<String, dynamic> map, String id) {
    return ReplenishmentOrderModel(
      id: id,
      bukuId: map['buku_id'] ?? '',
      judulBuku: map['judul_buku'] ?? '',
      quantity: map['quantity'] ?? 0,
      tanggalPesan: (map['tanggal_pesan'] as Timestamp).toDate(),
      tanggalDiterima:
          map['tanggal_diterima'] != null
              ? (map['tanggal_diterima'] as Timestamp).toDate()
              : null,
      status: map['status'] ?? 'pending',
      catatan: map['catatan'],
      totalHarga:
          map['total_harga'] != null
              ? (map['total_harga'] as num).toDouble()
              : null,
      isAutomatic: map['is_automatic'] ?? false,
      stokSaatPesan: map['stok_saat_pesan'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'buku_id': bukuId,
      'judul_buku': judulBuku,
      'quantity': quantity,
      'tanggal_pesan': Timestamp.fromDate(tanggalPesan),
      'tanggal_diterima':
          tanggalDiterima != null ? Timestamp.fromDate(tanggalDiterima!) : null,
      'status': status,
      'catatan': catatan,
      'total_harga': totalHarga,
      'is_automatic': isAutomatic,
      'stok_saat_pesan': stokSaatPesan,
    };
  }

  ReplenishmentOrderModel copyWith({
    String? id,
    String? bukuId,
    String? judulBuku,
    int? quantity,
    DateTime? tanggalPesan,
    DateTime? tanggalDiterima,
    String? status,
    String? catatan,
    double? totalHarga,
    bool? isAutomatic,
    int? stokSaatPesan,
  }) {
    return ReplenishmentOrderModel(
      id: id ?? this.id,
      bukuId: bukuId ?? this.bukuId,
      judulBuku: judulBuku ?? this.judulBuku,
      quantity: quantity ?? this.quantity,
      tanggalPesan: tanggalPesan ?? this.tanggalPesan,
      tanggalDiterima: tanggalDiterima ?? this.tanggalDiterima,
      status: status ?? this.status,
      catatan: catatan ?? this.catatan,
      totalHarga: totalHarga ?? this.totalHarga,
      isAutomatic: isAutomatic ?? this.isAutomatic,
      stokSaatPesan: stokSaatPesan ?? this.stokSaatPesan,
    );
  }
}
