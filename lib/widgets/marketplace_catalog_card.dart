import 'package:flutter/material.dart';

import '../models/marketplace_item.dart';

const _maroon = Color(0xFF650D18);
const _softMaroon = Color(0xFFF7ECEE);
const _ink = Color(0xFF231A1C);

/// A responsive, image-first card for the public Marketplace catalog.
/// Prices, discounts, inventory and featured status all come from the API.
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

  String get _actionLabel {
    if (item.isService) return 'বুকিং করুন';
    return item.canAddToCart ? 'কার্টে যোগ করুন' : 'বিস্তারিত দেখুন';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final discount = item.discountPercent;
    final isUnavailable = !item.isService && !item.canAddToCart;
    final original = item.comparePrice;
    final hasOriginal = discount != null && original != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: _maroon.withValues(alpha: 0.10),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MarketplaceCatalogImage(item: item),
                  if (discount != null || item.isFeatured)
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 8,
                      child: Row(
                        children: [
                          if (discount != null)
                            _imageTag('-$discount%', const Color(0xFFB32635)),
                          const Spacer(),
                          if (item.isFeatured)
                            _imageTag('ফিচার্ড', _maroon),
                        ],
                      ),
                    ),
                  if (isUnavailable)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        color: _ink.withValues(alpha: 0.76),
                        child: const Text(
                          'স্টকে নেই',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.isNotEmpty
                          ? item.category
                          : (item.isService ? 'ফায়ার সেফটি সার্ভিস' : 'ফায়ার সেফটি পণ্য'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (item.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.priceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _maroon,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: FilledButton(
                            onPressed: actionBusy
                                ? null
                                : (isUnavailable ? onDetails : onAction),
                            style: FilledButton.styleFrom(
                              backgroundColor: isUnavailable
                                  ? scheme.surfaceContainerHighest
                                  : _maroon,
                              foregroundColor: isUnavailable
                                  ? scheme.onSurface
                                  : Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            child: Icon(
                              item.isService
                                  ? Icons.calendar_month_outlined
                                  : item.canAddToCart
                                      ? Icons.shopping_cart_outlined
                                      : Icons.visibility_outlined,
                              size: 20,
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

  Widget _imageTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Uses only secure absolute HTTPS image URLs. Missing/broken images display
/// a deliberate brand placeholder rather than a broken-image glyph.
class MarketplaceCatalogImage extends StatelessWidget {
  const MarketplaceCatalogImage({super.key, required this.item});

  final MarketplaceItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final uri = Uri.tryParse(url ?? '');
    final isValid = uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;

    if (!isValid) return _placeholder();

    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }

  Widget _placeholder() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF30272A), Color(0xFF211A1D)],
        ),
      ),
      child: Center(
        child: Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            item.isService ? Icons.engineering_outlined : Icons.fire_extinguisher,
            color: const Color(0xFFFFB4BD),
            size: 42,
          ),
        ),
      ),
    );
  }
}
