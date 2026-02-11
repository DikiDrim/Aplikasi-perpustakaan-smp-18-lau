import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/clodinary_service.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';

class EditBukuScreen extends StatefulWidget {
  final BukuModel buku;

  const EditBukuScreen({super.key, required this.buku});

  @override
  State<EditBukuScreen> createState() => _EditBukuScreenState();
}

class _EditBukuScreenState extends State<EditBukuScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _judulController;
  late final TextEditingController _pengarangController;
  late final TextEditingController _tahunController;
  late final TextEditingController _isbnController;
  late final TextEditingController _stokController;
  late final TextEditingController _kategoriController;
  late final TextEditingController _deskripsiController;
  late final TextEditingController _bookFileUrlController;
  XFile? _pickedImage;
  File? _pickedBookFile;
  Uint8List? _pickedBookBytes;
  String? _pickedBookFileName;
  bool _isUploadingImage = false;
  bool _isUploadingBookFile = false;
  String? _kategoriSelected;
  late final FirestoreService _service;
  String? _currentCoverUrl;
  String? _currentCoverPublicId;
  String? _currentBookFileUrl;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();

    // Initialize controllers with existing data
    _judulController = TextEditingController(text: widget.buku.judul);
    _pengarangController = TextEditingController(text: widget.buku.pengarang);
    _tahunController = TextEditingController(
      text: widget.buku.tahun.toString(),
    );
    _isbnController = TextEditingController(text: widget.buku.isbn ?? '');
    _stokController = TextEditingController(text: widget.buku.stok.toString());
    _kategoriController = TextEditingController();
    _deskripsiController = TextEditingController(
      text: widget.buku.deskripsi ?? '',
    );
    _bookFileUrlController = TextEditingController(
      text: widget.buku.bookFileUrl ?? '',
    );

    // Set existing values
    _kategoriSelected = widget.buku.kategori;
    _currentCoverUrl = widget.buku.coverUrl;
    _currentCoverPublicId = widget.buku.coverPublicId;
    _currentBookFileUrl = widget.buku.bookFileUrl;
  }

  @override
  void dispose() {
    _judulController.dispose();
    _pengarangController.dispose();
    _tahunController.dispose();
    _isbnController.dispose();
    _stokController.dispose();
    _kategoriController.dispose();
    _deskripsiController.dispose();
    _bookFileUrlController.dispose();
    super.dispose();
  }

  void _openManageCategories() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => _ManageCategoriesModal(
            service: _service,
            onCategoryAdded: (category) {
              setState(() => _kategoriSelected ??= category);
            },
            onCategorySelected: () {
              // Category selection will be handled by the modal's onTap
            },
          ),
    ).then((selectedCategory) {
      if (selectedCategory != null && selectedCategory is String) {
        setState(() => _kategoriSelected = selectedCategory);
      }
    });
  }

  /// Upload cover image to Cloudinary and return map with 'url' and 'publicId'
  Future<Map<String, String>?> _uploadCoverIfAny() async {
    if (_pickedImage == null) return null;
    try {
      if (mounted) setState(() => _isUploadingImage = true);
      final cl = ClodinaryService();
      final res = await cl.uploadImageToCloudinary(_pickedImage!, null);
      return res; // {'url':..., 'publicId':...}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat unggah foto ke Cloudinary: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  /// Pick image for cover
  Future<void> _pickCoverImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  /// Pick PDF file untuk buku
  Future<void> _pickBookFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        // Use different handling for web vs non-web: on web `path` is unavailable
        // and accessing it may throw. Use `bytes` on web.
        if (kIsWeb) {
          if (file.bytes != null) {
            setState(() {
              _pickedBookBytes = file.bytes;
              _pickedBookFileName = file.name;
              _pickedBookFile = null;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File dipilih: ${file.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Gagal membaca file di web')),
              );
            }
          }
        } else {
          if (file.path != null) {
            setState(() {
              _pickedBookFile = File(file.path!);
              _pickedBookBytes = null;
              _pickedBookFileName = file.name;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File dipilih: ${file.name}'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File tidak memiliki path atau bytes'),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error memilih file: $e')));
      }
    }
  }

  /// Upload file buku ke Firebase Storage
  Future<String?> _uploadBookFile(String bukuId) async {
    try {
      if (mounted) setState(() => _isUploadingBookFile = true);

      // Web: upload from bytes
      if (kIsWeb) {
        if (_pickedBookBytes == null || _pickedBookFileName == null)
          return null;
        final fileUrl = await _firestoreService.uploadBookFileBytes(
          _pickedBookBytes!,
          _pickedBookFileName!,
          bukuId,
        );
        return fileUrl;
      }

      // Non-web: upload from File
      if (_pickedBookFile == null) return null;
      final fileUrl = await _firestoreService.uploadBookFile(
        _pickedBookFile!,
        bukuId,
      );
      return fileUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saat unggah file buku: $e')),
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingBookFile = false);
    }
  }

  Future<void> _updateBuku() async {
    if (!_formKey.currentState!.validate()) return;

    await runWithLoading(context, () async {
      // Upload cover baru jika ada
      String? coverUrl = _currentCoverUrl;
      String? coverPublicId = _currentCoverPublicId;

      if (_pickedImage != null) {
        // Hapus cover lama jika ada
        if (_currentCoverPublicId != null &&
            _currentCoverPublicId!.isNotEmpty) {
          final cl = ClodinaryService();
          await cl.deleteImageByPublicId(_currentCoverPublicId!);
        }

        // Upload cover baru
        final uploadRes = await _uploadCoverIfAny();
        if (uploadRes != null) {
          coverUrl = uploadRes['url'];
          coverPublicId = uploadRes['publicId'];
        }
      }

      // Upload file buku baru jika ada (sebelum update buku)
      String? finalBookFileUrl = _currentBookFileUrl;
      // Support both non-web File and web bytes selection
      if (_pickedBookFile != null || _pickedBookBytes != null) {
        final bookFileUrl = await _uploadBookFile(widget.buku.id!);
        if (bookFileUrl != null) {
          finalBookFileUrl = bookFileUrl;
        }
      } else if (_bookFileUrlController.text.trim().isNotEmpty) {
        // Jika ada URL yang diinput manual, gunakan URL tersebut
        finalBookFileUrl = _bookFileUrlController.text.trim();
      }

      final buku = BukuModel(
        id: widget.buku.id,
        judul: _judulController.text,
        pengarang: _pengarangController.text,
        tahun: int.parse(_tahunController.text),
        stok: int.parse(_stokController.text),
        kategori: _kategoriSelected ?? _kategoriController.text,
        deskripsi:
            _deskripsiController.text.isEmpty
                ? null
                : _deskripsiController.text,
        isbn: _isbnController.text.isEmpty ? null : _isbnController.text,
        coverUrl: coverUrl,
        coverPublicId: coverPublicId,
        totalPeminjaman: widget.buku.totalPeminjaman,
        bookFileUrl:
            finalBookFileUrl, // Use the final URL (existing or newly uploaded)
        // Preserve ARS-related fields from original book
        isArsEnabled: widget.buku.isArsEnabled,
        safetyStock: widget.buku.safetyStock,
        stokMinimum: widget.buku.stokMinimum,
        stokAwal: widget.buku.stokAwal,
        arsNotified: widget.buku.arsNotified,
      );

      // Update buku
      await _firestoreService.updateBuku(widget.buku.id!, buku);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buku berhasil diperbarui')),
        );
        Navigator.pop(context, true);
      }
    }, message: '');
  }

  /// Build cover image card with preview and upload button
  Widget _buildCoverImageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Material(
              elevation: 1,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 120,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                        image:
                            _pickedImage != null
                                ? DecorationImage(
                                  image: FileImage(File(_pickedImage!.path)),
                                  fit: BoxFit.cover,
                                )
                                : _currentCoverUrl != null &&
                                    _currentCoverUrl!.isNotEmpty
                                ? DecorationImage(
                                  image: NetworkImage(_currentCoverUrl!),
                                  fit: BoxFit.cover,
                                )
                                : null,
                      ),
                      child:
                          _pickedImage == null &&
                                  (_currentCoverUrl == null ||
                                      _currentCoverUrl!.isEmpty)
                              ? const Center(
                                child: Icon(
                                  Icons.photo,
                                  color: Colors.grey,
                                  size: 40,
                                ),
                              )
                              : null,
                    ),
                    if (_isUploadingImage)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilledButton.icon(
                    onPressed: _isUploadingImage ? null : _pickCoverImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Ubah Sampul'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Format: JPG/PNG. Ukuran disarankan: landscape',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_currentCoverUrl != null && _currentCoverUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Sampul saat ini akan diganti',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.orange),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build basic form fields section
  Widget _buildBasicFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _judulController,
          decoration: const InputDecoration(
            labelText: 'Judul Buku',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Judul buku harus diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pengarangController,
          decoration: const InputDecoration(
            labelText: 'Penerbit',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Penerbit harus diisi';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _deskripsiController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Deskripsi Buku (opsional)',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  /// Build PDF file upload card
  Widget _buildBookFileCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'File Buku Digital (PDF)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentBookFileUrl != null &&
                _currentBookFileUrl!.isNotEmpty &&
                _pickedBookFile == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'File PDF sudah ada',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Pilih file baru untuk mengganti',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (_pickedBookFile != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickedBookFile!.path.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _pickedBookFile = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else if (_pickedBookBytes != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _pickedBookFileName ?? 'File dipilih',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _pickedBookBytes = null;
                          _pickedBookFileName = null;
                        });
                      },
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _isUploadingBookFile ? null : _pickBookFile,
                icon: const Icon(Icons.upload_file),
                label: Text(
                  _currentBookFileUrl != null && _currentBookFileUrl!.isNotEmpty
                      ? 'Ganti File PDF'
                      : 'Pilih File PDF',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                ),
              ),
            if (_isUploadingBookFile)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            const SizedBox(height: 8),
            Text(
              'Format: PDF. File akan diunggah ke Cloudinary.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            // Opsi input URL manual (jika file sudah ada di Cloudinary)
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Atau masukkan URL PDF manual:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bookFileUrlController,
              decoration: InputDecoration(
                labelText: 'URL File PDF (dari Cloudinary)',
                hintText: 'https://res.cloudinary.com/...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon:
                    _bookFileUrlController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _bookFileUrlController.clear();
                            });
                          },
                        )
                        : null,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {
                  // Update state untuk refresh UI
                });
              },
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final uri = Uri.tryParse(value);
                  if (uri == null ||
                      (!value.startsWith('http://') &&
                          !value.startsWith('https://'))) {
                    return 'URL tidak valid';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Jika file PDF sudah ada di Cloudinary, copy URL-nya dan paste di sini.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check admin status once using read (not watch to avoid rebuild issues)
    final auth = context.read<AuthProvider>();
    final isAdmin = (auth.role == 'admin');

    // Proteksi: Hanya admin yang bisa akses
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Akses Ditolak'),
          backgroundColor: const Color(0xFF0D47A1),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Anda tidak memiliki izin untuk mengedit buku',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Edit Buku',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildCoverImageCard(),
              const SizedBox(height: 16),
              _buildBasicFormFields(),
              const SizedBox(height: 16),
              _buildBookFileCard(),
              const SizedBox(height: 16),
              StreamBuilder<List<String>>(
                stream: _service.getCategoriesStream(),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? const <String>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value:
                                  categories.contains(_kategoriSelected)
                                      ? _kategoriSelected
                                      : null,
                              decoration: const InputDecoration(
                                labelText: 'Kategori',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                ...categories.map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                ),
                                const DropdownMenuItem(
                                  value: '__ADD_NEW__',
                                  child: Text('+ Tambah kategori baru...'),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == '__ADD_NEW__') {
                                  final ctrl = TextEditingController();
                                  final ok = await showDialog<String>(
                                    context: context,
                                    builder:
                                        (dialogContext) => AlertDialog(
                                          title: const Text('Tambah Kategori'),
                                          content: TextField(
                                            controller: ctrl,
                                            decoration: const InputDecoration(
                                              labelText: 'Nama kategori',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    dialogContext,
                                                  ),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    dialogContext,
                                                    ctrl.text.trim(),
                                                  ),
                                              child: const Text('Simpan'),
                                            ),
                                          ],
                                        ),
                                  );
                                  ctrl.dispose();
                                  if (ok != null && ok.isNotEmpty) {
                                    await _service.addCategory(ok);
                                    if (mounted) {
                                      setState(() => _kategoriSelected = ok);
                                    }
                                  }
                                } else {
                                  setState(() => _kategoriSelected = v);
                                }
                              },
                              validator: (v) {
                                if ((v == null || v.isEmpty) &&
                                    _kategoriController.text.isEmpty) {
                                  return 'Kategori harus diisi';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Kelola kategori',
                            child: IconButton(
                              onPressed: () => _openManageCategories(),
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if ((_kategoriSelected == null ||
                              _kategoriSelected!.isEmpty) &&
                          categories.isEmpty)
                        TextFormField(
                          controller: _kategoriController,
                          decoration: const InputDecoration(
                            labelText: 'Kategori (baru)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _tahunController,
                decoration: const InputDecoration(
                  labelText: 'Tahun Terbit',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Tahun terbit harus diisi';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Tahun terbit harus berupa angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _isbnController,
                decoration: const InputDecoration(
                  labelText: 'ISBN (opsional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _stokController,
                decoration: const InputDecoration(
                  labelText: 'Stok',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Stok harus diisi';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Stok harus berupa angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!Throttle.allow('update_buku')) return;
                    await _updateBuku();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal widget untuk mengelola kategori buku
class _ManageCategoriesModal extends StatefulWidget {
  final FirestoreService service;
  final VoidCallback? onCategorySelected;
  final Function(String)? onCategoryAdded;

  const _ManageCategoriesModal({
    required this.service,
    this.onCategorySelected,
    this.onCategoryAdded,
  });

  @override
  State<_ManageCategoriesModal> createState() => _ManageCategoriesModalState();
}

class _ManageCategoriesModalState extends State<_ManageCategoriesModal> {
  late final TextEditingController _nameController;
  late final Stream<List<String>> _categoriesStream;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _categoriesStream = widget.service.getCategoriesStream();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _editCategory(String oldName) async {
    final editController = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit Kategori'),
            content: TextField(
              controller: editController,
              decoration: const InputDecoration(
                labelText: 'Nama kategori',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  final val = editController.text.trim();
                  if (val.isNotEmpty && val != oldName) {
                    Navigator.pop(dialogContext, val);
                  } else {
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          ),
    );
    editController.dispose();

    if (newName != null && newName.isNotEmpty && mounted) {
      await widget.service.updateCategory(oldName, newName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori berhasil diubah')),
        );
      }
    }
  }

  Future<void> _deleteCategory(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Hapus kategori?'),
            content: Text(
              'Kategori "$name" akan dihapus dari daftar. '
              'Buku yang memakai kategori ini tidak dihapus dan akan dipindahkan ke "Tidak Berkategori".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
    );

    if (ok == true && mounted) {
      await widget.service.deleteCategoryAndReassignBooks(name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori dihapus dan buku dipindahkan'),
          ),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final v = _nameController.text.trim();
    if (v.isEmpty) return;
    await widget.service.addCategory(v);
    if (mounted) {
      _nameController.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kategori ditambahkan')));
      widget.onCategoryAdded?.call(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kelola Kategori',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tambah kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _addCategory,
                  child: const Text('Tambah'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: StreamBuilder<List<String>>(
                stream: _categoriesStream,
                builder: (_, snapshot) {
                  final items = snapshot.data ?? const <String>[];
                  if (items.isEmpty) {
                    return const Center(child: Text('Belum ada kategori'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final name = items[index];
                      return ListTile(
                        title: Text(name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.blue,
                              ),
                              onPressed: () => _editCategory(name),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () => _deleteCategory(name),
                            ),
                          ],
                        ),
                        onTap: () {
                          widget.onCategorySelected?.call();
                          Navigator.pop(context, name);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
