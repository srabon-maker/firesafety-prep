import 'package:flutter/material.dart';

import '../models/marketplace_category.dart';
import '../models/marketplace_item.dart';
import '../services/marketplace_api_service.dart';

const Color marketMaroon = Color(0xFF650D18);
const Color marketDeepMaroon = Color(0xFF36060D);
const Color marketBackground = Color(0xFFF8F5F5);

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  final Map<String, int> _cart = {};
  final Map<String, MarketplaceItem> _cartItems = {};
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  String? _categoryId;
  late Future<List<MarketplaceItem>> _catalog;
  late Future<List<MarketplaceCategory>> _categoryOptions;

  @override
  void initState() {
    super.initState();
    _reload();
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

  void _add(MarketplaceItem item) {
    if (!item.canAddToCart) return;
    final quantity = _cart[item.id] ?? 0;
    if (item.stock != null && quantity >= item.stock!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('স্টকের বেশি যোগ করা যাবে না।')),
      );
      return;
    }
    setState(() {
      _cart[item.id] = quantity + 1;
      _cartItems[item.id] = item;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('কার্টে যোগ হয়েছে।')),
    );
  }

  void _changeQuantity(String id, int delta) {
    final next = (_cart[id] ?? 0) + delta;
    final item = _cartItems[id];
    if (item == null || (item.stock != null && next > item.stock!)) return;
    setState(() {
      if (next <= 0) {
        _cart.remove(id);
        _cartItems.remove(id);
      } else {
        _cart[id] = next;
      }
    });
  }

  int get _cartCount => _cart.values.fold(0, (sum, qty) => sum + qty);

  void _showCart() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('আমার কার্ট')),
        body: StatefulBuilder(
          builder: (context, updateDialog) {
            final items = _cartItems.values.toList();
            final total = items.fold<double>(
              0, (sum, item) => sum + (item.price ?? 0) * (_cart[item.id] ?? 0),
            );
            if (items.isEmpty) {
              return const Center(child: Text('আপনার কার্ট খালি।'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((item) => Card(
                  child: ListTile(
                    title: Text(item.name),
                    subtitle: Text('${item.priceLabel} × ${_cart[item.id]}'),
                    trailing: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'কমাতে',
                          onPressed: () {
                            _changeQuantity(item.id, -1);
                            updateDialog(() {});
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${_cart[item.id]}'),
                        IconButton(
                          tooltip: 'বাড়াতে',
                          onPressed: () {
                            _changeQuantity(item.id, 1);
                            updateDialog(() {});
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                )),
                const SizedBox(height: 16),
                Text('মোট: ৳${total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  'Checkout এখনো চালু হয়নি। সার্ভারের Order API যাচাই করে পরবর্তী ধাপে যুক্ত করা হবে।',
                ),
              ],
            );
          },
        ),
      ),
    ));
  }

  void _showDetails(MarketplaceItem item) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('বিস্তারিত')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _itemImage(item, height: 210),
            const SizedBox(height: 18),
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (item.category.isNotEmpty) Text(item.category),
            const SizedBox(height: 8),
            Text(item.priceLabel,
                style: Theme.of(context).textTheme.titleLarge),
            if (item.comparePrice != null &&
                item.price != null &&
                item.comparePrice! > item.price!)
              Text(
                '৳${item.comparePrice!.toStringAsFixed(2)}',
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                ),
              ),
            if (!item.isService)
              Text('মজুত: ${item.stock ?? 0}টি'),
            const SizedBox(height: 16),
            Text(item.description.isEmpty
                ? 'বিস্তারিত তথ্য এখনো যোগ করা হয়নি।'
                : item.description),
            const SizedBox(height: 24),
            if (item.canAddToCart)
              FilledButton.icon(
                onPressed: () => _add(item),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('কার্টে যোগ করুন'),
              )
            else
              Text(item.isService
                  ? 'সার্ভিস বুকিং এখনো চালু হয়নি।'
                  : 'এই পণ্যটি বর্তমানে কার্টে যোগ করা যাচ্ছে না।'),
          ],
        ),
      ),
    ));
  }

  Widget _itemImage(MarketplaceItem item, {double height = 130}) {
    final uri = Uri.tryParse(item.imageUrl ?? '');
    final valid = uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
    if (!valid) {
      return Container(
        height: height,
        color: const Color(0xFFF4E7E9),
        child: Icon(item.isService ? Icons.engineering : Icons.fire_extinguisher,
            color: marketMaroon, size: 44),
      );
    }
    return Image.network(
      item.imageUrl!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFF4E7E9),
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: .68,
          ),
          itemBuilder: (context, index) {
            final item = filtered[index];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showDetails(item),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _itemImage(item),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Text(item.priceLabel, maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (item.comparePrice != null &&
                                item.price != null &&
                                item.comparePrice! > item.price!)
                              Text(
                                '৳${item.comparePrice!.toStringAsFixed(2)}',
                                maxLines: 1,
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: item.canAddToCart
                                    ? () => _add(item)
                                    : () => _showDetails(item),
                                style: FilledButton.styleFrom(
                                  backgroundColor: marketMaroon,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(item.canAddToCart
                                    ? 'কার্টে যোগ'
                                    : 'বিস্তারিত'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: marketBackground,
    appBar: AppBar(
      backgroundColor: marketDeepMaroon,
      foregroundColor: Colors.white,
      title: const Text('মার্কেটপ্লেস'),
      actions: [
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
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [marketMaroon, marketDeepMaroon],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                SizedBox(height: 10),
                Text('ফায়ার সেফটি মার্কেটপ্লেস',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 20)),
                SizedBox(height: 5),
                Text('ফায়ার সেফটি পণ্য ও সার্ভিস এক জায়গায়',
                    style: TextStyle(color: Colors.white70)),
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
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
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
                    return ChoiceChip(
                      label: Text(category?.name ??
                          (_tab == 0 ? 'সব পণ্য' : 'সব সেবা')),
                      selected: _categoryId == id,
                      onSelected: (_) =>
                          setState(() => _categoryId = id),
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
