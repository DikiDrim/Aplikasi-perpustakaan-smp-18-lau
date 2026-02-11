import 'package:cloud_firestore/cloud_firestore.dart';

class BukuModel {
  final String? id;
  final String judul;
  final String pengarang;
  final int stok;
  final int? stokMinimum; // batas minimum stok untuk trigger ARS
  final int? stokAwal; // target stok awal saat reset
  final String kategori;
  final int tahun;
  final String? isbn; // ISBN buku
  final String? coverUrl; // url gambar sampul
  final String? coverPublicId; // cloudinary public id
  final String? bookFileUrl; // url file buku digital (PDF/EPUB) di Cloudinary
  final int totalPeminjaman;
  final String? deskripsi; // deskripsi singkat buku

  // ARS (Automatic Replenishment System) Parameters
  final bool isArsEnabled; // apakah ARS aktif untuk buku ini
  final int? safetyStock; // stok aman (buffer stock)
  final bool
  arsNotified; // flag: apakah notifikasi ARS sudah dikirim untuk stok <= safetyStock

  // Status kondisi buku: 'Tersedia', 'Rusak', 'Hilang'
  final String statusKondisi;
  // Jumlah eksemplar yang rusak
  final int jumlahRusak;
  // Jumlah eksemplar yang hilang
  final int jumlahHilang;
  // Catatan terkait kerusakan/kehilangan
  final String? catatanKondisi;
  // Tanggal perubahan status kondisi
  final DateTime? tanggalStatusKondisi;

  /// Jumlah rusak efektif — backward-compatible dengan data lama
  /// yang hanya punya status_kondisi tanpa jumlah_rusak.
  int get effectiveJumlahRusak {
    if (jumlahRusak > 0) return jumlahRusak;
    if (statusKondisi == 'Rusak') return 1; // data lama, minimal 1
    return 0;
  }

  /// Jumlah hilang efektif — backward-compatible dengan data lama
  int get effectiveJumlahHilang {
    if (jumlahHilang > 0) return jumlahHilang;
    if (statusKondisi == 'Hilang') return 1; // data lama, minimal 1
    return 0;
  }

  BukuModel({
    this.id,
    required this.judul,
    required this.pengarang,
    required this.stok,
    this.stokMinimum,
    this.stokAwal,
    required this.kategori,
    required this.tahun,
    this.isbn,
    this.coverUrl,
    this.coverPublicId,
    this.bookFileUrl,
    this.totalPeminjaman = 0,
    this.deskripsi,
    this.isArsEnabled = true,
    this.safetyStock,
    this.arsNotified = false,
    this.statusKondisi = 'Tersedia',
    this.jumlahRusak = 0,
    this.jumlahHilang = 0,
    this.catatanKondisi,
    this.tanggalStatusKondisi,
  });

  factory BukuModel.fromMap(Map<String, dynamic> map, String id) {
    return BukuModel(
      id: id,
      judul: map['judul'] ?? '',
      pengarang: map['pengarang'] ?? '',
      stok: map['stok'] ?? 0,
      stokMinimum: map['stok_minimum'],
      stokAwal: map['stok_awal'],
      kategori: map['kategori'] ?? '',
      tahun: map['tahun'] ?? 0,
      isbn: map['isbn'],
      coverUrl: map['cover_url'],
      coverPublicId: map['cover_public_id'],
      bookFileUrl: map['book_file_url'],
      totalPeminjaman: map['total_peminjaman'] ?? 0,
      deskripsi: map['deskripsi'],
      isArsEnabled: map['is_ars_enabled'] ?? true,
      safetyStock: map['safety_stock'],
      arsNotified: map['ars_notified'] ?? false,
      statusKondisi: map['status_kondisi'] ?? 'Tersedia',
      jumlahRusak: map['jumlah_rusak'] ?? 0,
      jumlahHilang: map['jumlah_hilang'] ?? 0,
      catatanKondisi: map['catatan_kondisi'],
      tanggalStatusKondisi:
          map['tanggal_status_kondisi'] != null
              ? (map['tanggal_status_kondisi'] is Timestamp
                  ? (map['tanggal_status_kondisi'] as Timestamp).toDate()
                  : DateTime.tryParse(map['tanggal_status_kondisi'].toString()))
              : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'judul': judul,
      'pengarang': pengarang,
      'stok': stok,
      'stok_minimum': stokMinimum,
      'stok_awal': stokAwal,
      'kategori': kategori,
      'tahun': tahun,
      'isbn': isbn,
      'cover_url': coverUrl,
      'cover_public_id': coverPublicId,
      'book_file_url': bookFileUrl,
      'total_peminjaman': totalPeminjaman,
      'deskripsi': deskripsi,
      'is_ars_enabled': isArsEnabled,
      'safety_stock': safetyStock,
      'ars_notified': arsNotified,
      'status_kondisi': statusKondisi,
      'jumlah_rusak': jumlahRusak,
      'jumlah_hilang': jumlahHilang,
      'catatan_kondisi': catatanKondisi,
      'tanggal_status_kondisi':
          tanggalStatusKondisi != null
              ? Timestamp.fromDate(tanggalStatusKondisi!)
              : null,
    };
  }

  BukuModel copyWith({
    String? id,
    String? judul,
    String? pengarang,
    int? stok,
    int? stokMinimum,
    int? stokAwal,
    String? kategori,
    int? tahun,
    String? isbn,
    String? coverUrl,
    String? coverPublicId,
    String? bookFileUrl,
    int? totalPeminjaman,
    String? deskripsi,
    bool? isArsEnabled,
    int? safetyStock,
    bool? arsNotified,
    String? statusKondisi,
    int? jumlahRusak,
    int? jumlahHilang,
    String? catatanKondisi,
    DateTime? tanggalStatusKondisi,
  }) {
    return BukuModel(
      id: id ?? this.id,
      judul: judul ?? this.judul,
      pengarang: pengarang ?? this.pengarang,
      stok: stok ?? this.stok,
      stokMinimum: stokMinimum ?? this.stokMinimum,
      stokAwal: stokAwal ?? this.stokAwal,
      kategori: kategori ?? this.kategori,
      tahun: tahun ?? this.tahun,
      isbn: isbn ?? this.isbn,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPublicId: coverPublicId ?? this.coverPublicId,
      bookFileUrl: bookFileUrl ?? this.bookFileUrl,
      totalPeminjaman: totalPeminjaman ?? this.totalPeminjaman,
      deskripsi: deskripsi ?? this.deskripsi,
      isArsEnabled: isArsEnabled ?? this.isArsEnabled,
      safetyStock: safetyStock ?? this.safetyStock,
      arsNotified: arsNotified ?? this.arsNotified,
      statusKondisi: statusKondisi ?? this.statusKondisi,
      jumlahRusak: jumlahRusak ?? this.jumlahRusak,
      jumlahHilang: jumlahHilang ?? this.jumlahHilang,
      catatanKondisi: catatanKondisi ?? this.catatanKondisi,
      tanggalStatusKondisi: tanggalStatusKondisi ?? this.tanggalStatusKondisi,
    );
  }
}
