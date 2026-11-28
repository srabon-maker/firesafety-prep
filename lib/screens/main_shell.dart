
import 'package:flutter/material.dart';

import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import 'home_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'marketplace_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.authorize, this.tabBuilder});

  // Optional test fixtures. Production retains the existing pages and guard.
  final Future<bool> Function(BuildContext)? authorize;
  final Widget Function(int index, bool active, VoidCallback onLogout)? tabBuilder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  bool _shopVisited = false;

  late final List<Widget> pages = [
    _tab(0, () => const HomePage()),
    // Community is mounted only after successful authentication.
    const SizedBox.shrink(),
  ];

  Widget _tab(int i, Widget Function() production) =>
      widget.tabBuilder?.call(i, index == i, _goToHome) ?? production();

  void _goToHome() {
    if (!mounted) return;

    setState(() {
      index = 0;
    });
  }

  Future<void> _onDestinationSelected(int i) async {
    // Home ও Marketplace সবার জন্য উন্মুক্ত
    if (i == 0 || i == 2) {
      setState(() {
        if (i == 2) _shopVisited = true;
        index = i;
      });
      return;
    }

    // অন্য পেজে প্রবেশের আগে Login যাচাই
    final authenticated =
        await (widget.authorize?.call(context) ??
            AuthGuard.ensureAuthenticated(context));

    if (!mounted || !authenticated) return;

    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope<Object?>(
      // Let Android handle normal root exit on Home. Other tabs return Home.
      // Normally the IME consumes Back first; guard the remaining events too.
      canPop: index == 0 && !keyboardVisible,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (keyboardVisible) {
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }
        if (index != 0) _goToHome();
      },
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            TickerMode(enabled: index == 0, child: pages[0]),
            if (index == 1) _tab(1, () => const CommunityPage())
            else pages[1],
            // Mount on first visit, then keep filters and scroll state alive.
            if (_shopVisited) _tab(2, () => MarketplacePage(active: index == 2))
            else const SizedBox.shrink(),
            // Mount only after AuthGuard succeeds. Discard account-specific
            // state on leaving Profile so a new login cannot see stale data.
            if (index == 3) _tab(3, () => ProfilePage(onLogout: _goToHome))
            else const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: MediaQuery.textScalerOf(context).scale(11) > 14 ? 80 : 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          animationDuration: MediaQuery.of(context).disableAnimations
              ? Duration.zero : const Duration(milliseconds: 220),
          selectedIndex: index,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          elevation: 2,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: AppText.of(context, 'হোম', 'Home'),
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: AppText.of(context, 'কমিউনিটি', 'Community'),
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: AppText.of(context, 'শপ', 'Shop'),
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: AppText.of(context, 'প্রোফাইল', 'Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
