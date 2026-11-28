import 'package:flutter/material.dart';
import '../services/premium_service.dart';
import '../settings/app_settings.dart';
import 'support_page.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key, this.loadStatus});
  final Future<Map<String, dynamic>> Function()? loadStatus;

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  late final _service = PremiumService();
  late Future<Map<String, dynamic>> _future = _status();

  Future<Map<String, dynamic>> _status() =>
      widget.loadStatus?.call() ?? _service.status();

  void _refresh() => setState(() => _future = _status());
  String _tr(String bn, String en) => AppText.of(context, bn, en);

  void _support() => Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => const SupportPage()));

  Widget _headerAction(IconData icon, String label, VoidCallback action) =>
      IconButton(
        tooltip: label,
        onPressed: action,
        icon: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      );

  PreferredSizeWidget _header() => AppBar(
    toolbarHeight: 68,
    titleSpacing: 8,
    leadingWidth: 48,
    centerTitle: false,
    backgroundColor: const Color(0xFF36060D),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    title: LayoutBuilder(builder: (context, constraints) => Row(children: [
      if (constraints.maxWidth >= 125) ...[
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .24)),
          ),
          child: const Icon(Icons.workspace_premium_outlined,
            size: 27, color: Color(0xFFFFD166)),
        ),
        const SizedBox(width: 9),
        Container(width: 1, height: 42, color: Colors.white54),
        const SizedBox(width: 9),
      ],
      const Expanded(child: Text('Premium', maxLines: 2,
        overflow: TextOverflow.ellipsis, style: TextStyle(
          color: Colors.white, fontSize: 15.5,
          fontWeight: FontWeight.w500, height: 1.2))),
    ])),
    actions: [
      _headerAction(Icons.chat_bubble_outline,
        _tr('পেমেন্ট সহায়তা', 'Payment support'), _support),
      _headerAction(Icons.refresh_rounded, _tr('রিফ্রেশ', 'Refresh'), _refresh),
      const SizedBox(width: 4),
    ],
  );

  Widget _banner(bool freeMode, bool active, DateTime? expiry) => Container(
    key: const ValueKey('premium-status-banner'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF36060D),
        Color(0xFF650D18), Color(0xFF8B263C)]),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.workspace_premium_outlined,
        color: Color(0xFFFFD166), size: 32),
      const SizedBox(height: 6),
      Text(freeMode
          ? _tr('এখন সব শিক্ষামূলক সুবিধা Free', 'All learning features are free')
          : active
            ? _tr('Premium সদস্যপদ সক্রিয়', 'Premium membership active')
            : _tr('ফ্রি সদস্যপদ', 'Free Membership'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 17,
          fontWeight: FontWeight.w800, height: 1.25)),
      if (active && expiry != null) ...[
        const SizedBox(height: 4),
        Text(_tr('মেয়াদ: ${expiry.toString().split('.').first}',
          'Expires: ${expiry.toString().split('.').first}'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
      const SizedBox(height: 4),
      Text(_tr('পেশাগত প্রস্তুতির জন্য উন্নত শেখার সুবিধা',
        'Enhanced learning for professional preparation'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
    ]),
  );

  Widget _sectionHeading(String label) => Text(label,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 15, fontWeight: FontWeight.w800));

  Widget _benefit(String label) {
    final theme = Theme.of(context);
    final good = theme.brightness == Brightness.dark
        ? const Color(0xFF8BD5AF) : const Color(0xFF207A50);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.check_circle_outline, size: 18, color: good),
      const SizedBox(width: 8),
      Expanded(child: Text(label,
        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.3))),
    ]);
  }

  Widget _benefits() => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _benefit(_tr('চিহ্নিত Premium ইন্টারভিউ প্রশ্নের সম্পূর্ণ উত্তর',
          'Full answers to marked Premium interview questions')),
        const SizedBox(height: 8),
        _benefit(_tr('চিহ্নিত Premium প্রশ্ন ব্যাংক', 'Marked Premium question bank')),
        const SizedBox(height: 8),
        _benefit(_tr('চিহ্নিত Premium স্টাডি নোট ও সুরক্ষিত PDF',
          'Marked Premium study notes and protected PDFs')),
        const SizedBox(height: 8),
        _benefit(_tr('চিহ্নিত Premium মডেল টেস্ট', 'Marked Premium model tests')),
      ]),
    ),
  );

  Widget _plan(Map p) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final months = p['months'];
    final label = _tr('$months মাস', '$months ${months.toString() == '1' ? 'month' : 'months'}');
    final price = Text('৳${p['proposed_price_bdt']}',
      style: theme.textTheme.titleMedium?.copyWith(fontSize: 20,
        fontWeight: FontWeight.w800, color: scheme.onSurface));
    return Card(
      key: ValueKey('premium-plan-$months'),
      margin: const EdgeInsets.only(bottom: 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: LayoutBuilder(builder: (context, constraints) {
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700, fontSize: 14, height: 1.2)),
                const SizedBox(height: 2),
                Text(_tr('প্রস্তাবিত মূল্য', 'Proposed price'),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12,
                    height: 1.2, color: scheme.onSurfaceVariant)),
              ],
            );
            return Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.workspace_premium_outlined,
                  size: 21, color: scheme.primary)),
              const SizedBox(width: 9),
              if (constraints.maxWidth < 230 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20)
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 4), price]))
              else ...[
                Expanded(child: details),
                const SizedBox(width: 8),
                price,
              ],
            ]);
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _header(),
    body: FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_tr('সদস্যপদের তথ্য লোড হয়নি। লগইন ও সংযোগ পরীক্ষা করুন।',
                'Membership could not load. Check your login and connection.'),
                textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _refresh,
                child: Text(_tr('আবার চেষ্টা করুন', 'Try again'))),
            ]),
          ));
        }

        final data = snapshot.data!;
        final active = data['premium'] == true;
        final policy = data['access_policy'];
        final freeMode = policy is Map && policy['mode'] == 'free';
        final scheduled = policy is Map && policy['scheduled_mode'] != 'free' && freeMode;
        final start = policy is Map
            ? DateTime.tryParse(policy['starts_at']?.toString() ?? '')?.toUtc()
                .add(const Duration(hours: 6)) : null;
        final expiry = DateTime.tryParse(data['expires_at']?.toString() ?? '')?.toLocal();
        final plans = (data['plans'] as List? ?? []).whereType<Map>();
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
          children: [
            _banner(freeMode, active, expiry),
            const SizedBox(height: 12),
            if (scheduled && start != null) ...[
              Card(margin: EdgeInsets.zero, child: ListTile(
                leading: Icon(Icons.event_outlined, color: scheme.primary),
                title: Text(_tr('Premium লক চালুর নির্ধারিত সময়',
                  'Scheduled Premium access restrictions')),
                subtitle: Text(_tr('${start.toString().substring(0, 16)} (বাংলাদেশ সময়)',
                  '${start.toString().substring(0, 16)} (Bangladesh time)')),
              )),
              const SizedBox(height: 10),
            ],
            _sectionHeading(_tr('সুবিধাসমূহ', 'Benefits')),
            const SizedBox(height: 6),
            _benefits(),
            const SizedBox(height: 12),
            _sectionHeading(_tr('পরিকল্পিত প্যাকেজ', 'Planned packages')),
            const SizedBox(height: 3),
            Text(_tr('এখন কেনা যাবে না', 'Not available for purchase yet'),
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            for (final p in plans) _plan(p),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 7),
              Expanded(child: Text(_tr('বিজ্ঞাপন ও অনলাইন কেনাকাটা বর্তমানে বন্ধ।',
                'Ads and online purchases are currently disabled.'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12, height: 1.3, color: scheme.onSurfaceVariant))),
            ]),
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: _support,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: Text(_tr('পেমেন্ট সংক্রান্ত সহায়তা', 'Payment support'),
                textAlign: TextAlign.center)),
            const SizedBox(height: 8),
            Text(_tr('Google Play পেমেন্ট চালু হলে চূড়ান্ত মূল্য ও কেনার অপশন দেখানো হবে। এখন পেমেন্ট নেওয়া হচ্ছে না।',
              'Final prices and purchase options will appear when Google Play payments launch. No payments are being collected now.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12, height: 1.35, color: scheme.onSurfaceVariant)),
          ],
        );
      },
    ),
  );
}
