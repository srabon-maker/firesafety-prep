import 'package:flutter/material.dart';

import '../models/marketplace_item.dart';

const _maroon = Color(0xFFAD1028);
const _card = Color(0xFF282326);
const _border = Color(0xFF51484B);
const _muted = Color(0xFFBDB4B7);

/// Compact dark product tile matching the Fire Safety BD marketplace reference.
class MarketplaceCatalogCard extends StatelessWidget {
  const MarketplaceCatalogCard({
    super.key,
    required this.item,
    required this.onDetails,
    required this.onAction,
    this.actionBusy = false,
  });

  final MarketplaceItem item;
  final VoidCallback onDetails;
  final VoidCallback onAction;
  final bool actionBusy;

  String get _actionLabel => item.isService
      ? 'সার্ভিস বুকিং করুন'
      : item.canAddToCart
          ? 'কার্টে যোগ করুন'
          : 'বিস্তারিত দেখুন';

  @override
  Widget build(BuildContext context) {
    final unavailable = !item.isService && !item.canAddToCart;
    final discount = item.discountPercent;
    final original = item.comparePrice;
    final hasOriginal = discount != null && original != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: _card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: _border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 112,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MarketplaceCatalogImage(item: item),
                  if (discount != null || item.isFeatured)
                    Positioned(
                      left: 7,
                      right: 7,
                      top: 7,
                      child: Row(
                        children: [
                          if (discount != null) _tag('-$discount%'),
                          const Spacer(),
                          if (item.isFeatured) _tag('ফিচার্ড'),
                        ],
                      ),
                    ),
                  if (unavailable)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black.withValues(alpha: 0.72),
                        child: const Text(
                          'স্টকে নেই',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 6, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 10,
                            height: 1.15),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (hasOriginal)
                                Text(
                                  '৳${original.toStringAsFixed(original % 1 == 0 ? 0 : 2)}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: IconButton(
                            tooltip: _actionLabel,
                            onPressed: actionBusy
                                ? null
                                : (unavailable ? onDetails : onAction),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: _maroon,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _maroon.withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: Icon(
                              item.isService
                                  ? Icons.engineering_outlined
                                  : unavailable
                                      ? Icons.visibility_outlined
                                      : Icons.shopping_cart_outlined,
                              size: 21,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: _maroon,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: const TextStyle(color: Colors.white,
        fontSize: 9, fontWeight: FontWeight.w800)),
  );
}

/// Uses only secure absolute HTTPS image URLs and a dark branded fallback.
class MarketplaceCatalogImage extends StatelessWidget {
  const MarketplaceCatalogImage({super.key, required this.item});

  final MarketplaceItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final uri = Uri.tryParse(url ?? '');
    final valid = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    if (!valid) return _placeholder();

    return Image.network(
      url!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF30272A), Color(0xFF211A1D)],
      ),
    ),
    child: Center(
      child: Icon(
        item.isService ? Icons.engineering_outlined : Icons.fire_extinguisher,
        color: const Color(0xFFFFB4BD),
        size: 42,
      ),
    ),
  );
}
