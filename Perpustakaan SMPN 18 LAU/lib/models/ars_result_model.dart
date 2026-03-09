import 'dart:math';

/// Model hasil perhitungan Automatic Replenishment System (ARS)
/// per kategori buku.
///
/// Rumus:
/// - Rata-rata permintaan harian: D̅ = total_peminjaman / jumlah_hari
/// - Standar deviasi: σ = sqrt( Σ(Xi - D̅)² / n )
/// - Safety Stock: SS = Z × σ × sqrt(L)
/// - Reorder Point: ROP = (D̅ × L) + SS
/// - Stok saat ini: langsung dari DB (stok aktual yang tersedia)
/// - Jika stok saat ini ≤ ROP → notifikasi pengadaan ulang
///
/// Ketentuan:
/// - Lead time (L) = 3 hari
/// - Service level 95% → Z = 1.65
/// - Tidak ada pemesanan otomatis, hanya notifikasi rekomendasi
class ArsResultModel {
  /// Nama kategori buku
  final String kategori;

  /// Array jumlah peminjaman harian selama 7 hari
  final List<int> peminjamanHarian;

  /// Jumlah hari observasi (default 7)
  final int jumlahHari;

  /// Total stok saat ini dari DB
  final int stokAwal;

  /// Total peminjaman (sum peminjamanHarian)
  final int totalPeminjaman;

  /// Rata-rata permintaan harian (D̅)
  final double rataRataPermintaan;

  /// Standar deviasi (σ)
  final double standarDeviasi;

  /// Safety Stock (SS) = Z × σ × √L
  final double safetyStock;

  /// Reorder Point (ROP) = (D̅ × L) + SS
  final double reorderPoint;

  /// Stok akhir = stok saat ini dari DB (di perpustakaan buku dikembalikan,
  /// jadi stok akhir = stok saat ini saat pengecekan)
  final int stokAkhir;

  /// Status stok: 'Perlu Pengadaan Ulang' atau 'Stok Aman'
  final String statusStok;

  /// Lead time (hari)
  final int leadTime;

  /// Nilai Z (service level)
  final double nilaiZ;

  /// Jumlah buku dalam kategori ini
  final int jumlahBuku;

  const ArsResultModel({
    required this.kategori,
    required this.peminjamanHarian,
    required this.jumlahHari,
    required this.stokAwal,
    required this.totalPeminjaman,
    required this.rataRataPermintaan,
    required this.standarDeviasi,
    required this.safetyStock,
    required this.reorderPoint,
    required this.stokAkhir,
    required this.statusStok,
    required this.leadTime,
    required this.nilaiZ,
    required this.jumlahBuku,
  });

  /// Factory method untuk menghitung ARS dari data mentah.
  ///
  /// [kategori] - nama kategori buku
  /// [peminjamanHarian] - array jumlah peminjaman harian (7 hari)
  /// [stokAwal] - stok saat ini dari database (bukan stok awal periode)
  /// [leadTime] - lead time dalam hari (default 3)
  /// [nilaiZ] - nilai Z untuk service level (default 1.65 untuk 95%)
  /// [jumlahBuku] - jumlah buku dalam kategori
  factory ArsResultModel.calculate({
    required String kategori,
    required List<int> peminjamanHarian,
    required int stokAwal,
    int leadTime = 3,
    double nilaiZ = 1.65,
    int jumlahBuku = 0,
  }) {
    final int jumlahHari = peminjamanHarian.length;

    // 1. Total peminjaman
    final int totalPeminjaman = peminjamanHarian.fold(0, (sum, x) => sum + x);

    // 2. Rata-rata permintaan harian: D̅ = total_peminjaman / jumlah_hari
    final double dBar = jumlahHari > 0 ? totalPeminjaman / jumlahHari : 0.0;

    // 3. Standar deviasi: σ = sqrt( Σ(Xi - D̅)² / n )
    //    Menggunakan populasi σ (bukan sample), sesuai rumus di spesifikasi
    double sumSquaredDiff = 0.0;
    for (final xi in peminjamanHarian) {
      final diff = xi - dBar;
      sumSquaredDiff += diff * diff;
    }
    final double sigma =
        jumlahHari > 0 ? sqrt(sumSquaredDiff / jumlahHari) : 0.0;

    // 4. Safety Stock: SS = Z × σ × √L
    final double ss = nilaiZ * sigma * sqrt(leadTime.toDouble());

    // 5. Reorder Point: ROP = (D̅ × L) + SS
    final double rop = (dBar * leadTime) + ss;

    // 6. Stok akhir = stok saat ini dari DB.
    //    Di perpustakaan, buku dikembalikan sehingga stok naik kembali.
    //    Yang relevan adalah stok SAAT INI vs ROP.
    final int stokAkhir = stokAwal;

    // 7. Logika notifikasi: bandingkan stok saat ini dengan ROP
    final String statusStok =
        stokAkhir <= rop ? 'Perlu Pengadaan Ulang' : 'Stok Aman';

    return ArsResultModel(
      kategori: kategori,
      peminjamanHarian: peminjamanHarian,
      jumlahHari: jumlahHari,
      stokAwal: stokAwal,
      totalPeminjaman: totalPeminjaman,
      rataRataPermintaan: dBar,
      standarDeviasi: sigma,
      safetyStock: ss,
      reorderPoint: rop,
      stokAkhir: stokAkhir,
      statusStok: statusStok,
      leadTime: leadTime,
      nilaiZ: nilaiZ,
      jumlahBuku: jumlahBuku,
    );
  }

  /// Apakah stok perlu diisi ulang?
  bool get perluPengadaan => statusStok == 'Perlu Pengadaan Ulang';

  /// Konversi ke Map untuk disimpan ke Firestore
  Map<String, dynamic> toMap() {
    return {
      'kategori': kategori,
      'peminjaman_harian': peminjamanHarian,
      'jumlah_hari': jumlahHari,
      'stok_awal': stokAwal,
      'total_peminjaman': totalPeminjaman,
      'rata_rata_permintaan': rataRataPermintaan,
      'standar_deviasi': standarDeviasi,
      'safety_stock': safetyStock,
      'reorder_point': reorderPoint,
      'stok_akhir': stokAkhir,
      'status_stok': statusStok,
      'lead_time': leadTime,
      'nilai_z': nilaiZ,
      'jumlah_buku': jumlahBuku,
    };
  }

  factory ArsResultModel.fromMap(Map<String, dynamic> map) {
    return ArsResultModel(
      kategori: map['kategori'] ?? '',
      peminjamanHarian: List<int>.from(map['peminjaman_harian'] ?? []),
      jumlahHari: map['jumlah_hari'] ?? 7,
      stokAwal: map['stok_awal'] ?? 0,
      totalPeminjaman: map['total_peminjaman'] ?? 0,
      rataRataPermintaan: (map['rata_rata_permintaan'] ?? 0.0).toDouble(),
      standarDeviasi: (map['standar_deviasi'] ?? 0.0).toDouble(),
      safetyStock: (map['safety_stock'] ?? 0.0).toDouble(),
      reorderPoint: (map['reorder_point'] ?? 0.0).toDouble(),
      stokAkhir: map['stok_akhir'] ?? 0,
      statusStok: map['status_stok'] ?? 'Stok Aman',
      leadTime: map['lead_time'] ?? 3,
      nilaiZ: (map['nilai_z'] ?? 1.65).toDouble(),
      jumlahBuku: map['jumlah_buku'] ?? 0,
    );
  }

  @override
  String toString() {
    return '''
ARS Result [$kategori]
  Peminjaman Harian (7 hari): $peminjamanHarian
  Total Peminjaman: $totalPeminjaman
  Stok Awal: $stokAwal
  Rata-rata Permintaan (D̅): ${rataRataPermintaan.toStringAsFixed(4)}
  Standar Deviasi (σ): ${standarDeviasi.toStringAsFixed(4)}
  Safety Stock (SS): ${safetyStock.toStringAsFixed(4)}
  Reorder Point (ROP): ${reorderPoint.toStringAsFixed(4)}
  Stok Akhir: $stokAkhir
  Status: $statusStok
''';
  }
}
