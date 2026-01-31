import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/global_loading_provider.dart';

/// Wrap any async action with a global loading overlay and minimal delay.
Future<T> runWithLoading<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? message,
  Duration minDelay = const Duration(milliseconds: 300),
}) async {
  final loading = context.read<GlobalLoading>();
  loading.start(message: message);
  final sw = Stopwatch()..start();
  try {
    final result = await action();
    final elapsed = sw.elapsed;
    if (elapsed < minDelay) {
      await Future.delayed(minDelay - elapsed);
    }
    return result;
  } catch (e) {
    // Tutup loading dan tampilkan error
    loading.end();

    if (context.mounted) {
      final message = getFriendlyErrorMessage(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    rethrow;
  } finally {
    loading.end();
  }
}

/// Convert general exceptions into user-friendly message
String getFriendlyErrorMessage(Object exception) {
  final raw = exception.toString();

  if (exception is FirebaseAuthException || raw.contains('firebase_auth/')) {
    return getFriendlyAuthMessage(exception);
  }

  if (raw.contains('FirebaseException') ||
      raw.contains('PlatformException') ||
      raw.contains('cloud_firestore')) {
    return 'Terjadi kesalahan. Coba lagi.';
  }

  if (raw.startsWith('Exception: ')) {
    return raw.substring(10);
  }

  return raw;
}

/// Convert Firebase auth exception to user-friendly Indonesian message
String getFriendlyAuthMessage(Object exception) {
  try {
    String? code;
    if (exception is FirebaseAuthException) {
      code = exception.code;
    } else {
      final msg = exception.toString();
      final match = RegExp(r'\[firebase_auth/([^\]]+)\]').firstMatch(msg);
      code = match?.group(1);
    }

    switch (code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah. Coba lagi.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun dinonaktifkan. Hubungi admin.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Username atau password salah.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      default:
        return 'Gagal masuk. Coba lagi.';
    }
  } catch (_) {
    return 'Gagal masuk. Coba lagi.';
  }
}
