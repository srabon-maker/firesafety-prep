import 'package:flutter/material.dart';
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

  Widget _option(String key, String title, String subtitle, IconData icon) {
    return SwitchListTile(
      value: _values[key] ?? true,
      onChanged: _loading ? null : (value) => _set(key, value),
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('নোটিফিকেশন পছন্দ')),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text('কোন ধরনের নোটিফিকেশন পেতে চান তা নির্বাচন করুন।',
                style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            _option('study', 'পড়াশোনার রিমাইন্ডার',
              'নিয়মিত অনুশীলনের কথা মনে করিয়ে দেওয়ার পছন্দ।',
              Icons.school_outlined),
            _option('updates', 'অ্যাপ আপডেট',
              'নতুন ফিচার ও গুরুত্বপূর্ণ অ্যাপ আপডেটের পছন্দ।',
              Icons.system_update_alt),
            _option('community', 'কমিউনিটি কার্যক্রম',
              'কমিউনিটির কার্যক্রম সম্পর্কিত নোটিফিকেশনের পছন্দ।',
              Icons.groups_outlined),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('এগুলো আপনার ডিভাইসে সংরক্ষিত পছন্দ। Push notification পাঠানোর ব্যবস্থা আলাদাভাবে সংযুক্ত করতে হবে.',
                style: TextStyle(fontSize: 12, height: 1.5)),
            ),
          ],
        ),
  );
}
