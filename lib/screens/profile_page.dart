import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/auth_service.dart';
import '../services/auth_guard.dart';
import '../services/support_service.dart';
import '../services/model_test_service.dart';
import '../settings/app_settings.dart';
import 'settings_page.dart';
import 'edit_profile_page.dart';
import 'tests_page.dart';
import 'notes_page.dart';
import 'saved_notes_page.dart';
import 'notification_preferences_page.dart';
import 'notification_inbox_page.dart';
import 'premium_page.dart';
import 'support_page.dart';

// Private colours: other files can not clash with these names.
const Color _maroon = Color(0xFF650D18);
const Color _deepMaroon = Color(0xFF36060D);
// Use the app's complete light/dark color scheme, including matching
// foreground colors, rather than overriding only the primary color.
ColorScheme _scheme(BuildContext context) => Theme.of(context).colorScheme;

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.onLogout,
    this.loadProfile,
    this.loadStats,
    this.authorizeSupport,
    this.supportService,
  });

  final VoidCallback onLogout;
  // Optional loaders for deterministic widget tests. Production uses the
  // authenticated service paths below.
  final Future<Map<String, dynamic>?> Function(bool forceRefresh)? loadProfile;
  final Future<List<dynamic>> Function()? loadStats;
  // Optional fixture hooks for support navigation; production uses the same
  // authentication guard and service as the home header.
  final Future<bool> Function(BuildContext)? authorizeSupport;
  final SupportService? supportService;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<Map<String, dynamic>?> _profileFuture;
  late Future<List<dynamic>> _statsFuture;
  bool _deleting = false;

  // Last loaded data, so a refresh does not replace the page with a spinner.
  Map<String, dynamic>? _lastUser;
  List<dynamic>? _lastStats;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
    _statsFuture = _startStats();
  }

  Future<List<dynamic>> _startStats() {
    final future = widget.loadStats?.call() ?? _loadStats();
    // Profile may fail before the stats FutureBuilder is mounted.
    future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }

  Future<Map<String, dynamic>?> _loadProfile({bool forceRefresh = false}) async {
    final loader = widget.loadProfile;
    if (loader != null) return loader(forceRefresh);
    final session =
        await AuthService.instance.validateSession(forceRefresh: forceRefresh);

    if (session == null) return null;

    final user = session['user'];

    if (user is Map<String, dynamic>) {
      return user;
    }

    return null;
  }

  // Each part loads on its own, so one failure does not hide the other.
  Future<List<dynamic>> _loadStats() async {
    dynamic results;
    dynamic practice;
    Object? error1;
    Object? error2;
    await Future.wait([
      () async {
        try {
          results = await ModelTestService.instance.myResults();
        } catch (e) {
          error1 = e;
          debugPrint('myResults failed: $e');
        }
      }(),
      () async {
        try {
          practice = await ModelTestService.instance.practiceDashboard();
        } catch (e) {
          error2 = e;
          debugPrint('practiceDashboard failed: $e');
        }
      }(),
    ]);
    if (error1 != null && error2 != null) {
      throw Exception('শেখার অগ্রগতি লোড করা যায়নি।');
    }
    return [results, practice];
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _profileFuture = _loadProfile(forceRefresh: true);
      _statsFuture = _startStats();
    });

    try {
      await _profileFuture;
    } catch (e) {
      debugPrint('Profile refresh failed: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr(context, 'লগ আউট করবেন?', 'Log out?')),
        content: Text(_tr(
            context,
            'আপনি কি নিশ্চিতভাবে আপনার অ্যাকাউন্ট থেকে লগ আউট করতে চান?',
            'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_tr(context, 'না', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_tr(context, 'হ্যাঁ, লগ আউট', 'Yes, log out')),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Take these before logout: the page may disappear afterwards.
    final messenger = ScaffoldMessenger.of(context);
    final successText =
        _tr(context, 'সফলভাবে লগ আউট হয়েছে।', 'Logged out successfully.');
    final failPrefix = _tr(context, 'লগ আউট করা যায়নি: ', 'Could not log out: ');

    try {
      await AuthService.instance.logout();
      widget.onLogout();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successText),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('$failPrefix$e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openPersonalInformation(Map<String, dynamic> user) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _PersonalInformationPage(
          user: user,
          reload: () async {
            if (!mounted) return null;
            await _refreshProfile();
            return _profileFuture;
          },
        ),
      ),
    );
  }

  /// Returns true only if the account was really deleted.
  Future<bool> _deleteAccount(String email) async {
    if (_deleting) return false;
    var typedConfirmation = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_tr(context, 'অ্যাকাউন্ট স্থায়ীভাবে মুছবেন?',
              'Permanently delete account?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tr(
                context,
                'এতে আপনার প্রোফাইল, পরীক্ষার ফলাফল, অনুশীলনের তথ্য ও সংরক্ষিত নোট স্থায়ীভাবে মুছে যাবে। এই কাজ ফেরানো যাবে না।',
                'Your profile, test results, practice history and saved notes will be permanently deleted. This cannot be undone.',
              )),
              const SizedBox(height: 14),
              Text(_tr(context, 'নিশ্চিত করতে DELETE লিখুন।',
                  'Type DELETE to confirm.')),
              const SizedBox(height: 8),
              TextField(
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (value) =>
                    setDialogState(() => typedConfirmation = value),
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
                backgroundColor: _scheme(context).error,
                foregroundColor: _scheme(context).onError,
              ),
              child:
                  Text(_tr(context, 'স্থায়ীভাবে মুছুন', 'Delete permanently')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() => _deleting = true);
    try {
      await AuthService.instance.deleteAccount(email: email);

      try {
        await AuthService.instance.logout();
      } catch (_) {}

      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  String _tr(BuildContext context, String bn, String en) =>
      AppText.of(context, bn, en);

  Future<void> _openAccountManagement(Map<String, dynamic> user) async {
    // Real email for the server; '—' is only for showing on screen.
    final rawEmail = user['email']?.toString().trim() ?? '';
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _AccountManagementPage(
          email: _value(user['email']),
          onDelete: () => _deleteAccount(rawEmail),
        ),
      ),
    );
    // The account page has closed itself by now. Go to login.
    if (deleted == true && mounted) {
      widget.onLogout();
    }
  }

  Future<void> _openSupport() async {
    final allowed = await (widget.authorizeSupport?.call(context) ??
        AuthGuard.ensureAuthenticated(context));
    if (!allowed || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SupportPage(
        generalSupport: true,
        service: widget.supportService,
      )),
    );
  }

  Widget _sectionHeading(String title, IconData icon) {
    final scheme = _scheme(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(3, 2, 3, 6),
      child: Row(children: [
        Icon(icon, size: 17, color: scheme.primary),
        const SizedBox(width: 7),
        Expanded(child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontSize: 14, fontWeight: FontWeight.w600, color: scheme.onSurface))),
      ]),
    );
  }

  Widget _menuGroup(List<Widget> items) {
    final scheme = _scheme(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 49,
            endIndent: 10, color: scheme.outlineVariant),
          items[i],
        ],
      ]),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    final scheme = _scheme(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14, height: 1.3, fontWeight: FontWeight.w500, color: scheme.onSurface))),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18,
              color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }

  Widget _learningMetric(String value, String label, IconData icon) {
    final scheme = _scheme(context);
    return Column(
      children: [
        Icon(icon, color: scheme.primary, size: 17),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: scheme.primary)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.2, color: scheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _statsErrorCard(ColorScheme scheme, Object? error) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(context, 'শেখার অগ্রগতি লোড করা যায়নি।',
                        'Could not load learning progress.'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error.toString().replaceFirst('Exception: ', ''),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _statsFuture = _startStats()),
              child: Text(_tr(context, 'আবার চেষ্টা', 'Retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileBody() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          _lastUser = snapshot.data;
        }
        if (snapshot.connectionState == ConnectionState.done &&
            (snapshot.hasError || snapshot.data == null)) {
          _lastUser = null;
          _lastStats = null;
        }
        final loadedUser = snapshot.data ?? _lastUser;

        if (loadedUser == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: _scheme(context).primary,
              ),
            );
          }
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
                    color: _scheme(context).primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.hasError
                        ? _tr(context, 'প্রোফাইল তথ্য লোড করা যায়নি।',
                            'Could not load profile information.')
                        : _tr(context, 'প্রোফাইল তথ্য পাওয়া যায়নি।',
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

        final user = loadedUser;
        final name = _value(user['full_name']);
        final email = _value(user['email']);
        final photo = user['profile_photo']?.toString().trim() ?? '';
        // Only a full web link (http/https) counts as a usable photo.
        final hasPhoto = photo.startsWith('http://') ||
            photo.startsWith('https://');
        final scheme = _scheme(context);

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  label: _tr(context, 'ব্যক্তিগত তথ্য দেখুন', 'View personal information'),
                  child: GestureDetector(
                    key: const ValueKey('profile-summary-card'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openPersonalInformation(user),
                    child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_deepMaroon, _maroon, Color(0xFF891C32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _maroon.withValues(alpha: .08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .55),
                                width: 1,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFFFEDF0),
                              // If the photo fails to load, the icon is shown.
                              child: hasPhoto
                                  ? ClipOval(
                                      child: Image.network(
                                        photo,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person_rounded,
                                          color: _maroon,
                                          size: 28,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      color: _maroon,
                                      size: 28,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                    fontSize: 16,
                                    height: 1.2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFF1CBD2),
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  key: const ValueKey('profile-member-badge'),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _tr(context, 'সদস্য', 'Member'),
                                    semanticsLabel: _tr(context, 'Fire Safety BD সদস্য', 'Fire Safety BD member'),
                                    style: const TextStyle(
                                      color: Color(0xFFFFE4E9),
                                      fontSize: 10,
                                      height: 1.2,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
                  ),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<dynamic>>(
                  future: _statsFuture,
                  builder: (context, stats) {
                    // Remember the last good stats, so a refresh keeps
                    // showing them (no jump, no flicker).
                    if (stats.hasData &&
                        stats.data != null &&
                        stats.data!.length >= 2) {
                      _lastStats = stats.data;
                    }
                    final data = _lastStats;

                    if (data == null) {
                      if (stats.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 110,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      // Failed to load: tell the user and allow retry.
                      return _statsErrorCard(scheme, stats.error);
                    }

                    final rawResults = data[0];

                    final List<Map<String, dynamic>> results = rawResults
                            is List
                        ? rawResults
                            .whereType<Map>()
                            .map<Map<String, dynamic>>(
                              (item) => Map<String, dynamic>.from(item),
                            )
                            .toList()
                        : <Map<String, dynamic>>[];

                    final rawPractice = data[1];

                    final Map<String, dynamic> practice = rawPractice is Map
                        ? Map<String, dynamic>.from(rawPractice)
                        : <String, dynamic>{};

                    final Map<String, dynamic> overall =
                        practice['overall'] is Map
                            ? Map<String, dynamic>.from(
                                practice['overall'] as Map,
                              )
                            : <String, dynamic>{};

                    final int questions =
                        (overall['questions'] as num?)?.toInt() ?? 0;

                    final int correct =
                        (overall['correct'] as num?)?.toInt() ?? 0;

                    final double accuracy =
                        questions == 0 ? 0.0 : (correct / questions) * 100;
                    return Card(
                      key: const ValueKey('profile-learning-card'),
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tooltip(
                              key: const ValueKey('profile-learning-info'),
                              triggerMode: TooltipTriggerMode.tap,
                              message: _tr(context,
                                'প্রকাশিত পরীক্ষার ফলাফল ও সংরক্ষিত অনুশীলন সেশনের ভিত্তিতে।',
                                'Based on released test results and saved practice sessions.'),
                              child: Row(children: [
                                Expanded(child: Text(
                                  _tr(context, 'শেখার অগ্রগতি', 'Learning progress'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14),
                                )),
                                Icon(Icons.info_outline_rounded, size: 17,
                                  color: scheme.onSurfaceVariant),
                              ]),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: _learningMetric(
                                      data[0] == null ? '—' : results.length.toString(),
                                      _tr(context, 'মডেল টেস্ট',
                                          'Model tests'),
                                      Icons.fact_check_outlined)),
                              Expanded(
                                  child: _learningMetric(
                                      data[1] == null ? '—' : questions.toString(),
                                      _tr(context, 'অনুশীলন প্রশ্ন',
                                          'Practice questions'),
                                      Icons.quiz_outlined)),
                              Expanded(
                                  child: _learningMetric(
                                      data[1] == null ? '—' : '${accuracy.toStringAsFixed(0)}%',
                                      _tr(context, 'সঠিক উত্তর', 'Accuracy'),
                                      Icons.track_changes_outlined)),
                            ]),
                            if (data[1] != null && questions > 0) ...[
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(4),
                                value: (accuracy / 100).clamp(0.0, 1.0).toDouble(),
                                semanticsLabel: _tr(context, 'সঠিক উত্তর','Accuracy'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _sectionHeading(
                  _tr(context, 'শেখা ও অনুশীলন', 'Learning & practice'),
                  Icons.school_outlined,
                ),
                _menuGroup([
                  _menuTile(
                    icon: Icons.history_rounded,
                    title: _tr(context, 'মডেল টেস্টের ফলাফল', 'Model test results'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const MyTestResultsPage())),
                  ),
                  _menuTile(
                    icon: Icons.insights_rounded,
                    title: _tr(context, 'অনুশীলন ড্যাশবোর্ড', 'Practice dashboard'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PracticeDashboardPage())),
                  ),
                  _menuTile(
                    icon: Icons.menu_book_outlined,
                    title: _tr(context, 'নোট ও রিসোর্স', 'Notes & resources'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const NotesPage())),
                  ),
                  _menuTile(
                    icon: Icons.bookmark_rounded,
                    title: _tr(context, 'সংরক্ষিত নোট', 'Saved notes'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SavedNotesPage())),
                  ),
                ]),
                const SizedBox(height: 12),
                _sectionHeading(
                  _tr(context, 'অ্যাপ ও অ্যাকাউন্ট', 'App & account'),
                  Icons.tune_rounded,
                ),
                _menuGroup([
                  _menuTile(
                    icon: Icons.workspace_premium_outlined,
                    title: _tr(context, 'প্রিমিয়াম সদস্যপদ', 'Premium membership'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PremiumPage())),
                  ),
                  _menuTile(
                    icon: Icons.settings_outlined,
                    title: _tr(context, 'অ্যাপ সেটিংস', 'App settings'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
                  ),
                  _menuTile(
                    icon: Icons.notifications_active_outlined,
                    title: _tr(context, 'নোটিফিকেশন ইনবক্স', 'Notification inbox'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const NotificationInboxPage())),
                  ),
                  _menuTile(
                    icon: Icons.notifications_none_rounded,
                    title: _tr(context, 'নোটিফিকেশন পছন্দ', 'Notification preferences'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const NotificationPreferencesPage())),
                  ),
                  _menuTile(
                    icon: Icons.support_agent_rounded,
                    title: _tr(context, 'অ্যাডমিন সাপোর্ট', 'Admin support'),
                    onTap: _openSupport,
                  ),
                  _menuTile(
                    icon: Icons.info_outline_rounded,
                    title: _tr(context, 'অ্যাপ সম্পর্কে', 'About app'),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Fire Safety BD',
                      applicationVersion: '1.0.0',
                      applicationLegalese: _tr(context,
                        'ফায়ার সেফটি শেখা ও প্রস্তুতির ডিজিটাল প্ল্যাটফর্ম।',
                        'A digital platform for fire safety learning and preparation.'),
                    ),
                  ),
                  _menuTile(
                    icon: Icons.manage_accounts_outlined,
                    title: _tr(context, 'অ্যাকাউন্ট ও নিরাপত্তা', 'Account & security'),
                    onTap: () => _openAccountManagement(user),
                  ),
                ]),
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
                      color: scheme.primary.withOpacity(0.45),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: _scheme(context)),
      child: Builder(builder: _scaffold),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        backgroundColor: _deepMaroon,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: .24)),
            ),
            child: const Icon(Icons.person_rounded, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42,
            color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr(context, 'প্রোফাইল', 'Profile'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
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

class _PersonalInformationPage extends StatefulWidget {
  const _PersonalInformationPage({required this.user, required this.reload});
  final Map<String, dynamic> user;
  final Future<Map<String, dynamic>?> Function() reload;

  @override
  State<_PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<_PersonalInformationPage> {
  late Map<String, dynamic>? _user = widget.user;
  bool _loading = false;

  String _tr(BuildContext context, String bn, String en) => AppText.of(context, bn, en);

  String _value(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() => _loading = true);
    Map<String, dynamic>? user;
    try {
      user = await widget.reload();
    } catch (_) {
      // Do not continue displaying stale personal details after a failed reload.
    }
    if (!mounted) return;
    setState(() {
      _user = user;
      _loading = false;
    });
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EditProfilePage(user: user)),
    );
    if (!mounted || saved != true) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_tr(context, 'প্রোফাইল আপডেট হয়েছে।', 'Profile updated.')),
    ));
  }

  Widget _profileInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    dynamic value,
  ) {
    final scheme = _scheme(context);
    return Padding(
      key: ValueKey('profile-info-$label'),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, height: 1.2, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(_value(value),
                    style: const TextStyle(
                        fontSize: 14, height: 1.2, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = _scheme(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final user = _user;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: dark ? _deepMaroon : _maroon,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: _tr(context, 'ফিরে যান', 'Back'),
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
            child: const Icon(Icons.badge_outlined, size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(_tr(context, 'ব্যক্তিগত তথ্য', 'Personal information'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_tr(context, 'প্রোফাইল তথ্য লোড করা যায়নি।',
                      'Could not load profile information.'), textAlign: TextAlign.center),
                    TextButton(onPressed: _reload,
                      child: Text(_tr(context, 'আবার চেষ্টা করুন', 'Try again'))),
                  ]),
                ))
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 22),
                    children: [
                      Card(
                        key: const ValueKey('profile-personal-card'),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .65)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                        _profileInfoRow(
                            context,
                            Icons.person_outline,
                            _tr(context, 'পূর্ণ নাম', 'Full name'),
                            user['full_name']),
                        _profileInfoRow(context, Icons.email_outlined,
                            _tr(context, 'ইমেইল', 'Email'), user['email']),
                        _profileInfoRow(
                            context,
                            Icons.phone_outlined,
                            _tr(context, 'মোবাইল', 'Mobile'),
                            user['mobile_number']),
                        _profileInfoRow(
                            context,
                            Icons.work_outline,
                            _tr(context, 'বর্তমান অবস্থা', 'Current status'),
                            user['current_status']),
                        _profileInfoRow(
                            context,
                            Icons.business_outlined,
                            _tr(context, 'প্রতিষ্ঠান', 'Company'),
                            user['company_name']),
                        _profileInfoRow(
                            context,
                            Icons.badge_outlined,
                            _tr(context, 'পদবি', 'Designation'),
                            user['designation']),
                        _profileInfoRow(
                            context,
                            Icons.location_on_outlined,
                            _tr(context, 'কর্মস্থল', 'Job location'),
                            user['job_location']),
                        _profileInfoRow(
                            context,
                            Icons.home_outlined,
                            _tr(context, 'বর্তমান ঠিকানা', 'Current address'),
                            user['current_address']),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => _editProfile(user),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(_tr(context, 'তথ্য পরিবর্তন করুন', 'Edit information')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _AccountManagementPage extends StatefulWidget {
  const _AccountManagementPage({
    required this.email,
    required this.onDelete,
  });

  final String email;
  // Returns true only when the account was really deleted.
  final Future<bool> Function() onDelete;

  @override
  State<_AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<_AccountManagementPage> {
  bool _busy = false;

  Future<void> _handleDelete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final deleted = await widget.onDelete();
    if (!mounted) return;
    if (deleted) {
      // Close this page. The profile page then sends the user to login.
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: _scheme(context)),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final scheme = _scheme(context);
    String tr(String bn, String en) => AppText.of(context, bn, en);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 8,
        leadingWidth: 48,
        centerTitle: false,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? _deepMaroon : _maroon,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        leading: IconButton(
          tooltip: tr('ফিরে যান', 'Back'),
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
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
            child: const Icon(Icons.verified_user_outlined,
              size: 29, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Container(width: 1, height: 42, color: Colors.white.withValues(alpha: .55)),
          const SizedBox(width: 9),
          Expanded(child: Text(tr('অ্যাকাউন্ট ও নিরাপত্তা', 'Account & security'),
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 15.5,
              fontWeight: FontWeight.w500, height: 1.2))),
        ]),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user_outlined,
                    size: 22, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('আপনার অ্যাকাউন্ট', 'Your account'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
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
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 5, bottom: 8),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, size: 17, color: scheme.error),
              const SizedBox(width: 7),
              Expanded(child: Text(
                tr('অ্যাকাউন্ট ব্যবস্থাপনা', 'Account management'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: scheme.error),
              )),
            ]),
          ),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: scheme.error.withOpacity(0.35),
              ),
            ),
            child: ListTile(
              key: const ValueKey('account-delete-tile'),
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              horizontalTitleGap: 10,
              leading: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_forever_outlined,
                  size: 21, color: scheme.onErrorContainer),
              ),
              title: Text(
                tr('অ্যাকাউন্ট মুছুন', 'Delete account'),
                style: TextStyle(
                  color: scheme.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                _busy
                    ? tr('অপেক্ষা করুন...', 'Please wait...')
                    : tr('স্থায়ীভাবে অপসারণ · নিশ্চিতকরণ প্রয়োজন',
                        'Permanent removal · Confirmation required'),
                style: TextStyle(fontSize: 11, height: 1.35,
                  color: scheme.onSurfaceVariant),
              ),
              trailing:
                  Icon(Icons.chevron_right_rounded, color: scheme.error),
              onTap: _busy ? null : _handleDelete,
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
