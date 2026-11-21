import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/model_test_service.dart';
import '../settings/app_settings.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';
import 'tests_page.dart';
import 'notes_page.dart';
import 'saved_notes_page.dart';
import 'notification_preferences_page.dart';

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
  late final ScrollController _profileScrollController;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    // Keep this tab's scroll position independent from the other pages
    // retained inside MainShell's IndexedStack.
    _profileScrollController = ScrollController();
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _profileScrollController.dispose();
    super.dispose();
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


  void _openAccountManagement(Map<String, dynamic> user) {
    final email = _value(user['email']);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccountManagementPage(
          email: email,
          onEdit: () => _editProfile(user),
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

  Widget _profileInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    dynamic value,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: scheme.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                Text(_value(value), style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _learningMetric(String value, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 19),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w900, color: scheme.primary)),
        const SizedBox(height: 3),
        Text(label, textAlign: TextAlign.center, maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
      ],
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
            controller: _profileScrollController,
            primary: false,
            // Use the platform's standard clamping physics for predictable
            // touch dragging in both directions. AlwaysScrollable keeps
            // pull-to-refresh available even when the content is short.
            physics: const ClampingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            // Let Flutter begin the drag after the normal touch slop so
            // small taps on profile tiles are not mistaken for scrolls.
            dragStartBehavior: DragStartBehavior.start,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(Icons.badge_outlined, color: scheme.primary),
                    title: Text(
                      _tr(context, 'ব্যক্তিগত তথ্য', 'Personal information'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(_tr(context, 'আপনার প্রোফাইলের বিস্তারিত',
                        'Your profile details')),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      _profileInfoRow(context, Icons.person_outline,
                          _tr(context, 'পূর্ণ নাম', 'Full name'), user['full_name']),
                      _profileInfoRow(context, Icons.email_outlined,
                          _tr(context, 'ইমেইল', 'Email'), user['email']),
                      _profileInfoRow(context, Icons.phone_outlined,
                          _tr(context, 'মোবাইল', 'Mobile'), user['mobile_number']),
                      _profileInfoRow(context, Icons.work_outline,
                          _tr(context, 'বর্তমান অবস্থা', 'Current status'), user['current_status']),
                      _profileInfoRow(context, Icons.business_outlined,
                          _tr(context, 'প্রতিষ্ঠান', 'Company'), user['company_name']),
                      _profileInfoRow(context, Icons.badge_outlined,
                          _tr(context, 'পদবি', 'Designation'), user['designation']),
                      _profileInfoRow(context, Icons.location_on_outlined,
                          _tr(context, 'কর্মস্থল', 'Job location'), user['job_location']),
                      _profileInfoRow(context, Icons.home_outlined,
                          _tr(context, 'বর্তমান ঠিকানা', 'Current address'), user['current_address']),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _editProfile(user),
                          icon: const Icon(Icons.edit_outlined),
                          label: Text(_tr(context, 'তথ্য পরিবর্তন করুন', 'Edit information')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FutureBuilder<List<dynamic>>(
                future: Future.wait([
                  ModelTestService.instance.myResults(),
                  ModelTestService.instance.practiceDashboard(),
                ]),
                builder: (context, stats) {
                  if (stats.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (stats.hasError || stats.data == null) {
                    return const SizedBox.shrink();
                  }
                  final results = stats.data![0] as List<Map<String, dynamic>>;
                  final practice = Map<String, dynamic>.from(stats.data![1] as Map);
                  final overall = Map<String, dynamic>.from(
                    practice['overall'] as Map? ?? {},
                  );
                  final questions = (overall['questions'] as num?)?.toInt() ?? 0;
                  final correct = (overall['correct'] as num?)?.toInt() ?? 0;
                  final accuracy = questions == 0 ? 0.0 : correct / questions * 100;
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_tr(context, 'আপনার শেখার অগ্রগতি',
                              'Your learning progress'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _learningMetric(
                              results.length.toString(),
                              _tr(context, 'মডেল টেস্ট', 'Model tests'),
                              Icons.fact_check_outlined)),
                            Expanded(child: _learningMetric(
                              questions.toString(),
                              _tr(context, 'অনুশীলন প্রশ্ন', 'Practice questions'),
                              Icons.quiz_outlined)),
                            Expanded(child: _learningMetric(
                              '${accuracy.toStringAsFixed(0)}%',
                              _tr(context, 'সঠিক উত্তর', 'Accuracy'),
                              Icons.track_changes_outlined)),
                          ]),
                          const SizedBox(height: 8),
                          Text(_tr(context,
                            'প্রকাশিত পরীক্ষার ফলাফল ও সংরক্ষিত অনুশীলন সেশনের ভিত্তিতে।',
                            'Based on released test results and saved practice sessions.'),
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  );
                },
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MyTestResultsPage(),
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.insights_rounded,
                title: _tr(context, 'অনুশীলন ড্যাশবোর্ড', 'Practice dashboard'),
                subtitle: _tr(context, 'দৈনিক লক্ষ্য ও শেখার অগ্রগতি',
                    'Daily target and learning progress'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PracticeDashboardPage(),
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.menu_book_outlined,
                title: _tr(context, 'নোট ও রিসোর্স', 'Notes & resources'),
                subtitle: _tr(context, 'প্রকাশিত স্টাডি নোট দেখুন',
                    'Browse published study notes'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotesPage(),
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.bookmark_rounded,
                title: _tr(context, 'সংরক্ষিত নোট', 'Saved notes'),
                subtitle: _tr(context, 'আপনার বুকমার্ক করা নোট',
                    'Your bookmarked notes'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedNotesPage(),
                  ),
                ),
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
                subtitle: _tr(context, 'আপনার নোটিফিকেশন পছন্দ নিয়ন্ত্রণ করুন',
                    'Manage your notification preferences'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationPreferencesPage(),
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.info_outline_rounded,
                title: _tr(context, 'অ্যাপ সম্পর্কে', 'About app'),
                subtitle: _tr(context, 'Fire Safety BD সম্পর্কে জানুন',
                    'Learn about Fire Safety BD'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Fire Safety BD',
                  applicationVersion: '1.0.0',
                  applicationLegalese: _tr(
                    context,
                    'ফায়ার সেফটি শেখা ও প্রস্তুতির ডিজিটাল প্ল্যাটফর্ম।',
                    'A digital platform for fire safety learning and preparation.',
                  ),
                ),
              ),
              _menuTile(
                icon: Icons.manage_accounts_outlined,
                title: _tr(context, 'অ্যাকাউন্ট ও নিরাপত্তা',
                    'Account & security'),
                subtitle: _tr(context, 'প্রোফাইল এডিট ও অ্যাকাউন্ট ডিলিট',
                    'Edit profile and delete account'),
                onTap: () => _openAccountManagement(user),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  _tr(context, 'লগআউট করুন', 'Log out'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.primary,
                  side: BorderSide(
                    color: scheme.primary.withValues(alpha: 0.45),
                  ),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
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
    required this.onEdit,
    required this.onDelete,
  });

  final String email;
  final VoidCallback onEdit;
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(Icons.edit_outlined, color: scheme.primary),
              title: Text(tr('প্রোফাইল এডিট করুন', 'Edit profile')),
              subtitle: Text(tr('নাম, মোবাইল ও পেশাগত তথ্য পরিবর্তন',
                  'Update name, mobile and professional details')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onEdit,
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

