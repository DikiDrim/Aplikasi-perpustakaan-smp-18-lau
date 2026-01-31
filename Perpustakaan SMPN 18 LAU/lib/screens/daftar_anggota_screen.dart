import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'tambah_siswa_screen.dart';
import 'detail_anggota_screen.dart';

class DaftarAnggotaScreen extends StatefulWidget {
  const DaftarAnggotaScreen({super.key});

  @override
  State<DaftarAnggotaScreen> createState() => _DaftarAnggotaScreenState();
}

class _DaftarAnggotaScreenState extends State<DaftarAnggotaScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _siswaList = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSiswa();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _filterSiswa();
    });
  }

  void _filterSiswa() {
    if (_searchQuery.isEmpty) {
      _filteredList = _siswaList;
    } else {
      _filteredList =
          _siswaList.where((siswa) {
            final nama = (siswa['nama'] ?? '').toString().toLowerCase();
            final nis = (siswa['nis'] ?? '').toString().toLowerCase();
            final username = (siswa['username'] ?? '').toString().toLowerCase();
            return nama.contains(_searchQuery) ||
                nis.contains(_searchQuery) ||
                username.contains(_searchQuery);
          }).toList();
    }
  }

  Future<void> _loadSiswa() async {
    try {
      setState(() => _loading = true);
      final list = await _firestoreService.getSiswa();
      setState(() {
        _siswaList = list;
        _filterSiswa();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data anggota: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _tambahSiswa() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TambahSiswaScreen()),
    );
    if (result == true || mounted) {
      await _loadSiswa();
    }
  }

  Future<void> _editSiswa(Map<String, dynamic> siswa) async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (context) => _EditSiswaDialog(siswa: siswa),
    );

    if (result != null && mounted) {
      try {
        final nama = result['nama']!;
        final nis = result['nis']!;
        final kelas = result['kelas']!;

        if (nama.isEmpty || nis.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nama dan NIS tidak boleh kosong'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (nis.length != 6 || !RegExp(r'^\d{6}$').hasMatch(nis)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('NIS harus terdiri dari 6 digit angka'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        await _firestoreService.updateSiswa(
          siswa['id'] ?? '',
          siswa['uid'] ?? '',
          nama: nama,
          nis: nis,
          kelas: kelas.isEmpty ? null : kelas,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data anggota berhasil diupdate'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadSiswa();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal mengupdate anggota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _hapusSiswa(Map<String, dynamic> siswa) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Hapus Anggota'),
            content: Text(
              'Apakah Anda yakin ingin menghapus anggota "${siswa['nama']}"?\nTindakan ini tidak dapat dibatalkan.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      try {
        await _firestoreService.deleteSiswa(
          siswa['id'] ?? '',
          siswa['uid'] ?? '',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anggota berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadSiswa();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus anggota: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '-';
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year}';
      } else if (timestamp is String) {
        final date = DateTime.parse(timestamp);
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '-';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Anggota Perpustakaan')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cari anggota',
                hintText: 'Cari berdasarkan nama, NIS, atau username',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Info card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Total Anggota: ${_filteredList.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // List siswa
          Expanded(
            child:
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Belum ada anggota terdaftar'
                                : 'Tidak ada hasil pencarian',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadSiswa,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredList.length,
                        // Optimize: cacheExtent untuk lazy loading
                        cacheExtent: 500,
                        itemBuilder: (context, index) {
                          final siswa = _filteredList[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            DetailAnggotaScreen(siswa: siswa),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(16),
                                leading: CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFF0D47A1,
                                  ).withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: Color(0xFF0D47A1),
                                  ),
                                ),
                                title: Text(
                                  siswa['nama'] ?? '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('NIS: ${siswa['nis'] ?? '-'}'),
                                    Text(
                                      'Username: ${siswa['username'] ?? '-'}',
                                    ),
                                    Text(
                                      'Terdaftar: ${_formatDate(siswa['created_at'])}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton(
                                  itemBuilder:
                                      (context) => [
                                        PopupMenuItem(
                                          child: const Row(
                                            children: [
                                              Icon(Icons.edit, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit'),
                                            ],
                                          ),
                                          onTap: () => _editSiswa(siswa),
                                        ),
                                        PopupMenuItem(
                                          child: const Row(
                                            children: [
                                              Icon(
                                                Icons.delete,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Hapus',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () => _hapusSiswa(siswa),
                                        ),
                                      ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambahSiswa,
        icon: const Icon(Icons.person_add, size: 24),
        label: const Text(
          'Tambah Anggota',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        tooltip: 'Tambah anggota perpustakaan baru',
      ),
    );
  }
}

// Separate StatefulWidget for Edit Dialog to properly manage TextEditingControllers
class _EditSiswaDialog extends StatefulWidget {
  final Map<String, dynamic> siswa;

  const _EditSiswaDialog({required this.siswa});

  @override
  State<_EditSiswaDialog> createState() => _EditSiswaDialogState();
}

class _EditSiswaDialogState extends State<_EditSiswaDialog> {
  late TextEditingController _namaController;
  late TextEditingController _nisController;
  late TextEditingController _kelasController;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.siswa['nama'] ?? '');
    _nisController = TextEditingController(text: widget.siswa['nis'] ?? '');
    _kelasController = TextEditingController(text: widget.siswa['kelas'] ?? '');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nisController.dispose();
    _kelasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Data Anggota'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _namaController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nisController,
              decoration: const InputDecoration(
                labelText: 'NIS (6 digit)',
                prefixIcon: Icon(Icons.numbers),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _kelasController,
              decoration: const InputDecoration(
                labelText: 'Kelas (opsional)',
                prefixIcon: Icon(Icons.class_),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'nama': _namaController.text.trim(),
              'nis': _nisController.text.trim(),
              'kelas': _kelasController.text.trim(),
            });
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
