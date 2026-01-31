class BukuModel {
  final String? id;
  final String judul;
  final String pengarang;
  final int stok;
  final int? stokMinimum; // batas minimum stok untuk trigger ARS
  final int? stokAwal; // target stok awal saat reset
  final String kategori;
  final int tahun;
  final int? tahunPembelian; // tahun pembelian
  final double? hargaSatuan; // harga satuan buku
  final double? totalHarga; // hargaSatuan * stok
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

  BukuModel({
    this.id,
    required this.judul,
    required this.pengarang,
    required this.stok,
    this.stokMinimum,
    this.stokAwal,
    required this.kategori,
    required this.tahun,
    this.tahunPembelian,
    this.hargaSatuan,
    this.totalHarga,
    this.coverUrl,
    this.coverPublicId,
    this.bookFileUrl,
    this.totalPeminjaman = 0,
    this.deskripsi,
    this.isArsEnabled = false,
    this.safetyStock,
    this.arsNotified = false,
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
      tahunPembelian: map['tahun_pembelian'],
      hargaSatuan:
          map['harga_satuan'] != null
              ? (map['harga_satuan'] as num).toDouble()
              : null,
      totalHarga:
          map['total_harga'] != null
              ? (map['total_harga'] as num).toDouble()
              : null,
      coverUrl: map['cover_url'],
      coverPublicId: map['cover_public_id'],
      bookFileUrl: map['book_file_url'],
      totalPeminjaman: map['total_peminjaman'] ?? 0,
      deskripsi: map['deskripsi'],
      isArsEnabled: map['is_ars_enabled'] ?? false,
      safetyStock: map['safety_stock'],
      arsNotified: map['ars_notified'] ?? false,
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
      'tahun_pembelian': tahunPembelian,
      'harga_satuan': hargaSatuan,
      'total_harga': totalHarga,
      'cover_url': coverUrl,
      'cover_public_id': coverPublicId,
      'book_file_url': bookFileUrl,
      'total_peminjaman': totalPeminjaman,
      'deskripsi': deskripsi,
      'is_ars_enabled': isArsEnabled,
      'safety_stock': safetyStock,
      'ars_notified': arsNotified,
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
    int? tahunPembelian,
    double? hargaSatuan,
    double? totalHarga,
    String? coverUrl,
    String? coverPublicId,
    String? bookFileUrl,
    int? totalPeminjaman,
    String? deskripsi,
    bool? isArsEnabled,
    int? safetyStock,
    bool? arsNotified,
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
      tahunPembelian: tahunPembelian ?? this.tahunPembelian,
      hargaSatuan: hargaSatuan ?? this.hargaSatuan,
      totalHarga: totalHarga ?? this.totalHarga,
      coverUrl: coverUrl ?? this.coverUrl,
      coverPublicId: coverPublicId ?? this.coverPublicId,
      bookFileUrl: bookFileUrl ?? this.bookFileUrl,
      totalPeminjaman: totalPeminjaman ?? this.totalPeminjaman,
      deskripsi: deskripsi ?? this.deskripsi,
      isArsEnabled: isArsEnabled ?? this.isArsEnabled,
      safetyStock: safetyStock ?? this.safetyStock,
      arsNotified: arsNotified ?? this.arsNotified,
    );
  }
}
