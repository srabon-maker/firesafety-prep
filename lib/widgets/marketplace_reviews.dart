import 'package:flutter/material.dart';
import '../models/marketplace_engagement.dart';
import '../services/marketplace_api_service.dart';
import '../services/auth_guard.dart';
import '../settings/app_settings.dart';

class MarketplaceReviews extends StatefulWidget {
  const MarketplaceReviews({super.key, required this.productId});
  final String productId;
  @override
  State<MarketplaceReviews> createState() => _MarketplaceReviewsState();
}

class _MarketplaceReviewsState extends State<MarketplaceReviews> {
  late Future<Map<String, dynamic>> _reviews;
  final _text = TextEditingController();
  int _stars = 5;
  bool _busy = false;

  String tr(String bn, String en) => AppText.of(context, bn, en);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _reviews = MarketplaceApiService.instance.get('engagement.php',
      queryParameters: {'action':'reviews','product_id':widget.productId});
    _reviews.then<void>((_) {}, onError: (Object _, StackTrace __) {});
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!await AuthGuard.ensureAuthenticated(context) || !mounted) return;
      await MarketplaceApiService.instance.post('engagement.php', body: {
        'product_id': widget.productId, 'rating': _stars, 'review_text': _text.text.trim(),
      });
      if (!mounted) return;
      _text.clear();
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        tr('রিভিউ অনুমোদনের জন্য জমা হয়েছে।','Review submitted for moderation.'))));
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        RegExp(r'[\u0980-\u09FF]').hasMatch(msg) ? msg :
        tr('রিভিউ জমা হয়নি। আবার চেষ্টা করুন।','Review could not be submitted. Try again.'),
        maxLines: 3, overflow: TextOverflow.ellipsis)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('রেটিং ও রিভিউ','Ratings & reviews'),style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      FutureBuilder<Map<String, dynamic>>(future: _reviews, builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError || snapshot.data == null || snapshot.data!['data'] is! Map) {
          return TextButton.icon(onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh), label: Text(tr('রিভিউ লোড হয়নি। আবার চেষ্টা করুন','Reviews unavailable. Retry')));
        }
        final data = Map<String, dynamic>.from(snapshot.data!['data'] as Map);
        final summary = data['summary'];
        final rating = summary is Map ? ProductRating.fromJson(Map<String,dynamic>.from(summary)) : const ProductRating(0,0);
        final rows = data['reviews'];
        return Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
          Text(rating.count == 0 ? tr('এখনো কোনো রিভিউ নেই।','No reviews yet') :
              '${rating.average.toStringAsFixed(1)}/5 ★  (${rating.count})'),
          if (rows is List)
            for (final row in rows.whereType<Map>())
              ListTile(contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.verified_user_outlined),
                title: Text('${row['rating']}/5 ★ · ${tr('যাচাইকৃত ক্রেতা','Verified buyer')}'),
                subtitle: Text('${row['review_text'] ?? ''}')),
        ]);
      }),
      const Divider(),
      Text(tr('ডেলিভারি সম্পন্ন হওয়া পণ্যে রিভিউ দিন','Review a delivered purchase')),
      Wrap(children: [
        for (var i = 1; i <= 5; i++)
          IconButton(tooltip: '$i/5',onPressed: _busy ? null : () => setState(() => _stars=i),
            icon: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
              color: const Color(0xFFE6A126))),
      ]),
      TextField(controller: _text, enabled: !_busy, maxLength: 1000,
        minLines: 2, maxLines: 4, decoration: InputDecoration(
          hintText: tr('আপনার অভিজ্ঞতা লিখুন (ঐচ্ছিক)','Share your experience (optional)'))),
      FilledButton(onPressed: _busy ? null : _submit,child: Text(
        tr('রিভিউ জমা দিন / আপডেট করুন','Submit / update review'))),
    ]),
  ));
}
