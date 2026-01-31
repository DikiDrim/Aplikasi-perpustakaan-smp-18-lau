import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Login siswa menggunakan username (bukan email lengkap)
  // Username akan dikonversi ke email format: username@siswa.smpn18lau.sch.id
  Future<UserCredential> signInWithUsername(
    String username,
    String password,
  ) async {
    // Jika username sudah mengandung @, gunakan langsung
    // Jika tidak, tambahkan @siswa.smpn18lau.sch.id
    final email =
        username.contains('@') ? username : '$username@siswa.smpn18lau.sch.id';

    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> register(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Membuat akun siswa dengan username dan password
  // PENTING: Menggunakan secondary Firebase App agar admin tidak logout
  Future<UserCredential> createStudentAccount(
    String username,
    String nis,
  ) async {
    final email = '$username@siswa.smpn18lau.sch.id';
    final password = nis; // Password adalah NIS (6 digit)

    // Buat secondary Firebase App untuk membuat akun tanpa mempengaruhi session admin
    FirebaseApp? secondaryApp;
    try {
      // Cek apakah secondary app sudah ada
      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (e) {
        // Jika belum ada, buat baru dengan options yang sama
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      // Gunakan secondary app untuk membuat akun
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final newUserCredential = await secondaryAuth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Sign out dari secondary app (tidak mempengaruhi primary app)
      await secondaryAuth.signOut();

      return newUserCredential;
    } catch (e) {
      rethrow;
    }
  }
}
