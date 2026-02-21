import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../models/buku_model.dart';
import 'clodinary_service.dart';
import '../configs/claudinary_api_config.dart';
import '../models/peminjaman_model.dart';
import 'auth_service.dart';
import 'app_notification_service.dart';
import 'ars_service_impl.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'books';
  final String _peminjamanCollection = 'peminjaman';
  final String _categoryCollection = 'categories';

  // ============================================================================
  // PERMISSION & AUTHORIZATION
  // ============================================================================

  Future<void> _checkAdminPermission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User tidak terautentikasi');
    }

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final role = userDoc.data()?['role'];

    if (role != 'admin') {
      throw Exception(
        'Akses ditolak: Hanya admin yang dapat melakukan operasi ini',
      );
    }
  }

  // ============================================================================
  // BOOK MANAGEMENT (CRUD)
  // ============================================================================

  /// Migrasi: Set is_ars_enabled = true untuk SEMUA buku yang masih false/null.
  /// Panggil sekali saat app start untuk fix data lama.
  Future<void> migrateArsEnabledForAllBooks() async {
    try {
      final snapshot = await _firestore.collection(_collection).get();
      final batch = _firestore.batch();
      int count = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final isArs = data['is_ars_enabled'];
        if (isArs == null || isArs == false) {
          batch.update(doc.reference, {'is_ars_enabled': true});
          count++;
        }
      }
      if (count > 0) {
        await batch.commit();
        print('[MIGRASI] $count buku di-update: is_ars_enabled → true');
      } else {
        print('[MIGRASI] Semua buku sudah is_ars_enabled = true');
      }
    } catch (e) {
      print('[MIGRASI ERROR] $e');
    }
  }

  Future<String> addBuku(BukuModel buku) async {
    try {
      // Cek permission: hanya admin yang bisa menambah buku
      await _checkAdminPermission();

      final data = Map<String, dynamic>.from(buku.toMap());
      // Ensure ARS is enabled by default for newly added books
      data['is_ars_enabled'] = true;
      final docRef = await _firestore.collection(_collection).add(data);
      return docRef.id;
    } catch (e, st) {
      // Print for debugging in console and include a readable message
      print('approvePeminjaman error (raw): $e');
      print(st);

      // Try to extract wrapped error/stack if present (some Firebase errors are boxed)
      String extracted = '';
      try {
        final dyn = e as dynamic;
        if (dyn.error != null) {
          extracted += 'boxed_error: ${dyn.error}\n';
        }
        if (dyn.stack != null) {
          extracted += 'boxed_stack: ${dyn.stack}\n';
        }
      } catch (_) {
        // ignore
      }

      String msg;
      try {
        if (e is FirebaseException) {
          msg = '${e.code}: ${e.message}';
        } else if (extracted.isNotEmpty) {
          msg = '${e.toString()}\n$extracted';
        } else {
          msg = e.toString();
        }
      } catch (_) {
        msg = e.toString();
      }

      throw Exception('Gagal menyetujui peminjaman: $msg');
    }
  }

  // Mengambil buku berdasarkan ID
  Future<BukuModel?> getBukuById(String id) async {
    try {
      final DocumentSnapshot doc =
          await _firestore.collection(_collection).doc(id).get();
      if (doc.exists) {
        return BukuModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Gagal mengambil buku: $e');
    }
  }

  // Mengupdate buku
  Future<void> updateBuku(String id, BukuModel buku) async {
    try {
      // Cek permission: hanya admin yang bisa update buku
      await _checkAdminPermission();

      final data = buku.toMap();
      // Jangan overwrite ARS fields jika tidak di-set secara eksplisit.
      // Baca nilai ARS saat ini dari Firestore dan pertahankan.
      final currentDoc = await _firestore.collection(_collection).doc(id).get();
      if (currentDoc.exists) {
        final currentData = currentDoc.data() as Map<String, dynamic>;
        // Pertahankan field ARS dari dokumen saat ini jika belum di-set di model
        data['is_ars_enabled'] = currentData['is_ars_enabled'] ?? true;
        if (currentData.containsKey('safety_stock') &&
            data['safety_stock'] == null) {
          data['safety_stock'] = currentData['safety_stock'];
        }
        if (currentData.containsKey('stok_minimum') &&
            data['stok_minimum'] == null) {
          data['stok_minimum'] = currentData['stok_minimum'];
        }
        if (currentData.containsKey('stok_awal') && data['stok_awal'] == null) {
          data['stok_awal'] = currentData['stok_awal'];
        }
        if (currentData.containsKey('ars_notified')) {
          data['ars_notified'] = currentData['ars_notified'];
        }
      }

      await _firestore.collection(_collection).doc(id).update(data);
    } catch (e) {
      throw Exception('Gagal mengupdate buku: $e');
    }
  }

  Future<void> deleteBuku(String id) async {
    try {
      // Cek permission: hanya admin yang bisa hapus buku
      await _checkAdminPermission();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Try callable function first
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'deleteBookCallable',
        );
        final result = await callable.call(<String, dynamic>{'bookId': id});
        final resData = result.data;
        if (resData == true || (resData is Map && resData['success'] == true)) {
          return; // backend handled deletion
        }
        // If payload unexpected, we'll fallback
      } catch (e) {
        // Callable failed (not deployed or error)
        print('Callable delete failed: $e');

        // If client-side deletion is explicitly allowed via env, perform fallback.
        if (ClaudinaryApiConfig.allowClientDelete) {
          print(
            'ALLOW_CLIENT_DELETE=true → performing client-side Cloudinary delete (unsafe)',
          );
          // Fallback client-side deletion
          final docRef = _firestore.collection(_collection).doc(id);
          final doc = await docRef.get();
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            final publicId = data['cover_public_id'];
            if (publicId != null && publicId is String && publicId.isNotEmpty) {
              try {
                final cl = ClodinaryService();
                final ok = await cl.deleteImageByPublicId(publicId);
                if (!ok)
                  print(
                    'Warning: cloudinary delete returned false for publicId=$publicId',
                  );
              } catch (e) {
                print('Gagal menghapus gambar Cloudinary (fallback): $e');
              }
            }
          }
          await docRef.delete();
          return;
        }

        // Otherwise, do NOT perform client-side deletion. Surface a clear error.
        throw Exception(
          'Backend delete function is not available and client-side delete is disabled.\n'
          'Please deploy the Firebase Function `deleteBookCallable` or set ALLOW_CLIENT_DELETE=true in your .env to enable the insecure fallback (not recommended).',
        );
      }
    } catch (e) {
      throw Exception('Gagal menghapus buku: $e');
    }
  }

  /// Hapus hanya cover (gambar) yang terkait dengan buku di Cloudinary
  /// dan bersihkan field coverUrl / cover_public_id di dokumen Firestore.
  Future<bool> deleteCover(String bukuId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(bukuId);
      final doc = await docRef.get();
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      final publicId = data['cover_public_id'] as String?;
      if (publicId == null || publicId.isEmpty) return false;

      final cl = ClodinaryService();
      final ok = await cl.deleteImageByPublicId(publicId);
      if (ok) {
        await docRef.update({
          'coverUrl': FieldValue.delete(),
          'cover_public_id': FieldValue.delete(),
        });
      }
      return ok;
    } catch (e) {
      print('deleteCover error: $e');
      return false;
    }
  }

  Future<void> deleteBukuDocument(String id) async {
    try {
      await _checkAdminPermission();

      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      throw Exception('Gagal menghapus dokumen buku: $e');
    }
  }

  Future<List<BukuModel>> searchBuku(String query) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection(_collection)
              .where('judul', isGreaterThanOrEqualTo: query)
              .where('judul', isLessThan: query + 'z')
              .get();

      return snapshot.docs.map((doc) {
        return BukuModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Gagal mencari buku: $e');
    }
  }

  // Cache untuk getBuku - reduce frequent queries
  List<BukuModel>? _bukuCache;
  DateTime? _bukuCacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  Future<List<BukuModel>> getBuku({bool forceRefresh = false}) async {
    try {
      // Return cache jika masih valid dan tidak force refresh
      if (!forceRefresh && _bukuCache != null && _bukuCacheTime != null) {
        final elapsed = DateTime.now().difference(_bukuCacheTime!);
        if (elapsed < _cacheDuration) {
          return _bukuCache!;
        }
      }

      final QuerySnapshot snapshot =
          await _firestore.collection(_collection).orderBy('judul').get();

      final bukuList =
          snapshot.docs.map((doc) {
            return BukuModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }).toList();

      // Update cache
      _bukuCache = bukuList;
      _bukuCacheTime = DateTime.now();

      return bukuList;
    } catch (e) {
      throw Exception('Gagal mengambil data buku: $e');
    }
  }

  Stream<List<BukuModel>> getBukuStream() {
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BukuModel.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // ============================================================================
  // LOAN MANAGEMENT (Peminjaman & Booking)
  // ============================================================================

  Stream<List<PeminjamanModel>> getActiveLoansStreamForUser(String uidSiswa) {
    return _firestore
        .collection(_peminjamanCollection)
        .where('uid_siswa', isEqualTo: uidSiswa)
        .snapshots()
        .map((snapshot) {
          final loans =
              snapshot.docs
                  .map((d) => PeminjamanModel.fromMap(d.data(), d.id))
                  .where((p) => p.status == 'dipinjam')
                  .toList();
          loans.sort((a, b) {
            final ad = a.tanggalJatuhTempo ?? DateTime(2100);
            final bd = b.tanggalJatuhTempo ?? DateTime(2100);
            return ad.compareTo(bd); // ascending by due date
          });
          return loans;
        });
  }

  Future<void> _assertStokCukup(PeminjamanModel peminjaman) async {
    final bukuSnap =
        await _firestore.collection(_collection).doc(peminjaman.bukuId).get();
    if (!bukuSnap.exists) {
      throw Exception('Buku tidak ditemukan');
    }

    final data = bukuSnap.data();
    final statusKondisi = data?['status_kondisi'] ?? 'Tersedia';
    if (statusKondisi == 'Rusak') {
      throw Exception(
        'Buku ini tidak dapat dipinjam karena dalam kondisi RUSAK',
      );
    }
    if (statusKondisi == 'Hilang') {
      throw Exception('Buku ini tidak dapat dipinjam karena berstatus HILANG');
    }

    final stokSaatIni = (data?['stok'] ?? 0) as int;
    if (stokSaatIni < peminjaman.jumlah) {
      throw Exception('Stok tidak cukup. Sisa stok: $stokSaatIni');
    }
  }

  Future<bool> addPeminjaman(PeminjamanModel peminjaman) async {
    try {
      await _assertStokCukup(peminjaman);
      await _firestore
          .collection(_peminjamanCollection)
          .add(peminjaman.toMap());

      // Update stok buku dan dapatkan stok baru setelah dikurangi
      final newStok = await updateStokBuku(
        peminjaman.bukuId,
        -peminjaman.jumlah,
      );
      print(
        '[addPeminjaman] bukuId=${peminjaman.bukuId}, jumlah=${peminjaman.jumlah}, newStok=$newStok',
      );

      // Update total peminjaman buku
      await updateTotalPeminjaman(peminjaman.bukuId, peminjaman.jumlah);

      // ARS check: CEK DULU sebelum auto-restock!
      // Gunakan stok AKTUAL yang baru saja dihitung (bukan baca ulang dari DB)
      try {
        print('[addPeminjaman] Memulai ARS check...');
        final arsService = ArsService();
        await arsService.checkArsOnTransaction(
          bukuId: peminjaman.bukuId,
          stokSetelahTransaksi: newStok,
          jumlahDipinjam: peminjaman.jumlah,
        );
      } catch (e) {
        // Log error tapi jangan blokir alur peminjaman
        print('[ARS ERROR in addPeminjaman] $e');
      }

      // ARS: cek stok dan lakukan restok otomatis jika perlu
      final didRestock = await _autoRestockIfNeeded(peminjaman.bukuId);
      return didRestock;
    } on Exception {
      // Pesan sudah user-friendly (mis. stok tidak cukup, limit tercapai)
      rethrow;
    } catch (e) {
      throw Exception('Gagal menambahkan peminjaman: $e');
    }
  }

  /// Buat booking peminjaman oleh siswa (status: 'pending').
  /// Booking tidak mengubah stok sampai admin menyetujui.
  Future<void> addBooking(PeminjamanModel peminjaman) async {
    try {
      final data = peminjaman.toMap();
      // Simpan additional metadata
      data['status'] = 'pending';
      data['created_at'] = FieldValue.serverTimestamp();
      await _firestore.collection(_peminjamanCollection).add(data);
    } catch (e) {
      throw Exception('Gagal membuat booking peminjaman: $e');
    }
  }

  /// Approve / setujui peminjaman yang berstatus 'pending'.
  /// Only admin can call this.
  Future<void> approvePeminjaman(String peminjamanId) async {
    await _checkAdminPermission();
    final docRef = _firestore
        .collection(_peminjamanCollection)
        .doc(peminjamanId);
    try {
      final snap = await docRef.get();
      if (!snap.exists) throw Exception('Peminjaman tidak ditemukan');
      final data = snap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? 'pending') as String;
      if (status != 'pending')
        throw Exception('Peminjaman bukan dalam status pending');

      final bukuId = data['buku_id'] as String?;
      final jumlah = (data['jumlah'] ?? 1) as int;

      if (bukuId == null || bukuId.isEmpty)
        throw Exception('Data buku tidak valid');

      // Lakukan transaksi untuk memastikan stok dan update atomik
      int newStokAfterApproval = 0;
      await _firestore.runTransaction((tx) async {
        final bukuRef = _firestore.collection(_collection).doc(bukuId);
        final bukuSnap = await tx.get(bukuRef);
        if (!bukuSnap.exists) throw Exception('Buku tidak ditemukan');
        final bukuData = bukuSnap.data() as Map<String, dynamic>;
        final currentStok = (bukuData['stok'] ?? 0) as int;
        if (currentStok < jumlah)
          throw Exception('Stok tidak cukup. Tersisa: $currentStok');

        // Kurangi stok dan update total peminjaman
        final currentTotal = (bukuData['total_peminjaman'] ?? 0) as int;
        final newStok = (currentStok - jumlah).clamp(0, 999);
        newStokAfterApproval = newStok;

        tx.update(bukuRef, {
          'stok': newStok,
          'total_peminjaman': currentTotal + jumlah,
          'last_stock_update': FieldValue.serverTimestamp(),
        });

        // Update dokumen peminjaman: status -> dipinjam, set tanggal_pinjam/jatuh_tempo jika belum ada
        final pemSnap = await tx.get(docRef);
        final pemData = pemSnap.data() as Map<String, dynamic>;
        final now = FieldValue.serverTimestamp();

        // Safely parse existing tanggal_jatuh_tempo (could be Timestamp, String, or DateTime)
        Timestamp dueTimestamp;
        final rawDue = pemData['tanggal_jatuh_tempo'];
        if (rawDue is Timestamp) {
          dueTimestamp = rawDue;
        } else if (rawDue is DateTime) {
          dueTimestamp = Timestamp.fromDate(rawDue);
        } else if (rawDue is String) {
          try {
            final parsed = DateTime.parse(rawDue);
            dueTimestamp = Timestamp.fromDate(parsed);
          } catch (_) {
            dueTimestamp = Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 7)),
            );
          }
        } else {
          dueTimestamp = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          );
        }

        tx.update(docRef, {
          'status': 'dipinjam',
          'tanggal_pinjam': now,
          'tanggal_jatuh_tempo': dueTimestamp,
        });
      });

      // ARS check: CEK DULU sebelum auto-restock!
      try {
        final arsService = ArsService();
        await arsService.checkArsOnTransaction(
          bukuId: bukuId,
          stokSetelahTransaksi: newStokAfterApproval,
          jumlahDipinjam: jumlah,
        );
      } catch (e) {
        print('[ARS ERROR in approvePeminjaman] $e');
      }

      // Setelah ARS cek, lakukan restok otomatis jika perlu
      try {
        await _autoRestockIfNeeded(bukuId);
      } catch (_) {}

      // Kirim notifikasi ke siswa jika ada UID
      try {
        final uid = data['uid_siswa'] as String?;
        final judul = data['judul_buku'] as String? ?? '';
        final tanggalJt = data['tanggal_jatuh_tempo'];
        if (uid != null && uid.isNotEmpty) {
          final appNotificationService = AppNotificationService();
          await appNotificationService.createNotification(
            userId: uid,
            title: 'Peminjaman Disetujui',
            body:
                'Booking peminjaman buku "$judul" telah disetujui oleh admin.',
            type: 'peminjaman_approve',
            data: {
              'peminjaman_id': peminjamanId,
              'buku_id': bukuId,
              'tanggal_jatuh_tempo': tanggalJt?.toString(),
            },
          );
        }
      } catch (_) {}
    } catch (e, st) {
      // Print for debugging in console and include a readable message
      print('approvePeminjaman error (raw): $e');
      print(st);

      // Try to extract boxed error/details/stack if present (common with converted Futures)
      String extracted = '';
      try {
        final dyn = e as dynamic;
        if (dyn.error != null) extracted += 'boxed_error: ${dyn.error}\n';
        if (dyn.details != null) extracted += 'details: ${dyn.details}\n';
        if (dyn.stack != null) extracted += 'boxed_stack: ${dyn.stack}\n';
      } catch (_) {
        // ignore
      }

      String msg;
      try {
        if (e is FirebaseException) {
          msg = '${e.code}: ${e.message}';
        } else if (extracted.isNotEmpty) {
          msg = '${e.toString()}\n$extracted';
        } else {
          msg = e.toString();
        }
      } catch (_) {
        msg = e.toString();
      }

      throw Exception('Gagal menyetujui peminjaman: $msg');
    }
  }

  // ARS: Restock otomatis berdasarkan stok_minimum dan stok_awal atau reorder_quantity
  // Mengembalikan true jika restok dilakukan
  Future<bool> _autoRestockIfNeeded(String bukuId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(bukuId);
      bool restocked = false;
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>;
        final currentStok = (data['stok'] ?? 0) as int;
        final stokMinimum = (data['stok_minimum'] ?? 0) as int;
        final stokAwal = data['stok_awal'] as int?;
        final isArsEnabled =
            (data['is_ars_enabled'] ?? true) as bool; // default aktif

        if (!isArsEnabled) return;
        if (stokMinimum <= 0) return; // jika tidak diset, skip

        if (currentStok <= stokMinimum) {
          int increaseBy = 0;
          if (stokAwal != null && stokAwal > currentStok) {
            increaseBy = stokAwal - currentStok; // reset ke stok_awal
          } else {
            increaseBy = 10; // default fallback
          }
          if (increaseBy > 0) {
            final newStok = (currentStok + increaseBy).clamp(0, 999);
            tx.update(docRef, {'stok': newStok});
            restocked = true;
          }
        }
      });
      // Jika terjadi restok otomatis, kirim notifikasi ke semua admin (inbox)
      if (restocked) {
        try {
          final updated = await docRef.get();
          if (updated.exists) {
            final data = updated.data() as Map<String, dynamic>;
            final judul = (data['judul'] ?? 'Buku') as String;
            final stok = (data['stok'] ?? 0) as int;
            final appNotificationService = AppNotificationService();
            await appNotificationService.createNotificationForAllAdmins(
              title: 'ARS Restok Otomatis',
              body:
                  'Stok buku "$judul" diisi ulang otomatis menjadi $stok oleh ARS.',
              type: 'ars',
              data: {
                'buku_id': bukuId,
                'judul_buku': judul,
                'stok': stok,
                'source': 'auto_restock',
              },
            );
          }
        } catch (_) {
          // Silent fail, tidak mengganggu alur
        }
      }
      return restocked;
    } catch (e) {
      // Jika gagal restok, jangan blokir alur peminjaman
      return false;
    }
  }

  // Mengambil semua peminjaman
  Future<List<PeminjamanModel>> getPeminjaman() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore.collection(_peminjamanCollection).get();
      return snapshot.docs.map((doc) {
        return PeminjamanModel.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data peminjaman: $e');
    }
  }

  // Mengembalikan buku (bisa sebagian). quantity: jumlah yang dikembalikan
  // denda: optional hukuman jika terlambat
  Future<void> kembalikanBuku(
    String peminjamanId,
    String bukuId,
    int quantity, {
    String? denda,
    bool isTerlambat = false,
  }) async {
    try {
      final docRef = _firestore
          .collection(_peminjamanCollection)
          .doc(peminjamanId);

      String? uidSiswa;
      String? judulBuku;
      String kelasInfo = '';

      // Try to update the live peminjaman document first
      final snap = await docRef.get();
      if (snap.exists) {
        // Live doc exists: perform transaction update
        await _firestore.runTransaction((tx) async {
          final s = await tx.get(docRef);
          if (!s.exists) return;
          final data = s.data() as Map<String, dynamic>;
          final sudahKembali = (data['jumlah_kembali'] ?? 0) as int;
          final totalDipinjam = (data['jumlah'] ?? 1) as int;
          final baruKembali = (sudahKembali + quantity).clamp(0, totalDipinjam);

          final status =
              baruKembali >= totalDipinjam ? 'dikembalikan' : 'dipinjam';

          // Simpan data untuk notifikasi
          uidSiswa = data['uid_siswa'];
          judulBuku = data['judul_buku'];
          final kelasData = data['kelas'] as String?;
          kelasInfo =
              (kelasData != null && kelasData.isNotEmpty)
                  ? ' (Kelas: $kelasData)'
                  : '';

          final updateData = <String, dynamic>{
            'jumlah_kembali': baruKembali,
            'status': status,
            'tanggal_kembali':
                status == 'dikembalikan' ? Timestamp.now() : null,
          };

          // Tambahkan denda jika ada
          if (denda != null && denda.isNotEmpty) {
            updateData['denda'] = denda;
          }

          tx.update(docRef, updateData);
        });

        // Update stok buku
        await updateStokBuku(bukuId, quantity);

        // Kirim notifikasi ke siswa jika ada UID
        if (uidSiswa != null && uidSiswa!.isNotEmpty && judulBuku != null) {
          final appNotificationService = AppNotificationService();

          String notifTitle;
          String notifBody;
          String notifType;

          if (isTerlambat) {
            notifTitle = 'Buku Dikembalikan - Terlambat';
            notifBody =
                'Buku "$judulBuku"$kelasInfo telah dikembalikan dengan keterlambatan.\n\nPeringatan: Harap mengembalikan buku tepat waktu di lain kesempatan.';
            notifType = 'keterlambatan';
          } else {
            notifTitle = 'Buku Berhasil Dikembalikan';
            notifBody =
                'Buku "$judulBuku"$kelasInfo telah berhasil dikembalikan. Terima kasih!';
            notifType = 'pengembalian';
          }

          await appNotificationService.createNotification(
            userId: uidSiswa!,
            title: notifTitle,
            body: notifBody,
            type: notifType,
            data: {
              'buku_id': bukuId,
              'judul_buku': judulBuku,
              'jumlah': quantity,
              'peminjaman_id': peminjamanId,
              'is_terlambat': isTerlambat,
            },
          );
        }
        return;
      }

      // If live doc doesn't exist, try archived peminjaman_history
      final archiveRef = _firestore
          .collection('peminjaman_history')
          .doc(peminjamanId);
      final archiveSnap = await archiveRef.get();
      if (!archiveSnap.exists) {
        // Nothing to do: peminjaman not found anywhere
        throw Exception('Peminjaman tidak ditemukan (baik live maupun arsip)');
      }

      // Process return on archive record: update jumlah_kembali and status, and restore stock
      final archiveData = archiveSnap.data() as Map<String, dynamic>;
      final sudahKembaliA = (archiveData['jumlah_kembali'] ?? 0) as int;
      final totalDipinjamA = (archiveData['jumlah'] ?? 1) as int;
      final baruKembaliA = (sudahKembaliA + quantity).clamp(0, totalDipinjamA);
      final statusA =
          baruKembaliA >= totalDipinjamA ? 'dikembalikan' : 'dipinjam';

      // Update archive doc
      final archiveUpdateData = <String, dynamic>{
        'jumlah_kembali': baruKembaliA,
        'status': statusA,
        'tanggal_kembali': statusA == 'dikembalikan' ? Timestamp.now() : null,
        'restored_from_live_missing': true,
      };

      // Tambahkan denda jika ada
      if (denda != null && denda.isNotEmpty) {
        archiveUpdateData['denda'] = denda;
      }

      await archiveRef.update(archiveUpdateData);

      // Restore stock for the quantity being returned
      await updateStokBuku(bukuId, quantity);

      // Prepare notification fields from archive
      uidSiswa = archiveData['uid_siswa'] as String?;
      judulBuku = archiveData['judul_buku'] as String?;
      final archiveKelas = archiveData['kelas'] as String?;
      final archiveKelasInfo =
          (archiveKelas != null && archiveKelas.isNotEmpty)
              ? ' (Kelas: $archiveKelas)'
              : '';

      if (uidSiswa != null && uidSiswa.isNotEmpty && judulBuku != null) {
        final appNotificationService = AppNotificationService();

        String notifTitle;
        String notifBody;
        String notifType;

        if (isTerlambat) {
          notifTitle = 'Buku Dikembalikan - Terlambat';
          notifBody =
              'Buku "$judulBuku"$archiveKelasInfo telah dikembalikan dengan keterlambatan.\n\nPeringatan: Harap mengembalikan buku tepat waktu di lain kesempatan.';
          notifType = 'keterlambatan';
        } else {
          notifTitle = 'Buku Berhasil Dikembalikan';
          notifBody =
              'Buku "$judulBuku"$archiveKelasInfo telah berhasil dikembalikan. Terima kasih!';
          notifType = 'pengembalian';
        }

        await appNotificationService.createNotification(
          userId: uidSiswa,
          title: notifTitle,
          body: notifBody,
          type: notifType,
          data: {
            'buku_id': bukuId,
            'judul_buku': judulBuku,
            'jumlah': quantity,
            'peminjaman_id': peminjamanId,
            'archived': true,
            'is_terlambat': isTerlambat,
          },
        );
      }
    } catch (e) {
      throw Exception('Gagal mengembalikan buku: $e');
    }
  }

  /// Kirim notifikasi keterlambatan ke siswa
  /// Dipanggil saat admin melihat daftar pengembalian dan ada buku yang terlambat
  Future<void> kirimNotifikasiKeterlambatan({
    required String peminjamanId,
    required String uidSiswa,
    required String judulBuku,
    required String namaPeminjam,
    required DateTime tanggalJatuhTempo,
  }) async {
    try {
      // Update flag notifikasi di peminjaman
      final docRef = _firestore
          .collection(_peminjamanCollection)
          .doc(peminjamanId);

      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final alreadyNotified = data['terlambat_notified'] == true;

      // Jika sudah pernah dinotifikasi, skip
      if (alreadyNotified) return;

      // Update flag
      await docRef.update({'terlambat_notified': true});

      // Hitung berapa hari terlambat
      final now = DateTime.now();
      final hariTerlambat = now.difference(tanggalJatuhTempo).inDays;

      // Ambil info kelas dari data peminjaman
      final kelas = data['kelas'] as String?;
      final kelasInfo =
          (kelas != null && kelas.isNotEmpty) ? ' (Kelas: $kelas)' : '';

      // Kirim notifikasi
      final appNotificationService = AppNotificationService();
      await appNotificationService.createNotification(
        userId: uidSiswa,
        title: '⚠️ Buku Terlambat Dikembalikan',
        body:
            'Buku "$judulBuku" yang dipinjam oleh $namaPeminjam$kelasInfo telah melewati batas waktu pengembalian ${hariTerlambat > 0 ? "$hariTerlambat hari" : "beberapa jam"} yang lalu.\n\nMohon segera kembalikan buku ke perpustakaan.',
        type: 'keterlambatan',
        data: {
          'peminjaman_id': peminjamanId,
          'judul_buku': judulBuku,
          'kelas': kelas,
          'tanggal_jatuh_tempo': Timestamp.fromDate(tanggalJatuhTempo),
          'hari_terlambat': hariTerlambat,
        },
      );
    } catch (e) {
      // Silent fail - notifikasi tidak kritis
      print('Gagal kirim notifikasi keterlambatan: $e');
    }
  }

  // ============================================================================
  // STOCK MANAGEMENT (Manajemen Stok)
  // ============================================================================

  Future<int> updateStokBuku(String bukuId, int perubahan) async {
    try {
      int resultStok = 0;
      final docRef = _firestore.collection(_collection).doc(bukuId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final currentStok = (data['stok'] ?? 0) as int;
          final newStok = (currentStok + perubahan).clamp(0, 999);
          resultStok = newStok;

          // Read ARS-related fields from document (use sensible fallbacks)
          final stokMinimum = (data['stok_minimum'] ?? 0) as int;
          // stok_awal is used as stok_maksimal when provided
          final stokMaksimal =
              (data['stok_awal'] as int?) ?? (stokMinimum + 10);

          // Determine stock status per your spec:
          // - Kritis: stok <= stok_minimum
          // - Aman: stok > stok_minimum && stok < stok_maksimal
          // - Maksimal: stok >= stok_maksimal
          String stokStatus;
          if (newStok <= stokMinimum) {
            stokStatus = 'Kritis';
          } else if (newStok > stokMinimum && newStok < stokMaksimal) {
            stokStatus = 'Aman';
          } else {
            stokStatus = 'Maksimal';
          }

          // Calculate replenishment recommendation: rekomendasi = stok_maksimal - stok
          final rekomendasi =
              (stokMaksimal - newStok) > 0 ? (stokMaksimal - newStok) : 0;

          transaction.update(docRef, {
            'stok': newStok,
            'stok_status': stokStatus,
            'rekomendasi_restock': rekomendasi,
            'last_stock_update': FieldValue.serverTimestamp(),
          });
        }
      });
      return resultStok;
    } catch (e) {
      throw Exception('Gagal update stok buku: $e');
    }
  }

  // Set stok buku secara absolut (bukan penjumlahan) dan perbarui status stok
  Future<void> setStokBukuAbsolute(
    String bukuId,
    int stokBaru, {
    bool updateStokAwal = false,
  }) async {
    final int target = stokBaru.clamp(0, 999);
    try {
      final docRef = _firestore.collection(_collection).doc(bukuId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Buku tidak ditemukan');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final stokMinimum = (data['stok_minimum'] ?? 0) as int;
        final stokAwalDoc = data['stok_awal'] as int?;
        final stokMaksimal = stokAwalDoc ?? (stokMinimum + 10);

        String stokStatus;
        if (target <= stokMinimum) {
          stokStatus = 'Kritis';
        } else if (target > stokMinimum && target < stokMaksimal) {
          stokStatus = 'Aman';
        } else {
          stokStatus = 'Maksimal';
        }

        final rekomendasi =
            (stokMaksimal - target) > 0 ? (stokMaksimal - target) : 0;

        final updateData = <String, dynamic>{
          'stok': target,
          'stok_status': stokStatus,
          'rekomendasi_restock': rekomendasi,
          'last_stock_update': FieldValue.serverTimestamp(),
        };

        if (updateStokAwal) {
          updateData['stok_awal'] = target;
        }

        transaction.update(docRef, updateData);
      });
    } catch (e) {
      throw Exception('Gagal mengatur stok buku: $e');
    }
  }

  /// Set or update `stok_awal` explicitly and recalculate rekomendasi/status
  Future<void> setStokAwal(String bukuId, int stokAwal) async {
    try {
      final int target = stokAwal.clamp(0, 999);
      final docRef = _firestore.collection(_collection).doc(bukuId);
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) throw Exception('Buku tidak ditemukan');

        final data = snapshot.data() as Map<String, dynamic>;
        final stokMinimum = (data['stok_minimum'] ?? 0) as int;
        final currentStok = (data['stok'] ?? 0) as int;

        final stokMaksimal = target;

        String stokStatus;
        if (currentStok <= stokMinimum) {
          stokStatus = 'Kritis';
        } else if (currentStok > stokMinimum && currentStok < stokMaksimal) {
          stokStatus = 'Aman';
        } else {
          stokStatus = 'Maksimal';
        }

        final rekomendasi =
            (stokMaksimal - currentStok) > 0 ? (stokMaksimal - currentStok) : 0;

        tx.update(docRef, {
          'stok_awal': target,
          'stok_status': stokStatus,
          'rekomendasi_restock': rekomendasi,
          'last_stock_update': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      throw Exception('Gagal set stok_awal: $e');
    }
  }

  // Update total peminjaman buku
  Future<void> updateTotalPeminjaman(String bukuId, int tambahan) async {
    try {
      final docRef = _firestore.collection(_collection).doc(bukuId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final currentTotal = snapshot.data()!['total_peminjaman'] ?? 0;
          final newTotal = currentTotal + tambahan;
          transaction.update(docRef, {'total_peminjaman': newTotal});
        }
      });
    } catch (e) {
      throw Exception('Gagal update total peminjaman: $e');
    }
  }

  // Ambil daftar peminjaman untuk buku tertentu
  Future<List<PeminjamanModel>> getPeminjamanByBuku(String bukuId) async {
    try {
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .get();

      return snapshot.docs.map((doc) {
        return PeminjamanModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil peminjaman untuk buku: $e');
    }
  }

  // Stream untuk real-time updates peminjaman
  Stream<List<PeminjamanModel>> getPeminjamanStream() {
    return _firestore
        .collection(_peminjamanCollection)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snapshot) {
          final List<PeminjamanModel> list = [];
          for (final doc in snapshot.docs) {
            try {
              final data = doc.data();
              list.add(PeminjamanModel.fromMap(data, doc.id));
            } catch (e, st) {
              // Log but don't crash the stream; skip malformed doc
              print('getPeminjamanStream: failed to parse doc ${doc.id}: $e');
              print(st);
              continue;
            }
          }
          return list;
        });
  }

  Future<void> deletePeminjaman(String peminjamanId) async {
    try {
      final docRef = _firestore
          .collection(_peminjamanCollection)
          .doc(peminjamanId);
      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      final bukuId = (data['buku_id'] ?? data['bukuId']) as String?;
      final jumlah = (data['jumlah'] ?? 0) as int;
      final jumlahKembali = (data['jumlah_kembali'] ?? 0) as int;

      // Determine how much stock should be restored when deleting the peminjaman.
      // - If booking/pending: no stock was reserved/changed -> do nothing
      // - If dipinjam: restore outstanding (jumlah - jumlah_kembali)
      // - If dikembalikan: already returned -> nothing to restore
      if (bukuId != null && bukuId.isNotEmpty && status == 'dipinjam') {
        final outstanding = (jumlah - jumlahKembali).clamp(0, jumlah);
        if (outstanding > 0) {
          // Add back the outstanding quantity to stock
          await updateStokBuku(bukuId, outstanding);
        }
      }

      await docRef.delete();
    } catch (e) {
      throw Exception('Gagal menghapus peminjaman: $e');
    }
  }

  // ============================================================================
  // CATEGORY MANAGEMENT (Manajemen Kategori)
  // ============================================================================

  Future<List<String>> getCategories() async {
    final snap =
        await _firestore.collection(_categoryCollection).orderBy('name').get();
    return snap.docs.map((d) => (d.data()['name'] as String)).toList();
  }

  Stream<List<String>> getCategoriesStream() {
    return _firestore
        .collection(_categoryCollection)
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => (d.data()['name'] as String)).toList());
  }

  Future<void> addCategory(String name) async {
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    final exists =
        await _firestore
            .collection(_categoryCollection)
            .where('name_lower', isEqualTo: normalized.toLowerCase())
            .limit(1)
            .get();
    if (exists.docs.isNotEmpty) return;
    await _firestore.collection(_categoryCollection).add({
      'name': normalized,
      'name_lower': normalized.toLowerCase(),
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Mengubah nama kategori dan memperbarui semua buku yang menggunakan kategori tersebut
  Future<void> updateCategory(String oldName, String newName) async {
    final oldNormalized = oldName.trim();
    final newNormalized = newName.trim();
    if (oldNormalized.isEmpty || newNormalized.isEmpty) return;
    if (oldNormalized == newNormalized) return;

    // Cek apakah nama baru sudah ada
    final exists =
        await _firestore
            .collection(_categoryCollection)
            .where('name_lower', isEqualTo: newNormalized.toLowerCase())
            .limit(1)
            .get();
    if (exists.docs.isNotEmpty) {
      throw Exception('Kategori dengan nama "$newNormalized" sudah ada');
    }

    // Ambil dokumen kategori lama
    final oldCategorySnap =
        await _firestore
            .collection(_categoryCollection)
            .where('name_lower', isEqualTo: oldNormalized.toLowerCase())
            .get();

    if (oldCategorySnap.docs.isEmpty) return;

    // Update kategori di master list
    final batch = _firestore.batch();
    for (final doc in oldCategorySnap.docs) {
      batch.update(doc.reference, {
        'name': newNormalized,
        'name_lower': newNormalized.toLowerCase(),
      });
    }
    await batch.commit();

    // Update semua buku yang menggunakan kategori ini
    const int pageSize = 400;
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('kategori', isEqualTo: oldNormalized)
        .limit(pageSize);

    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      final batchBooks = _firestore.batch();
      for (final doc in snap.docs) {
        batchBooks.update(doc.reference, {'kategori': newNormalized});
      }
      await batchBooks.commit();

      if (snap.docs.length < pageSize) break;
      final last = snap.docs.last;
      query = _firestore
          .collection(_collection)
          .where('kategori', isEqualTo: oldNormalized)
          .startAfterDocument(last)
          .limit(pageSize);
    }
  }

  /// Menghapus kategori dari master list tanpa menghapus buku.
  /// Buku yang sudah memiliki nama kategori ini tetap utuh (tidak diubah).
  Future<void> deleteCategoryByName(String name) async {
    final snap =
        await _firestore
            .collection(_categoryCollection)
            .where('name_lower', isEqualTo: name.toLowerCase())
            .get();

    final batch = _firestore.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  /// Menghapus kategori dan memindahkan semua buku berkategori tsb ke kategori pengganti.
  /// Default kategori pengganti adalah "Tidak Berkategori".
  Future<void> deleteCategoryAndReassignBooks(
    String name, {
    String replacementName = 'Tidak Berkategori',
  }) async {
    final String oldName = name.trim();
    if (oldName.isEmpty) return;
    final newName =
        replacementName.trim().isEmpty
            ? 'Tidak Berkategori'
            : replacementName.trim();

    // Pastikan kategori pengganti tersedia di master list
    await addCategory(newName);

    // Hapus kategori lama dari master list
    await deleteCategoryByName(oldName);

    // Re-assign buku per halaman agar aman dari limit batch (<=500 operasi)
    const int pageSize = 400;
    Query<Map<String, dynamic>> query = _firestore
        .collection(_collection)
        .where('kategori', isEqualTo: oldName)
        .limit(pageSize);

    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'kategori': newName});
      }
      await batch.commit();

      if (snap.docs.length < pageSize) break;
      final last = snap.docs.last;
      query = _firestore
          .collection(_collection)
          .where('kategori', isEqualTo: oldName)
          .startAfterDocument(last)
          .limit(pageSize);
    }
  }

  // ============================================================================
  // STUDENT MANAGEMENT (Manajemen Siswa)
  // ============================================================================

  final String _siswaCollection = 'siswa';

  Future<String> _generateUsernameFromName(String nama) async {
    final String namaClean = nama.toLowerCase().replaceAll(
      RegExp(r'[^a-z]'),
      '',
    );

    String prefix;
    if (namaClean.length >= 3) {
      prefix = namaClean.substring(0, 3);
    } else if (namaClean.length == 2) {
      // Jika hanya 2 huruf, tambahkan 'x' di akhir
      prefix = '${namaClean}x';
    } else if (namaClean.length == 1) {
      // Jika hanya 1 huruf, tambahkan 'xx' di akhir
      prefix = '${namaClean}xx';
    } else {
      // Jika tidak ada huruf sama sekali, gunakan 'xxx'
      prefix = 'xxx';
    }

    // Generate username dengan random number (001-999)
    final random = Random();
    String username;
    int attempts = 0;

    while (attempts < 50) {
      final randomNum = random.nextInt(999) + 1; // 1-999
      username = '$prefix${randomNum.toString().padLeft(3, '0')}';

      // Cek apakah username sudah ada
      final existing =
          await _firestore
              .collection(_siswaCollection)
              .where('username', isEqualTo: username)
              .limit(1)
              .get();

      if (existing.docs.isEmpty) {
        return username; // Username tersedia
      }

      attempts++;
    }

    // Jika 50x tidak ketemu, throw error
    throw Exception(
      'Gagal generate username unik. Terlalu banyak siswa dengan prefix nama yang sama',
    );
  }

  // Registrasi siswa baru (status: pending, perlu approval admin)
  Future<void> registerSiswaPending({
    required String nama,
    required String nis,
  }) async {
    try {
      // Validasi NIS harus 6 digit
      if (nis.length != 6 || !RegExp(r'^\d{6}$').hasMatch(nis)) {
        throw Exception('NIS harus terdiri dari 6 digit angka');
      }

      // Cek apakah NIS sudah ada (baik yang pending maupun approved)
      final existingSiswa =
          await _firestore
              .collection(_siswaCollection)
              .where('nis', isEqualTo: nis)
              .limit(1)
              .get();

      if (existingSiswa.docs.isNotEmpty) {
        throw Exception('NIS sudah terdaftar');
      }

      // Cek apakah ada pendaftaran pending dengan NIS yang sama
      final pendingRegistrations =
          await _firestore
              .collection('pending_registrations')
              .where('nis', isEqualTo: nis)
              .where('status', isEqualTo: 'pending')
              .limit(1)
              .get();

      if (pendingRegistrations.docs.isNotEmpty) {
        throw Exception('NIS sudah terdaftar');
      }

      // Simpan ke pending_registrations (BELUM membuat akun Firebase Auth)
      await _firestore.collection('pending_registrations').add({
        'nama': nama,
        'nis': nis,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // Menambahkan siswa baru dan membuat akun (setelah approval admin)
  Future<Map<String, String>> addSiswa({
    required String nama,
    required String nis,
    String? kelas,
  }) async {
    try {
      // Validasi NIS harus 6 digit
      if (nis.length != 6 || !RegExp(r'^\d{6}$').hasMatch(nis)) {
        throw Exception('NIS harus terdiri dari 6 digit angka');
      }

      // Cek apakah NIS sudah ada
      final existingSiswa =
          await _firestore
              .collection(_siswaCollection)
              .where('nis', isEqualTo: nis)
              .limit(1)
              .get();

      if (existingSiswa.docs.isNotEmpty) {
        throw Exception('NIS sudah terdaftar');
      }

      // Generate username dari nama (3 huruf pertama + 3 digit)
      final username = await _generateUsernameFromName(nama);
      final email = '$username@siswa.smpn18lau.sch.id';

      // Buat akun Firebase Auth
      final authService = AuthService();
      final userCredential = await authService.createStudentAccount(
        username,
        nis,
      );
      final uid = userCredential.user!.uid;

      // Simpan data siswa ke Firestore
      await _firestore.collection(_siswaCollection).add({
        'nama': nama,
        'nis': nis,
        'username': username,
        'email': email,
        'uid': uid,
        'kelas': kelas ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Buat dokumen user untuk role checking
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'username': username,
        'role': 'siswa',
        'nama': nama,
        'nis': nis,
        'uid': uid,
        'kelas': kelas ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Return username dan password untuk ditampilkan
      return {'username': username, 'password': nis, 'email': email};
    } catch (e) {
      throw Exception('Gagal menambahkan siswa: $e');
    }
  }

  // Mengambil semua pendaftaran yang pending
  // Optimize: Hapus orderBy untuk menghindari index requirement, sort di client side
  Future<List<Map<String, dynamic>>> getPendingRegistrations() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('pending_registrations')
              .where('status', isEqualTo: 'pending')
              .get();

      // Sort di client side berdasarkan created_at
      final list =
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();

      // Sort berdasarkan created_at descending
      list.sort((a, b) {
        final aTime = a['created_at'];
        final bTime = b['created_at'];
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        DateTime? aDate, bDate;
        try {
          if (aTime is Timestamp) {
            aDate = aTime.toDate();
          } else if (aTime is String) {
            aDate = DateTime.parse(aTime);
          }
          if (bTime is Timestamp) {
            bDate = bTime.toDate();
          } else if (bTime is String) {
            bDate = DateTime.parse(bTime);
          }
        } catch (e) {
          return 0;
        }

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return bDate.compareTo(aDate); // Descending
      });

      return list;
    } catch (e) {
      throw Exception('Gagal mengambil pendaftaran pending: $e');
    }
  }

  // Approve pendaftaran siswa (membuat akun)
  Future<Map<String, String>> approveSiswaRegistration(
    String registrationId,
  ) async {
    try {
      // Skip permission check for direct approval
      // await _checkAdminPermission();
      // Ambil data pendaftaran
      final registrationDoc =
          await _firestore
              .collection('pending_registrations')
              .doc(registrationId)
              .get();

      if (!registrationDoc.exists) {
        throw Exception('Pendaftaran tidak ditemukan');
      }

      final data = registrationDoc.data()!;
      final nama = data['nama'] as String;
      final nis = data['nis'] as String;

      // Buat akun siswa
      final accountInfo = await addSiswa(nama: nama, nis: nis);

      // Update status pendaftaran menjadi approved
      await _firestore
          .collection('pending_registrations')
          .doc(registrationId)
          .update({
            'status': 'approved',
            'approved_at': FieldValue.serverTimestamp(),
            'username': accountInfo['username'],
          });

      // Dapatkan UID siswa yang baru dibuat untuk mengirim notifikasi
      // Cari berdasarkan username
      final siswaQuery =
          await _firestore
              .collection(_siswaCollection)
              .where('username', isEqualTo: accountInfo['username'])
              .limit(1)
              .get();

      if (siswaQuery.docs.isNotEmpty) {
        final siswaData = siswaQuery.docs.first.data();
        final siswaUid = siswaData['uid'] as String?;

        if (siswaUid != null && siswaUid.isNotEmpty) {
          // Kirim notifikasi selamat datang ke inbox siswa
          final appNotificationService = AppNotificationService();
          await appNotificationService.createNotification(
            userId: siswaUid,
            title: 'Akun Anda Telah Disetujui!',
            body:
                'Selamat datang di Perpustakaan SMPN 18 LAU! Akun Anda telah disetujui oleh admin. Username: ${accountInfo['username']}, Password: ${accountInfo['password']}',
            type: 'approval',
            data: {
              'username': accountInfo['username'],
              'password': accountInfo['password'],
              'email': accountInfo['email'],
            },
          );
        }
      }

      return accountInfo;
    } catch (e) {
      throw Exception('Gagal menyetujui pendaftaran: $e');
    }
  }

  // Reject pendaftaran siswa
  Future<void> rejectSiswaRegistration(String registrationId) async {
    try {
      // Skip permission check for direct rejection
      // await _checkAdminPermission();
      await _firestore
          .collection('pending_registrations')
          .doc(registrationId)
          .update({
            'status': 'rejected',
            'rejected_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      throw Exception('Gagal menolak pendaftaran: $e');
    }
  }

  // Mengambil semua siswa
  Future<List<Map<String, dynamic>>> getSiswa() async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection(_siswaCollection)
              .orderBy('created_at', descending: true)
              .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil data siswa: $e');
    }
  }

  // Mengambil siswa berdasarkan NIS
  Future<Map<String, dynamic>?> getSiswaByNis(String nis) async {
    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection(_siswaCollection)
              .where('nis', isEqualTo: nis)
              .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      return {'id': doc.id, ...data};
    } catch (e) {
      throw Exception('Gagal mengambil siswa: $e');
    }
  }

  // Update data siswa
  Future<void> updateSiswa(
    String siswaId,
    String uid, {
    required String nama,
    required String nis,
    String? kelas,
  }) async {
    try {
      // Validasi NIS harus 6 digit
      if (nis.length != 6 || !RegExp(r'^\d{6}$').hasMatch(nis)) {
        throw Exception('NIS harus terdiri dari 6 digit angka');
      }

      // Cek apakah NIS baru sudah ada di siswa lain
      final existingSiswa =
          await _firestore
              .collection(_siswaCollection)
              .where('nis', isEqualTo: nis)
              .get();

      if (existingSiswa.docs.isNotEmpty &&
          existingSiswa.docs.first.id != siswaId) {
        throw Exception('NIS $nis sudah digunakan oleh siswa lain');
      }

      // Update di Firestore
      await _firestore.collection(_siswaCollection).doc(siswaId).update({
        'nama': nama,
        'nis': nis,
        'kelas': kelas ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Update di collection users juga
      await _firestore.collection('users').doc(uid).update({
        'nama': nama,
        'nis': nis,
        'kelas': kelas ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Gagal mengupdate siswa: $e');
    }
  }

  // Menghapus siswa (dan akun Firebase Auth jika diperlukan)
  Future<void> deleteSiswa(String siswaId, String uid) async {
    try {
      // Hapus dari Firestore
      await _firestore.collection(_siswaCollection).doc(siswaId).delete();

      // Note: Menghapus akun Firebase Auth memerlukan admin privileges
      // Biasanya dilakukan melalui Cloud Functions atau Admin SDK
      // Untuk sekarang, kita hanya hapus dari Firestore
    } catch (e) {
      throw Exception('Gagal menghapus siswa: $e');
    }
  }

  // ============================================================================
  // FILE UPLOAD MANAGEMENT (Manajemen Upload File)
  // ============================================================================
  // FILE UPLOAD MANAGEMENT (Manajemen Upload File)
  // ============================================================================

  // Upload file buku (PDF) ke Cloudinary (menggantikan Firebase Storage)
  Future<String> uploadBookFile(File file, String bukuId) async {
    try {
      // Validasi file
      if (!await file.exists()) {
        throw Exception('File tidak ditemukan');
      }

      // Pastikan bukuId tidak kosong dan valid
      if (bukuId.isEmpty) {
        throw Exception('ID buku tidak valid');
      }

      final bytes = await file.readAsBytes();
      final fileHash = sha256.convert(bytes).toString();

      // Cek apakah sudah ada file dengan hash yang sama
      try {
        final dupQ =
            await _firestore
                .collection(_collection)
                .where('file_hash', isEqualTo: fileHash)
                .limit(1)
                .get();
        if (dupQ.docs.isNotEmpty) {
          final existing = dupQ.docs.first.data();
          final existingUrl = existing['book_file_url'] as String?;
          if (existingUrl != null && existingUrl.isNotEmpty) {
            // Reuse existing URL, tidak perlu upload ulang
            return existingUrl;
          }
        }
      } catch (_) {
        // Jika query gagal, lanjutkan upload normal
      }

      // Gunakan Cloudinary untuk upload PDF
      final clodinaryService = ClodinaryService();

      // Buat publicId berdasarkan bukuId untuk memudahkan manajemen
      // Bersihkan bukuId dari karakter yang tidak valid
      final cleanBukuId = bukuId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'books/$cleanBukuId/$timestamp';

      // Upload PDF ke Cloudinary
      final result = await clodinaryService.uploadPdfToCloudinary(
        file,
        publicId,
      );

      if (result == null || result['url'] == null || result['url']!.isEmpty) {
        throw Exception('Gagal mengunggah file PDF ke Cloudinary');
      }

      final url = result['url']!;

      // Simpan metadata hash ke dokumen buku agar bisa dideteksi di upload selanjutnya
      try {
        final fileName = file.path.split(Platform.pathSeparator).last;
        await _firestore.collection(_collection).doc(bukuId).update({
          'book_file_url': url,
          'file_hash': fileHash,
          'book_file_name': fileName,
        });
      } catch (_) {
        // Silent fail: jika update metadata gagal, tetap kembalikan URL
      }

      return url;
    } catch (e) {
      throw Exception('Gagal mengunggah file buku: $e');
    }
  }

  // Upload file buku (PDF) dari bytes untuk platform Web
  Future<String> uploadBookFileBytes(
    Uint8List bytes,
    String fileName,
    String bukuId,
  ) async {
    try {
      if (bytes.isEmpty) {}

      if (bukuId.isEmpty) {
        throw Exception('ID buku tidak valid');
      }

      // Hitung hash bytes untuk deteksi duplikat
      final fileHash = sha256.convert(bytes).toString();

      // Cek duplikat berdasarkan hash
      try {
        final dupQ =
            await _firestore
                .collection(_collection)
                .where('file_hash', isEqualTo: fileHash)
                .limit(1)
                .get();
        if (dupQ.docs.isNotEmpty) {
          final existing = dupQ.docs.first.data();
          final existingUrl = existing['book_file_url'] as String?;
          if (existingUrl != null && existingUrl.isNotEmpty) {
            return existingUrl;
          }
        }
      } catch (_) {
        // ignore and continue to upload
      }

      final clodinaryService = ClodinaryService();

      final cleanBukuId = bukuId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = 'books/$cleanBukuId/$timestamp';

      print(
        'uploadBookFileBytes: bukuId=$bukuId, publicId=$publicId, fileName=$fileName, size=${bytes.length}',
      );
      final result = await clodinaryService.uploadPdfBytesToCloudinary(
        bytes,
        fileName,
        publicId,
      );

      print('Cloudinary response: $result');

      if (result == null || result['url'] == null || result['url']!.isEmpty) {
        throw Exception('Gagal mengunggah file PDF ke Cloudinary');
      }

      final url = result['url']!;

      // Simpan metadata hash + filename ke dokumen buku
      try {
        await _firestore.collection(_collection).doc(bukuId).update({
          'book_file_url': url,
          'file_hash': fileHash,
          'book_file_name': fileName,
        });
      } catch (_) {}

      return url;
    } catch (e) {
      print('uploadBookFileBytes error: $e');
      throw Exception('Gagal mengunggah file buku: $e');
    }
  }

  // Update bookFileUrl untuk buku tertentu
  Future<void> updateBookFileUrl(String bukuId, String fileUrl) async {
    try {
      await _firestore.collection(_collection).doc(bukuId).update({
        'book_file_url': fileUrl,
      });
    } catch (e) {}
  }

  // ============================================================================
  // DAMAGED / LOST BOOK MANAGEMENT
  // ============================================================================

  /// **Module 1: Book Inventory (Asset Management)**
  /// Allow Admin to manually change a book's status_kondisi.
  /// Valid values: 'Tersedia', 'Rusak', 'Hilang'
  /// When marked 'Rusak' or 'Hilang', stok is decremented by [jumlah] to
  /// prevent borrowing of that unit.
  Future<void> updateStatusKondisiBuku(
    String bukuId, {
    required String statusKondisi,
    String? catatan,
    int jumlah = 1,
  }) async {
    try {
      await _checkAdminPermission();

      if (!['Tersedia', 'Rusak', 'Hilang'].contains(statusKondisi)) {
        throw Exception(
          'Status kondisi tidak valid. Gunakan: Tersedia, Rusak, atau Hilang',
        );
      }

      final docRef = _firestore.collection(_collection).doc(bukuId);
      final snap = await docRef.get();
      if (!snap.exists) throw Exception('Buku tidak ditemukan');

      final data = snap.data() as Map<String, dynamic>;
      final currentStatus = data['status_kondisi'] ?? 'Tersedia';
      final currentStok = (data['stok'] ?? 0) as int;
      final currentJumlahRusak = (data['jumlah_rusak'] ?? 0) as int;
      final currentJumlahHilang = (data['jumlah_hilang'] ?? 0) as int;

      final updateData = <String, dynamic>{
        'catatan_kondisi': catatan,
        'tanggal_status_kondisi': Timestamp.now(),
      };

      // Logika update jumlah rusak/hilang dan stok
      if (statusKondisi == 'Rusak') {
        final newJumlahRusak = currentJumlahRusak + jumlah;
        updateData['jumlah_rusak'] = newJumlahRusak;
        updateData['status_kondisi'] = 'Rusak';
        // Kurangi stok jika dari Tersedia
        if (currentStatus == 'Tersedia' || currentStatus == 'Rusak') {
          final newStok = (currentStok - jumlah).clamp(0, currentStok);
          updateData['stok'] = newStok;
        }
      } else if (statusKondisi == 'Hilang') {
        final newJumlahHilang = currentJumlahHilang + jumlah;
        updateData['jumlah_hilang'] = newJumlahHilang;
        updateData['status_kondisi'] = 'Hilang';
        // Kurangi stok jika dari Tersedia
        if (currentStatus == 'Tersedia' || currentStatus == 'Hilang') {
          final newStok = (currentStok - jumlah).clamp(0, currentStok);
          updateData['stok'] = newStok;
        }
      } else if (statusKondisi == 'Tersedia') {
        // Reset: kembalikan dari rusak/hilang ke tersedia
        final restoreAmount = jumlah;
        updateData['stok'] = currentStok + restoreAmount;
        // Kurangi jumlah rusak/hilang sesuai asal
        if (currentStatus == 'Rusak') {
          updateData['jumlah_rusak'] = (currentJumlahRusak - jumlah).clamp(
            0,
            currentJumlahRusak,
          );
        } else if (currentStatus == 'Hilang') {
          updateData['jumlah_hilang'] = (currentJumlahHilang - jumlah).clamp(
            0,
            currentJumlahHilang,
          );
        }
        // Update status: jika semua sudah kembali normal
        final finalRusak =
            (updateData['jumlah_rusak'] ?? currentJumlahRusak) as int;
        final finalHilang =
            (updateData['jumlah_hilang'] ?? currentJumlahHilang) as int;
        if (finalRusak == 0 && finalHilang == 0) {
          updateData['status_kondisi'] = 'Tersedia';
        } else if (finalRusak > 0) {
          updateData['status_kondisi'] = 'Rusak';
        } else {
          updateData['status_kondisi'] = 'Hilang';
        }
      }

      await docRef.update(updateData);

      // Log ke koleksi riwayat_kondisi_buku
      await _firestore.collection('riwayat_kondisi_buku').add({
        'buku_id': bukuId,
        'judul_buku': data['judul'] ?? '',
        'status_sebelum': currentStatus,
        'status_sesudah': statusKondisi,
        'catatan': catatan,
        'jumlah': jumlah,
        'tanggal': Timestamp.now(),
        'diubah_oleh': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      // Invalidate cache
      _bukuCache = null;
    } catch (e) {
      throw Exception('Gagal mengubah status kondisi buku: $e');
    }
  }

  /// Update jumlah rusak dan hilang secara bersamaan (absolut).
  /// Stok akan dihitung otomatis: stok = totalPool - jumlahRusak - jumlahHilang.
  Future<void> updateKondisiBukuGabungan(
    String bukuId, {
    required int jumlahRusak,
    required int jumlahHilang,
    String? catatan,
  }) async {
    try {
      await _checkAdminPermission();

      final docRef = _firestore.collection(_collection).doc(bukuId);
      final snap = await docRef.get();
      if (!snap.exists) throw Exception('Buku tidak ditemukan');

      final data = snap.data() as Map<String, dynamic>;
      final currentStok = (data['stok'] ?? 0) as int;
      final currentRusak = (data['jumlah_rusak'] ?? 0) as int;
      final currentHilang = (data['jumlah_hilang'] ?? 0) as int;
      final totalPool = currentStok + currentRusak + currentHilang;

      if (jumlahRusak < 0 || jumlahHilang < 0) {
        throw Exception('Jumlah tidak boleh negatif');
      }
      if (jumlahRusak + jumlahHilang > totalPool) {
        throw Exception('Total rusak + hilang melebihi total buku');
      }

      final newStok = totalPool - jumlahRusak - jumlahHilang;

      // Determine status_kondisi
      String statusKondisi;
      if (jumlahRusak == 0 && jumlahHilang == 0) {
        statusKondisi = 'Tersedia';
      } else if (jumlahHilang > 0 && jumlahRusak > 0) {
        statusKondisi = 'Rusak'; // prioritas rusak jika keduanya ada
      } else if (jumlahHilang > 0) {
        statusKondisi = 'Hilang';
      } else {
        statusKondisi = 'Rusak';
      }

      await docRef.update({
        'stok': newStok,
        'jumlah_rusak': jumlahRusak,
        'jumlah_hilang': jumlahHilang,
        'status_kondisi': statusKondisi,
        'catatan_kondisi': catatan,
        'tanggal_status_kondisi': Timestamp.now(),
      });

      // Log riwayat
      await _firestore.collection('riwayat_kondisi_buku').add({
        'buku_id': bukuId,
        'judul_buku': data['judul'] ?? '',
        'status_sebelum': data['status_kondisi'] ?? 'Tersedia',
        'status_sesudah': statusKondisi,
        'jumlah_rusak': jumlahRusak,
        'jumlah_hilang': jumlahHilang,
        'catatan': catatan,
        'tanggal': Timestamp.now(),
        'diubah_oleh': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      _bukuCache = null;
    } catch (e) {
      throw Exception('Gagal mengubah kondisi buku: $e');
    }
  }

  /// **Module 2: Book Return with Condition (Circulation)**
  /// Extended return: records book condition and gives warning.
  /// [kondisiBuku]: 'Baik', 'Rusak', 'Hilang'
  Future<void> kembalikanBukuDenganKondisi(
    String peminjamanId,
    String bukuId,
    int quantity, {
    required String kondisiBuku,
    String? denda,
    bool isTerlambat = false,
  }) async {
    try {
      final docRef = _firestore
          .collection(_peminjamanCollection)
          .doc(peminjamanId);

      String? uidSiswa;
      String? judulBuku;
      String kelasInfo = '';

      final snap = await docRef.get();
      if (!snap.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      // Live doc: perform transaction update
      await _firestore.runTransaction((tx) async {
        final s = await tx.get(docRef);
        if (!s.exists) return;
        final data = s.data() as Map<String, dynamic>;
        final sudahKembali = (data['jumlah_kembali'] ?? 0) as int;
        final totalDipinjam = (data['jumlah'] ?? 1) as int;
        final baruKembali = (sudahKembali + quantity).clamp(0, totalDipinjam);

        final status =
            baruKembali >= totalDipinjam ? 'dikembalikan' : 'dipinjam';

        uidSiswa = data['uid_siswa'];
        judulBuku = data['judul_buku'];
        final kelasData = data['kelas'] as String?;
        kelasInfo =
            (kelasData != null && kelasData.isNotEmpty)
                ? ' (Kelas: $kelasData)'
                : '';

        final updateData = <String, dynamic>{
          'jumlah_kembali': baruKembali,
          'status': status,
          'tanggal_kembali': status == 'dikembalikan' ? Timestamp.now() : null,
          'kondisi_buku': kondisiBuku,
        };

        if (denda != null && denda.isNotEmpty) {
          updateData['denda'] = denda;
        }

        tx.update(docRef, updateData);
      });

      // Conditional stock restoration:
      // 'Baik' → restore stok normally
      // 'Rusak' / 'Hilang' → do NOT restore stok (unit is removed from circulation)
      if (kondisiBuku == 'Baik') {
        await updateStokBuku(bukuId, quantity);
      }

      // If damaged or lost, update master book inventory status + quantities
      if (kondisiBuku == 'Rusak' || kondisiBuku == 'Hilang') {
        final bukuDoc =
            await _firestore.collection(_collection).doc(bukuId).get();
        if (bukuDoc.exists) {
          final bukuData = bukuDoc.data() as Map<String, dynamic>;
          final currentJumlahRusak = (bukuData['jumlah_rusak'] ?? 0) as int;
          final currentJumlahHilang = (bukuData['jumlah_hilang'] ?? 0) as int;

          final updateBukuData = <String, dynamic>{
            'status_kondisi': kondisiBuku,
            'catatan_kondisi':
                'Dilaporkan $kondisiBuku saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}',
            'tanggal_status_kondisi': Timestamp.now(),
          };

          if (kondisiBuku == 'Rusak') {
            updateBukuData['jumlah_rusak'] = currentJumlahRusak + quantity;
          } else {
            updateBukuData['jumlah_hilang'] = currentJumlahHilang + quantity;
          }

          await _firestore
              .collection(_collection)
              .doc(bukuId)
              .update(updateBukuData);
        }

        // Log to riwayat_kondisi_buku
        await _firestore.collection('riwayat_kondisi_buku').add({
          'buku_id': bukuId,
          'judul_buku': judulBuku ?? '',
          'status_sebelum': 'Tersedia',
          'status_sesudah': kondisiBuku,
          'catatan':
              'Dilaporkan saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}',
          'jumlah': quantity,
          'peminjaman_id': peminjamanId,
          'tanggal': Timestamp.now(),
          'diubah_oleh': FirebaseAuth.instance.currentUser?.uid ?? '',
        });

        // Invalidate cache
        _bukuCache = null;
      }

      // Send notification to student
      if (uidSiswa != null && uidSiswa!.isNotEmpty && judulBuku != null) {
        final appNotificationService = AppNotificationService();

        String notifTitle;
        String notifBody;
        String notifType;

        if (kondisiBuku == 'Rusak') {
          notifTitle = 'Peringatan: Buku Dikembalikan Rusak';
          notifBody =
              'Buku "$judulBuku"$kelasInfo dikembalikan dalam kondisi RUSAK.\n\n'
              'Peringatan: Harap menjaga buku perpustakaan dengan baik. '
              'Kerusakan berulang dapat mengakibatkan penangguhan hak pinjam.';
          notifType = 'peringatan_kondisi';
        } else if (kondisiBuku == 'Hilang') {
          notifTitle = 'Peringatan: Buku Dilaporkan Hilang';
          notifBody =
              'Buku "$judulBuku"$kelasInfo dilaporkan HILANG.\n\n'
              'Peringatan: Kehilangan buku perpustakaan adalah pelanggaran serius. '
              'Harap segera melapor ke petugas perpustakaan.';
          notifType = 'peringatan_kondisi';
        } else if (isTerlambat) {
          notifTitle = 'Buku Dikembalikan - Terlambat';
          notifBody =
              'Buku "$judulBuku"$kelasInfo telah dikembalikan dengan keterlambatan.\n\nPeringatan: Harap mengembalikan buku tepat waktu di lain kesempatan.';
          notifType = 'keterlambatan';
        } else {
          notifTitle = 'Buku Berhasil Dikembalikan';
          notifBody =
              'Buku "$judulBuku"$kelasInfo telah berhasil dikembalikan dalam kondisi baik. Terima kasih!';
          notifType = 'pengembalian';
        }

        await appNotificationService.createNotification(
          userId: uidSiswa!,
          title: notifTitle,
          body: notifBody,
          type: notifType,
          data: {
            'buku_id': bukuId,
            'judul_buku': judulBuku,
            'jumlah': quantity,
            'peminjaman_id': peminjamanId,
            'kondisi_buku': kondisiBuku,
            'is_terlambat': isTerlambat,
          },
        );
      }
    } catch (e) {
      throw Exception('Gagal mengembalikan buku: $e');
    }
  }

  /// **Module 2: Book Return with Mixed Conditions (Circulation)**
  /// Extended return: records mixed book conditions (baik, rusak, hilang).
  /// Allows returning books with different conditions in a single transaction.
  Future<void> kembalikanBukuDenganKondisiGabungan(
    String peminjamanId,
    String bukuId, {
    required int jumlahBaik,
    required int jumlahRusak,
    required int jumlahHilang,
    String? denda,
    bool isTerlambat = false,
  }) async {
    final totalKembali = jumlahBaik + jumlahRusak + jumlahHilang;
    if (totalKembali <= 0) {
      throw Exception('Jumlah buku yang dikembalikan harus lebih dari 0');
    }

    try {
      final docRef = _firestore
          .collection(_peminjamanCollection)
          .doc(peminjamanId);

      String? uidSiswa;
      String? judulBuku;
      String kelasInfo = '';

      final snap = await docRef.get();
      if (!snap.exists) {
        throw Exception('Data peminjaman tidak ditemukan');
      }

      // Live doc: perform transaction update
      await _firestore.runTransaction((tx) async {
        final s = await tx.get(docRef);
        if (!s.exists) return;
        final data = s.data() as Map<String, dynamic>;
        final sudahKembali = (data['jumlah_kembali'] ?? 0) as int;
        final totalDipinjam = (data['jumlah'] ?? 1) as int;
        final baruKembali = (sudahKembali + totalKembali).clamp(
          0,
          totalDipinjam,
        );

        final status =
            baruKembali >= totalDipinjam ? 'dikembalikan' : 'dipinjam';

        uidSiswa = data['uid_siswa'];
        judulBuku = data['judul_buku'];
        final kelasData = data['kelas'] as String?;
        kelasInfo =
            (kelasData != null && kelasData.isNotEmpty)
                ? ' (Kelas: $kelasData)'
                : '';

        // Determine primary condition for record
        String kondisiUtama;
        if (jumlahHilang > 0 && jumlahRusak > 0) {
          kondisiUtama = 'Rusak & Hilang';
        } else if (jumlahHilang > 0) {
          kondisiUtama = 'Hilang';
        } else if (jumlahRusak > 0) {
          kondisiUtama = 'Rusak';
        } else {
          kondisiUtama = 'Baik';
        }

        final updateData = <String, dynamic>{
          'jumlah_kembali': baruKembali,
          'status': status,
          'tanggal_kembali': status == 'dikembalikan' ? Timestamp.now() : null,
          'kondisi_buku': kondisiUtama,
          'jumlah_baik_kembali': FieldValue.increment(jumlahBaik),
          'jumlah_rusak_kembali': FieldValue.increment(jumlahRusak),
          'jumlah_hilang_kembali': FieldValue.increment(jumlahHilang),
        };

        if (denda != null && denda.isNotEmpty) {
          updateData['denda'] = denda;
        }

        tx.update(docRef, updateData);
      });

      // Restore stock for good books only
      if (jumlahBaik > 0) {
        await updateStokBuku(bukuId, jumlahBaik);
      }

      // Update master book inventory for damaged/lost books
      if (jumlahRusak > 0 || jumlahHilang > 0) {
        final bukuDoc =
            await _firestore.collection(_collection).doc(bukuId).get();
        if (bukuDoc.exists) {
          final bukuData = bukuDoc.data() as Map<String, dynamic>;
          final currentJumlahRusak = (bukuData['jumlah_rusak'] ?? 0) as int;
          final currentJumlahHilang = (bukuData['jumlah_hilang'] ?? 0) as int;

          final updateBukuData = <String, dynamic>{
            'tanggal_status_kondisi': Timestamp.now(),
          };

          if (jumlahRusak > 0) {
            updateBukuData['jumlah_rusak'] = currentJumlahRusak + jumlahRusak;
          }
          if (jumlahHilang > 0) {
            updateBukuData['jumlah_hilang'] =
                currentJumlahHilang + jumlahHilang;
          }

          // Update status_kondisi based on what was reported
          if (jumlahHilang > 0 && jumlahRusak > 0) {
            updateBukuData['status_kondisi'] = 'Rusak & Hilang';
            updateBukuData['catatan_kondisi'] =
                'Dilaporkan $jumlahRusak rusak dan $jumlahHilang hilang saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}';
          } else if (jumlahHilang > 0) {
            updateBukuData['status_kondisi'] = 'Hilang';
            updateBukuData['catatan_kondisi'] =
                'Dilaporkan $jumlahHilang hilang saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}';
          } else {
            updateBukuData['status_kondisi'] = 'Rusak';
            updateBukuData['catatan_kondisi'] =
                'Dilaporkan $jumlahRusak rusak saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}';
          }

          await _firestore
              .collection(_collection)
              .doc(bukuId)
              .update(updateBukuData);
        }

        // Log to riwayat_kondisi_buku for rusak
        if (jumlahRusak > 0) {
          await _firestore.collection('riwayat_kondisi_buku').add({
            'buku_id': bukuId,
            'judul_buku': judulBuku ?? '',
            'status_sebelum': 'Tersedia',
            'status_sesudah': 'Rusak',
            'catatan':
                'Dilaporkan saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}',
            'jumlah': jumlahRusak,
            'peminjaman_id': peminjamanId,
            'tanggal': Timestamp.now(),
            'diubah_oleh': FirebaseAuth.instance.currentUser?.uid ?? '',
          });
        }

        // Log to riwayat_kondisi_buku for hilang
        if (jumlahHilang > 0) {
          await _firestore.collection('riwayat_kondisi_buku').add({
            'buku_id': bukuId,
            'judul_buku': judulBuku ?? '',
            'status_sebelum': 'Tersedia',
            'status_sesudah': 'Hilang',
            'catatan':
                'Dilaporkan saat pengembalian oleh ${snap.data()?['nama_peminjam'] ?? 'Anggota'}',
            'jumlah': jumlahHilang,
            'peminjaman_id': peminjamanId,
            'tanggal': Timestamp.now(),
            'diubah_oleh': FirebaseAuth.instance.currentUser?.uid ?? '',
          });
        }

        // Invalidate cache
        _bukuCache = null;
      }

      // Send notification to student
      if (uidSiswa != null && uidSiswa!.isNotEmpty && judulBuku != null) {
        final appNotificationService = AppNotificationService();

        String notifTitle;
        String notifBody;
        String notifType;

        if (jumlahRusak > 0 && jumlahHilang > 0) {
          notifTitle = 'Peringatan: Buku Rusak dan Hilang';
          notifBody =
              'Buku "$judulBuku"$kelasInfo dikembalikan dengan:\n'
              '• $jumlahRusak buku dalam kondisi RUSAK\n'
              '• $jumlahHilang buku dilaporkan HILANG\n\n'
              'Peringatan: Harap lebih menjaga buku perpustakaan.';
          notifType = 'peringatan_kondisi';
        } else if (jumlahRusak > 0) {
          notifTitle = 'Peringatan: Buku Dikembalikan Rusak';
          notifBody =
              'Buku "$judulBuku"$kelasInfo: $jumlahRusak dari ${totalKembali} buku dikembalikan dalam kondisi RUSAK.\n\n'
              'Peringatan: Harap menjaga buku perpustakaan dengan baik.';
          notifType = 'peringatan_kondisi';
        } else if (jumlahHilang > 0) {
          notifTitle = 'Peringatan: Buku Dilaporkan Hilang';
          notifBody =
              'Buku "$judulBuku"$kelasInfo: $jumlahHilang dari ${totalKembali} buku dilaporkan HILANG.\n\n'
              'Peringatan: Kehilangan buku perpustakaan adalah pelanggaran serius.';
          notifType = 'peringatan_kondisi';
        } else if (isTerlambat) {
          notifTitle = 'Buku Dikembalikan - Terlambat';
          notifBody =
              'Buku "$judulBuku"$kelasInfo ($totalKembali buku) telah dikembalikan dengan keterlambatan.\nPeringatan: Harap mengembalikan buku tepat waktu di lain kesempatan.';
          notifType = 'keterlambatan';
        } else {
          notifTitle = 'Buku Berhasil Dikembalikan';
          notifBody =
              'Buku "$judulBuku"$kelasInfo ($totalKembali buku) telah berhasil dikembalikan dalam kondisi baik. Terima kasih!';
          notifType = 'pengembalian';
        }

        await appNotificationService.createNotification(
          userId: uidSiswa!,
          title: notifTitle,
          body: notifBody,
          type: notifType,
          data: {
            'buku_id': bukuId,
            'judul_buku': judulBuku,
            'jumlah_baik': jumlahBaik,
            'jumlah_rusak': jumlahRusak,
            'jumlah_hilang': jumlahHilang,
            'peminjaman_id': peminjamanId,
            'is_terlambat': isTerlambat,
          },
        );
      }
    } catch (e) {
      throw Exception('Gagal mengembalikan buku: $e');
    }
  }

  /// **Module 3: Reporting**
  /// Get all books currently marked as 'Rusak' or 'Hilang'
  Future<List<BukuModel>> getBukuRusakHilang() async {
    try {
      final snapshot =
          await _firestore
              .collection(_collection)
              .where('status_kondisi', whereIn: ['Rusak', 'Hilang'])
              .orderBy('tanggal_status_kondisi', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        return BukuModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      // Firestore composite index may not exist yet — fallback to client-side filter
      try {
        final snapshot = await _firestore.collection(_collection).get();
        return snapshot.docs
            .map((doc) => BukuModel.fromMap(doc.data(), doc.id))
            .where(
              (b) => b.statusKondisi == 'Rusak' || b.statusKondisi == 'Hilang',
            )
            .toList();
      } catch (e2) {
        throw Exception('Gagal mengambil data buku rusak/hilang: $e2');
      }
    }
  }

  /// Get the full condition-change history for reporting
  Future<List<Map<String, dynamic>>> getRiwayatKondisiBuku() async {
    try {
      final snapshot =
          await _firestore
              .collection('riwayat_kondisi_buku')
              .orderBy('tanggal', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      throw Exception('Gagal mengambil riwayat kondisi buku: $e');
    }
  }

  /// Get all peminjaman records where book was returned damaged or lost
  Future<List<PeminjamanModel>> getPeminjamanDenganKondisiBuruk() async {
    try {
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('kondisi_buku', whereIn: ['Rusak', 'Hilang'])
              .get();

      return snapshot.docs.map((doc) {
        return PeminjamanModel.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      // Fallback: client-side filter
      try {
        final snapshot =
            await _firestore.collection(_peminjamanCollection).get();
        return snapshot.docs
            .map((doc) => PeminjamanModel.fromMap(doc.data(), doc.id))
            .where((p) => p.kondisiBuku == 'Rusak' || p.kondisiBuku == 'Hilang')
            .toList();
      } catch (e2) {
        throw Exception(
          'Gagal mengambil data peminjaman dengan kondisi buruk: $e2',
        );
      }
    }
  }
}
