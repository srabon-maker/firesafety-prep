
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../settings/app_settings.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';

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
  bool _deleting = false;

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
        title: Text(_tr(context, 'লগ আউট করবেন?', 'Log out?')),
        content: Text(_tr(context, 'আপনি কি নিশ্চিতভাবে আপনার অ্যাকাউন্ট থেকে লগ আউট করতে চান?', 'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: Text(_tr(context, 'না', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            child: Text(_tr(context, 'হ্যাঁ, লগ আউট', 'Yes, log out')),
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
        SnackBar(
          content: Text(_tr(context, 'সফলভাবে লগ আউট হয়েছে।', 'Logged out successfully.')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tr(context, 'লগ আউট করা যায়নি: $e', 'Could not log out: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: user),
      ),
    );
    if (!mounted || saved != true) return;
    await _refreshProfile();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr(context, 'প্রোফাইল আপডেট হয়েছে।', 'Profile updated.'))),
    );
  }

  Future<void> _deleteAccount() async {
    if (_deleting) return;
    var typedConfirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_tr(context, 'অ্যাকাউন্ট স্থায়ীভাবে মুছবেন?',
              'Permanently delete account?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tr(
                context,
                'এতে আপনার প্রোফাইল, পোস্ট, পরীক্ষার ফলাফল, কার্ট, অর্ডার ও সার্ভিস রিকোয়েস্টের তথ্য স্থায়ীভাবে মুছে যাবে। এই কাজ ফেরানো যাবে না।',
                'Your profile, posts, test history, cart, orders and service requests will be permanently deleted. This cannot be undone.',
              )),
              const SizedBox(height: 14),
              Text(_tr(context, 'নিশ্চিত করতে DELETE লিখুন।',
                  'Type DELETE to confirm.')),
              const SizedBox(height: 8),
              TextField(
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (value) => setDialogState(() => typedConfirmation = value),
                decoration: const InputDecoration(hintText: 'DELETE'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_tr(context, 'বাতিল', 'Cancel')),
            ),
            FilledButton(
              onPressed: typedConfirmation.trim() == 'DELETE'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: Text(_tr(context, 'স্থায়ীভাবে মুছুন', 'Delete permanently')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount();
      if (!mounted) return;
      widget.onLogout();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _tr(BuildContext context, String bn, String en) => AppText.of(context, bn, en);

  Widget _profileInformation(
    IconData icon,
    String title,
    dynamic value,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: Icon(icon, color: maroon),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          _value(value),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
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
        _profileInformation(
          Icons.person_outline,
          _tr(context, 'পূর্ণ নাম', 'Full name'),
          user['full_name'],
        ),
        _profileInformation(
          Icons.email_outlined,
          _tr(context, 'ইমেইল', 'Email'),
          user['email'],
        ),
        _profileInformation(
          Icons.phone_android,
          _tr(context, 'মোবাইল নম্বর', 'Phone number'),
          user['mobile_number'],
        ),
        _profileInformation(
          Icons.work_outline,
          _tr(context, 'বর্তমান অবস্থা', 'Employment status'),
          user['current_status'],
        ),
        _profileInformation(
          Icons.business_outlined,
          _tr(context, 'কোম্পানির নাম', 'Company'),
          user['company_name'],
        ),
        _profileInformation(
          Icons.badge_outlined,
          _tr(context, 'পদবি', 'Designation'),
          user['designation'],
        ),
        _profileInformation(
          Icons.location_on_outlined,
          _tr(context, 'কর্মস্থল', 'Workplace'),
          user['job_location'],
        ),
        _profileInformation(
          Icons.home_outlined,
          _tr(context, 'বর্তমান ঠিকানা', 'Current address'),
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
              color: Theme.of(context).colorScheme.primary,
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
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 45,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tr(context, 'প্রোফাইল তথ্য লোড করা যায়নি।', 'Could not load profile information.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: Text(_tr(context, 'আবার চেষ্টা করুন', 'Try again')),
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
                  Icon(
                    Icons.person_off_outlined,
                    size: 45,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _tr(context, 'প্রোফাইল তথ্য পাওয়া যায়নি।', 'Profile information not found.'),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: Text(_tr(context, 'আবার চেষ্টা করুন', 'Try again')),
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
          color: Theme.of(context).colorScheme.primary,
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
                    Text(
                      _tr(context, 'Fire Safety BD সদস্য', 'Fire Safety BD member'),
                      style: TextStyle(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      number: '০',
                      label: _tr(context, 'মডেল টেস্ট', 'Model tests'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      number: '০',
                      label: _tr(context, 'পোস্ট', 'Posts'),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      number: '০%',
                      label: _tr(context, 'অগ্রগতি', 'Progress'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Card(
                elevation: 0,
                child: ExpansionTile(
                  initiallyExpanded: false,
                  leading: Icon(Icons.badge_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(_tr(context, 'ব্যক্তিগত তথ্য', 'Personal information')),
                  subtitle: Text(_tr(context, 'দেখতে ট্যাপ করুন',
                      'Tap to view your details')),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: _personalInformation(user),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _editProfile(user),
                icon: const Icon(Icons.edit_outlined),
                label: Text(_tr(context, 'প্রোফাইল এডিট করুন', 'Edit profile')),
              ),

              const SizedBox(height: 12),

              for (final item in [
                (Icons.history, _tr(context, 'মডেল টেস্টের ফলাফল', 'Model test results')),
                (Icons.bookmark_border, _tr(context, 'সংরক্ষিত নোট', 'Saved notes')),
                (Icons.notifications_none, _tr(context, 'নোটিফিকেশন', 'Notifications')),
                (Icons.settings_outlined, _tr(context, 'সেটিংস', 'Settings')),
                (Icons.info_outline, _tr(context, 'অ্যাপ সম্পর্কে', 'About app')),
                (Icons.logout, _tr(context, 'লগ আউট', 'Log out')),
              ])
                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(item.$1, color: maroon),
                    title: Text(item.$2),
                    trailing:
                        const Icon(Icons.chevron_right),
                    onTap: item.$2 == _tr(context, 'লগ আউট', 'Log out')
                        ? () => _logout(context)
                        : item.$2 == _tr(context, 'সেটিংস', 'Settings')
                            ? () => Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => const SettingsPage(),
                                ))
                            : null,
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: ListTile(
                  leading: Icon(Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: Text(
                    _tr(context, 'অ্যাকাউন্ট ডিলিট করুন', 'Delete account'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  subtitle: Text(_tr(context, 'স্থায়ীভাবে সব অ্যাকাউন্ট তথ্য মুছে ফেলুন',
                      'Permanently remove your account and data')),
                  trailing: _deleting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: _deleting ? null : _deleteAccount,
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
        title: Text(_tr(context, 'প্রোফাইল', 'Profile')),
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
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
}
