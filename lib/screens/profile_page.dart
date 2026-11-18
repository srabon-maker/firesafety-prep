
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

  Future<Map<String, dynamic>?> _loadProfile({bool forceRefresh = false}) async {
    final session =
        await AuthService.instance.validateSession(forceRefresh: forceRefresh);

    if (session == null) return null;

    final user = session['user'];

    if (user is Map<String, dynamic>) {
      return user;
    }

    return null;
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfile(forceRefresh: true);
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

  Future<void> _deleteAccount(String email) async {
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
                'এতে আপনার প্রোফাইল, পোস্ট, পরীক্ষার ফলাফল, কার্ট, অর্ডার ও সার্ভিস রিকোয়েস্টের তথ্য স্থায়ীভাবে মুছে যাবে। চলমান অর্ডার বা সার্ভিস রিকোয়েস্ট থাকলে আগে সেগুলো শেষ করতে হবে। এই কাজ ফেরানো যাবে না।',
                'Your profile, posts, test history, cart, orders and service requests will be permanently deleted. Active orders and service requests must be completed or cancelled first. This cannot be undone.',
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
      await AuthService.instance.deleteAccount(email: email);
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


  void _openAccountManagement(String email) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccountManagementPage(
          email: email,
          onLogout: () => _logout(context),
          onDelete: () => _deleteAccount(email),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 9),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 21, color: scheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                if (enabled)
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant)
                else
                  Text(
                    _tr(context, 'শীঘ্রই', 'Soon'),
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _profileBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    snapshot.hasError
                        ? Icons.cloud_off_outlined
                        : Icons.person_off_outlined,
                    size: 44,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? _tr(context, 'প্রোফাইল তথ্য লোড করা যায়নি।',
                            'Could not load profile information.')
                        : _tr(context, 'প্রোফাইল তথ্য পাওয়া যায়নি।',
                            'Profile information not found.'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _refreshProfile,
                    child: Text(_tr(context, 'আবার চেষ্টা করুন', 'Try again')),
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data!;
        final name = _value(user['full_name']);
        final email = _value(user['email']);
        final photo = user['profile_photo']?.toString();
        final scheme = Theme.of(context).colorScheme;

        return RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [deepMaroon, maroon, Color(0xFF891C32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [
                    BoxShadow(
                      color: maroon.withValues(alpha: 0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor: const Color(0xFFFFEDF0),
                            backgroundImage: photo != null && photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null || photo.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: maroon,
                                    size: 36,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFF1CBD2),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _tr(context, 'Fire Safety BD সদস্য',
                                      'Fire Safety BD member'),
                                  style: const TextStyle(
                                    color: Color(0xFFFFE4E9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () => _editProfile(user),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: Text(
                          _tr(context, 'এডিট', 'Edit'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 5,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      number: '০',
                      label: _tr(context, 'মডেল টেস্ট', 'Model tests'),
                      icon: Icons.fact_check_outlined,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _StatCard(
                      number: '০',
                      label: _tr(context, 'পোস্ট', 'Posts'),
                      icon: Icons.article_outlined,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _StatCard(
                      number: '০%',
                      label: _tr(context, 'অগ্রগতি', 'Progress'),
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _sectionHeading(
                _tr(context, 'আপনার কার্যক্রম', 'Your activity'),
                Icons.grid_view_rounded,
              ),
              _menuTile(
                icon: Icons.history_rounded,
                title: _tr(context, 'মডেল টেস্টের ফলাফল', 'Model test results'),
                subtitle: _tr(context, 'পরীক্ষার ফলাফল ও ইতিহাস',
                    'Your scores and history'),
              ),
              _menuTile(
                icon: Icons.bookmark_border_rounded,
                title: _tr(context, 'সংরক্ষিত নোট', 'Saved notes'),
                subtitle: _tr(context, 'আপনার বুকমার্ক করা নোট',
                    'Your bookmarked notes'),
              ),
              const SizedBox(height: 11),
              _sectionHeading(
                _tr(context, 'অ্যাপ ও অ্যাকাউন্ট', 'App & account'),
                Icons.tune_rounded,
              ),
              _menuTile(
                icon: Icons.settings_outlined,
                title: _tr(context, 'অ্যাপ সেটিংস', 'App settings'),
                subtitle: _tr(context, 'ভাষা ও থিম পরিবর্তন',
                    'Language and appearance'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsPage(),
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.notifications_none_rounded,
                title: _tr(context, 'নোটিফিকেশন', 'Notifications'),
              ),
              _menuTile(
                icon: Icons.info_outline_rounded,
                title: _tr(context, 'অ্যাপ সম্পর্কে', 'About app'),
              ),
              _menuTile(
                icon: Icons.manage_accounts_outlined,
                title: _tr(context, 'অ্যাকাউন্ট ও নিরাপত্তা',
                    'Account & security'),
                subtitle: _tr(context, 'লগআউট ও অ্যাকাউন্ট ম্যানেজমেন্ট',
                    'Log out and manage your account'),
                onTap: () => _openAccountManagement(email),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Fire Safety BD',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: _tr(context, 'তথ্য আপডেট করুন', 'Refresh profile'),
          ),
        ],
      ),
      body: _profileBody(),
    );
  }
}

class _AccountManagementPage extends StatelessWidget {
  const _AccountManagementPage({
    required this.email,
    required this.onLogout,
    required this.onDelete,
  });

  final String email;
  final VoidCallback onLogout;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String tr(String bn, String en) => AppText.of(context, bn, en);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('অ্যাকাউন্ট ও নিরাপত্তা', 'Account & security')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 28, color: scheme.primary),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('আপনার অ্যাকাউন্ট', 'Your account'),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: scheme.primary),
              title: Text(tr('লগআউট করুন', 'Log out')),
              subtitle: Text(tr('এই ডিভাইস থেকে সাইন আউট করুন',
                  'Sign out from this device')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onLogout,
            ),
          ),
          const SizedBox(height: 26),
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 8),
            child: Text(
              tr('বিপজ্জনক কার্যক্রম', 'Danger zone'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: scheme.error,
              ),
            ),
          ),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(
                color: scheme.error.withValues(alpha: 0.35),
              ),
            ),
            child: ListTile(
              leading: Icon(Icons.delete_forever_outlined,
                  color: scheme.error),
              title: Text(
                tr('অ্যাকাউন্ট ডিলিট করুন', 'Delete account'),
                style: TextStyle(
                  color: scheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                tr('স্থায়ীভাবে মুছে ফেলার আগে নিশ্চিতকরণ প্রয়োজন',
                    'Confirmation required before permanent deletion'),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: scheme.error),
              onTap: onDelete,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              tr('অ্যাকাউন্ট মুছে ফেললে তথ্য ফেরত আনা যাবে না।',
                  'Deleting your account cannot be undone.'),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.number,
    required this.label,
    required this.icon,
  });

  final String number;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 6),
          Text(
            number,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
