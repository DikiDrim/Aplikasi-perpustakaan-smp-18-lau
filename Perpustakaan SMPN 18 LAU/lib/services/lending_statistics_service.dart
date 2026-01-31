import 'package:cloud_firestore/cloud_firestore.dart';

/// Service untuk menghitung statistik peminjaman per-hari dan per-bulan
/// Mendukung desain ARS dengan tracking peminjaman yang terukur
class LendingStatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final String _peminjamanCollection = 'peminjaman';
  final String _statisticsSubcollection = 'lending_statistics';

  /// Hitung total peminjaman hari ini untuk sebuah buku
  /// Returns count transaksi peminjaman dalam 24 jam terakhir (00:00 - 23:59)
  Future<int> getTotalLoansTodayForBook(String bukuId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final startOfNextDay = startOfDay.add(const Duration(days: 1));

      print('[LendingStats] Ambil peminjaman: $bukuId');
      print('[LendingStats] Range: $startOfDay hingga $startOfNextDay');

      // Query SEMUA peminjaman untuk buku ini (tanpa filter tanggal di query)
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .get();

      print('[LendingStats] Total docs ditemukan: ${snapshot.docs.length}');

      int totalLoans = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final tanggalPinjamRaw = data['tanggal_pinjam'];

        DateTime tanggalPinjam;
        if (tanggalPinjamRaw is Timestamp) {
          tanggalPinjam = tanggalPinjamRaw.toDate();
        } else if (tanggalPinjamRaw is DateTime) {
          tanggalPinjam = tanggalPinjamRaw;
        } else {
          continue;
        }

        // Filter client-side: hanya ambil peminjaman yang tanggalnya hari ini
        final tanggalPinjamDate = DateTime(
          tanggalPinjam.year,
          tanggalPinjam.month,
          tanggalPinjam.day,
        );
        final todayDate = DateTime(
          startOfDay.year,
          startOfDay.month,
          startOfDay.day,
        );

        if (tanggalPinjamDate.isAtSameMomentAs(todayDate)) {
          final jumlah = data['jumlah'] ?? 1;
          totalLoans += (jumlah as num).toInt();
          print(
            '[LendingStats] ✓ Dihitung: tanggal=$tanggalPinjam, jumlah=$jumlah',
          );
        } else {
          print(
            '[LendingStats] ✗ Tidak dihitung: tanggal=$tanggalPinjam (bukan hari ini)',
          );
        }
      }

      print('[LendingStats] Total peminjaman hari ini: $totalLoans');
      return totalLoans;
    } catch (e) {
      print('[LendingStats] ❌ Error: $e');
      return 0;
    }
  }

  /// Hitung total peminjaman bulan ini untuk sebuah buku
  /// Returns count transaksi peminjaman dalam bulan kalender saat ini
  Future<int> getTotalLoansThisMonthForBook(String bukuId) async {
    try {
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayOfNextMonth =
          now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1);

      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .where('tanggal_pinjam', isGreaterThanOrEqualTo: firstDayOfMonth)
              .where('tanggal_pinjam', isLessThan: firstDayOfNextMonth)
              .get();

      int totalLoans = 0;
      for (final doc in snapshot.docs) {
        final jumlah = doc.data()['jumlah'] ?? 1;
        totalLoans += (jumlah as num).toInt();
      }

      return totalLoans;
    } catch (e) {
      print('Error menghitung total loans bulan ini: $e');
      return 0;
    }
  }

  /// Hitung total peminjaman dalam range tanggal tertentu
  /// Digunakan untuk perhitungan ARS dan analisis historis
  Future<int> getTotalLoansInRange(
    String bukuId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .where('tanggal_pinjam', isGreaterThanOrEqualTo: startDate)
              .where('tanggal_pinjam', isLessThanOrEqualTo: endDate)
              .get();

      int totalLoans = 0;
      for (final doc in snapshot.docs) {
        final jumlah = doc.data()['jumlah'] ?? 1;
        totalLoans += (jumlah as num).toInt();
      }

      return totalLoans;
    } catch (e) {
      print('Error menghitung total loans dalam range: $e');
      return 0;
    }
  }

  /// Dapatkan breakdown peminjaman per-hari dalam range tertentu
  /// Returns list: [{date: "2026-01-30", count: 5}, ...]
  Future<List<Map<String, dynamic>>> getLoanDailyBreakdown(
    String bukuId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .where('tanggal_pinjam', isGreaterThanOrEqualTo: startDate)
              .where('tanggal_pinjam', isLessThanOrEqualTo: endDate)
              .get();

      // Group by date
      final Map<String, int> dailyBreakdown = {};
      for (final doc in snapshot.docs) {
        final tanggalPinjam =
            (doc.data()['tanggal_pinjam'] as Timestamp).toDate();
        final dateKey =
            '${tanggalPinjam.year}-${tanggalPinjam.month.toString().padLeft(2, '0')}-${tanggalPinjam.day.toString().padLeft(2, '0')}';
        final jumlah = (doc.data()['jumlah'] ?? 1) as num;

        dailyBreakdown[dateKey] =
            (dailyBreakdown[dateKey] ?? 0) + jumlah.toInt();
      }

      // Convert to list and sort
      final result =
          dailyBreakdown.entries
              .map((e) => {'date': e.key, 'count': e.value})
              .toList();
      result.sort(
        (a, b) => (a['date'] as String).compareTo(b['date'] as String),
      );

      return result;
    } catch (e) {
      print('Error mendapatkan daily breakdown: $e');
      return [];
    }
  }

  /// Update monthly statistics untuk buku
  /// Dipanggil once per day atau on-demand untuk agregasi bulanan
  Future<void> updateMonthlyStatistics(String bukuId) async {
    try {
      final now = DateTime.now();
      final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final firstDayOfNextMonth =
          now.month == 12
              ? DateTime(now.year + 1, 1, 1)
              : DateTime(now.year, now.month + 1, 1);

      // Query semua peminjaman bulan ini
      final snapshot =
          await _firestore
              .collection(_peminjamanCollection)
              .where('buku_id', isEqualTo: bukuId)
              .where('tanggal_pinjam', isGreaterThanOrEqualTo: firstDayOfMonth)
              .where('tanggal_pinjam', isLessThan: firstDayOfNextMonth)
              .get();

      int totalLoans = 0;
      final Set<String> uniqueBorrowers = {};
      final Map<String, int> dailyBreakdown = {};
      int peakCount = 0;
      String peakDate = '';

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final jumlah = (data['jumlah'] ?? 1) as num;
        final tanggalPinjam = (data['tanggal_pinjam'] as Timestamp).toDate();
        final uidSiswa = data['uid_siswa'] ?? '';

        totalLoans += jumlah.toInt();
        if (uidSiswa.isNotEmpty) uniqueBorrowers.add(uidSiswa);

        // Daily breakdown
        final dateKey =
            '${tanggalPinjam.year}-${tanggalPinjam.month.toString().padLeft(2, '0')}-${tanggalPinjam.day.toString().padLeft(2, '0')}';
        final dayCount = (dailyBreakdown[dateKey] ?? 0) + jumlah.toInt();
        dailyBreakdown[dateKey] = dayCount;

        // Track peak
        if (dayCount > peakCount) {
          peakCount = dayCount;
          peakDate = dateKey;
        }
      }

      // Save to sub-collection
      final docRef = _firestore
          .collection('books')
          .doc(bukuId)
          .collection(_statisticsSubcollection)
          .doc(monthKey);

      await docRef.set({
        'month': monthKey,
        'total_loans': totalLoans,
        'unique_borrowers': uniqueBorrowers.length,
        'peak_date': peakDate,
        'peak_count': peakCount,
        'daily_breakdown':
            dailyBreakdown.entries
                .map((e) => {'date': e.key, 'count': e.value})
                .toList(),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating monthly statistics: $e');
    }
  }

  /// Dapatkan statistik bulanan untuk buku
  Future<Map<String, dynamic>?> getMonthlyStatistics(
    String bukuId,
    String monthKey, // format: "2026-01"
  ) async {
    try {
      final doc =
          await _firestore
              .collection('books')
              .doc(bukuId)
              .collection(_statisticsSubcollection)
              .doc(monthKey)
              .get();

      if (!doc.exists) return null;

      return doc.data();
    } catch (e) {
      print('Error getting monthly statistics: $e');
      return null;
    }
  }

  /// Dapatkan semua statistik bulanan untuk buku (last N months)
  Future<List<Map<String, dynamic>>> getMonthlyStatisticsHistory(
    String bukuId, {
    int monthsBack = 6,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection('books')
              .doc(bukuId)
              .collection(_statisticsSubcollection)
              .orderBy('month', descending: true)
              .limit(monthsBack)
              .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting monthly statistics history: $e');
      return [];
    }
  }

  /// Helper: Get date in correct format for Firestore queries
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Helper: Get first day of month
  static DateTime getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  /// Helper: Get first day of next month (exclusive end for queries)
  static DateTime getFirstDayOfNextMonth(DateTime date) {
    return date.month == 12
        ? DateTime(date.year + 1, 1, 1)
        : DateTime(date.year, date.month + 1, 1);
  }
}
