import 'package:flutter/material.dart';

import '../models/inbox_notification.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../settings/app_settings.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage({super.key});

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
      final token = await AuthService.instance.getSessionToken();
      if (!mounted) return;
      if (token == null || token.isEmpty) throw const InboxSessionExpired();
      _service = NotificationService(token);
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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('নোটিফিকেশন', 'Notifications')),
        actions: [IconButton(
          tooltip: tr('সব পড়া হিসেবে চিহ্নিত করুন', 'Mark all as read'),
          onPressed: _busy || _expired || _unread == 0 || _items.isEmpty
              ? null : _markAll,
          icon: const Icon(Icons.done_all),
        )],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr('না-পড়া: $_unread', 'Unread: $_unread'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
              Padding(padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  Icon(Icons.notifications_none, size: 52, color: colors.outline),
                  const SizedBox(height: 12),
                  Text(tr('এখনো কোনো নোটিফিকেশন নেই।', 'No notifications yet.')),
                ])),
            for (final item in _items)
              Card(
                color: item.isRead ? null : colors.primaryContainer,
                child: ListTile(
                  enabled: !_busy && !_expired,
                  onTap: () => _open(item),
                  leading: Icon(item.isRead ? Icons.mark_email_read_outlined
                      : Icons.mark_email_unread_outlined),
                  title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('${_type(item.type)} · ${item.sentAt}',
                        style: Theme.of(context).textTheme.bodySmall),
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
