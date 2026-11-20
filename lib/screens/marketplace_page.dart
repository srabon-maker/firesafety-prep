import 'package:flutter/material.dart';

import '../models/marketplace_category.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_api_service.dart';
import '../services/marketplace_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/auth_guard.dart';
import '../widgets/marketplace_catalog_card.dart';
import 'marketplace_flows.dart';

const Color marketMaroon = Color(0xFF650D18);
const Color marketDeepMaroon = Color(0xFF36060D);
const Color marketBackground = Color(0xFFF8F5F5);

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  int _cartCount = 0;
  bool _adding = false;
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  String? _categoryId;
  String _sort = 'featured';
  late Future<List<MarketplaceItem>> _catalog;
  late Future<List<MarketplaceCategory>> _categoryOptions;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadCartCount();
  }

  void _reload() {
    _catalog = MarketplaceApiService.instance.fetchCatalog(
      isService: _tab == 1,
    );
    _categoryOptions = MarketplaceApiService.instance.fetchCategories(
      isService: _tab == 1,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
    setState(() => _adding = true);
    try {
      final service = MarketplaceTransactionService.instance;
      final cart = await service.getCart();
      final existing = cart.items.where((line) => line.productId == id);
      final quantity = existing.isEmpty ? 0 : existing.first.quantity;
      if (quantity >= 99 || quantity >= (item.stock ?? 0)) {
        throw Exception('স্টকের বেশি পণ্য যোগ করা যাবে না।');
      }
      final updated = await service.setQuantity(id, quantity + 1);
      if (!mounted) return;
      setState(() => _cartCount = updated.count);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('কার্টে যোগ হয়েছে।')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
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
    final hasDiscount = item.discountPercent != null;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: marketBackground,
        appBar: AppBar(
          title: Text(item.isService ? 'সার্ভিস বিস্তারিত' : 'পণ্যের বিস্তারিত'),
          backgroundColor: marketDeepMaroon,
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
                style: const TextStyle(
                  color: marketMaroon,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 6),
            Text(
              item.name,
              style: const TextStyle(
                color: marketDeepMaroon,
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
                  style: const TextStyle(
                    color: marketMaroon,
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasDiscount)
                  Text(
                    '৳${item.comparePrice!.toStringAsFixed(item.comparePrice! % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                      color: Colors.grey,
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
                    color: item.canAddToCart
                        ? const Color(0xFF27815A)
                        : marketMaroon,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    item.canAddToCart
                        ? 'স্টকে আছে · ${item.stock}টি'
                        : 'বর্তমানে স্টকে নেই',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'বিস্তারিত বিবরণ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: marketDeepMaroon,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.description.isEmpty
                        ? 'বিস্তারিত তথ্য এখনো যোগ করা হয়নি।'
                        : item.description,
                    style: const TextStyle(height: 1.55, fontSize: 14),
                  ),
                ],
              ),
            ),
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
                        backgroundColor: marketMaroon,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: const Text('সার্ভিস বুকিং করুন'),
                    )
                  : FilledButton.icon(
                      onPressed: item.canAddToCart && !_adding
                          ? () => _add(item)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: marketMaroon,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: Text(item.canAddToCart
                          ? 'কার্টে যোগ করুন'
                          : 'স্টকে নেই'),
                    ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _catalogView() {
    return FutureBuilder<List<MarketplaceItem>>(
      future: _catalog,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(48),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(
            children: [
              const Icon(Icons.wifi_off, size: 44, color: marketMaroon),
              const SizedBox(height: 12),
              const Text('পণ্য বা সার্ভিস লোড করা যায়নি।'),
              const SizedBox(height: 6),
              Text('${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh),
                label: const Text('আবার চেষ্টা করুন'),
              ),
            ],
          );
        }
        final query = _search.text.trim().toLowerCase();
        final filtered = (snapshot.data ?? []).where((item) {
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
                final featured = (b.isFeatured ? 1 : 0)
                    .compareTo(a.isFeatured ? 1 : 0);
                return featured != 0 ? featured : a.name.toLowerCase()
                    .compareTo(b.name.toLowerCase());
            }
          });
        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text(query.isNotEmpty || _categoryId != null
                  ? 'এই অনুসন্ধানে কিছু পাওয়া যায়নি।'
                  : 'এখনো কোনো ${_tab == 0 ? 'পণ্য' : 'সার্ভিস'} প্রকাশ করা হয়নি।'),
            ),
          );
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 950 ? 4 : width >= 650 ? 3 : 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.grid_view_rounded,
                        color: marketMaroon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _tab == 0 ? 'জনপ্রিয় পণ্য' : 'জনপ্রিয় সার্ভিস',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: marketDeepMaroon,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length}টি',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'ফলাফল সাজান',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sort,
                        borderRadius: BorderRadius.circular(14),
                        items: const [
                          DropdownMenuItem(
                            value: 'featured', child: Text('প্রস্তাবিত'),
                          ),
                          DropdownMenuItem(
                            value: 'price_low', child: Text('কম দাম আগে'),
                          ),
                          DropdownMenuItem(
                            value: 'price_high', child: Text('বেশি দাম আগে'),
                          ),
                          DropdownMenuItem(
                            value: 'name', child: Text('নাম অনুযায়ী'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _sort = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 372,
                  ),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return MarketplaceCatalogCard(
                      key: ValueKey('${item.isService}-${item.id}'),
                      item: item,
                      actionBusy: _adding,
                      onDetails: () => _showDetails(item),
                      onAction: () {
                        if (item.isService) {
                          _bookService(item);
                        } else {
                          _add(item);
                        }
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _categoryIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('নির্বাপক') || value.contains('extinguisher')) {
      return Icons.fire_extinguisher_rounded;
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      toolbarHeight: 60,
      backgroundColor: marketDeepMaroon,
      foregroundColor: Colors.white,
      leadingWidth: 64,
      leading: const Padding(
        padding: EdgeInsets.all(13),
        child: Icon(
          Icons.local_fire_department_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      title: null,
      actions: [
        IconButton(
          tooltip: 'অর্ডার ও বুকিং ইতিহাস',
          onPressed: _showHistory,
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        Badge(
          isLabelVisible: _cartCount > 0,
          label: Text('$_cartCount'),
          child: IconButton(
            tooltip: 'কার্ট',
            onPressed: _showCart,
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: RefreshIndicator(
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
          Container(
            height: 214,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8F182A), marketMaroon, marketDeepMaroon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: marketMaroon.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -46,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                        width: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: -12,
                  child: Icon(
                    Icons.fire_extinguisher_rounded,
                    size: 154,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 22, 18, 20),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 42,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4052),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'ফায়ার সেফটি\\nমার্কেটপ্লেস',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                height: 1.16,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'ফায়ার সেফটি পণ্য ও নির্ভরযোগ্য সার্ভিস এক জায়গায়',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        flex: 4,
                        child: SizedBox(
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Positioned(
                                right: 0,
                                bottom: 3,
                                child: Icon(
                                  Icons.fire_extinguisher_rounded,
                                  color: Color(0xFFFFE9EC),
                                  size: 116,
                                ),
                              ),
                              Positioned(
                                left: 0,
                                bottom: 12,
                                child: Icon(
                                  Icons.sensors_rounded,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  size: 43,
                                ),
                              ),
                              Positioned(
                                left: 4,
                                top: 19,
                                child: Icon(
                                  Icons.notifications_active_rounded,
                                  color: const Color(0xFFFF6573)
                                      .withValues(alpha: 0.95),
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'পণ্য বা সার্ভিস খুঁজুন',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 17,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: const BorderSide(color: marketMaroon, width: 1.6),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'সার্চ মুছুন',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            showSelectedIcon: true,
            style: SegmentedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              selectedBackgroundColor: marketMaroon,
              selectedForegroundColor: Colors.white,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            ),
            segments: const [
              ButtonSegment(value: 0, label: Text('পণ্য'),
                  icon: Icon(Icons.shopping_bag_outlined)),
              ButtonSegment(value: 1, label: Text('সার্ভিস'),
                  icon: Icon(Icons.engineering_outlined)),
            ],
            selected: {_tab},
            onSelectionChanged: (selection) => setState(() {
              _tab = selection.first;
              _categoryId = null;
              _reload();
            }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text(
                'ক্যাটাগরি',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _categoryId = null),
                child: const Text(
                  'সব দেখুন  ›',
                  style: TextStyle(
                    color: Color(0xFFFF4052),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<MarketplaceCategory>>(
            future: _categoryOptions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(
                  children: [
                    const Expanded(
                      child: Text('ক্যাটাগরি লোড করা যায়নি।'),
                    ),
                    TextButton(
                      onPressed: () => setState(_reload),
                      child: const Text('আবার চেষ্টা'),
                    ),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 92,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final categories = snapshot.data!;
              if (categories.isEmpty) {
                return const SizedBox.shrink();
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 650 ? 5 : 4;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      mainAxisExtent: 104,
                    ),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final selected = _categoryId == category.id;
                      return Material(
                        color: selected
                            ? marketMaroon.withValues(alpha: 0.24)
                            : Theme.of(context)
                                .colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => setState(() {
                            _categoryId = selected ? null : category.id;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFFFF4052)
                                    : Theme.of(context)
                                        .colorScheme.outlineVariant
                                        .withValues(alpha: 0.65),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _categoryIcon(category.name),
                                  color: selected
                                      ? const Color(0xFFFF6573)
                                      : const Color(0xFFFFB4BD),
                                  size: 30,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  category.name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.2,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 18),
          _catalogView(),
        ],
      ),
    ),
  );
}
