import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../settings/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() => _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState extends State<NotificationPreferencesPage> {
  static const _keys = {
    'study': 'notify_study_reminders',
    'updates': 'notify_app_updates',
    'community': 'notify_community_activity',
  };
  final Map<String, bool> _values = {
    'study': true,
    'updates': true,
    'community': true,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final entry in _keys.entries) {
        _values[entry.key] = prefs.getBool(entry.value) ?? true;
      }
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keys[key]!, value);
    if (mounted) setState(() => _values[key] = value);
  }

  String _tr(String bn, String en) => AppText.of(context, bn, en);

  Widget _option(String key, String title, String subtitle, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      key: ValueKey('notification-preference-$key'),
      value: _values[key] ?? true,
      onChanged: _loading ? null : (value) => _set(key, value),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      dense: true,
      secondary: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
      ),
      title: Text(title, style: TextStyle(
        fontSize: 14, height: 1.25, fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      )),
      subtitle: Text(subtitle, style: TextStyle(
        fontSize: 11, height: 1.3, color: scheme.onSurfaceVariant,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
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
          tooltip: _tr('ফিরে যান', 'Back'),
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
            child: const Icon(Icons.notifications_active_outlined,
              size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr('নোটিফিকেশন পছন্দ', 'Notification preferences'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    color: scheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      _option('study', _tr('পড়াশোনার রিমাইন্ডার', 'Study reminders'),
                        _tr('নিয়মিত অনুশীলনের জন্য', 'For regular practice'),
                        Icons.school_outlined),
                      Divider(height: 1, indent: 56, endIndent: 12, color: scheme.outlineVariant),
                      _option('updates', _tr('অ্যাপ আপডেট', 'App updates'),
                        _tr('নতুন ফিচার ও আপডেট', 'New features and updates'),
                        Icons.system_update_alt),
                      Divider(height: 1, indent: 56, endIndent: 12, color: scheme.outlineVariant),
                      _option('community', _tr('কমিউনিটি', 'Community'),
                        _tr('নতুন কার্যক্রমের খবর', 'Community activity'),
                        Icons.groups_outlined),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _tr('পছন্দ ডিভাইসে সংরক্ষিত হয়। Push Notification এখনো সক্রিয় নয়।',
                          'Preferences are saved on this device. Push notifications are not active yet.'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant, height: 1.4),
                      )),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}
