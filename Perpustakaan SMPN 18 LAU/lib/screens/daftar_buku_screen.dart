import 'package:flutter/material.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import 'detail_buku_screen.dart';
import '../widgets/buku_card.dart';

class DaftarBukuScreen extends StatefulWidget {
  const DaftarBukuScreen({super.key});

  @override
  State<DaftarBukuScreen> createState() => _DaftarBukuScreenState();
}

class _DaftarBukuScreenState extends State<DaftarBukuScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchController = TextEditingController();

  List<BukuModel> _allBukuList = [];
  List<BukuModel> _filteredBukuList = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBuku();
    _searchController.addListener(_filterBooks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBuku() async {
    try {
      final bukuList = await _firestoreService.getBuku();

      // Ambil daftar kategori unik
      final categories = bukuList.map((b) => b.kategori).toSet().toList();
      categories.sort();

      setState(() {
        _allBukuList = bukuList;
        _filteredBukuList = bukuList;
        _categories = categories;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading books: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filterBooks() {
    final query = _searchController.text.toLowerCase();

    setState(() {
      _filteredBukuList =
          _allBukuList.where((buku) {
            final matchSearch =
                query.isEmpty ||
                buku.judul.toLowerCase().contains(query) ||
                buku.pengarang.toLowerCase().contains(query);

            final matchCategory =
                _selectedCategory == null || buku.kategori == _selectedCategory;

            return matchSearch && matchCategory;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Daftar Buku',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search Section
          Container(
            color: const Color(0xFF0D47A1),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari judul atau pengarang...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.white,
                  size: 20,
                ),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        )
                        : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Category Filter Section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: DropdownButton<String?>(
                isExpanded: true,
                underline: const SizedBox(),
                value: _selectedCategory == null ? 'Semua' : _selectedCategory,
                items: [
                  const DropdownMenuItem(
                    value: 'Semua',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Semua Kategori',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                  ..._categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          category,
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value == 'Semua' ? null : value;
                    _filterBooks();
                  });
                },
                dropdownColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black87,
                  size: 22,
                ),
              ),
            ),
          ),
          // Books List
          Expanded(
            child:
                _loading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF87CEEB),
                      ),
                    )
                    : _filteredBukuList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isNotEmpty ||
                                    _selectedCategory != null
                                ? 'Tidak ada buku yang sesuai'
                                : 'Belum ada buku tersedia',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_searchController.text.isNotEmpty ||
                              _selectedCategory != null) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _selectedCategory = null);
                                _filterBooks();
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Reset Filter'),
                            ),
                          ],
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadBuku,
                      color: const Color(0xFF87CEEB),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredBukuList.length,
                        cacheExtent: 500,
                        itemExtent: null,
                        itemBuilder: (context, index) {
                          final buku = _filteredBukuList[index];
                          return BukuCard(
                            key: ValueKey(buku.id),
                            buku: buku,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => DetailBukuScreen(buku: buku),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
