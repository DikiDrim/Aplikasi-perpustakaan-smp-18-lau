import 'package:flutter/material.dart';
import '../models/buku_model.dart';
import '../services/firestore_service.dart';
import '../utils/async_action.dart';
import '../widgets/success_popup.dart';

/// Module 1: Book Inventory (Asset Management)
/// Allows Admin to manually change a book's condition status.
/// Supports setting both rusak AND hilang quantities simultaneously.
class UbahKondisiBukuScreen extends StatefulWidget {
  final BukuModel buku;
  const UbahKondisiBukuScreen({super.key, required this.buku});

  @override
  State<UbahKondisiBukuScreen> createState() => _UbahKondisiBukuScreenState();
}

class _UbahKondisiBukuScreenState extends State<UbahKondisiBukuScreen> {
  final _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _catatanController = TextEditingController();

  late int _jumlahRusak;
  late int _jumlahHilang;

  // Palette konsisten
  static const _kPrimary = Color(0xFF455A64);
  static const _kTersedia = Color(0xFF2E7D32);
  static const _kRusak = Color(0xFFE65100);
  static const _kHilang = Color(0xFFC62828);
  static const _kSurface = Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _jumlahRusak = widget.buku.effectiveJumlahRusak;
    _jumlahHilang = widget.buku.effectiveJumlahHilang;
    _catatanController.text = widget.buku.catatanKondisi ?? '';
  }

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  bool get _isChanged =>
      _jumlahRusak != widget.buku.effectiveJumlahRusak ||
      _jumlahHilang != widget.buku.effectiveJumlahHilang ||
      _catatanController.text.trim() != (widget.buku.catatanKondisi ?? '');

  /// Total stok awal (stok + rusak + hilang saat ini) = pool tetap
  int get _totalPool =>
      widget.buku.stok +
      widget.buku.effectiveJumlahRusak +
      widget.buku.effectiveJumlahHilang;

  /// Stok tersedia setelah perubahan
  int get _stokTersedia => _totalPool - _jumlahRusak - _jumlahHilang;

  /// Max rusak yang bisa diset (sisakan hilang, stok minimal 0)
  int get _maxRusak => _totalPool - _jumlahHilang;

  /// Max hilang yang bisa diset (sisakan rusak, stok minimal 0)
  int get _maxHilang => _totalPool - _jumlahRusak;

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Konfirmasi Perubahan',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.buku.judul,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _buildConfirmRow('Stok Tersedia', '$_stokTersedia', _kTersedia),
                const SizedBox(height: 8),
                _buildConfirmRow(
                  'Jumlah Rusak',
                  '$_jumlahRusak eksemplar',
                  _kRusak,
                ),
                const SizedBox(height: 8),
                _buildConfirmRow(
                  'Jumlah Hilang',
                  '$_jumlahHilang eksemplar',
                  _kHilang,
                ),
                if (_stokTersedia < widget.buku.stok) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Stok buku akan disesuaikan otomatis.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('Ya, Simpan'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      await runWithLoading(context, () async {
        await _firestoreService.updateKondisiBukuGabungan(
          widget.buku.id!,
          jumlahRusak: _jumlahRusak,
          jumlahHilang: _jumlahHilang,
          catatan:
              _catatanController.text.trim().isEmpty
                  ? null
                  : _catatanController.text.trim(),
        );
      });

      if (!mounted) return;

      final statusLabel =
          _jumlahRusak > 0 && _jumlahHilang > 0
              ? 'Rusak: $_jumlahRusak, Hilang: $_jumlahHilang'
              : _jumlahRusak > 0
              ? 'Rusak: $_jumlahRusak'
              : _jumlahHilang > 0
              ? 'Hilang: $_jumlahHilang'
              : 'Tersedia';

      await SuccessPopup.show(
        context,
        title: 'Kondisi Berhasil Diperbarui!',
        subtitle: '"${widget.buku.judul}" → $statusLabel',
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Widget _buildConfirmRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final buku = widget.buku;

    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(title: const Text('Ubah Kondisi Buku'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Book Info Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buku.judul,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      buku.pengarang,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _kSurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          _buildSmallInfo(
                            'Total Pool',
                            '$_totalPool',
                            _kPrimary,
                          ),
                          _dividerDot(),
                          _buildSmallInfo(
                            'Tersedia',
                            '$_stokTersedia',
                            _kTersedia,
                          ),
                          if (_jumlahRusak > 0) ...[
                            _dividerDot(),
                            _buildSmallInfo('Rusak', '$_jumlahRusak', _kRusak),
                          ],
                          if (_jumlahHilang > 0) ...[
                            _dividerDot(),
                            _buildSmallInfo(
                              'Hilang',
                              '$_jumlahHilang',
                              _kHilang,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Jumlah Rusak ──
              Text(
                'Atur Jumlah Buku Rusak',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              _buildQuantityCard(
                icon: Icons.build_circle_outlined,
                label: 'Buku Rusak',
                color: _kRusak,
                value: _jumlahRusak,
                max: _maxRusak,
                onDecrease:
                    _jumlahRusak > 0
                        ? () => setState(() => _jumlahRusak--)
                        : null,
                onIncrease:
                    _jumlahRusak < _maxRusak
                        ? () => setState(() => _jumlahRusak++)
                        : null,
              ),

              const SizedBox(height: 20),

              // ── Jumlah Hilang ──
              Text(
                'Atur Jumlah Buku Hilang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              _buildQuantityCard(
                icon: Icons.search_off_rounded,
                label: 'Buku Hilang',
                color: _kHilang,
                value: _jumlahHilang,
                max: _maxHilang,
                onDecrease:
                    _jumlahHilang > 0
                        ? () => setState(() => _jumlahHilang--)
                        : null,
                onIncrease:
                    _jumlahHilang < _maxHilang
                        ? () => setState(() => _jumlahHilang++)
                        : null,
              ),

              const SizedBox(height: 20),

              // ── Stok Preview ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      _stokTersedia > 0
                          ? _kTersedia.withOpacity(0.06)
                          : Colors.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        _stokTersedia > 0
                            ? _kTersedia.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: _stokTersedia > 0 ? _kTersedia : _kHilang,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Stok tersedia setelah perubahan: $_stokTersedia eksemplar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _stokTersedia > 0 ? _kTersedia : _kHilang,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Notes ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextFormField(
                  controller: _catatanController,
                  decoration: InputDecoration(
                    labelText: 'Catatan (opsional)',
                    labelStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    hintText: 'Misal: Halaman robek, buku basah, dll.',
                    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                    prefixIcon: Icon(
                      Icons.notes_rounded,
                      color: Colors.grey[400],
                      size: 20,
                    ),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14),
                ),
              ),

              const SizedBox(height: 28),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isChanged ? _simpan : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isChanged ? _kPrimary : null,
                    foregroundColor: _isChanged ? Colors.white : null,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Simpan Perubahan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityCard({
    required IconData icon,
    required String label,
    required Color color,
    required int value,
    required int max,
    VoidCallback? onDecrease,
    VoidCallback? onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value > 0 ? color.withOpacity(0.3) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value > 0 ? color : Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: value > 0 ? color : Colors.grey[700],
              ),
            ),
          ),
          // Stepper
          Container(
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _stepperBtn(Icons.remove, onDecrease),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '$value',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: value > 0 ? color : _kPrimary,
                    ),
                  ),
                ),
                _stepperBtn(Icons.add, onIncrease),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfo(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _dividerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
      ),
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback? onPressed) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: enabled ? _kPrimary : Colors.grey[300],
          ),
        ),
      ),
    );
  }
}
