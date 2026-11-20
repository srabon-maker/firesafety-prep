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

Widget _marketplaceHeaderPill(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFFD9DF), size: 15),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600,
        )),
      ],
    ),
  );
}

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
    final hasDiscount = item.price != null &&
        item.comparePrice != null &&
        item.comparePrice! > item.price!;
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
          final queryMatches = query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query);
          return categoryMatches && queryMatches;
        }).toList();
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
                      _tab == 0 ? 'আমাদের পণ্যসমূহ' : 'আমাদের সার্ভিসসমূহ',
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
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 346,
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      backgroundColor: marketDeepMaroon,
      foregroundColor: Colors.white,
      title: const Text('মার্কেটপ্লেস'),
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8F182A), marketMaroon, marketDeepMaroon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: marketMaroon.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -34,
                  top: -42,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 28,
                  bottom: -55,
                  child: Icon(
                    Icons.shield_outlined,
                    size: 150,
                    color: Colors.white.withValues(alpha: 0.055),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(21, 22, 21, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ),
                            child: const Icon(
                              Icons.local_fire_department_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_user_outlined,
                                  color: Color(0xFFFFD9DF), size: 15),
                                SizedBox(width: 6),
                                Text('সেফটি ফার্স্ট',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  )),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'ফায়ার সেফটি\nমার্কেটপ্লেস',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 25,
                          height: 1.16,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ফায়ার সেফটি পণ্য ও নির্ভরযোগ্য সার্ভিস—সব এক জায়গায়',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _marketplaceHeaderPill(
                            Icons.shopping_bag_outlined, 'মানসম্মত পণ্য',
                          ),
                          _marketplaceHeaderPill(
                            Icons.engineering_outlined, 'প্রফেশনাল সার্ভিস',
                          ),
                        ],
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
          const Text('ক্যাটাগরি',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
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
                  height: 44,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final categories = snapshot.data!;
              return SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final category = i == 0 ? null : categories[i - 1];
                    final id = category?.id;
                    final selected = _categoryId == id;
                    return ChoiceChip(
                      avatar: selected
                          ? const Icon(Icons.check_rounded, size: 16)
                          : null,
                      label: Text(category?.name ??
                          (_tab == 0 ? 'সব পণ্য' : 'সব সেবা')),
                      selected: selected,
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      selectedColor: marketMaroon,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      side: BorderSide(
                        color: selected
                            ? marketMaroon
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (_) => setState(() => _categoryId = id),
                    );
                  },
                ),
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
