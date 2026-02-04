import 'package:cloud_firestore/cloud_firestore.dart';

class PeminjamanModel {
  final String? id;
  final String namaPeminjam;
  final String? kelas;
  final String? uidSiswa; // UID siswa yang meminjam (untuk filter riwayat)
  final String judulBuku;
  final DateTime tanggalPinjam;
  final DateTime? tanggalKembali;
  final DateTime? tanggalJatuhTempo; // batas waktu pengembalian
  final String status; // 'dipinjam', 'dikembalikan'
  final String bukuId;
  final int jumlah;
  final String? denda; // Hukuman/denda jika terlambat
  final bool terlambatNotified; // Apakah notifikasi keterlambatan sudah dikirim

  PeminjamanModel({
    this.id,
    required this.namaPeminjam,
    this.kelas,
    this.uidSiswa,
    required this.judulBuku,
    required this.tanggalPinjam,
    this.tanggalKembali,
    this.tanggalJatuhTempo,
    required this.status,
    required this.bukuId,
    this.jumlah = 1,
    this.denda,
    this.terlambatNotified = false,
  });

  factory PeminjamanModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic v) {
      try {
        if (v == null) return DateTime.now();
        if (v is Timestamp) return v.toDate();
        if (v is DateTime) return v;
        if (v is String) return DateTime.parse(v);
      } catch (_) {}
      return DateTime.now();
    }

    int parseInt(dynamic v) {
      try {
        if (v == null) return 1;
        if (v is int) return v;
        if (v is double) return v.toInt();
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? 1;
      } catch (_) {}
      return 1;
    }

    // Prefer explicit tanggal_pinjam, fall back to created_at, then now
    final tanggalPinjamRaw = map['tanggal_pinjam'] ?? map['created_at'];
    final tanggalKembaliRaw = map['tanggal_kembali'];
    final tanggalJatuhTempoRaw = map['tanggal_jatuh_tempo'] ?? map['due_date'];

    return PeminjamanModel(
      id: id,
      namaPeminjam: map['nama_peminjam'] ?? (map['nama'] ?? ''),
      kelas: map['kelas'] ?? map['class'],
      uidSiswa: map['uid_siswa'] ?? map['uid'] as String?,
      judulBuku: map['judul_buku'] ?? (map['judul'] ?? ''),
      tanggalPinjam: parseDate(tanggalPinjamRaw),
      tanggalKembali:
          tanggalKembaliRaw != null ? parseDate(tanggalKembaliRaw) : null,
      tanggalJatuhTempo:
          tanggalJatuhTempoRaw != null ? parseDate(tanggalJatuhTempoRaw) : null,
      status: (map['status'] ?? 'pending').toString(),
      bukuId: map['buku_id'] ?? (map['book_id'] ?? ''),
      jumlah: parseInt(map['jumlah'] ?? map['qty'] ?? 1),
      denda: map['denda'] as String?,
      terlambatNotified: map['terlambat_notified'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nama_peminjam': namaPeminjam,
      'kelas': kelas,
      'uid_siswa': uidSiswa,
      'judul_buku': judulBuku,
      'tanggal_pinjam': Timestamp.fromDate(tanggalPinjam),
      'tanggal_kembali':
          tanggalKembali != null ? Timestamp.fromDate(tanggalKembali!) : null,
      'tanggal_jatuh_tempo':
          tanggalJatuhTempo != null
              ? Timestamp.fromDate(tanggalJatuhTempo!)
              : null,
      'status': status,
      'buku_id': bukuId,
      'jumlah': jumlah,
      'denda': denda,
      'terlambat_notified': terlambatNotified,
    };
  }

  PeminjamanModel copyWith({
    String? id,
    String? namaPeminjam,
    String? kelas,
    String? uidSiswa,
    String? judulBuku,
    DateTime? tanggalPinjam,
    DateTime? tanggalKembali,
    DateTime? tanggalJatuhTempo,
    String? status,
    String? bukuId,
    int? jumlah,
    String? denda,
    bool? terlambatNotified,
  }) {
    return PeminjamanModel(
      id: id ?? this.id,
      namaPeminjam: namaPeminjam ?? this.namaPeminjam,
      kelas: kelas ?? this.kelas,
      uidSiswa: uidSiswa ?? this.uidSiswa,
      judulBuku: judulBuku ?? this.judulBuku,
      tanggalPinjam: tanggalPinjam ?? this.tanggalPinjam,
      tanggalKembali: tanggalKembali ?? this.tanggalKembali,
      tanggalJatuhTempo: tanggalJatuhTempo ?? this.tanggalJatuhTempo,
      status: status ?? this.status,
      bukuId: bukuId ?? this.bukuId,
      jumlah: jumlah ?? this.jumlah,
      denda: denda ?? this.denda,
      terlambatNotified: terlambatNotified ?? this.terlambatNotified,
    );
  }
}
