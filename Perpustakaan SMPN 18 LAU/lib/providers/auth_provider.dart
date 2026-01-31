import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? currentUser;
  String? role; // 'admin' or 'siswa'
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeAuthState();
  }

  /// Initialize auth state listener
  void _initializeAuthState() {
    _authService.authStateChanges.listen((user) async {
      currentUser = user;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        role = doc.data()?['role'];
      } else {
        role = null;
      }
      _isInitialized = true;
      notifyListeners();
    });
  }

  /// Sign in with email and password
  /// State updates automatically via auth state listener
  Future<void> signIn(String email, String password) async {
    await _authService.signIn(email, password);
  }

  /// Sign in with username and password
  /// State updates automatically via auth state listener
  Future<void> signInWithUsername(String username, String password) async {
    await _authService.signInWithUsername(username, password);
  }

  /// Register a new admin user
  /// State updates automatically via auth state listener
  Future<void> registerAdmin({
    required String email,
    required String password,
    required String nama,
  }) async {
    final cred = await _authService.register(email, password);
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'role': 'admin',
      'nama': nama,
      'uid': cred.user!.uid,
    });
  }

  /// Sign out current user
  /// State updates automatically via auth state listener
  Future<void> signOut() async {
    await _authService.signOut();
  }
}
