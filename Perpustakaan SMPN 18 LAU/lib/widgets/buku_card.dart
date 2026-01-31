import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/buku_model.dart';

class BukuCard extends StatelessWidget {
  final BukuModel buku;
  final VoidCallback? onTap;

  const BukuCard({super.key, required this.buku, this.onTap});

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
                                memCacheWidth:
                                    90, // Optimize: smaller cache for cards
                                memCacheHeight: 120,
                                filterQuality:
                                    FilterQuality
                                        .low, // Optimize for low-end devices
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
                          'oleh ${buku.pengarang}',
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
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    buku.stok > 0
                                        ? const Color(0xFF6BCF7F)
                                        : const Color(0xFFFF6B6B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                buku.stok > 0
                                    ? 'Stok: ${buku.stok}'
                                    : 'Stok Habis',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (buku.isArsEnabled)
                              Tooltip(
                                message: 'ARS aktif',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF00695C,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF00695C,
                                      ).withOpacity(0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 12,
                                        color: Color(0xFF00695C),
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Auto',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF00695C),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (buku.isArsEnabled &&
                                buku.safetyStock != null &&
                                buku.stok <= buku.safetyStock!)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Tooltip(
                                  message: 'Stok rendah',
                                  child: const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 18,
                                  ),
                                ),
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
}
