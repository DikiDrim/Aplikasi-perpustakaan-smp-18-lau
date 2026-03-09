import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../services/clodinary_service.dart';

class ProfilSiswaScreen extends StatefulWidget {
  const ProfilSiswaScreen({super.key});

  @override
  State<ProfilSiswaScreen> createState() => _ProfilSiswaScreenState();
}

class _ProfilSiswaScreenState extends State<ProfilSiswaScreen> {
  final ClodinaryService _cloudinaryService = ClodinaryService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _nisController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  String? _selectedKelas;

  // Daftar kelas SMP
  final List<String> _kelasList = [
    'VII-A',
    'VII-B',
    'VII-C',
    'VII-D',
    'VIII-A',
    'VIII-B',
    'VIII-C',
    'VIII-D',
    'IX-A',
    'IX-B',
    'IX-C',
    'IX-D',
  ];

  User? _currentUser;
  Map<String, dynamic>? _userData;
  String? _photoUrl;
  String? _photoPublicId;
  bool _loading = true;
  bool _saving = false;
  bool _isPrinting = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _loading = true);
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser == null) return;

      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .get();

      if (userDoc.exists) {
        _userData = userDoc.data();
        _namaController.text = _userData!['nama'] ?? '';
        _nisController.text = _userData!['nis'] ?? '';
        _usernameController.text = _userData!['username'] ?? '';
        _emailController.text = _userData!['email'] ?? '';
        _photoUrl = _userData!['photo_url'];
        _photoPublicId = _userData!['photo_public_id'];
        _selectedKelas = _userData!['kelas'];
        if (_selectedKelas != null && _selectedKelas!.isEmpty) {
          _selectedKelas = null;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      // Pastikan source adalah camera, bukan gallery
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1080,
        maxHeight: 1080,
        preferredCameraDevice:
            CameraDevice
                .front, // Default gunakan kamera depan untuk foto profil
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengambil foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Pilih Sumber Foto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Galeri'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Kamera'),
                  onTap: () {
                    Navigator.pop(context);
                    _takePhoto();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;

    setState(() => _saving = true);

    try {
      String? newPhotoUrl = _photoUrl;
      String? newPhotoPublicId = _photoPublicId;

      // Upload foto jika ada gambar baru
      if (_selectedImage != null) {
        final imageFile = XFile(_selectedImage!.path);

        // Selalu upload sebagai file baru (tanpa publicId lama)
        // agar tidak gagal jika preset Cloudinary tidak izinkan overwrite
        final result = await _cloudinaryService.uploadImageToCloudinary(
          imageFile,
          null,
        );

        newPhotoUrl = result?['url'];
        newPhotoPublicId = result?['publicId'];

        // Hapus foto lama jika berhasil upload foto baru
        if (_photoPublicId != null &&
            _photoPublicId!.isNotEmpty &&
            newPhotoPublicId != null) {
          try {
            await _cloudinaryService.deleteImageByPublicId(_photoPublicId!);
          } catch (_) {
            // Abaikan error hapus foto lama, yang penting foto baru sudah terupload
          }
        }
      }

      // Update data di Firestore - foto dan kelas
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update({
            // 'nama': TIDAK diupdate - siswa tidak bisa mengubah nama
            'photo_url': newPhotoUrl,
            'photo_public_id': newPhotoPublicId,
            'kelas': _selectedKelas ?? '',
            'updated_at': FieldValue.serverTimestamp(),
          });

      // Update juga di collection siswa jika ada - HANYA foto
      final siswaQuery =
          await FirebaseFirestore.instance
              .collection('siswa')
              .where('uid', isEqualTo: _currentUser!.uid)
              .limit(1)
              .get();

      if (siswaQuery.docs.isNotEmpty) {
        await siswaQuery.docs.first.reference.update({
          // 'nama': TIDAK diupdate - siswa tidak bisa mengubah nama
          'photo_url': newPhotoUrl,
          'photo_public_id': newPhotoPublicId,
          'kelas': _selectedKelas ?? '',
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      setState(() {
        _photoUrl = newPhotoUrl;
        _photoPublicId = newPhotoPublicId;
        _selectedImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Print data siswa dengan desain profesional
  Future<void> _printDataSiswa() async {
    if (_isPrinting || _userData == null) return;

    setState(() => _isPrinting = true);

    try {
      final pdf = pw.Document();
      final primaryColor = PdfColor.fromHex('#0D47A1');
      final lightBlue = PdfColor.fromHex('#E3F2FD');
      final now = DateTime.now();
      final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(now);
      final formattedTime = DateFormat('HH:mm').format(now);

      // Try to load school logo
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load(
          'assets/images/perpustakaan1.jpeg',
        );
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {}

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // === HEADER WITH BORDER ===
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: primaryColor, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 60,
                          height: 60,
                          child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                        ),
                      if (logoImage != null) pw.SizedBox(width: 16),
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'PERPUSTAKAAN SMPN 18 LAU',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'KARTU DATA ANGGOTA PERPUSTAKAAN',
                              style: pw.TextStyle(
                                fontSize: 13,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(
                              height: 2,
                              width: 200,
                              color: primaryColor,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // === DATA ANGGOTA TABLE ===
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    children: [
                      // Table header
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 16,
                        ),
                        decoration: pw.BoxDecoration(
                          color: primaryColor,
                          borderRadius: const pw.BorderRadius.only(
                            topLeft: pw.Radius.circular(3),
                            topRight: pw.Radius.circular(3),
                          ),
                        ),
                        child: pw.Text(
                          'DATA PRIBADI ANGGOTA',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      // Rows
                      _buildPdfTableRow(
                        'Nama Lengkap',
                        _userData!['nama'] ?? '-',
                        false,
                      ),
                      _buildPdfTableRow('NIS', _userData!['nis'] ?? '-', true),
                      _buildPdfTableRow(
                        'Kelas',
                        (_selectedKelas != null && _selectedKelas!.isNotEmpty)
                            ? _selectedKelas!
                            : '-',
                        false,
                      ),
                      _buildPdfTableRow(
                        'Username',
                        _userData!['username'] ?? '-',
                        true,
                      ),
                      _buildPdfTableRow(
                        'Email',
                        _userData!['email'] ?? '-',
                        false,
                      ),
                      _buildPdfTableRow('Status', 'Anggota Aktif', true),
                    ],
                  ),
                ),
                pw.SizedBox(height: 30),

                // === CATATAN ===
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightBlue,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('#90CAF9')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Catatan:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '• Kartu ini merupakan bukti keanggotaan perpustakaan SMPN 18 LAU.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '• Kartu ini bersifat pribadi dan tidak dapat dipindahtangankan.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        '• Jaga baik-baik kartu ini dan laporkan jika terjadi kehilangan.',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),

                pw.Spacer(),

                // === FOOTER: TTD + Tanggal ===
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Dicetak pada:',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600,
                          ),
                        ),
                        pw.Text(
                          '$formattedDate, $formattedTime WIB',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'Mengetahui,',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'Petugas Perpustakaan',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 50),
                        pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(width: 1)),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'NIP. .............................',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF berhasil dibuat'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  pw.Widget _buildPdfTableRow(String label, String value, bool isShaded) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        color: isShaded ? PdfColor.fromHex('#F5F5F5') : null,
        border: const pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Saya')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil Saya')),
        body: const Center(child: Text('Anda belum login')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Saya')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto Profil
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[300],
                    backgroundImage:
                        _selectedImage != null
                            ? FileImage(_selectedImage!)
                            : _photoUrl != null
                            ? NetworkImage(_photoUrl!)
                            : null,
                    child:
                        _selectedImage == null && _photoUrl == null
                            ? const Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey,
                            )
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D47A1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                        onPressed: _showImageSourceDialog,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Form Data
            TextFormField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                helperText:
                    'Nama tidak dapat diubah. Hubungi admin untuk perubahan nama.',
                helperStyle: TextStyle(fontSize: 12),
              ),
              enabled: false, // Nama tidak bisa diubah
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nisController,
              decoration: const InputDecoration(
                labelText: 'NIS',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              enabled: false, // NIS tidak bisa diubah
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.alternate_email),
              ),
              enabled: false, // Username tidak bisa diubah
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              enabled: false, // Email tidak bisa diubah
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedKelas,
              decoration: const InputDecoration(
                labelText: 'Kelas',
                hintText: 'Pilih kelas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.class_),
                helperText: 'Ubah kelas saat naik kelas',
                helperStyle: TextStyle(fontSize: 12),
              ),
              items:
                  _kelasList.map((kelas) {
                    return DropdownMenuItem<String>(
                      value: kelas,
                      child: Text(kelas),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => _selectedKelas = value);
              },
            ),
            const SizedBox(height: 24),
            // Tombol Print Data Anggota
            ElevatedButton.icon(
              onPressed: _isPrinting ? null : _printDataSiswa,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.green,
              ),
              icon:
                  _isPrinting
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Mencetak...' : 'Print Data Anggota'),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Anda dapat mengubah foto profil dan kelas. Untuk mengubah nama, hubungi admin.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF0D47A1),
              ),
              child:
                  _saving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : const Text(
                        'Simpan Perubahan',
                        style: TextStyle(fontSize: 16),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
