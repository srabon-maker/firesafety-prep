
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

const Color maroon = Color(0xFF650D18);
const Color deepMaroon = Color(0xFF36060D);

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.onLogout,
  });

  final VoidCallback onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<Map<String, dynamic>?> _loadProfile() async {
    final session =
        await AuthService.instance.validateSession();

    if (session == null) return null;

    final user = session['user'];

    if (user is Map<String, dynamic>) {
      return user;
    }

    return null;
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfile();
    });

    try {
      await _profileFuture;
    } catch (_) {}
  }

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
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('না'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: maroon,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: const Text('হ্যাঁ, লগ আউট'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await AuthService.instance.logout();

      if (!context.mounted) return;

      widget.onLogout();

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

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'তথ্য দেওয়া হয়নি' : text;
  }

  Widget _profileInformation(
    IconData icon,
    String title,
    dynamic value,
  ) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: Icon(icon, color: maroon),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
        subtitle: Text(
          _value(value),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _personalInformation(
    Map<String, dynamic> user,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(
            top: 20,
            bottom: 10,
          ),
          child: Text(
            'ব্যক্তিগত তথ্য',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: maroon,
            ),
          ),
        ),
        _profileInformation(
          Icons.person_outline,
          'পূর্ণ নাম',
          user['full_name'],
        ),
        _profileInformation(
          Icons.email_outlined,
          'ইমেইল',
          user['email'],
        ),
        _profileInformation(
          Icons.phone_android,
          'মোবাইল নম্বর',
          user['mobile_number'],
        ),
        _profileInformation(
          Icons.work_outline,
          'বর্তমান অবস্থা',
          user['current_status'],
        ),
        _profileInformation(
          Icons.business_outlined,
          'কোম্পানির নাম',
          user['company_name'],
        ),
        _profileInformation(
          Icons.badge_outlined,
          'পদবি',
          user['designation'],
        ),
        _profileInformation(
          Icons.location_on_outlined,
          'কর্মস্থল',
          user['job_location'],
        ),
        _profileInformation(
          Icons.home_outlined,
          'বর্তমান ঠিকানা',
          user['current_address'],
        ),
      ],
    );
  }

  Widget _profileBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: maroon,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 45,
                    color: maroon,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'প্রোফাইল তথ্য লোড করা যায়নি।',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('আবার চেষ্টা করুন'),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    size: 45,
                    color: maroon,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'প্রোফাইল তথ্য পাওয়া যায়নি।',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('আবার চেষ্টা করুন'),
                  ),
                ],
              ),
            ),
          );
        }

        final name = _value(user['full_name']);
        final email = _value(user['email']);
        final photo = user['profile_photo']?.toString();

        return RefreshIndicator(
          color: maroon,
          onRefresh: _refreshProfile,
          child: ListView(
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
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          photo != null && photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                      child: photo == null || photo.isEmpty
                          ? const Icon(
                              Icons.person,
                              color: maroon,
                              size: 45,
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Fire Safety BD সদস্য',
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Row(
                children: [
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

              _personalInformation(user),

              const SizedBox(height: 12),

              for (final item in [
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
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: item.$2 == 'লগ আউট'
                        ? () => _logout(context)
                        : () {},
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('প্রোফাইল'),
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'তথ্য আপডেট করুন',
          ),
        ],
      ),
      body: _profileBody(),
    );
  }
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
