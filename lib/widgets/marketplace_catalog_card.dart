import 'package:flutter/material.dart';

import '../models/marketplace_item.dart';
import '../models/marketplace_engagement.dart';
import '../settings/app_settings.dart';

// Same filled-button maroon as the marketplace page.
const _maroon = Color(0xFF7A1224);

/// Card colours for light and dark mode.
class _CardPalette {
  const _CardPalette(this.dark);
  final bool dark;

  Color get surface => dark ? const Color(0xFF282326) : Colors.white;
  Color get border =>
      dark ? const Color(0xFF51484B) : const Color(0xFFE4D2D5);
  Color get text => dark ? Colors.white : const Color(0xFF241A1D);
  Color get muted =>
      dark ? const Color(0xFFBDB4B7) : const Color(0xFF6E6064);
  Color get placeholderStart =>
      dark ? const Color(0xFF30272A) : const Color(0xFFFBF0F2);
  Color get placeholderEnd =>
      dark ? const Color(0xFF211A1D) : const Color(0xFFF1DDE1);
  Color get placeholderIcon =>
      dark ? const Color(0xFFFFB4BD) : const Color(0xFF7A1224);
}

_CardPalette _pal(BuildContext context) =>
    _CardPalette(Theme.of(context).brightness == Brightness.dark);

/// Compact product tile. Follows light / dark mode and the app language.
class MarketplaceCatalogCard extends StatelessWidget {
  const MarketplaceCatalogCard({
    super.key,
    required this.item,
    required this.onDetails,
    required this.onAction,
    this.actionBusy = false,
    this.rating,
  });

  final MarketplaceItem item;
  final VoidCallback onDetails;
  final VoidCallback onAction;
  final bool actionBusy;
  final ProductRating? rating;

  String _actionLabel(BuildContext context) => item.isService
      ? AppText.of(context, 'সার্ভিস বুকিং করুন', 'Book service')
      : item.canAddToCart
          ? AppText.of(context, 'কার্টে যোগ করুন', 'Add to cart')
          : AppText.of(context, 'বিস্তারিত দেখুন', 'View details');

  @override
  Widget build(BuildContext context) {
    final p = _pal(context);
    final unavailable = !item.isService && !item.canAddToCart;
    final discount = item.discountPercent;
    final original = item.comparePrice;
    final hasOriginal = discount != null && original != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: p.border, width: 1),
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
                          if (item.isFeatured)
                            _tag(AppText.of(context, 'ফিচার্ড', 'Featured')),
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
                        color: Colors.black.withOpacity(0.72),
                        child: Text(
                          AppText.of(context, 'স্টকে নেই', 'Out of stock'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 4, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 13,
                        height: 1.12,
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
                            color: p.muted, fontSize: 10, height: 1.15),
                      ),
                    ],
                    if (rating != null && rating!.count > 0)
                      Text('★ ${rating!.average.toStringAsFixed(1)} (${rating!.count})',
                        style: TextStyle(color: p.muted, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
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
                                style: TextStyle(
                                  color: p.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (hasOriginal)
                                Text(
                                  '৳${original.toStringAsFixed(original % 1 == 0 ? 0 : 2)}',
                                  style: TextStyle(
                                    color: p.muted,
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            tooltip: _actionLabel(context),
                            onPressed: actionBusy
                                ? null
                                : (unavailable ? onDetails : onAction),
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: _maroon,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  _maroon.withOpacity(0.45),
                              disabledForegroundColor: Colors.white70,
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
                              size: 19,
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
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
      );
}

/// Uses only secure absolute HTTPS image URLs and a branded fallback.
class MarketplaceCatalogImage extends StatelessWidget {
  const MarketplaceCatalogImage({super.key, required this.item});

  final MarketplaceItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final uri = Uri.tryParse(url ?? '');
    final valid = uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
    if (!valid) return _placeholder(context);

    return Image.network(
      url!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(context),
      errorBuilder: (context, _, __) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final p = _pal(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.placeholderStart, p.placeholderEnd],
        ),
      ),
      child: Center(
        child: Icon(
          item.isService ? Icons.engineering_outlined : Icons.fire_extinguisher,
          color: p.placeholderIcon,
          // Larger than before (was 42), so it does not look lost in the box.
          size: 56,
        ),
      ),
    );
  }
}
