import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/clodinary_service.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../providers/auth_provider.dart';
import '../utils/async_action.dart';
import '../utils/throttle.dart';
import '../widgets/success_popup.dart';

class TambahBukuScreen extends StatefulWidget {
  const TambahBukuScreen({super.key});

  @override
  State<TambahBukuScreen> createState() => _TambahBukuScreenState();
}

class _TambahBukuScreenState extends State<TambahBukuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _pengarangController = TextEditingController();
  final _tahunController = TextEditingController();
  final _tahunPembelianController = TextEditingController();
  final _stokController = TextEditingController();
  final _hargaSatuanController = TextEditingController();
  final _kategoriController = TextEditingController();
  final _deskripsiController = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  File? _pickedBookFile;
  Uint8List? _pickedBookBytes;
  String? _pickedBookFileName;
  bool _isUploadingImage = false;
  bool _isUploadingBookFile = false;
  String? _kategoriSelected;
  late final FirestoreService _service;
  double _totalHarga = 0;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void dispose() {
    _judulController.dispose();
    _pengarangController.dispose();
    _tahunController.dispose();
    _tahunPembelianController.dispose();
    _stokController.dispose();
    _hargaSatuanController.dispose();
    _kategoriController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _service = FirestoreService();
    _stokController.addListener(_recalculateTotal);
    _hargaSatuanController.addListener(_recalculateTotal);
  }

  void _recalculateTotal() {
    final int stok = int.tryParse(_stokController.text) ?? 0;
    final double harga =
        double.tryParse(_hargaSatuanController.text.replaceAll(',', '.')) ?? 0;
    setState(() {
      _totalHarga = stok * harga;
    });
  }

  void _openManageCategories() {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final nameController = TextEditingController();
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tambah kategori',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final v = nameController.text.trim();
                        if (v.isEmpty) return;
                        await _service.addCategory(v);
                        if (mounted) {
                          nameController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Kategori ditambahkan'),
                            ),
                          );
                          setState(() => _kategoriSelected ??= v);
                        }
                      },
                      child: const Text('Tambah'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 320,
                  child: StreamBuilder<List<String>>(
                    stream: _service.getCategoriesStream(),
                    builder: (context, snapshot) {
                      final items = snapshot.data ?? const <String>[];
                      if (items.isEmpty) {
                        return const Center(child: Text('Belum ada kategori'));
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
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
                                  onPressed: () async {
                                    final editController =
                                        TextEditingController(text: name);
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
                                                onPressed:
                                                    () => Navigator.pop(
                                                      dialogContext,
                                                    ),
                                                child: const Text('Batal'),
                                              ),
                                              FilledButton(
                                                onPressed: () {
                                                  final val =
                                                      editController.text
                                                          .trim();
                                                  if (val.isNotEmpty &&
                                                      val != name) {
                                                    Navigator.pop(
                                                      dialogContext,
                                                      val,
                                                    );
                                                  } else {
                                                    Navigator.pop(
                                                      dialogContext,
                                                    );
                                                  }
                                                },
                                                child: const Text('Simpan'),
                                              ),
                                            ],
                                          ),
                                    );
                                    editController.dispose();
                                    if (newName != null && newName.isNotEmpty) {
                                      await _service.updateCategory(
                                        name,
                                        newName,
                                      );
                                      if (mounted) {
                                        if (_kategoriSelected == name) {
                                          setState(
                                            () => _kategoriSelected = newName,
                                          );
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Kategori berhasil diubah',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (dialogContext) => AlertDialog(
                                            title: const Text(
                                              'Hapus kategori?',
                                            ),
                                            content: Text(
                                              'Kategori "$name" akan dihapus dari daftar. '
                                              'Buku yang memakai kategori ini tidak dihapus dan akan dipindahkan ke "Tidak Berkategori".',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      dialogContext,
                                                      false,
                                                    ),
                                                child: const Text('Batal'),
                                              ),
                                              FilledButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      dialogContext,
                                                      true,
                                                    ),
                                                child: const Text('Hapus'),
                                              ),
                                            ],
                                          ),
                                    );
                                    if (ok == true) {
                                      await _service
                                          .deleteCategoryAndReassignBooks(name);
                                      if (mounted) {
                                        if (_kategoriSelected == name) {
                                          setState(
                                            () => _kategoriSelected = null,
                                          );
                                        }
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Kategori dihapus dan buku dipindahkan',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () {
                              setState(() => _kategoriSelected = name);
                              Navigator.pop(context);
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
      },
    );
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
        // Periksa ukuran file (bytes). Batasi maksimal 10 MB.
        const int maxBytes = 10 * 1024 * 1024; // 10 MB
        int fileBytes = 0;
        if (kIsWeb) {
          fileBytes = file.size;
        } else if (file.path != null) {
          try {
            fileBytes = File(file.path!).lengthSync();
          } catch (_) {
            fileBytes = file.size; // fallback
          }
        } else {
          fileBytes = file.size;
        }

        if (fileBytes > maxBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ukuran file terlalu besar. Maksimal 10 MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        if (kIsWeb && file.bytes != null) {
          setState(() {
            _pickedBookBytes = file.bytes;
            _pickedBookFileName = file.name;
            _pickedBookFile = null;
          });
        } else if (file.path != null) {
          setState(() {
            _pickedBookFile = File(file.path!);
            _pickedBookBytes = null;
            _pickedBookFileName = file.name;
          });
        } else {
          throw Exception('File tidak memiliki path atau bytes');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File dipilih: ${file.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
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

  /// Upload file buku ke Cloudinary
  Future<String?> _uploadBookFile(String bukuId) async {
    if (!kIsWeb && _pickedBookFile == null) return null;
    if (kIsWeb && (_pickedBookBytes == null || _pickedBookFileName == null)) {
      return null;
    }
    try {
      if (mounted) setState(() => _isUploadingBookFile = true);
      final fileUrl =
          kIsWeb
              ? await _firestoreService.uploadBookFileBytes(
                _pickedBookBytes!,
                _pickedBookFileName!,
                bukuId,
              )
              : await _firestoreService.uploadBookFile(
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

  Future<void> _saveBuku() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Loading dulu saat proses upload dan simpan data
    String? judulBuku;
    await runWithLoading(context, () async {
      final uploadRes = await _uploadCoverIfAny();
      final coverUrl = uploadRes == null ? null : uploadRes['url'];
      final coverPublicId = uploadRes == null ? null : uploadRes['publicId'];
      final buku = BukuModel(
        judul: _judulController.text,
        pengarang: _pengarangController.text,
        tahun: int.parse(_tahunController.text),
        stok: int.parse(_stokController.text),
        kategori: _kategoriSelected ?? _kategoriController.text,
        deskripsi:
            _deskripsiController.text.isEmpty
                ? null
                : _deskripsiController.text,
        tahunPembelian:
            _tahunPembelianController.text.isEmpty
                ? null
                : int.parse(_tahunPembelianController.text),
        hargaSatuan:
            _hargaSatuanController.text.isEmpty
                ? null
                : double.parse(
                  _hargaSatuanController.text.replaceAll(',', '.'),
                ),
        totalHarga: _totalHarga == 0 ? null : _totalHarga,
        coverUrl: coverUrl,
        coverPublicId: coverPublicId,
        totalPeminjaman: 0,
      );

      judulBuku = buku.judul;

      // Simpan buku dan dapatkan ID
      final bukuId = await _firestoreService.addBuku(buku);

      // Upload file buku jika ada
      if (_pickedBookFile != null || _pickedBookBytes != null) {
        final bookFileUrl = await _uploadBookFile(bukuId);
        if (bookFileUrl != null) {
          await _firestoreService.updateBookFileUrl(bukuId, bookFileUrl);
        }
      }
    }, message: '');

    // 2. Setelah loading selesai, tampilkan popup sukses
    if (mounted && judulBuku != null) {
      await SuccessPopup.show(
        context,
        title: 'Buku Berhasil Ditambahkan!',
        subtitle: '"$judulBuku" telah ditambahkan ke perpustakaan',
      );

      // 3. Setelah popup, kembali ke screen sebelumnya
      if (mounted) {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = (auth.role == 'admin');
    final selectedFileName =
        _pickedBookFileName ?? _pickedBookFile?.path.split('/').last;
    final hasSelectedFile = _pickedBookFile != null || _pickedBookBytes != null;

    // Proteksi: Hanya admin yang bisa akses
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anda tidak memiliki izin untuk menambah buku'),
            backgroundColor: Colors.red,
          ),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: const Text(
          'Tambah Buku',
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
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                                      _pickedImage != null && !kIsWeb
                                          ? DecorationImage(
                                            image: FileImage(
                                              File(_pickedImage!.path),
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                          : null,
                                ),
                                child:
                                    _pickedImage == null || kIsWeb
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (image != null) {
                                  if (kIsWeb) {
                                    final bytes = await image.readAsBytes();
                                    setState(() {
                                      _pickedImage = image;
                                      _pickedImageBytes = bytes;
                                    });
                                  } else {
                                    setState(() {
                                      _pickedImage = image;
                                      _pickedImageBytes = null;
                                    });
                                  }
                                }
                              },
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Pilih Sampul'),
                            ),
                            if (_pickedImage != null ||
                                _pickedImageBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _pickedImage = null;
                                      _pickedImageBytes = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Hapus Sampul'),
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              'Format: JPG/PNG. Ukuran disarankan: landscape',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              // File Buku PDF
              Card(
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (hasSelectedFile && selectedFileName != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedFileName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _pickedBookFile = null;
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
                          onPressed:
                              _isUploadingBookFile ? null : _pickBookFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Pilih File PDF'),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Maksimal ukuran file: 10 MB.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                                        (_) => AlertDialog(
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
                                                  () => Navigator.pop(context),
                                              child: const Text('Batal'),
                                            ),
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(
                                                    context,
                                                    ctrl.text.trim(),
                                                  ),
                                              child: const Text('Simpan'),
                                            ),
                                          ],
                                        ),
                                  );
                                  if (ok != null && ok.isNotEmpty) {
                                    await _service.addCategory(ok);
                                    setState(() => _kategoriSelected = ok);
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
                controller: _tahunPembelianController,
                decoration: const InputDecoration(
                  labelText: 'Tahun Pembelian (opsional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      int.tryParse(value) == null) {
                    return 'Tahun pembelian harus berupa angka';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hargaSatuanController,
                decoration: const InputDecoration(
                  labelText: 'Harga Satuan (opsional)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final v = double.tryParse(value.replaceAll(',', '.'));
                    if (v == null || v < 0) return 'Harga tidak valid';
                  }
                  return null;
                },
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
              if (_hargaSatuanController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Total Harga: Rp ${_totalHarga.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!Throttle.allow('simpan_buku')) return;
                    await _saveBuku();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3498DB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Simpan Buku',
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
