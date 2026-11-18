import 'package:flutter/material.dart';

import '../models/marketplace_item.dart';
import '../models/marketplace_transaction.dart';
import '../services/marketplace_transaction_service.dart';

const _maroon = Color(0xFF650D18);
final _market = MarketplaceTransactionService.instance;

String _error(Object error) => error.toString()
    .replaceFirst('Exception: ', '')
    .replaceFirst('FormatException: ', '');

void _message(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

InputDecoration _field(String label) => InputDecoration(
  labelText: label,
  border: const OutlineInputBorder(),
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
);

String? _required(String? value) =>
    (value == null || value.trim().isEmpty) ? 'এই তথ্যটি লিখুন' : null;

String? _phone(String? value) {
  if (value == null || !RegExp(r'^[0-9+ -]{10,20}$').hasMatch(value.trim())) {
    return '১০–২০ অক্ষরের সঠিক মোবাইল নম্বর দিন';
  }
  return null;
}

class MarketplaceCartPage extends StatefulWidget {
  const MarketplaceCartPage({super.key});
  @override
  State<MarketplaceCartPage> createState() => _MarketplaceCartPageState();
}

class _MarketplaceCartPageState extends State<MarketplaceCartPage> {
  late Future<MarketCart> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _market.getCart();
  }

  Future<void> _refresh() async {
    setState(() => _future = _market.getCart());
    try { await _future; } catch (_) {}
  }

  Future<void> _update(int productId, int quantity) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final cart = quantity == 0
          ? await _market.remove(productId)
          : await _market.setQuantity(productId, quantity);
      if (mounted) setState(() => _future = Future.value(cart));
    } catch (e) {
      if (mounted) _message(context, _error(e));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkout(MarketCart cart) async {
    if (_busy || cart.items.isEmpty) return;
    final placed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => MarketplaceCheckoutPage(cart: cart)),
    );
    if (!mounted) return;
    if (placed == true) {
      await _refresh();
      if (mounted) _message(context, 'অর্ডার সফলভাবে জমা হয়েছে।');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('আমার কার্ট')),
    body: FutureBuilder<MarketCart>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('কার্ট লোড করা যায়নি: ${_error(snapshot.error!)}',
                  textAlign: TextAlign.center),
              TextButton(onPressed: _refresh, child: const Text('আবার চেষ্টা')),
            ],
          ));
        }
        final cart = snapshot.data!;
        if (cart.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(children: const [
              SizedBox(height: 180),
              Center(child: Text('আপনার কার্ট খালি।')),
            ]),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in cart.items)
                Card(child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Text('৳${item.price.toStringAsFixed(2)} × ${item.quantity}'
                          ' = ৳${item.lineTotal.toStringAsFixed(2)}'),
                      if (item.quantity > item.stock)
                        const Text('স্টক পরিবর্তন হয়েছে। পরিমাণ কমান।',
                            style: TextStyle(color: Colors.red)),
                      Row(children: [
                        IconButton(
                          tooltip: 'একটি কমান',
                          onPressed: _busy ? null : () => _update(
                              item.productId, item.quantity - 1),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${item.quantity}'),
                        IconButton(
                          tooltip: 'একটি বাড়ান',
                          onPressed: _busy || item.quantity >= item.stock ||
                              item.quantity >= 99
                              ? null
                              : () => _update(item.productId, item.quantity + 1),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'কার্ট থেকে সরান',
                          onPressed: _busy ? null : () => _update(item.productId, 0),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ]),
                    ],
                  ),
                )),
              const SizedBox(height: 12),
              Text('পণ্যের মোট: ৳${cart.subtotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge),
              const Text('ডেলিভারি চার্জ: ৳০.০০ (বর্তমান সার্ভার নিয়ম অনুযায়ী)'),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _maroon, foregroundColor: Colors.white),
                onPressed: _busy || cart.items.any((e) => e.quantity > e.stock)
                    ? null : () => _checkout(cart),
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('চেকআউট করুন (Cash on Delivery)'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class MarketplaceCheckoutPage extends StatefulWidget {
  const MarketplaceCheckoutPage({super.key, required this.cart});
  final MarketCart cart;
  @override
  State<MarketplaceCheckoutPage> createState() => _MarketplaceCheckoutPageState();
}

class _MarketplaceCheckoutPageState extends State<MarketplaceCheckoutPage> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose(); _mobile.dispose(); _address.dispose(); _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_key.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final number = await _market.placeOrder(
        name: _name.text, mobile: _mobile.text,
        address: _address.text, note: _note.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('অর্ডার সফল হয়েছে'),
          content: Text('অর্ডার নম্বর: $number\nপেমেন্ট: Cash on Delivery'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ঠিক আছে'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message(context, _error(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('চেকআউট')),
    body: Form(
      key: _key,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('অর্ডার সারাংশ', style: Theme.of(context).textTheme.titleLarge),
        for (final item in widget.cart.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.name),
            subtitle: Text('পরিমাণ: ${item.quantity}'),
            trailing: Text('৳${item.lineTotal.toStringAsFixed(2)}'),
          ),
        const Divider(),
        Text('পণ্যের মোট: ৳${widget.cart.subtotal.toStringAsFixed(2)}'),
        const Text('পেমেন্ট: Cash on Delivery (COD)'),
        const Text('চূড়ান্ত মূল্য ও স্টক সার্ভার পুনরায় যাচাই করবে।'),
        const SizedBox(height: 20),
        TextFormField(controller: _name, decoration: _field('আপনার পূর্ণ নাম'),
            validator: _required, maxLength: 150),
        const SizedBox(height: 10),
        TextFormField(controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: _field('মোবাইল নম্বর'), validator: _phone,
            maxLength: 20),
        const SizedBox(height: 10),
        TextFormField(controller: _address,
            maxLines: 3, maxLength: 2000,
            decoration: _field('সম্পূর্ণ ডেলিভারি ঠিকানা'),
            validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _note,
            maxLines: 2, maxLength: 2000,
            decoration: _field('অতিরিক্ত নির্দেশনা (ঐচ্ছিক)')),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _maroon, foregroundColor: Colors.white),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('COD অর্ডার নিশ্চিত করুন'),
        ),
      ]),
    ),
  );
}

class MarketplaceHistoryPage extends StatefulWidget {
  const MarketplaceHistoryPage({super.key});
  @override
  State<MarketplaceHistoryPage> createState() => _MarketplaceHistoryPageState();
}

class _MarketplaceHistoryPageState extends State<MarketplaceHistoryPage> {
  late Future<List<MarketOrder>> _orders;
  late Future<List<MarketServiceRequest>> _requests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _orders = _market.getOrders();
    _requests = _market.getServiceRequests();
  }

  Future<void> _refresh() async {
    setState(_load);
    try { await Future.wait([_orders, _requests]); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('অর্ডার ও সার্ভিস ইতিহাস')),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('আমার অর্ডার', style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<MarketOrder>>(
          future: _orders,
          builder: (context, snapshot) {
            if (snapshot.hasError) return ListTile(
              title: Text('অর্ডার লোড করা যায়নি: ${_error(snapshot.error!)}'),
              trailing: IconButton(onPressed: _refresh,
                  icon: const Icon(Icons.refresh)),
            );
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const ListTile(title: Text('এখনো কোনো অর্ডার নেই।'));
            }
            return Column(children: [
              for (final order in snapshot.data!)
                Card(child: ListTile(
                  title: Text(order.number),
                  subtitle: Text('স্ট্যাটাস: ${order.status} • '
                      'পেমেন্ট: ${order.paymentStatus}\n${order.createdAt}'),
                  trailing: Text('৳${order.total.toStringAsFixed(2)}'),
                  isThreeLine: true,
                )),
            ]);
          },
        ),
        const SizedBox(height: 24),
        Text('আমার সার্ভিস অনুরোধ',
            style: Theme.of(context).textTheme.titleLarge),
        FutureBuilder<List<MarketServiceRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) return ListTile(
              title: Text('সার্ভিস অনুরোধ লোড করা যায়নি: ${_error(snapshot.error!)}'),
              trailing: IconButton(onPressed: _refresh,
                  icon: const Icon(Icons.refresh)),
            );
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.data!.isEmpty) {
              return const ListTile(title: Text('এখনো কোনো সার্ভিস অনুরোধ নেই।'));
            }
            return Column(children: [
              for (final request in snapshot.data!)
                Card(child: ListTile(
                  title: Text(request.serviceName.isEmpty
                      ? request.number : request.serviceName),
                  subtitle: Text('${request.number}\n'
                      'স্ট্যাটাস: ${request.status} • ${request.location}'
                      '${request.preferredDate == null ? '' : ' • ${request.preferredDate}'}'),
                  isThreeLine: true,
                )),
            ]);
          },
        ),
        const SizedBox(height: 80),
      ]),
    ),
  );
}

class MarketplaceServiceBookingPage extends StatefulWidget {
  const MarketplaceServiceBookingPage({super.key, required this.service});
  final MarketplaceItem service;
  @override
  State<MarketplaceServiceBookingPage> createState() =>
      _MarketplaceServiceBookingPageState();
}

class _MarketplaceServiceBookingPageState
    extends State<MarketplaceServiceBookingPage> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _location = TextEditingController();
  final _company = TextEditingController();
  final _details = TextEditingController();
  DateTime? _date;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose(); _mobile.dispose(); _location.dispose();
    _company.dispose(); _details.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _submit() async {
    if (_submitting || !_key.currentState!.validate()) return;
    final id = int.tryParse(widget.service.id);
    if (id == null || id < 1) {
      _message(context, 'সার্ভিস ID সঠিক নয়।');
      return;
    }
    setState(() => _submitting = true);
    try {
      final date = _date;
      final dateText = date == null ? null :
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final number = await _market.requestService(
        serviceId: id,
        name: _name.text, mobile: _mobile.text,
        location: _location.text, company: _company.text,
        details: _details.text, preferredDate: dateText,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('সার্ভিস অনুরোধ জমা হয়েছে'),
          content: Text('অনুরোধ নম্বর: $number\nআমাদের টিম যোগাযোগ করবে।'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ঠিক আছে')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _message(context, _error(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('সার্ভিস বুকিং')),
    body: Form(
      key: _key,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text(widget.service.name,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(widget.service.priceLabel),
        const SizedBox(height: 20),
        TextFormField(controller: _name, maxLength: 150,
            decoration: _field('আপনার পূর্ণ নাম'), validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _mobile, maxLength: 20,
            keyboardType: TextInputType.phone,
            decoration: _field('মোবাইল নম্বর'), validator: _phone),
        const SizedBox(height: 10),
        TextFormField(controller: _location, maxLength: 2000,
            maxLines: 3, decoration: _field('সার্ভিসের সম্পূর্ণ ঠিকানা'),
            validator: _required),
        const SizedBox(height: 10),
        TextFormField(controller: _company, maxLength: 200,
            decoration: _field('কোম্পানির নাম (ঐচ্ছিক)')),
        const SizedBox(height: 10),
        TextFormField(controller: _details, maxLength: 10000,
            maxLines: 4, decoration: _field('কাজের বিস্তারিত (ঐচ্ছিক)')),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _chooseDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(_date == null ? 'পছন্দের তারিখ (ঐচ্ছিক)' :
              '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-'
              '${_date!.day.toString().padLeft(2, '0')}'),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _maroon, foregroundColor: Colors.white),
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('সার্ভিস অনুরোধ পাঠান'),
        ),
      ]),
    ),
  );
}
