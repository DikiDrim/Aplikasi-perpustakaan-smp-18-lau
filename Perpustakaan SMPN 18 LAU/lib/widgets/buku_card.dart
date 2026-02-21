import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/buku_model.dart';

class BukuCard extends StatelessWidget {
  final BukuModel buku;
  final VoidCallback? onTap;

  const BukuCard({super.key, required this.buku, this.onTap});

  String _buildKondisiLabel(BukuModel buku) {
    final parts = <String>[];
    if (buku.effectiveJumlahRusak > 0)
      parts.add('Rusak: ${buku.effectiveJumlahRusak}');
    if (buku.effectiveJumlahHilang > 0)
      parts.add('Hilang: ${buku.effectiveJumlahHilang}');
    if (parts.isEmpty) return buku.statusKondisi;
    return parts.join(', ');
  }

  // Palette konsisten
  static const _kRusak = Color(0xFFE65100);
  static const _kHilang = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image dengan caching
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 80,
                      color: Colors.grey[200],
                      child:
                          buku.coverUrl != null && buku.coverUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: buku.coverUrl!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                      size: 30,
                                    ),
                                memCacheWidth: 90,
                                memCacheHeight: 120,
                                filterQuality: FilterQuality.low,
                              )
                              : const Icon(
                                Icons.book,
                                color: Colors.grey,
                                size: 30,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          buku.judul,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Penerbit: ${buku.pengarang}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[500]),
                        ),
                        if (buku.deskripsi != null &&
                            buku.deskripsi!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            buku.deskripsi!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _buildPill(
                              buku.stok > 0
                                  ? 'Stok: ${buku.stok} buku'
                                  : 'Stok Habis',
                              buku.stok > 0
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFC62828),
                            ),
                            // Badge Kondisi Buku (Rusak / Hilang)
                            if (buku.statusKondisi != 'Tersedia')
                              _buildPill(
                                _buildKondisiLabel(buku),
                                buku.effectiveJumlahHilang > 0
                                    ? _kHilang
                                    : _kRusak,
                              ),

                            if (buku.isArsEnabled &&
                                buku.safetyStock != null &&
                                buku.stok <= buku.safetyStock!)
                              _buildPill(
                                'Stok Rendah',
                                const Color(0xFFE65100),
                                outlined: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.category, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      buku.kategori,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text(
                    buku.tahun.toString(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPill(String text, Color color, {bool outlined = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? color.withOpacity(0.08) : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: outlined ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
