import 'package:flutter/material.dart';
import '../widgets/design_system.dart';

import '../models/marketplace_category.dart';
import '../models/marketplace_engagement.dart';
import '../widgets/marketplace_reviews.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_api_service.dart';
import '../services/marketplace_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import '../widgets/marketplace_catalog_card.dart';
import 'marketplace_flows.dart';

// These public colours are kept because other files (the product card, cart
// and booking pages) may still use them. This page itself uses
// _MarketPalette below, which follows light / dark mode.
const Color marketMaroon = Color(0xFF9D1026);
const Color marketDeepMaroon = Color(0xFF39050D);
const Color marketBackground = Color(0xFF101010);
const Color marketCardSurface = Color(0xFF282326);
const Color marketCardBorder = Color(0xFF51484B);
const Color marketMutedText = Color(0xFFBDB4B7);

// Same maroon family as the profile page.
const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);
const Color _midMaroon = Color(0xFF891C32);

/// All colours of this page in one place, for light and dark mode.
class _MarketPalette {
  const _MarketPalette(this.dark);
  final bool dark;

  Color get background =>
      dark ? const Color(0xFF101010) : const Color(0xFFFBF5F5);
  Color get surface => dark ? const Color(0xFF282326) : Colors.white;
  Color get border =>
      dark ? const Color(0xFF51484B) : const Color(0xFFE4D2D5);
  Color get text => dark ? Colors.white : const Color(0xFF241A1D);
  Color get muted =>
      dark ? const Color(0xFFBDB4B7) : const Color(0xFF6E6064);
  Color get accent => dark ? const Color(0xFFFFB3BC) : _maroon;
  Color get fill => const Color(0xFF7A1224);
  Color get appBar => dark ? _deepMaroon : _maroon;
  Color get inputFill => dark ? const Color(0xFF292528) : Colors.white;
  Color get selectedTile =>
      dark ? const Color(0xFF4A1821) : const Color(0xFFF7E4E7);
  Color get tileIcon =>
      dark ? const Color(0xFFFFB4BD) : const Color(0xFF7A1224);
  Color get disabledFill =>
      dark ? const Color(0xFF3A3236) : const Color(0xFFE3D9DB);
  Color get good => const Color(0xFF2FA56F);
}

_MarketPalette _pal(BuildContext context) =>
    _MarketPalette(Theme.of(context).brightness == Brightness.dark);

// Thrown when the cart is already at the stock limit. A marker class (not
// a Bengali sentence) so the message can be shown in the chosen language.
class _StockLimitException implements Exception {
  const _StockLimitException();
}

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  int _cartCount = 0;
  bool _adding = false;
  // বিস্তারিত পেজের বাটনও যেন "যোগ হচ্ছে" অবস্থা জানতে পারে, তাই আলাদা নোটিফায়ার।
  final ValueNotifier<bool> _addingNotifier = ValueNotifier<bool>(false);
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  String? _categoryId;
  String _sort = 'featured';
  late Future<List<MarketplaceItem>> _catalog;
  late Future<List<MarketplaceCategory>> _categoryOptions;
  late Future<MarketplaceEngagement> _engagement;
  MarketplaceEngagement? _engagementCache;
  int _engagementEpoch = 0;

  // Last loaded data of each tab (0 = products, 1 = services). While a tab
  // reloads, its old data stays on screen, so the page does not jump.
  final Map<int, List<MarketplaceItem>> _catalogCache = {};
  final Map<int, List<MarketplaceCategory>> _categoryCache = {};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadCartCount();
  }

  void _reload() {
    final tab = _tab;
    final epoch = ++_engagementEpoch;
    _engagement = MarketplaceApiService.instance.get('engagement.php').then((response) {
      final data = MarketplaceEngagement.fromJson(Map<String,dynamic>.from(response['data'] as Map));
      if (mounted && epoch == _engagementEpoch) setState(() => _engagementCache = data);
      return data;
    });
    _engagement.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _catalog = MarketplaceApiService.instance
        .fetchCatalog(isService: tab == 1)
        .then((items) {
      _catalogCache[tab] = items;
      if (mounted && tab == _tab) setState(() {});
      return items;
    });
    _categoryOptions = MarketplaceApiService.instance
        .fetchCategories(isService: tab == 1)
        .then((categories) {
      _categoryCache[tab] = categories;
      return categories;
    });
    _catalog.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _categoryOptions.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  @override
  void dispose() {
    _search.dispose();
    _addingNotifier.dispose();
    super.dispose();
  }

  String _tr(BuildContext context, String bn, String en) =>
      AppText.of(context, bn, en);

  void _setAdding(bool value) {
    if (!mounted) return;
    setState(() => _adding = value);
    _addingNotifier.value = value;
  }

  // বাংলা বার্তা থাকলে সেটাই দেখাবে, না থাকলে সাধারণ বার্তা।
  String _friendlyError(Object e) {
    if (e is _StockLimitException) {
      return _tr(context, 'স্টকের বেশি পণ্য যোগ করা যাবে না।',
          'You cannot add more than the available stock.');
    }
    final message = e.toString().replaceFirst('Exception: ', '');
    final hasBengali = RegExp(r'[\u0980-\u09FF]').hasMatch(message);
    return hasBengali
        ? message
        : _tr(context, 'কিছু একটা সমস্যা হয়েছে। আবার চেষ্টা করুন।',
            'Something went wrong. Please try again.');
  }

  Future<void> _loadCartCount() async {
    try {
      final token = await AuthService.instance.getSessionToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _cartCount = 0);
        return;
      }
      final cart = await MarketplaceTransactionService.instance.getCart();
      if (mounted) setState(() => _cartCount = cart.count);
    } catch (_) {
      // The public catalog remains usable even when a session expires.
      if (mounted) setState(() => _cartCount = 0);
    }
  }

  Future<void> _add(MarketplaceItem item) async {
    if (_adding || !item.canAddToCart) return;
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    final id = int.tryParse(item.id);
    if (id == null || id < 1) return;
    _setAdding(true);
    try {
      final service = MarketplaceTransactionService.instance;
      final cart = await service.getCart();
      final existing = cart.items.where((line) => line.productId == id);
      final quantity = existing.isEmpty ? 0 : existing.first.quantity;
      if (quantity >= 99 || quantity >= (item.stock ?? 0)) {
        throw const _StockLimitException();
      }
      final updated = await service.setQuantity(id, quantity + 1);
      if (!mounted) return;
      setState(() => _cartCount = updated.count);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_tr(context, 'কার্টে যোগ হয়েছে।', 'Added to cart.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      _setAdding(false);
    }
  }

  Future<void> _showCart() async {
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MarketplaceCartPage(),
    ));
    if (mounted) await _loadCartCount();
  }

  Future<void> _showHistory() async {
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const MarketplaceHistoryPage(),
    ));
  }

  Future<void> _bookService(MarketplaceItem item) async {
    if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MarketplaceServiceBookingPage(service: item),
    ));
  }

  void _showDetails(MarketplaceItem item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (routeContext) => _detailsPage(routeContext, item),
    ));
  }

  Widget _detailsPage(BuildContext context, MarketplaceItem item) {
    final p = _pal(context);
    final hasDiscount = item.discountPercent != null;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(item.isService
            ? _tr(context, 'সার্ভিস বিস্তারিত', 'Service details')
            : _tr(context, 'পণ্যের বিস্তারিত', 'Product details')),
        backgroundColor: p.appBar,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 260,
              child: MarketplaceCatalogImage(item: item),
            ),
          ),
          const SizedBox(height: 18),
          if (item.category.isNotEmpty)
            Text(
              item.category,
              style: TextStyle(
                color: p.accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: TextStyle(
              color: p.text,
              fontWeight: FontWeight.w800,
              fontSize: 23,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                item.priceLabel,
                style: TextStyle(
                  color: p.accent,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasDiscount)
                Text(
                  '৳${item.comparePrice!.toStringAsFixed(item.comparePrice! % 1 == 0 ? 0 : 2)}',
                  style: TextStyle(
                    color: p.muted,
                    fontSize: 15,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
          if (!item.isService) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  item.canAddToCart
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: item.canAddToCart ? p.good : p.accent,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Text(
                  item.canAddToCart
                      ? _tr(context, 'স্টকে আছে · ${item.stock}টি',
                          'In stock · ${item.stock}')
                      : _tr(context, 'বর্তমানে স্টকে নেই',
                          'Currently out of stock'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: p.text,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: p.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr(context, 'বিস্তারিত বিবরণ', 'Description'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: p.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description.isEmpty
                      ? _tr(context, 'বিস্তারিত তথ্য এখনো যোগ করা হয়নি।',
                          'No details have been added yet.')
                      : item.description,
                  style: TextStyle(
                    height: 1.55,
                    fontSize: 14,
                    color: p.muted,
                  ),
                ),
              ],
            ),
          ),
          if (!item.isService) MarketplaceReviews(productId: item.id),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: SizedBox(
            height: 50,
            child: item.isService
                ? FilledButton.icon(
                    onPressed: () => _bookService(item),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.fill,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(_tr(context, 'সার্ভিস বুকিং করুন', 'Book service')),
                  )
                : ValueListenableBuilder<bool>(
                    valueListenable: _addingNotifier,
                    builder: (context, busy, _) => FilledButton.icon(
                      onPressed:
                          item.canAddToCart && !busy ? () => _add(item) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: p.fill,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: p.disabledFill,
                        disabledForegroundColor: p.muted,
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(item.canAddToCart
                          ? _tr(context, 'কার্টে যোগ করুন', 'Add to cart')
                          : _tr(context, 'স্টকে নেই', 'Out of stock')),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// Sort button shown next to the list heading.
  Widget _sortMenu(_MarketPalette p) {
    final options = <String, String>{
      'featured': _tr(context, 'বিশেষ পণ্য আগে', 'Featured first'),
      'price_low': _tr(context, 'দাম: কম থেকে বেশি', 'Price: low to high'),
      'price_high': _tr(context, 'দাম: বেশি থেকে কম', 'Price: high to low'),
      'name': _tr(context, 'নাম অনুযায়ী (A–Z)', 'Name (A–Z)'),
    };
    return PopupMenuButton<String>(
      tooltip: _tr(context, 'সাজান', 'Sort'),
      color: p.surface,
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      icon: Icon(
        Icons.sort_rounded,
        // Maroon when a non-default order is active.
        color: _sort == 'featured' ? p.muted : p.accent,
      ),
      itemBuilder: (_) => [
        for (final entry in options.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: _sort == entry.key
                      ? Icon(Icons.check_rounded, size: 18, color: p.accent)
                      : null,
                ),
                Text(entry.value, style: TextStyle(color: p.text)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _catalogView() {
    final p = _pal(context);
    return FutureBuilder<List<MarketplaceItem>>(
      key: ValueKey('catalog-$_tab'),
      future: _catalog,
      builder: (context, snapshot) {
        // Fresh data if ready, otherwise the last data of this tab.
        final items = snapshot.data ?? _catalogCache[_tab];
        if (items == null) {
          if (snapshot.hasError) {
            // ব্যবহারকারীকে কারিগরি ত্রুটির লেখা না দেখিয়ে শুধু সাধারণ বার্তা দেখানো হচ্ছে।
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.wifi_off, size: 44, color: p.accent),
                  const SizedBox(height: 12),
                  Text(
                    _tr(context, 'পণ্য বা সার্ভিস লোড করা যায়নি।',
                        'Could not load products or services.'),
                    style: TextStyle(color: p.text),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tr(context, 'ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
                        'Check your internet connection and try again.'),
                    style: TextStyle(color: p.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(_reload),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.accent,
                      side: BorderSide(color: p.accent.withOpacity(0.6)),
                    ),
                    icon: const Icon(Icons.refresh),
                    label: Text(_tr(context, 'আবার চেষ্টা করুন', 'Try again')),
                  ),
                ],
              ),
            );
          }
          // First load of this tab. Tall placeholder, so the page does not
          // shrink and jump to the top.
          return SizedBox(
            height: 360,
            child: const FsLoadingCards(count: 3),
          );
        }
        final query = _search.text.trim().toLowerCase();
        final filtered = items.where((item) {
          final categoryMatches =
              _categoryId == null || item.categoryId == _categoryId;
          final searchable = [
            item.name, item.description, item.category,
          ].join(' ').toLowerCase();
          final queryMatches = query.isEmpty || searchable.contains(query);
          return categoryMatches && queryMatches;
        }).toList()
          ..sort((a, b) {
            switch (_sort) {
              case 'price_low':
                return (a.price ?? double.infinity)
                    .compareTo(b.price ?? double.infinity);
              case 'price_high':
                return (b.price ?? -1).compareTo(a.price ?? -1);
              case 'name':
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              default:
                final featured =
                    (b.isFeatured ? 1 : 0).compareTo(a.isFeatured ? 1 : 0);
                return featured != 0
                    ? featured
                    : a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          });
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(
                query.isNotEmpty || _categoryId != null
                    ? _tr(context, 'এই অনুসন্ধানে কিছু পাওয়া যায়নি।',
                        'Nothing found for this search.')
                    : (_tab == 0
                        ? _tr(context, 'এখনো কোনো পণ্য প্রকাশ করা হয়নি।',
                            'No products have been published yet.')
                        : _tr(context, 'এখনো কোনো সার্ভিস প্রকাশ করা হয়নি।',
                            'No services have been published yet.')),
                style: TextStyle(color: p.text),
              ),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
            final columns = width < 290 || largeText
                ? 1
                : width >= 950 ? 4 : width >= 650 ? 3 : 2;
            const gap = 10.0;
            final cardWidth = (width - gap * (columns - 1)) / columns;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view_rounded, color: p.accent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _tab == 0
                            ? _tr(context, 'জনপ্রিয় পণ্য', 'Popular products')
                            : _tr(context, 'জনপ্রিয় সার্ভিস', 'Popular services'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: p.text,
                        ),
                      ),
                    ),
                    _sortMenu(p),
                    TextButton(
                      onPressed: () => setState(() {
                        _categoryId = null;
                        _search.clear();
                      }),
                      child: Text(
                        _tr(context, 'সব দেখুন  ›', 'View all  ›'),
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Let each card grow for real content instead of reserving a
                // fixed-height empty region under every product.
                Wrap(
                  spacing: gap,
                  runSpacing: 12,
                  children: [
                    for (final item in filtered)
                      SizedBox(
                        key: ValueKey('${item.isService}-${item.id}'),
                        width: cardWidth,
                        child: MarketplaceCatalogCard(
                          item: item,
                          actionBusy: _adding,
                          rating: item.isService ? null : _engagementCache?.ratings[item.id],
                          onDetails: () => _showDetails(item),
                          onAction: () {
                            if (item.isService) {
                              _bookService(item);
                            } else {
                              _add(item);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _productBanners() {
    final banners = _engagementCache?.banners ?? const <ProductBanner>[];
    if (_tab != 0 || banners.isEmpty) return const SizedBox.shrink();
    final products = _catalogCache[0] ?? const <MarketplaceItem>[];
    final byId = {for (final item in products) item.id: item};
    final visible = banners.where((b) => byId.containsKey(b.productId)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal, itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final banner = visible[index];
          final item = byId[banner.productId]!;
          final uri = Uri.tryParse(banner.imageUrl);
          return SizedBox(width: (MediaQuery.sizeOf(context).width - 48).clamp(160.0, 380.0).toDouble(),
            child: Material(color: const Color(0xFF650D18),borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,child: InkWell(onTap: () => _showDetails(item),
                child: Padding(padding: const EdgeInsets.all(12),child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,children: [
                      Text(banner.title,maxLines: 2,overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white,fontSize: 16,fontWeight: FontWeight.w600)),
                      if (banner.subtitle.isNotEmpty) Text(banner.subtitle,maxLines: 2,
                        overflow: TextOverflow.ellipsis,style: const TextStyle(color: Colors.white70,fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(_tr(context,'বিস্তারিত দেখুন ›','View details ›'),style: const TextStyle(color: Colors.white,fontSize: 12)),
                    ])),
                  const SizedBox(width: 8),
                  SizedBox(width: 88,height: 100,child: ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
                      ? Image.network(banner.imageUrl,fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => MarketplaceCatalogImage(item: item))
                      : MarketplaceCatalogImage(item: item))),
                ]))),
            ));
        },
      ),
    ));
  }

  Widget _categorySection() {
    final p = _pal(context);
    return FutureBuilder<List<MarketplaceCategory>>(
      key: ValueKey('categories-$_tab'),
      future: _categoryOptions,
      builder: (context, snapshot) {
        final categories = (snapshot.connectionState == ConnectionState.done
            ? snapshot.data : null) ?? _categoryCache[_tab] ??
            const <MarketplaceCategory>[];
        final loading = snapshot.connectionState == ConnectionState.waiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.category_outlined, color: p.accent, size: 19),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _tr(context, 'ক্যাটাগরি', 'Categories'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ),
                if (snapshot.hasError)
                  IconButton(
                    tooltip: _tr(context, 'ক্যাটাগরি আবার লোড করুন', 'Retry categories'),
                    onPressed: () => setState(_reload),
                    icon: Icon(Icons.refresh_rounded, color: p.accent),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ChoiceChip(
                    label: Text(_tr(context, 'সব', 'All')),
                    avatar: const Icon(Icons.grid_view_rounded, size: 16),
                    selected: _categoryId == null,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _categoryId = null),
                    selectedColor: p.selectedTile,
                    backgroundColor: p.surface,
                    side: BorderSide(
                      color: _categoryId == null ? p.accent : p.border,
                    ),
                    labelStyle: TextStyle(
                      color: _categoryId == null ? p.accent : p.text,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 7),
                  for (final category in categories) ...[
                    ChoiceChip(
                      label: Text(category.name),
                      avatar: Icon(_categoryIcon(category.name), size: 16),
                      selected: _categoryId == category.id,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _categoryId = _categoryId == category.id
                            ? null
                            : category.id;
                      }),
                      selectedColor: p.selectedTile,
                      backgroundColor: p.surface,
                      side: BorderSide(
                        color: _categoryId == category.id
                            ? p.accent
                            : p.border,
                      ),
                      labelStyle: TextStyle(
                        color: _categoryId == category.id ? p.accent : p.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
            if (categories.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  loading
                      ? _tr(context, 'ক্যাটাগরি লোড হচ্ছে…', 'Loading categories…')
                      : snapshot.hasError
                          ? _tr(context, 'ক্যাটাগরি লোড হয়নি। আবার চেষ্টা করুন।', 'Could not load categories. Try again.')
                          : _tr(context, 'এখনো কোনো ক্যাটাগরি যোগ করা হয়নি।', 'No categories have been added yet.'),
                  style: TextStyle(color: p.muted, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _headerAction({
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .12),
      foregroundColor: Colors.white,
      minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    icon: Icon(icon, size: 22),
  );

  IconData _categoryIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('নির্বাপক') || value.contains('extinguisher')) {
      return Icons.fire_extinguisher;
    }
    if (value.contains('ডিটেকশন') || value.contains('detector')) {
      return Icons.sensors_rounded;
    }
    if (value.contains('অ্যালার্ম') || value.contains('alarm')) {
      return Icons.notifications_active_rounded;
    }
    if (value.contains('স্প্রিংকলার') || value.contains('sprinkler')) {
      return Icons.water_drop_rounded;
    }
    if (value.contains('সার্ভিস') || value.contains('service')) {
      return Icons.engineering_rounded;
    }
    return Icons.grid_view_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = _pal(context);
    // This page is a bottom-menu tab. A back arrow is shown only when the
    // page was opened on top of another page.
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: p.appBar,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        leadingWidth: canGoBack ? 48 : 0,
        leading: canGoBack
            ? IconButton(
                tooltip: _tr(context, 'ফিরে যান', 'Back'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
              )
            : null,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.24)),
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                color: Colors.white,
                size: 29,
              ),
            ),
            const SizedBox(width: 9),
            Container(
              width: 1,
              height: 42,
              color: Colors.white.withOpacity(0.55),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                _tr(context, 'ফায়ার সেইফটি মার্কেটপ্লেস',
                    'Fire Safety Marketplace'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _headerAction(
            tooltip: _tr(context, 'অর্ডার ও বুকিং ইতিহাস',
                'Orders & booking history'),
            onPressed: _showHistory,
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(width: 5),
          Badge(
            isLabelVisible: _cartCount > 0,
            label: Text('$_cartCount'),
            child: _headerAction(
              tooltip: _tr(context, 'কার্ট', 'Cart'),
              onPressed: _showCart,
              icon: Icons.shopping_cart_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.surface,
        onRefresh: () async {
          setState(_reload);
          try {
            await _catalog;
          } catch (_) {
            // FutureBuilder displays the failure and retry action.
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _productBanners(),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: p.text, fontSize: 16),
              cursorColor: p.accent,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: p.muted, size: 26),
                hintText: _tr(context, 'পণ্য বা সার্ভিস খুঁজুন',
                    'Search products or services'),
                hintStyle: TextStyle(color: p.muted, fontSize: 15),
                filled: true,
                fillColor: p.inputFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: p.border, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(17),
                  borderSide: BorderSide(color: p.accent, width: 1.5),
                ),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: _tr(context, 'সার্চ মুছুন', 'Clear search'),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                        icon: Icon(Icons.close_rounded, color: p.muted),
                      ),
              ),
            ),
            const SizedBox(height: 13),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                backgroundColor: p.surface,
                foregroundColor: p.text,
                selectedBackgroundColor: p.fill,
                selectedForegroundColor: Colors.white,
                side: BorderSide(color: p.border, width: 1.1),
                textStyle:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                padding:
                    const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
              ),
              segments: [
                ButtonSegment(
                    value: 0,
                    label: Text(_tr(context, 'পণ্য', 'Products')),
                    icon: const Icon(Icons.shopping_bag_outlined, size: 21)),
                ButtonSegment(
                    value: 1,
                    label: Text(_tr(context, 'সার্ভিস', 'Services')),
                    icon: const Icon(Icons.engineering_outlined, size: 21)),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) => setState(() {
                _tab = selection.first;
                _categoryId = null;
                _reload();
              }),
            ),
            _categorySection(),
            const SizedBox(height: 18),
            _catalogView(),
          ],
        ),
      ),
    );
  }
}
