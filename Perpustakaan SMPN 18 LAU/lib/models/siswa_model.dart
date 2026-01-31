import 'package:cloud_firestore/cloud_firestore.dart';

class SiswaModel {
  final String? id;
  final String nama;
  final String nis; // 6 digit
  final String username; // Format: 3 huruf nama + 3 digit (contoh: reh001)
  final String email;
  final String uid; // Firebase Auth UID
  final DateTime createdAt;

  SiswaModel({
    this.id,
    required this.nama,
    required this.nis,
    required this.username,
    required this.email,
    required this.uid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'nama': nama,
      'nis': nis,
      'username': username,
      'email': email,
      'uid': uid,
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  factory SiswaModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime createdAt;
    if (map['created_at'] != null) {
      if (map['created_at'] is Timestamp) {
        createdAt = (map['created_at'] as Timestamp).toDate();
      } else if (map['created_at'] is String) {
        createdAt = DateTime.parse(map['created_at']);
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }

    return SiswaModel(
      id: id,
      nama: map['nama'] ?? '',
      nis: map['nis'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      uid: map['uid'] ?? '',
      createdAt: createdAt,
    );
  }
}
