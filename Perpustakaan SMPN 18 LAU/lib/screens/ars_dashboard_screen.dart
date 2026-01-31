import 'package:flutter/material.dart';
import '../services/ars_service_impl.dart';
import '../models/replenishment_order_model.dart';
import '../models/buku_model.dart';
import '../utils/async_action.dart';

class ArsDashboardScreen extends StatefulWidget {
  const ArsDashboardScreen({super.key});

  @override
  State<ArsDashboardScreen> createState() => _ArsDashboardScreenState();
}

class _ArsDashboardScreenState extends State<ArsDashboardScreen> {
  final ArsService _arsService = ArsService();
  bool _loading = true;
  bool _checking = false;
  List<ReplenishmentOrderModel> _orders = [];
  List<BukuModel> _lowStockBooks = [];
  Map<String, dynamic> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      final results = await Future.wait([
        _arsService.getReplenishmentOrders(),
        _arsService.getLowStockBooks(),
        _arsService.getArsStatistics(),
      ]);
      setState(() {
        _orders = results[0] as List<ReplenishmentOrderModel>;
        _lowStockBooks = results[1] as List<BukuModel>;
        _stats = results[2] as Map<String, dynamic>;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data ARS: ${getFriendlyErrorMessage(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkNow() async {
    try {
      setState(() => _checking = true);
      final created = await _arsService.checkAndCreateReplenishmentOrders();
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.isEmpty
                ? 'Tidak ada order baru. Stok aman.'
                : 'Berhasil membuat ${created.length} order replenishment.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal cek & buat order: ${getFriendlyErrorMessage(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _receiveOrder(String orderId) async {
    try {
      await _arsService.receiveOrder(orderId);
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order diterima & stok diperbarui')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menerima order: ${getFriendlyErrorMessage(e)}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARS Dashboard')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Buku ARS',
                            value: '${_stats['total_ars_enabled'] ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Low Stock',
                            value: '${_stats['low_stock_books'] ?? 0}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Pending',
                            value: '${_stats['pending_orders'] ?? 0}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Selesai',
                            value: '${_stats['completed_orders'] ?? 0}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checking ? null : _checkNow,
                            icon: const Icon(
                              Icons.playlist_add_check_circle_rounded,
                            ),
                            label: Text(
                              _checking
                                  ? 'Memeriksa...'
                                  : 'Cek & Buat Order Otomatis',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Buku Stok Rendah',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_lowStockBooks.isEmpty)
                      const Text('Tidak ada buku low stock.')
                    else
                      ..._lowStockBooks.map(
                        (b) => Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                            title: Text(b.judul),
                            subtitle: Text(
                              'Stok: ${b.stok} • Safety Stock: ${b.safetyStock ?? '-'}',
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      'Replenishment Orders',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_orders.isEmpty)
                      const Text('Belum ada order replenishment.')
                    else
                      ..._orders.map(
                        (o) => Card(
                          child: ListTile(
                            title: Text(o.judulBuku),
                            subtitle: Text(
                              'Qty: ${o.quantity} • Status: ${o.status}${o.isAutomatic ? ' • Auto' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (o.status != 'diterima')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.inventory_2_rounded,
                                      color: Color(0xFF2E7D32),
                                    ),
                                    tooltip: 'Terima & tambah stok',
                                    onPressed: () => _receiveOrder(o.id!),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
