import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Utility untuk membuat akun admin khusus
/// Email: smpn18lau@gmail.com
/// Password: SMPN18LAU
///
/// PENTING: Jalankan fungsi ini sekali saja untuk membuat akun admin.
/// Bisa dipanggil dari main.dart atau dari screen khusus setup.
class AdminSetup {
  static const String adminEmail = 'smpn18lau@gmail.com';
  static const String adminPassword = 'SMPN18LAU';

  /// Membuat akun admin khusus jika belum ada
  /// Return true jika berhasil membuat, false jika sudah ada
  static Future<bool> createAdminAccount() async {
    try {
      final auth = FirebaseAuth.instance;
      final firestore = FirebaseFirestore.instance;

      // Cek apakah admin sudah ada di Firestore
      final adminQuery =
          await firestore
              .collection('users')
              .where('email', isEqualTo: adminEmail)
              .where('role', isEqualTo: 'admin')
              .limit(1)
              .get();

      if (adminQuery.docs.isNotEmpty) {
        debugPrint('Admin account already exists in Firestore');
        return false;
      }

      // Cek apakah email sudah terdaftar di Firebase Auth
      try {
        await auth.signInWithEmailAndPassword(
          email: adminEmail,
          password: adminPassword,
        );
        // Jika berhasil login, berarti akun sudah ada
        debugPrint('Admin account already exists in Firebase Auth');
        await auth.signOut();
        return false;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // Akun belum ada atau password salah, lanjutkan membuat
        } else {
          rethrow;
        }
      }

      // Buat akun Firebase Auth
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      final uid = userCredential.user!.uid;

      // Simpan ke Firestore dengan role admin
      await firestore.collection('users').doc(uid).set({
        'email': adminEmail,
        'role': 'admin',
        'nama': 'Admin SMPN 18 LAU',
        'uid': uid,
        'is_system_admin': true, // Flag untuk membedakan admin khusus
        'created_at': FieldValue.serverTimestamp(),
      });

      debugPrint('Admin account created successfully!');
      debugPrint('Email: $adminEmail');
      debugPrint('Password: $adminPassword');

      // Sign out setelah membuat
      await auth.signOut();

      return true;
    } catch (e) {
      debugPrint('Error creating admin account: $e');
      rethrow;
    }
  }
}
