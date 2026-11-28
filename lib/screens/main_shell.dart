
import 'package:flutter/material.dart';

import '../services/auth_guard.dart';
import '../settings/app_settings.dart';
import 'home_page.dart';
import 'community_page.dart';
import 'profile_page.dart';
import 'marketplace_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;

  late final List<Widget> pages = [
    const HomePage(),
    // Community is mounted only after successful authentication.
    const SizedBox.shrink(),
    const MarketplacePage(),

  ];

  void _goToHome() {
    if (!mounted) return;

    setState(() {
      index = 0;
    });
  }

  Future<void> _onDestinationSelected(int i) async {
    // Home ও Marketplace সবার জন্য উন্মুক্ত
    if (i == 0 || i == 2) {
      setState(() => index = i);
      return;
    }

    // অন্য পেজে প্রবেশের আগে Login যাচাই
    final authenticated =
        await AuthGuard.ensureAuthenticated(context);

    if (!mounted || !authenticated) return;

    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(
          index: index,
          children: [
            TickerMode(enabled: index == 0, child: pages[0]),
            if (index == 1) const CommunityPage()
            else pages[1],
            pages[2],
            // Mount only after AuthGuard succeeds. Discard account-specific
            // state on leaving Profile so a new login cannot see stale data.
            if (index == 3) ProfilePage(onLogout: _goToHome)
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
      );
}
