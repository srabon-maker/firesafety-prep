
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
    const CommunityPage(),
    const MarketplacePage(),
    ProfilePage(
      onLogout: _goToHome,
    ),
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
            ...pages.skip(1),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 76,
          animationDuration: const Duration(milliseconds: 240),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: index,
          backgroundColor: Theme.of(context).colorScheme.surface,
          indicatorColor: Theme.of(context).colorScheme.primaryContainer,
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: AppText.of(context, 'হোম', 'Home'),
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
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
