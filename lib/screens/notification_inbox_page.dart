import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/inbox_notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../settings/app_settings.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key, this.createService});

  // Optional factory for isolated widget tests; production uses the login session.
  final Future<NotificationService> Function()? createService;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  NotificationService? _service;
  List<InboxNotification> _items = [];
  String? _cursor;
  int _unread = 0;
  bool _busy = true;
  bool _failed = false;
  bool _expired = false;

  String tr(String bn, String en) => AppText.of(context, bn, en);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final factory = widget.createService;
      if (factory != null) {
        final service = await factory();
        if (!mounted) {
          service.dispose();
          return;
        }
        _service = service;
      } else {
        final token = await AuthService.instance.getSessionToken();
        if (!mounted) return;
        if (token == null || token.isEmpty) throw const InboxSessionExpired();
        _service = NotificationService(token);
      }
      await _load(initial: true);
    } catch (e) {
      _error(e);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(Object error) {
    if (!mounted) return;
    setState(() {
      _failed = true;
      if (error is InboxSessionExpired) {
        _expired = true;
        _items = [];
        _cursor = null;
        _unread = 0;
      }
    });
  }

  Future<void> _load({bool more = false, bool initial = false}) async {
    if ((!initial && _busy) || _expired || (more && _cursor == null)) return;
    final service = _service;
    if (service == null) return;
    setState(() { _busy = true; _failed = false; });
    try {
      final page = await service.fetch(beforeId: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        final known = _items.map((n) => n.id).toSet();
        _items = more
            ? [..._items, ...page.items.where((n) => known.add(n.id))]
            : page.items;
        _cursor = page.nextBeforeId;
        _unread = page.unreadCount;
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(InboxNotification item) async {
    final service = _service;
    if (_busy || _expired || service == null) return;
    setState(() { _busy = true; _failed = false; });
    try {
      await service.checkSession();
      if (!item.isRead) {
        final count = await service.markRead(item.id);
        if (!mounted) return;
        setState(() {
          _unread = count;
          _items = _items.map((n) => n.id == item.id ? n.read() : n).toList();
        });
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title),
          content: SingleChildScrollView(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [Text(item.message), const SizedBox(height: 16),
              Text(item.sentAt, style: Theme.of(context).textTheme.bodySmall)],
          )),
          actions: [TextButton(onPressed: () => Navigator.pop(context),
            child: Text(AppText.of(context, 'বন্ধ করুন', 'Close')))],
        ),
      );
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _markAll() async {
    final service = _service;
    if (_busy || _expired || _items.isEmpty || service == null) return;
    setState(() { _busy = true; _failed = false; });
    try {
      final count = await service.markAllRead(_items.first.id);
      if (!mounted) return;
      setState(() {
        _unread = count;
        _items = _items.map((n) => n.read()).toList();
      });
    } catch (e) {
      _error(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _type(String type) => switch (type) {
    'study' => tr('পড়াশোনা', 'Study'),
    'app_update' => tr('অ্যাপ আপডেট', 'App update'),
    'community' => tr('কমিউনিটি', 'Community'),
    'marketplace' => tr('মার্কেটপ্লেস', 'Marketplace'),
    _ => tr('সাধারণ', 'General'),
  };

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final canMarkAll = !_busy && !_expired && _unread > 0 && _items.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: dark ? const Color(0xFF36060D) : const Color(0xFF650D18),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        leading: IconButton(
          tooltip: tr('ফিরে যান', 'Back'),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
        ),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(tr('নোটিফিকেশন', 'Notifications'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        actions: [
          Tooltip(
            message: tr('সব পড়া হিসেবে চিহ্নিত করুন', 'Mark all as read'),
            child: Semantics(
              button: true,
              enabled: canMarkAll,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('inbox-mark-all'),
                  onTap: canMarkAll ? _markAll : null,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 58, height: 54,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.done_all_rounded, size: 20,
                            color: canMarkAll ? Colors.white : Colors.white54),
                        ),
                        const SizedBox(height: 2),
                        Text(tr('সব পড়ুন', 'Read all'),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: canMarkAll ? Colors.white : Colors.white54)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          children: [
            Row(children: [
              Expanded(child: Text(tr('ইনবক্স', 'Inbox'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              if (!_expired && !(_failed && _items.isEmpty) && !(_busy && _items.isEmpty))
                Flexible(child: Container(
                  key: const ValueKey('inbox-unread-count'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tr('$_unread অপঠিত', '$_unread unread'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onPrimaryContainer, fontWeight: FontWeight.w600)),
                )),
            ]),
            const SizedBox(height: 10),
            if (_busy) const LinearProgressIndicator(),
            if (_failed) Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Text(_expired
                    ? tr('সেশনের মেয়াদ শেষ। ফিরে গিয়ে আবার লগইন করুন।',
                        'Session expired. Go back and sign in again.')
                    : tr('নোটিফিকেশন লোড বা আপডেট করা যায়নি। আবার চেষ্টা করুন।',
                        'Could not load or update notifications. Try again.')),
                if (!_expired) TextButton(
                  onPressed: _busy ? null : () {
                    if (_service == null) {
                      setState(() { _busy = true; _failed = false; });
                      _initialize();
                    } else {
                      _load();
                    }
                  },
                  child: Text(tr('আবার চেষ্টা করুন', 'Retry')),
                ),
              ]),
            )),
            if (!_busy && !_failed && _items.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
                child: Column(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer, shape: BoxShape.circle),
                    child: Icon(Icons.notifications_off_outlined, size: 30,
                      color: colors.onPrimaryContainer),
                  ),
                  const SizedBox(height: 12),
                  Text(tr('কোনো নোটিফিকেশন নেই', 'No notifications'),
                    textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(tr('নতুন আপডেট এখানে দেখা যাবে।', 'New updates will appear here.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                ])),
            for (final item in _items)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                color: item.isRead ? colors.surface : colors.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: colors.outlineVariant),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minLeadingWidth: 24,
                  horizontalTitleGap: 10,
                  enabled: !_busy && !_expired,
                  onTap: () => _open(item),
                  leading: Icon(item.isRead ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined,
                    color: item.isRead ? colors.onSurfaceVariant : colors.onPrimaryContainer, size: 22),
                  title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14,
                      color: item.isRead ? colors.onSurface : colors.onPrimaryContainer,
                      fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: item.isRead
                          ? colors.onSurfaceVariant : colors.onPrimaryContainer)),
                      const SizedBox(height: 4),
                      Text('${_type(item.type)} · ${item.sentAt}',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11,
                          color: item.isRead ? colors.onSurfaceVariant : colors.onPrimaryContainer)),
                    ]),
                  trailing: item.isRead ? null : Icon(Icons.circle, size: 9, color: colors.primary),
                ),
              ),
            if (_cursor != null && !_expired) TextButton(
              onPressed: _busy ? null : () => _load(more: true),
              child: Text(tr('আরও দেখুন', 'Load more')),
            ),
          ],
        ),
      ),
    );
  }
}
