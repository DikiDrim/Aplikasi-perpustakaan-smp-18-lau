import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Top-level background message handler required by `firebase_messaging`.
/// This runs in its own isolate and should only perform lightweight work.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  try {
    final data = message.data;
    final userId = (data['user_id'] ?? data['userId']) as String?;
    if (userId != null && userId.isNotEmpty) {
      await FirebaseFirestore.instance.collection('notifications').add({
        'user_id': userId,
        'title': message.notification?.title ?? data['title'] ?? '',
        'body': message.notification?.body ?? data['body'] ?? '',
        'type': data['type'] ?? 'fcm',
        'status': 'unread',
        'timestamp': FieldValue.serverTimestamp(),
        'data': data,
      });
    }
  } catch (_) {
    // Swallow errors in background handler
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Call this on app startup (after Firebase.initializeApp)
  static Future<void> init() async {
    // Request permission on iOS (no-op on Android)
    await _messaging.requestPermission();

    // Get token and save
    await _saveTokenToFirestore();

    // Refresh token handling
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      await _saveToken(token);
    });

    // (Optional) background message handler should be set in main.dart if needed
  }

  static Future<void> _saveTokenToFirestore() async {
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  static Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      await docRef.update({
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // If update fails because doc doesn't exist, set it
      try {
        await docRef.set({
          'fcm_tokens': [token],
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  /// Remove token when user signs out or token invalidated
  static Future<void> removeToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final docRef = _firestore.collection('users').doc(user.uid);
    try {
      await docRef.update({
        'fcm_tokens': FieldValue.arrayRemove([token]),
      });
    } catch (_) {}
  }
}
