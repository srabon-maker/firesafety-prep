
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('লগ আউট করবেন?'),
        content: const Text(
          'আপনি কি নিশ্চিতভাবে আপনার অ্যাকাউন্ট থেকে লগ আউট করতে চান?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: maroon,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('হ্যাঁ, লগ আউট'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await AuthService.instance.logout();

      if (!context.mounted) return;

      // MainShell-এর Home tab-এ ফিরে যাবে।
      Navigator.of(context).popUntil((route) => route.isFirst);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('সফলভাবে লগ আউট হয়েছে।'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('লগ আউট করা যায়নি: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('প্রোফাইল'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [deepMaroon, maroon],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      color: maroon,
                      size: 45,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'আপনার প্রোফাইল',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Fire Safety BD সদস্য',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(
                  child: _StatCard(
                    number: '০',
                    label: 'মডেল টেস্ট',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    number: '০',
                    label: 'পোস্ট',
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    number: '০%',
                    label: 'অগ্রগতি',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            for (final item in [
              (Icons.person_outline, 'ব্যক্তিগত তথ্য'),
              (Icons.history, 'মডেল টেস্টের ফলাফল'),
              (Icons.bookmark_border, 'সংরক্ষিত নোট'),
              (Icons.notifications_none, 'নোটিফিকেশন'),
              (Icons.language, 'ভাষা'),
              (Icons.info_outline, 'অ্যাপ সম্পর্কে'),
              (Icons.logout, 'লগ আউট'),
            ])
              Card(
                color: Colors.white,
                elevation: 0,
                child: ListTile(
                  leading: Icon(item.$1, color: maroon),
                  title: Text(item.$2),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: item.$2 == 'লগ আউট'
                      ? () => _logout(context)
                      : () {},
                ),
              ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.number,
    required this.label,
  });

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 6,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: maroon,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      );
}
